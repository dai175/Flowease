import Foundation

/// ストレッチカテゴリ
public enum StretchCategory: String, Codable, CaseIterable, Sendable {
    case neck // 首
    case shoulder // 肩
    case back // 腰・背中
    case fullBody // 全身

    public var displayName: String {
        switch self {
        case .neck: return "首"
        case .shoulder: return "肩"
        case .back: return "腰・背中"
        case .fullBody: return "全身"
        }
    }

    /// SF Symbolsアイコン名
    public var iconName: String {
        switch self {
        case .neck: return "figure.cooldown"
        case .shoulder: return "figure.arms.open"
        case .back: return "figure.flexibility"
        case .fullBody: return "figure.mixed.cardio"
        }
    }
}

/// ストレッチモデル
public struct Stretch: Identifiable, Codable, Sendable {
    /// 一意の識別子
    public let id: String

    /// ストレッチ名
    public let name: String

    /// カテゴリ
    public let category: StretchCategory

    /// 所要時間（秒）
    public let durationSeconds: Int

    /// 説明文
    public let description: String

    /// 手順（ステップごと）
    public let steps: [String]

    /// アニメーションアセット名
    public let animationAsset: String

    public init(
        id: String,
        name: String,
        category: StretchCategory,
        durationSeconds: Int,
        description: String,
        steps: [String],
        animationAsset: String
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.durationSeconds = max(
            Constants.Stretch.minimumDurationSeconds,
            min(Constants.Stretch.maximumDurationSeconds, durationSeconds)
        )
        self.description = description
        self.steps = steps
        self.animationAsset = animationAsset
    }
}

// MARK: - Static Data

public extension Stretch {
    /// 全ての組み込みストレッチ
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
                "3回繰り返します",
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
                "反対側も同様に行います",
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
                "前回し5回、後ろ回し5回行います",
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
                "15秒キープします",
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
                "反対側も同様に行います",
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
                "3回繰り返します",
            ],
            animationAsset: "stretch_full_body"
        ),
    ]

    /// カテゴリ別のストレッチを取得
    static func stretches(for category: StretchCategory) -> [Stretch] {
        allStretches.filter { $0.category == category }
    }
}
