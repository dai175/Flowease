//
//  PostureDetectionServiceTests.swift
//  FloweaseTests
//
//  Created by Daisuke Ooba on 2025/12/29.
//

import AVFoundation
import Combine
import CoreVideo
import XCTest

@testable import Flowease

/// PostureDetectionService のテスト
final class PostureDetectionServiceTests: XCTestCase {
    // MARK: - Properties

    private var sut: PostureDetectionService!
    private var mockCameraService: MockCameraService!
    private var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        mockCameraService = MockCameraService()
        sut = PostureDetectionService(cameraService: mockCameraService)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockCameraService = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertFalse(sut.isDetecting, "Service should not be detecting initially")
        XCTAssertNil(sut.currentPosture, "Current posture should be nil initially")
    }

    // MARK: - Start Detection Tests

    func testStartDetectionUpdatesIsDetecting() async throws {
        mockCameraService.authorizationStatus = .authorized

        try await sut.startDetection(cameraDeviceID: nil)

        XCTAssertTrue(sut.isDetecting, "Service should be detecting after start")
    }

    func testStartDetectionThrowsWhenCameraAccessDenied() async {
        mockCameraService.authorizationStatus = .denied

        do {
            try await sut.startDetection(cameraDeviceID: nil)
            XCTFail("Should throw when camera access is denied")
        } catch let error as PostureDetectionError {
            XCTAssertEqual(error, .cameraAccessDenied)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testStartDetectionThrowsWhenAlreadyRunning() async throws {
        mockCameraService.authorizationStatus = .authorized

        try await sut.startDetection(cameraDeviceID: nil)

        do {
            try await sut.startDetection(cameraDeviceID: nil)
            XCTFail("Should throw when already running")
        } catch let error as PostureDetectionError {
            XCTAssertEqual(error, .alreadyRunning)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Stop Detection Tests

    func testStopDetectionUpdatesIsDetecting() async throws {
        mockCameraService.authorizationStatus = .authorized
        try await sut.startDetection(cameraDeviceID: nil)

        sut.stopDetection()

        XCTAssertFalse(sut.isDetecting, "Service should not be detecting after stop")
    }

    // MARK: - Posture Publisher Tests

    func testPosturePublisherReceivesUpdates() async throws {
        mockCameraService.authorizationStatus = .authorized

        let expectation = XCTestExpectation(description: "Posture update received")
        var receivedPosture: PostureState?

        sut.posturePublisher
            .compactMap { $0 }
            .first()
            .sink { posture in
                receivedPosture = posture
                expectation.fulfill()
            }
            .store(in: &cancellables)

        try await sut.startDetection(cameraDeviceID: nil)

        // Simulate frame from camera
        mockCameraService.simulateFrame()

        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertNotNil(receivedPosture, "Should receive posture update")
    }

    // MARK: - Detection Interval Tests

    func testDetectionRespectsInterval() async throws {
        mockCameraService.authorizationStatus = .authorized

        var updateCount = 0
        let expectation = XCTestExpectation(description: "At least one frame processed")

        sut.posturePublisher
            .compactMap { $0 }
            .sink { _ in
                updateCount += 1
                if updateCount == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        try await sut.startDetection(cameraDeviceID: nil)

        // Send first frame - should be processed immediately
        mockCameraService.simulateFrame()

        // Wait a bit for processing
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second

        // Send more frames rapidly - should be skipped due to interval
        for _ in 0 ..< 5 {
            mockCameraService.simulateFrame()
        }

        await fulfillment(of: [expectation], timeout: 3.0)

        // First frame should be processed, subsequent rapid frames should be skipped
        // Due to 2-second interval, only 1 update should be received in 0.5 seconds
        XCTAssertEqual(updateCount, 1, "Only first frame should be processed within interval")
    }

    // MARK: - Face Detection Tests

    // Note: Empty pixel buffer naturally results in no face detection by Vision Framework
    func testPostureUnknownWhenNoFaceDetected() async throws {
        mockCameraService.authorizationStatus = .authorized

        let expectation = XCTestExpectation(description: "Posture update received")
        var receivedPosture: PostureState?

        sut.posturePublisher
            .compactMap { $0 }
            .first()
            .sink { posture in
                receivedPosture = posture
                expectation.fulfill()
            }
            .store(in: &cancellables)

        try await sut.startDetection(cameraDeviceID: nil)
        mockCameraService.simulateFrame()

        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertEqual(receivedPosture?.level, .unknown)
        XCTAssertFalse(receivedPosture?.isFaceDetected ?? true)
    }
}

// MARK: - Mock Camera Service

final class MockCameraService: CameraServiceProtocol {
    // MARK: - Properties

    var availableCameras: [CameraDevice] = []
    var currentCamera: CameraDevice?
    var isActive = false

    private let frameSubject = PassthroughSubject<CVPixelBuffer, Never>()
    var framePublisher: AnyPublisher<CVPixelBuffer, Never> {
        frameSubject.eraseToAnyPublisher()
    }

    // MARK: - Mock Configuration

    var authorizationStatus: AVAuthorizationStatus = .notDetermined

    // MARK: - CameraServiceProtocol

    func checkAuthorization() async -> AVAuthorizationStatus {
        authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        authorizationStatus == .authorized
    }

    func startCamera(deviceID _: String?) async throws {
        guard authorizationStatus == .authorized else {
            throw CameraError.accessDenied
        }
        isActive = true
    }

    func stopCamera() async {
        isActive = false
    }

    func switchCamera(to _: String) async throws {
        // Mock implementation
    }

    func refreshAvailableCameras() {
        // Mock implementation
    }

    // MARK: - Simulation Methods

    func simulateFrame() {
        // Create a minimal pixel buffer for testing
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            640,
            480,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        if let buffer = pixelBuffer {
            frameSubject.send(buffer)
        }
    }
}
