# Quickstart: Flowease MVP開発ガイド

**Branch**: `001-mvp-features` | **Date**: 2025-12-28

## 前提条件

| 項目 | 要件 |
|------|------|
| macOS | 14.6 (Sonoma) 以降 |
| Xcode | 15.0 以降 |
| Swift | 5.0 |
| カメラ | 内蔵または外部カメラ |

---

## 環境セットアップ

### 1. リポジトリのクローン

```bash
git clone https://github.com/your-org/Flowease.git
cd Flowease
git checkout 001-mvp-features
```

### 2. Xcodeでプロジェクトを開く

```bash
open Flowease.xcodeproj
```

### 3. 署名設定

1. Xcode で `Flowease` ターゲットを選択
2. **Signing & Capabilities** タブを開く
3. **Team** を自分の開発者チームに設定
4. **Bundle Identifier** を必要に応じて変更

### 4. ビルドと実行

1. ターゲットとして `My Mac` を選択
2. `Cmd + R` でビルド＆実行

---

## プロジェクト構造

```
Flowease/
├── Flowease/
│   ├── App/
│   │   ├── FloweaseApp.swift        # @main エントリーポイント
│   │   └── AppDelegate.swift        # メニューバー管理
│   ├── Models/                      # データモデル
│   ├── Services/                    # ビジネスロジック
│   ├── Views/                       # SwiftUI ビュー
│   ├── Resources/
│   │   └── Info.plist               # カメラ権限設定
│   └── Utilities/                   # ヘルパー
├── FloweaseTests/                   # ユニットテスト
└── FloweaseUITests/                 # UIテスト
```

---

## 主要ファイルの説明

### FloweaseApp.swift

アプリケーションのエントリーポイント。

```swift
import SwiftUI

@main
struct FloweaseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
```

### AppDelegate.swift

メニューバーとポップオーバーを管理。

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupNotifications()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // アイコン設定...
    }
}
```

### PostureDetectionService.swift

姿勢検知の中核ロジック。

```swift
import Vision
import AVFoundation
import Combine

class PostureDetectionService: PostureDetectionServiceProtocol {
    var currentPosture = CurrentValueSubject<PostureState?, Never>(nil)

    func startDetection(cameraDeviceID: String?) async throws {
        // カメラ起動と姿勢検知開始
    }

    func detectPosture(from pixelBuffer: CVPixelBuffer) async throws -> PostureState {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw PostureDetectionError.noPoseDetected
        }

        return evaluatePosture(observation)
    }
}
```

---

## 開発ワークフロー

### テスト駆動開発（TDD）

Constitutionに従い、Red-Green-Refactorサイクルを実践します。

```bash
# テストを実行
xcodebuild test -scheme Flowease -destination 'platform=macOS'
```

#### 1. テストを先に書く（Red）

```swift
// FloweaseTests/PostureDetectionServiceTests.swift
import XCTest
@testable import Flowease

class PostureDetectionServiceTests: XCTestCase {
    func testGoodPostureDetection() async throws {
        let service = PostureDetectionService()
        // テスト用のモックフレームを生成
        let mockBuffer = createMockPixelBuffer(posture: .good)

        let result = try await service.detectPosture(from: mockBuffer)

        XCTAssertEqual(result.level, .good)
    }
}
```

#### 2. 最小限の実装（Green）

テストを通過する最小限のコードを実装。

#### 3. リファクタリング（Refactor）

コードを整理し、重複を削除。

### ブランチ戦略

```
main                  # 安定版
  └── 001-mvp-features  # 現在の開発ブランチ
        ├── feature/posture-detection
        ├── feature/menu-bar-ui
        └── feature/break-reminder
```

---

## Info.plist 設定

### カメラ使用理由

```xml
<key>NSCameraUsageDescription</key>
<string>Floweaseは、あなたの姿勢をリアルタイムで検知し、悪い姿勢が続いた場合に通知を送ります。カメラ映像はデバイス内でのみ処理され、外部に送信されることはありません。</string>
```

### Dockアイコン非表示

```xml
<key>LSUIElement</key>
<true/>
```

---

## 依存関係

このプロジェクトは外部ライブラリを使用せず、Apple標準フレームワークのみを使用します。

| フレームワーク | 用途 |
|---------------|------|
| SwiftUI | UI構築 |
| AppKit | メニューバー、ポップオーバー |
| Vision | 姿勢検知 |
| AVFoundation | カメラ制御 |
| UserNotifications | 通知 |
| Combine | リアクティブプログラミング |

---

## デバッグ

### カメラ権限の問題

カメラ権限が拒否された場合:

1. **システム設定** > **プライバシーとセキュリティ** > **カメラ** を開く
2. Flowease を有効にする

### 姿勢検知のデバッグ

```swift
// デバッグ用に検知結果をコンソール出力
func debugPoseObservation(_ observation: VNHumanBodyPoseObservation) {
    if let nose = try? observation.recognizedPoint(.nose),
       let neck = try? observation.recognizedPoint(.neck) {
        print("Nose: \(nose.location), Neck: \(neck.location)")
        print("Confidence - Nose: \(nose.confidence), Neck: \(neck.confidence)")
    }
}
```

### メニューバーアイコンのデバッグ

アイコンが表示されない場合:
1. `LSUIElement` が `true` に設定されているか確認
2. `statusItem?.button?.image` が `nil` でないか確認

---

## ビルド設定

### Deployment Target

```
MACOSX_DEPLOYMENT_TARGET = 14.6
```

### コード署名

開発用（ローカルのみ）:
```
CODE_SIGN_IDENTITY = "Apple Development"
```

---

## トラブルシューティング

### ビルドエラー

| エラー | 解決策 |
|--------|--------|
| `Missing required framework` | Xcodeを再起動、DerivedDataを削除 |
| `Code signing failed` | 署名設定を確認、証明書を更新 |

### 実行時エラー

| 症状 | 解決策 |
|------|--------|
| メニューバーにアイコンが出ない | `LSUIElement` 設定を確認 |
| カメラが起動しない | 権限設定を確認 |
| 姿勢が検知されない | カメラに上半身が映っているか確認 |

---

## 次のステップ

1. `/speckit.tasks` を実行してタスク一覧を生成
2. 各タスクに従って機能を実装
3. テストを作成・実行
4. PRを作成してマージ

---

## 参考リンク

- [Apple Vision Framework](https://developer.apple.com/documentation/vision)
- [Detecting Human Body Poses in Images](https://developer.apple.com/documentation/vision/detecting_human_body_poses_in_images)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [UserNotifications](https://developer.apple.com/documentation/usernotifications)
