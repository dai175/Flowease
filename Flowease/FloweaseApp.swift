//
//  FloweaseApp.swift
//  Flowease
//
//  Created by Daisuke Ooba on 2025/12/27.
//

import SwiftUI

@main
struct FloweaseApp: App {
    init() {
        ServiceContainer.shared.registerSettingsService(SettingsService())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
