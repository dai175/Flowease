import Foundation
import Testing

@testable import Flowease

/// AlertSettingsのテスト
@MainActor
struct AlertSettingsTests {
    // MARK: - Default Value Tests

    @Test func defaultValuesAreCorrect() {
        // Given/When
        let settings = AlertSettings.default

        // Then
        #expect(settings.isEnabled == true)
        #expect(settings.threshold == 60)
        #expect(settings.evaluationPeriodSeconds == 300) // 5分
        #expect(settings.minimumIntervalSeconds == 900) // 15分
    }

    // MARK: - Threshold Validation Tests

    @Test func thresholdValidationRangeDefault() {
        // Given/When
        let settings = AlertSettings.default

        // Then
        #expect(AlertSettings.thresholdRange.contains(settings.threshold))
    }

    @Test func thresholdRangeIsCorrect() {
        // Given/When
        let range = AlertSettings.thresholdRange

        // Then
        #expect(range.lowerBound == 20)
        #expect(range.upperBound == 80)
    }

    // MARK: - Evaluation Period Validation Tests

    @Test func evaluationPeriodValidationRangeDefault() {
        // Given/When
        let settings = AlertSettings.default

        // Then
        #expect(AlertSettings.evaluationPeriodSecondsRange.contains(settings.evaluationPeriodSeconds))
    }

    @Test func evaluationPeriodRangeIsCorrect() {
        // Given/When
        let range = AlertSettings.evaluationPeriodSecondsRange

        // Then
        #expect(range.lowerBound == 60) // 1分
        #expect(range.upperBound == 600) // 10分
    }

    // MARK: - Minimum Interval Validation Tests

    @Test func minimumIntervalValidationRangeDefault() {
        // Given/When
        let settings = AlertSettings.default

        // Then
        #expect(AlertSettings.minimumIntervalSecondsRange.contains(settings.minimumIntervalSeconds))
    }

    @Test func minimumIntervalRangeIsCorrect() {
        // Given/When
        let range = AlertSettings.minimumIntervalSecondsRange

        // Then
        #expect(range.lowerBound == 300) // 5分
        #expect(range.upperBound == 3600) // 60分
    }

    // MARK: - Computed Properties Tests

    @Test func evaluationPeriodMinutesGetter() {
        // Given
        var settings = AlertSettings.default
        settings.evaluationPeriodSeconds = 300

        // When/Then
        #expect(settings.evaluationPeriodMinutes == 5)
    }

    @Test func evaluationPeriodMinutesSetter() {
        // Given
        var settings = AlertSettings.default

        // When
        settings.evaluationPeriodMinutes = 7

        // Then
        #expect(settings.evaluationPeriodSeconds == 420)
    }

    @Test func minimumIntervalMinutesGetter() {
        // Given
        var settings = AlertSettings.default
        settings.minimumIntervalSeconds = 1800

        // When/Then
        #expect(settings.minimumIntervalMinutes == 30)
    }

    @Test func minimumIntervalMinutesSetter() {
        // Given
        var settings = AlertSettings.default

        // When
        settings.minimumIntervalMinutes = 45

        // Then
        #expect(settings.minimumIntervalSeconds == 2700)
    }

    // MARK: - Codable Tests

    @Test func encodingAndDecodingPreservesValues() throws {
        // Given
        let original = AlertSettings(
            isEnabled: false,
            threshold: 50,
            evaluationPeriodSeconds: 180,
            minimumIntervalSeconds: 600
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AlertSettings.self, from: data)

        // Then
        #expect(decoded == original)
    }

    @Test func defaultSettingsCanBeEncodedAndDecoded() throws {
        // Given
        let original = AlertSettings.default

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AlertSettings.self, from: data)

        // Then
        #expect(decoded == original)
    }

    // MARK: - Equatable Tests

    @Test func equalSettingsAreEqual() {
        // Given
        let settings1 = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 300,
            minimumIntervalSeconds: 900
        )
        let settings2 = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 300,
            minimumIntervalSeconds: 900
        )

        // Then
        #expect(settings1 == settings2)
    }

    @Test func differentSettingsAreNotEqual() {
        // Given
        let settings1 = AlertSettings.default
        var settings2 = AlertSettings.default
        settings2.threshold = 50

        // Then
        #expect(settings1 != settings2)
    }
}

/// AlertSettingsStorageのテスト
@MainActor
struct AlertSettingsStorageTests {
    // MARK: - Test Helper

    /// テスト用のUserDefaultsスイート
    private func makeTestUserDefaults() -> UserDefaults {
        let suiteName = "cc.focuswave.Flowease.AlertSettingsStorageTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        // テスト開始時に既存データをクリア
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    // MARK: - Persistence Tests

    @Test func settingsAreSavedAndLoaded() {
        // Given
        let userDefaults = makeTestUserDefaults()
        let storage = AlertSettingsStorage(userDefaults: userDefaults)
        let customSettings = AlertSettings(
            isEnabled: false,
            threshold: 45,
            evaluationPeriodSeconds: 180,
            minimumIntervalSeconds: 1800
        )

        // When
        storage.save(customSettings)
        let loadedSettings = storage.load()

        // Then
        #expect(loadedSettings.isEnabled == false)
        #expect(loadedSettings.threshold == 45)
        #expect(loadedSettings.evaluationPeriodSeconds == 180)
        #expect(loadedSettings.minimumIntervalSeconds == 1800)
        #expect(loadedSettings == customSettings)
    }

    @Test func loadReturnsDefaultsWhenNoDataSaved() {
        // Given
        let userDefaults = makeTestUserDefaults()
        let storage = AlertSettingsStorage(userDefaults: userDefaults)

        // When
        let loadedSettings = storage.load()

        // Then
        #expect(loadedSettings == AlertSettings.default)
    }

    @Test func resetClearsAllSettings() {
        // Given
        let userDefaults = makeTestUserDefaults()
        let storage = AlertSettingsStorage(userDefaults: userDefaults)
        let customSettings = AlertSettings(
            isEnabled: false,
            threshold: 30,
            evaluationPeriodSeconds: 120,
            minimumIntervalSeconds: 600
        )
        storage.save(customSettings)

        // When
        storage.reset()
        let loadedSettings = storage.load()

        // Then
        #expect(loadedSettings == AlertSettings.default)
    }

    // MARK: - Validation Tests (Clamping)

    @Test func loadClampsThresholdBelowMinimum() {
        // Given
        let userDefaults = makeTestUserDefaults()
        userDefaults.set(10, forKey: AlertSettingsKeys.threshold) // 範囲外（下限20未満）

        let storage = AlertSettingsStorage(userDefaults: userDefaults)

        // When
        let loadedSettings = storage.load()

        // Then
        #expect(loadedSettings.threshold == 20) // 下限にクランプ
    }

    @Test func loadClampsThresholdAboveMaximum() {
        // Given
        let userDefaults = makeTestUserDefaults()
        userDefaults.set(100, forKey: AlertSettingsKeys.threshold) // 範囲外（上限80超過）

        let storage = AlertSettingsStorage(userDefaults: userDefaults)

        // When
        let loadedSettings = storage.load()

        // Then
        #expect(loadedSettings.threshold == 80) // 上限にクランプ
    }

    @Test func loadClampsEvaluationPeriodBelowMinimum() {
        // Given
        let userDefaults = makeTestUserDefaults()
        userDefaults.set(30, forKey: AlertSettingsKeys.evaluationPeriod) // 範囲外（下限60未満）

        let storage = AlertSettingsStorage(userDefaults: userDefaults)

        // When
        let loadedSettings = storage.load()

        // Then
        #expect(loadedSettings.evaluationPeriodSeconds == 60) // 下限にクランプ
    }

    @Test func loadClampsEvaluationPeriodAboveMaximum() {
        // Given
        let userDefaults = makeTestUserDefaults()
        userDefaults.set(1200, forKey: AlertSettingsKeys.evaluationPeriod) // 範囲外（上限600超過）

        let storage = AlertSettingsStorage(userDefaults: userDefaults)

        // When
        let loadedSettings = storage.load()

        // Then
        #expect(loadedSettings.evaluationPeriodSeconds == 600) // 上限にクランプ
    }

    @Test func loadClampsMinimumIntervalBelowMinimum() {
        // Given
        let userDefaults = makeTestUserDefaults()
        userDefaults.set(100, forKey: AlertSettingsKeys.minimumInterval) // 範囲外（下限300未満）

        let storage = AlertSettingsStorage(userDefaults: userDefaults)

        // When
        let loadedSettings = storage.load()

        // Then
        #expect(loadedSettings.minimumIntervalSeconds == 300) // 下限にクランプ
    }

    @Test func loadClampsMinimumIntervalAboveMaximum() {
        // Given
        let userDefaults = makeTestUserDefaults()
        userDefaults.set(7200, forKey: AlertSettingsKeys.minimumInterval) // 範囲外（上限3600超過）

        let storage = AlertSettingsStorage(userDefaults: userDefaults)

        // When
        let loadedSettings = storage.load()

        // Then
        #expect(loadedSettings.minimumIntervalSeconds == 3600) // 上限にクランプ
    }

    // MARK: - Partial Save Tests

    @Test func loadPreservesValidValuesWhenSomeInvalid() {
        // Given
        let userDefaults = makeTestUserDefaults()
        userDefaults.set(false, forKey: AlertSettingsKeys.isEnabled)
        userDefaults.set(50, forKey: AlertSettingsKeys.threshold) // 有効
        userDefaults.set(30, forKey: AlertSettingsKeys.evaluationPeriod) // 無効（下限未満）
        userDefaults.set(1200, forKey: AlertSettingsKeys.minimumInterval) // 有効

        let storage = AlertSettingsStorage(userDefaults: userDefaults)

        // When
        let loadedSettings = storage.load()

        // Then
        #expect(loadedSettings.isEnabled == false)
        #expect(loadedSettings.threshold == 50)
        #expect(loadedSettings.evaluationPeriodSeconds == 60) // クランプ
        #expect(loadedSettings.minimumIntervalSeconds == 1200)
    }
}

/// AlertStateのテスト
@MainActor
struct AlertStateTests {
    // MARK: - Initial State Tests

    @Test func initialStateHasCorrectValues() {
        // Given/When
        let state = AlertState.initial

        // Then
        #expect(state.lastNotificationTime == nil)
        #expect(state.hasImprovedSinceLastNotification == true)
    }

    // MARK: - State Modification Tests

    @Test func canSetLastNotificationTime() {
        // Given
        var state = AlertState.initial
        let notificationTime = Date()

        // When
        state.lastNotificationTime = notificationTime

        // Then
        #expect(state.lastNotificationTime == notificationTime)
    }

    @Test func canSetHasImprovedFlag() {
        // Given
        var state = AlertState.initial

        // When
        state.hasImprovedSinceLastNotification = false

        // Then
        #expect(state.hasImprovedSinceLastNotification == false)
    }

    // MARK: - Equatable Tests

    @Test func equalStatesAreEqual() {
        // Given
        let date = Date()
        let state1 = AlertState(
            lastNotificationTime: date,
            hasImprovedSinceLastNotification: false
        )
        let state2 = AlertState(
            lastNotificationTime: date,
            hasImprovedSinceLastNotification: false
        )

        // Then
        #expect(state1 == state2)
    }

    @Test func differentStatesAreNotEqual() {
        // Given
        let state1 = AlertState.initial
        var state2 = AlertState.initial
        state2.hasImprovedSinceLastNotification = false

        // Then
        #expect(state1 != state2)
    }
}
