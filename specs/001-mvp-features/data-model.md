# Data Model: Flowease MVP機能

**Branch**: `001-mvp-features` | **Date**: 2025-12-28

## 概要

このドキュメントは、Flowease MVPのデータモデルを定義します。全てのモデルはSwift構造体として実装され、必要に応じてUserDefaultsに永続化されます。

---

## エンティティ一覧

```
┌─────────────────┐     ┌──────────────────┐
│  PostureState   │     │  BreakReminder   │
│  (姿勢状態)      │     │  (休憩管理)       │
└─────────────────┘     └──────────────────┘
         │                       │
         └───────────┬───────────┘
                     │
              ┌──────┴──────┐
              │ UserSettings │
              │ (ユーザー設定) │
              └─────────────┘
                     │
              ┌──────┴──────┐
              │   Stretch    │
              │ (ストレッチ)   │
              └─────────────┘
```

---

## 1. PostureState（姿勢状態）

ユーザーの現在の姿勢状態を表すモデル。

### 定義

```swift
/// 姿勢の判定レベル
enum PostureLevel: String, Codable, CaseIterable {
    case good = "good"         // 良い姿勢
    case warning = "warning"   // 注意
    case bad = "bad"           // 悪い姿勢
    case unknown = "unknown"   // 顔未検出・判定不能

    /// メニューバーアイコンの色
    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .yellow
        case .bad: return .red
        case .unknown: return .gray
        }
    }

    /// SF Symbolsアイコン名
    var iconName: String {
        switch self {
        case .good: return "figure.stand"
        case .warning: return "exclamationmark.triangle.fill"
        case .bad: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    /// ローカライズされた表示名
    var displayName: String {
        switch self {
        case .good: return "良好"
        case .warning: return "注意"
        case .bad: return "要改善"
        case .unknown: return "未検出"
        }
    }
}

/// 姿勢状態モデル
struct PostureState {
    /// 現在の姿勢レベル
    var level: PostureLevel

    /// 姿勢スコア（0.0〜1.0、1.0が最良）
    var score: Double

    /// 前かがみ角度（度）
    var forwardLeanAngle: Double

    /// 首の傾き角度（度）
    var neckTiltAngle: Double

    /// 最終更新時刻
    var lastUpdated: Date

    /// 悪い姿勢が続いている時間（秒）
    var badPostureDuration: TimeInterval

    /// 顔が検出されているか
    var isFaceDetected: Bool
}
```

### フィールド詳細

| フィールド | 型 | 説明 | バリデーション |
|-----------|-----|------|----------------|
| level | PostureLevel | 姿勢の判定レベル（good/warning/bad/unknown） | - |
| score | Double | 姿勢スコア | 0.0〜1.0 |
| forwardLeanAngle | Double | 前かがみ角度 | 0.0〜90.0 |
| neckTiltAngle | Double | 首の傾き角度 | 0.0〜90.0 |
| lastUpdated | Date | 最終更新時刻 | - |
| badPostureDuration | TimeInterval | 悪い姿勢継続時間 | >= 0.0 |
| isFaceDetected | Bool | 顔検出フラグ | - |

### 状態遷移

```
    ┌───────────────────┐
    │      unknown      │◄─────── 顔未検出 ─────────┐
    │   (未検出)         │                          │
    └───────────────────┘                          │
             │                                      │
             │ 顔検出                               │
             ▼                                      │
                 ┌─────────────────────────────────┐│
                 │                                 ││
                 ▼                                 ││
    ┌───────────────────┐                         ││
    │       good        │◄────────────────────────┤│
    │   (良い姿勢)       │                         ││
    └───────────────────┘                         ││
             │                                    ││
             │ score < 0.6                        ││
             ▼                                    ││
    ┌───────────────────┐                         ││
    │      warning      │ ───► score >= 0.8 ─────┘│
    │   (注意)          │                          │
    └───────────────────┘                          │
             │                                      │
             │ score < 0.4 && duration >= 5秒      │
             ▼                                      │
    ┌───────────────────┐                          │
    │        bad        │ ───► score >= 0.6 ──► warning
    │   (悪い姿勢)       │                          │
    └───────────────────┘──────────────────────────┘
             │
             │ 5秒継続
             ▼
       [通知を送信]

※ unknown状態では通知を送信しない
※ unknown状態では badPostureDuration をリセット
```

### 永続化

**永続化しない**（リアルタイムの状態のみ）

---

## 2. BreakReminder（休憩リマインダー）

休憩リマインダーの設定と状態を管理するモデル。

### 定義

```swift
/// 休憩リマインダーモデル
struct BreakReminder: Codable {
    /// 休憩間隔（分）
    var intervalMinutes: Int

    /// 次回通知予定時刻
    var nextReminderTime: Date?

    /// リマインダーが有効か
    var isEnabled: Bool

    /// 最後に休憩した時刻
    var lastBreakTime: Date?

    /// スヌーズ回数（現在のセッション）
    var snoozeCount: Int

    /// 次の休憩までの残り時間（秒）
    var timeUntilNextBreak: TimeInterval? {
        guard let nextTime = nextReminderTime else { return nil }
        return nextTime.timeIntervalSinceNow
    }
}
```

### フィールド詳細

| フィールド | 型 | 説明 | バリデーション |
|-----------|-----|------|----------------|
| intervalMinutes | Int | 休憩間隔 | 30〜60 |
| nextReminderTime | Date? | 次回通知時刻 | nil = 未設定 |
| isEnabled | Bool | 有効/無効 | - |
| lastBreakTime | Date? | 最終休憩時刻 | - |
| snoozeCount | Int | スヌーズ回数 | >= 0 |

### デフォルト値

```swift
extension BreakReminder {
    static let `default` = BreakReminder(
        intervalMinutes: 30,
        nextReminderTime: nil,
        isEnabled: true,
        lastBreakTime: nil,
        snoozeCount: 0
    )
}
```

### 永続化

**UserDefaults**に保存
- キー: `com.flowease.breakReminder`

---

## 3. Stretch（ストレッチ）

ストレッチの情報を表すモデル。

### 定義

```swift
/// ストレッチカテゴリ
enum StretchCategory: String, Codable, CaseIterable {
    case neck = "neck"       // 首
    case shoulder = "shoulder" // 肩
    case back = "back"       // 腰・背中
    case fullBody = "fullBody" // 全身

    var displayName: String {
        switch self {
        case .neck: return "首"
        case .shoulder: return "肩"
        case .back: return "腰・背中"
        case .fullBody: return "全身"
        }
    }
}

/// ストレッチモデル
struct Stretch: Identifiable, Codable {
    /// 一意の識別子
    let id: String

    /// ストレッチ名
    let name: String

    /// カテゴリ
    let category: StretchCategory

    /// 所要時間（秒）
    let durationSeconds: Int

    /// 説明文
    let description: String

    /// 手順（ステップごと）
    let steps: [String]

    /// アニメーションアセット名
    let animationAsset: String
}
```

### フィールド詳細

| フィールド | 型 | 説明 | バリデーション |
|-----------|-----|------|----------------|
| id | String | 一意識別子 | UUID形式 |
| name | String | ストレッチ名 | 1〜50文字 |
| category | StretchCategory | カテゴリ | enum値 |
| durationSeconds | Int | 所要時間 | 10〜120 |
| description | String | 説明文 | 1〜200文字 |
| steps | [String] | 手順リスト | 1〜5ステップ |
| animationAsset | String | アニメーション名 | - |

### 静的データ（組み込み）

```swift
extension Stretch {
    static let allStretches: [Stretch] = [
        Stretch(
            id: "neck-rotation",
            name: "首回し",
            category: .neck,
            durationSeconds: 30,
            description: "左右にゆっくり首を回し、首の筋肉をほぐします。",
            steps: [
                "正面を向いて姿勢を正します",
                "ゆっくりと首を右に回します",
                "正面に戻り、左に回します",
                "3回繰り返します"
            ],
            animationAsset: "stretch_neck_rotation"
        ),
        Stretch(
            id: "neck-stretch",
            name: "首筋伸ばし",
            category: .neck,
            durationSeconds: 30,
            description: "首の横を伸ばして、凝りをほぐします。",
            steps: [
                "正面を向いて姿勢を正します",
                "右手で頭を右に傾けます",
                "15秒キープします",
                "反対側も同様に行います"
            ],
            animationAsset: "stretch_neck_side"
        ),
        Stretch(
            id: "shoulder-rotation",
            name: "肩回し",
            category: .shoulder,
            durationSeconds: 30,
            description: "両肩を前後に回して、肩こりを解消します。",
            steps: [
                "両肩をすくめるように上げます",
                "後ろに回しながら下げます",
                "前回し5回、後ろ回し5回行います"
            ],
            animationAsset: "stretch_shoulder_rotation"
        ),
        Stretch(
            id: "shoulder-blade",
            name: "肩甲骨寄せ",
            category: .shoulder,
            durationSeconds: 30,
            description: "肩甲骨を寄せて胸を開き、猫背を改善します。",
            steps: [
                "両手を後ろで組みます",
                "胸を張りながら肩甲骨を寄せます",
                "15秒キープします"
            ],
            animationAsset: "stretch_shoulder_blade"
        ),
        Stretch(
            id: "back-twist",
            name: "腰ひねり",
            category: .back,
            durationSeconds: 30,
            description: "椅子に座ったまま腰をひねり、背中の緊張を緩めます。",
            steps: [
                "椅子に深く座ります",
                "右手を左膝に置き、体を左にひねります",
                "15秒キープします",
                "反対側も同様に行います"
            ],
            animationAsset: "stretch_back_twist"
        ),
        Stretch(
            id: "full-stretch",
            name: "背伸び",
            category: .fullBody,
            durationSeconds: 30,
            description: "両手を上げて全身を伸ばし、リフレッシュします。",
            steps: [
                "両手を頭の上で組みます",
                "息を吸いながら上に伸びます",
                "5秒キープして息を吐きます",
                "3回繰り返します"
            ],
            animationAsset: "stretch_full_body"
        )
    ]
}
```

### 永続化

**永続化しない**（静的データとしてアプリにバンドル）

---

## 4. UserSettings（ユーザー設定）

ユーザー設定を管理するモデル。

### 定義

```swift
/// ユーザー設定モデル
struct UserSettings: Codable {
    /// 選択されたカメラのデバイスID
    var selectedCameraID: String?

    /// 休憩リマインダー間隔（分）
    var breakIntervalMinutes: Int

    /// 姿勢判定の感度（0.0〜1.0、高いほど厳しい）
    var postureSensitivity: Double

    /// 通知が有効か
    var notificationsEnabled: Bool

    /// 姿勢モニタリングが有効か
    var postureMonitoringEnabled: Bool

    /// 前かがみ警告の閾値（度）
    var forwardLeanThreshold: Double

    /// 首傾き警告の閾値（度）
    var neckTiltThreshold: Double

    /// 悪い姿勢の警告までの時間（秒）
    var badPostureAlertDelay: TimeInterval
}
```

### フィールド詳細

| フィールド | 型 | 説明 | デフォルト値 | バリデーション |
|-----------|-----|------|-------------|----------------|
| selectedCameraID | String? | カメラID | nil (自動選択) | - |
| breakIntervalMinutes | Int | 休憩間隔 | 30 | 30〜60 |
| postureSensitivity | Double | 姿勢感度 | 0.5 | 0.0〜1.0 |
| notificationsEnabled | Bool | 通知有効 | true | - |
| postureMonitoringEnabled | Bool | 姿勢監視有効 | true | - |
| forwardLeanThreshold | Double | 前かがみ閾値 | 15.0 | 5.0〜30.0 |
| neckTiltThreshold | Double | 首傾き閾値 | 20.0 | 10.0〜40.0 |
| badPostureAlertDelay | TimeInterval | 警告遅延 | 5.0 | 3.0〜10.0 |

### デフォルト値

```swift
extension UserSettings {
    static let `default` = UserSettings(
        selectedCameraID: nil,
        breakIntervalMinutes: 30,
        postureSensitivity: 0.5,
        notificationsEnabled: true,
        postureMonitoringEnabled: true,
        forwardLeanThreshold: 15.0,
        neckTiltThreshold: 20.0,
        badPostureAlertDelay: 5.0
    )
}
```

### 永続化

**UserDefaults**に保存
- キー: `com.flowease.userSettings`

---

## 5. StretchSession（ストレッチセッション）

ストレッチセッションの進行状況を管理するモデル。

### 定義

```swift
/// ストレッチセッションモデル
struct StretchSession {
    /// セッションに含まれるストレッチ
    let stretches: [Stretch]

    /// 現在のストレッチインデックス
    var currentIndex: Int

    /// 現在のストレッチ内の経過時間（秒）
    var elapsedSeconds: Int

    /// セッション開始時刻
    let startedAt: Date

    /// セッションが完了したか
    var isCompleted: Bool {
        currentIndex >= stretches.count
    }

    /// 現在のストレッチ
    var currentStretch: Stretch? {
        guard currentIndex < stretches.count else { return nil }
        return stretches[currentIndex]
    }

    /// 進捗率（0.0〜1.0）
    var progress: Double {
        let totalDuration = stretches.reduce(0) { $0 + $1.durationSeconds }
        let completedDuration = stretches.prefix(currentIndex).reduce(0) { $0 + $1.durationSeconds }
        return Double(completedDuration + elapsedSeconds) / Double(totalDuration)
    }
}
```

### 永続化

**永続化しない**（セッション中のみ保持）

---

## 6. CameraDevice（カメラデバイス）

利用可能なカメラデバイスを表すモデル。

### 定義

```swift
/// カメラデバイスモデル
struct CameraDevice: Identifiable {
    /// デバイスの一意識別子
    let id: String

    /// デバイス名
    let name: String

    /// 内蔵カメラか
    let isBuiltIn: Bool

    /// デバイスの位置
    let position: AVCaptureDevice.Position
}
```

### 永続化

**永続化しない**（起動時にシステムから取得）

---

## データフロー図

```
┌──────────────────────────────────────────────────────────────────┐
│                          起動時                                  │
│  ┌──────────────┐                    ┌──────────────────────┐   │
│  │ UserDefaults │ ──load──►          │ UserSettings         │   │
│  └──────────────┘                    │ BreakReminder        │   │
│                                      └──────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                        実行時                                    │
│                                                                  │
│  ┌────────────┐    ┌─────────────────┐    ┌──────────────────┐  │
│  │   Camera   │───►│ VisionFramework │───►│  PostureState    │  │
│  └────────────┘    └─────────────────┘    └──────────────────┘  │
│                                                  │               │
│                                                  ▼               │
│                                           ┌──────────────────┐  │
│                                           │ NotificationSvc  │  │
│                                           └──────────────────┘  │
│                                                                  │
│  ┌────────────────┐                       ┌──────────────────┐  │
│  │ BreakReminder  │◄──────────────────────│     Timer        │  │
│  └────────────────┘                       └──────────────────┘  │
│         │                                                        │
│         ▼                                                        │
│  ┌────────────────┐                       ┌──────────────────┐  │
│  │ StretchSession │───────────────────────│    StretchView   │  │
│  └────────────────┘                       └──────────────────┘  │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       設定変更時                                 │
│  ┌──────────────────┐                    ┌──────────────────┐   │
│  │  SettingsView    │ ──update──►        │ UserSettings     │   │
│  └──────────────────┘                    └──────────────────┘   │
│                                                  │               │
│                                                  ▼               │
│                                          ┌──────────────┐       │
│                                          │ UserDefaults │       │
│                                          └──────────────┘       │
└──────────────────────────────────────────────────────────────────┘
```

---

## UserDefaults キー一覧

| キー | 型 | 説明 |
|------|-----|------|
| `com.flowease.userSettings` | Data (JSON) | ユーザー設定 |
| `com.flowease.breakReminder` | Data (JSON) | 休憩リマインダー設定 |
| `com.flowease.lastVersion` | String | 最後に起動したバージョン |
| `com.flowease.onboardingCompleted` | Bool | オンボーディング完了フラグ |
