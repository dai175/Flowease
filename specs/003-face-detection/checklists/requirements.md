# Specification Quality Checklist: 顔検出ベースの姿勢検知

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-01-02
**Updated**: 2026-01-02
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Platform API specification is acceptable（※Vision Frameworkはプラットフォーム標準APIのため、検出方式の仕様として明記を許容）
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria reference platform capabilities where necessary（※Vision APIのプロパティ参照は許容）
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] Platform API references are justified（※macOS標準のVision Frameworkは唯一の選択肢のため許容）

## 指摘対応状況

| 指摘 | 対応状況 | 対応内容 |
|------|---------|---------|
| スコア算出仕様不足 | ✅ 対応済 | 「スコア算出仕様」セクション追加。3項目の重み・しきい値・計算式・欠損時の扱いを明記 |
| 成功指標の計測定義が曖昧 | ✅ 対応済 | SC-001/SC-004に計測条件・ベースラインを追加 |
| 複数人検出時の対象決定 | ✅ 対応済 | FR-007で「面積最大の顔」と明記 |
| UXの整合性 | ✅ 対応済 | 「顔未検出時のUX仕様」セクション追加。グレーアイコン＋メッセージの組み合わせを明記 |
| 既存キャリブレーション移行 | ✅ 対応済 | データ形式が異なる場合は自動クリア（FR-009）。特別な通知なし |
| 単位・座標系 | ✅ 対応済 | FR-002〜FR-004で正規化座標・ラジアン単位を明記 |
| SC-005の定量化 | ✅ 対応済 | 「SC-001と同等（±5%以内）」と明記 |
| SC-003のスコア計算整合性 | ✅ 対応済 | 20%→30%に変更（30%増加でサイズ項目0点→総合60点） |
| faceCaptureQualityの取得方法 | ✅ 対応済 | FR-001にVNDetectFaceCaptureQualityRequestを追加 |
| 旧形式データの暗黙クリア | ✅ 対応済 | Edge Casesに旧バージョンデータの扱いを追加 |
| SC-002のFPS依存 | ✅ 対応済 | Assumptionsに30FPS以上前提を追加 |
| yaw判定の要件不足 | ✅ 対応済 | Edge Cases/Assumptionsに「アプリ側でyaw判定は行わない」を明記 |
| 検出精度低下時の動作不明 | ✅ 対応済 | UX仕様テーブルに「動作」列追加、一時停止（スコア履歴クリア）と明記 |
| 複数顔のfaceCaptureQuality対応 | ✅ 対応済 | FR-007に「その顔のfaceCaptureQualityを使用」を追加 |
| 欠損フレームと一時停止の矛盾 | ✅ 対応済 | 「部分的データ欠損の扱い」に改名、顔未検出はUX仕様に従う旨を明記 |
| スコア算出の方向性未定義 | ✅ 対応済 | 各項目に「方向」列追加、計算式を明記（片方向/両方向） |
| roll角の±π不連続 | ✅ 対応済 | ラップアラウンドを考慮した最小角度差の計算式を追加 |
| ReferencePosture名の不一致 | ✅ 対応済 | spec.mdのKey EntitiesをFaceReferencePosture（新規型）に統一 |
| フレーム数とFPSの整合 | ✅ 対応済 | minimumFrameCount=30→15に変更（15FPS×1秒） |
| research.mdのデータ形式判定 | ✅ 対応済 | isFaceBasedFormat→デコード成否判定に統一 |
| チェックリストのAPI記述方針 | ✅ 対応済 | プラットフォームAPI参照は許容する方針に調整 |
| research.mdのReferencePosture記述 | ✅ 対応済 | 統合ポイントでReferencePosture/BaselineMetricsを「削除」と明記 |

## Notes

- 仕様は完全であり、`/speckit.plan` に進む準備ができています
- 既存のScoreCalculator、ReferencePosture、PauseReasonの構造を調査した上で仕様を策定
- Vision FrameworkのVNFaceObservationヘッダーを確認し、プロパティの詳細（座標系、単位、利用可能バージョン）を反映
