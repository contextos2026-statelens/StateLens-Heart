import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WatchSessionStore

    var body: some View {
        TabView {
            RealtimeDashboardView(store: store)
                .tabItem {
                    Label("リアルタイム", systemImage: "waveform.path.ecg")
                }

            HistoryView(store: store)
                .tabItem {
                    Label("履歴", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }

            UserSettingsView(store: store)
                .tabItem {
                    Label("ユーザー", systemImage: "person.2.fill")
                }
        }
    }
}
