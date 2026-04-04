//
//  StateLens_HeartApp.swift
//  StateLensHeart
//
//  Created by 西岡まひろ on 2026/04/04.
//

import SwiftUI

@main
struct StateLensHeartApp: App {
    @StateObject private var store = WatchSessionStore()

    init() {
        DebugSanityChecks.runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
