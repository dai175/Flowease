import Foundation

/// アプリケーション全体の依存性注入コンテナ
/// シングルトンパターンでサービスを管理し、テスト時にはモックを注入可能
public final class ServiceContainer {

    // MARK: - Singleton

    public static let shared = ServiceContainer()

    // MARK: - Services

    /// 設定サービス
    public lazy var settingsService: SettingsServiceProtocol = {
        SettingsService()
    }()

    // 以下のサービスはPhase 3以降で実装
    // Phase 3: User Story 4 - メニューバーUI完成後に実装
    // Phase 4: User Story 1 - 姿勢検知機能で実装

    /// カメラサービス（Phase 4で実装）
    private var _cameraService: CameraServiceProtocol?
    public var cameraService: CameraServiceProtocol {
        get {
            guard let service = _cameraService else {
                fatalError("CameraService has not been registered. Call registerCameraService() first.")
            }
            return service
        }
    }

    /// 通知サービス（Phase 4で実装）
    private var _notificationService: NotificationServiceProtocol?
    public var notificationService: NotificationServiceProtocol {
        get {
            guard let service = _notificationService else {
                fatalError("NotificationService has not been registered. Call registerNotificationService() first.")
            }
            return service
        }
    }

    /// 姿勢検知サービス（Phase 4で実装）
    private var _postureDetectionService: PostureDetectionServiceProtocol?
    public var postureDetectionService: PostureDetectionServiceProtocol {
        get {
            guard let service = _postureDetectionService else {
                fatalError("PostureDetectionService has not been registered. Call registerPostureDetectionService() first.")
            }
            return service
        }
    }

    /// 休憩リマインダーサービス（Phase 5で実装）
    private var _breakReminderService: BreakReminderServiceProtocol?
    public var breakReminderService: BreakReminderServiceProtocol {
        get {
            guard let service = _breakReminderService else {
                fatalError(
                    "BreakReminderService has not been registered. Call registerBreakReminderService() first.")
            }
            return service
        }
    }

    /// ストレッチサービス（Phase 6で実装）
    private var _stretchService: StretchServiceProtocol?
    public var stretchService: StretchServiceProtocol {
        get {
            guard let service = _stretchService else {
                fatalError("StretchService has not been registered. Call registerStretchService() first.")
            }
            return service
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Service Registration

    /// カメラサービスを登録
    public func registerCameraService(_ service: CameraServiceProtocol) {
        _cameraService = service
    }

    /// 通知サービスを登録
    public func registerNotificationService(_ service: NotificationServiceProtocol) {
        _notificationService = service
    }

    /// 姿勢検知サービスを登録
    public func registerPostureDetectionService(_ service: PostureDetectionServiceProtocol) {
        _postureDetectionService = service
    }

    /// 休憩リマインダーサービスを登録
    public func registerBreakReminderService(_ service: BreakReminderServiceProtocol) {
        _breakReminderService = service
    }

    /// ストレッチサービスを登録
    public func registerStretchService(_ service: StretchServiceProtocol) {
        _stretchService = service
    }

    // MARK: - Service Availability Check

    /// カメラサービスが登録されているか
    public var isCameraServiceAvailable: Bool {
        _cameraService != nil
    }

    /// 通知サービスが登録されているか
    public var isNotificationServiceAvailable: Bool {
        _notificationService != nil
    }

    /// 姿勢検知サービスが登録されているか
    public var isPostureDetectionServiceAvailable: Bool {
        _postureDetectionService != nil
    }

    /// 休憩リマインダーサービスが登録されているか
    public var isBreakReminderServiceAvailable: Bool {
        _breakReminderService != nil
    }

    /// ストレッチサービスが登録されているか
    public var isStretchServiceAvailable: Bool {
        _stretchService != nil
    }

    // MARK: - Reset (for testing)

    /// 全てのサービスをリセット（テスト用）
    public func reset() {
        _cameraService = nil
        _notificationService = nil
        _postureDetectionService = nil
        _breakReminderService = nil
        _stretchService = nil
    }
}
