import CoreGraphics
import Testing
@testable import Flowease

/// FaceDetectorサービスのテスト
///
/// TDD: T009 - 顔検出ロジックを検証
///
/// NOTE: VNFaceObservationはfinal classでモック化不可のため、
/// 以下のアプローチでテスト可能なロジックを検証:
/// - CGRectベースの面積計算ロジック
/// - 距離計算によるマッチングロジック
/// - FacePosition生成時のバリデーション
@MainActor
struct FaceDetectorTests {
    // MARK: - CGRect.area Tests

    /// CGRectの面積計算が正しく動作することを検証
    @Test func cgRectAreaCalculation() {
        let rect = CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.4)
        #expect(rect.area == 0.2)
    }

    /// 幅0のCGRectの面積は0
    @Test func cgRectAreaWithZeroWidth() {
        let rect = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.4)
        #expect(rect.area == 0.0)
    }

    /// 高さ0のCGRectの面積は0
    @Test func cgRectAreaWithZeroHeight() {
        let rect = CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.0)
        #expect(rect.area == 0.0)
    }

    /// 正方形のCGRectの面積計算
    @Test func cgRectAreaSquare() {
        let rect = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        #expect(rect.area == 0.25)
    }

    // MARK: - selectLargestFace Logic Tests (via CGRect)

    /// 最大面積の矩形が選択されることを検証
    /// NOTE: VNFaceObservationはモック化不可のため、CGRect比較ロジックで代替検証
    @Test func largestRectFromMultiple() {
        let rects = [
            CGRect(x: 0.0, y: 0.0, width: 0.1, height: 0.1), // area = 0.01
            CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.4), // area = 0.12 (largest)
            CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.2), // area = 0.04
        ]

        let largest = rects.max { $0.area < $1.area }
        #expect(largest?.area == 0.12)
    }

    /// 空配列の場合はnilを返す
    @Test func noRectFromEmpty() {
        let rects: [CGRect] = []
        let largest = rects.max { $0.area < $1.area }
        #expect(largest == nil)
    }

    /// 単一要素の場合はその要素を返す
    @Test func singleRectReturned() {
        let rects = [CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5)]
        let largest = rects.max { $0.area < $1.area }
        #expect(largest != nil)
        #expect(largest?.area == 0.25)
    }

    /// 同じ面積の場合は先頭の要素が選択される（max(by:)の動作）
    @Test func equalAreaSelectsFirst() {
        let rects = [
            CGRect(x: 0.0, y: 0.0, width: 0.2, height: 0.25), // area = 0.05
            CGRect(x: 0.5, y: 0.5, width: 0.25, height: 0.2), // area = 0.05
        ]

        let largest = rects.max { $0.area < $1.area }
        // max(by:)は等価の場合、先頭の要素を保持する
        #expect(largest?.origin.x == 0.0)
    }

    // MARK: - Distance Calculation Tests (for findMatchingQuality)

    /// 同じ中心点のCGRectは距離0
    @Test func distanceBetweenIdenticalRects() {
        let rect1 = CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3)
        let rect2 = CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3)

        let distance = calculateDistance(rect1, rect2)
        #expect(distance == 0.0)
    }

    /// 異なる中心点のCGRect間の距離
    @Test func distanceBetweenDifferentRects() {
        // rect1: center = (0.4, 0.45)
        let rect1 = CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3)
        // rect2: center = (0.7, 0.65)
        let rect2 = CGRect(x: 0.5, y: 0.5, width: 0.4, height: 0.3)

        let distance = calculateDistance(rect1, rect2)
        // dx = 0.3, dy = 0.2, distance = sqrt(0.09 + 0.04) = sqrt(0.13) ≈ 0.3606
        #expect(abs(distance - 0.3606) < 0.001)
    }

    /// 近い矩形が選択されることを検証
    @Test func closestRectIsSelected() {
        let target = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2) // center = (0.5, 0.5)
        let candidates = [
            CGRect(x: 0.0, y: 0.0, width: 0.2, height: 0.2), // center = (0.1, 0.1), far
            CGRect(x: 0.45, y: 0.45, width: 0.2, height: 0.2), // center = (0.55, 0.55), close
            CGRect(x: 0.7, y: 0.7, width: 0.2, height: 0.2), // center = (0.8, 0.8), medium
        ]

        let closest = candidates.min { calculateDistance(target, $0) < calculateDistance(target, $1) }
        #expect(closest?.origin.x == 0.45)
    }

    // MARK: - FaceDetector Instance Tests

    /// FaceDetectorがプロトコルに準拠していることを確認
    @Test func conformsToProtocol() {
        let detector = FaceDetector()
        #expect(detector is FaceDetectorProtocol)
    }

    /// FaceDetectorがSendableであることを確認
    @Test func isSendable() {
        let detector = FaceDetector()
        Task {
            // Sendableでなければコンパイルエラー
            _ = detector
        }
    }

    // MARK: - Test Helpers

    /// 2つのCGRect間の距離を計算（FaceDetectorの内部ロジックを再現）
    private func calculateDistance(_ rectA: CGRect, _ rectB: CGRect) -> CGFloat {
        let dx = rectA.midX - rectB.midX
        let dy = rectA.midY - rectB.midY
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Mock FaceDetector

/// テスト用のモックFaceDetector
final class MockFaceDetector: FaceDetectorProtocol, Sendable {
    /// 返却する結果
    private let resultToReturn: Result<FacePosition, FaceDetectionError>

    /// detectが呼ばれた回数をアトミックに管理
    private let callCountActor = CallCountActor()

    /// detectが呼ばれた回数
    var detectCallCount: Int {
        get async { await callCountActor.count }
    }

    /// 成功ケース用イニシャライザ
    init(positionToReturn: FacePosition) {
        self.resultToReturn = .success(positionToReturn)
    }

    /// 失敗ケース用イニシャライザ
    init(errorToReturn: FaceDetectionError = .noFaceDetected) {
        self.resultToReturn = .failure(errorToReturn)
    }

    func detect(from _: sending CMSampleBuffer) async -> Result<FacePosition, FaceDetectionError> {
        await callCountActor.increment()
        return resultToReturn
    }
}

/// 呼び出し回数をアクターで管理
private actor CallCountActor {
    var count = 0

    func increment() {
        count += 1
    }
}

// MARK: - CMSampleBuffer Stub

import AVFoundation

/// テスト用のCMSampleBufferスタブ型宣言
/// NOTE: 実際のCMSampleBuffer生成は複雑なため、テストではnilを返すモックを使用
