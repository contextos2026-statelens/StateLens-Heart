import SwiftUI

struct HistoryView: View {
    @StateObject private var store = HistoryStore()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("この MVP では Apple Watch 側を単体アプリとして先に動かします。iPhone 履歴は現状ローカル保存の確認用で、Watch からの自動同期は次段で拡張します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Sessions") {
                    ForEach(store.sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)

                                Text("Samples: \(session.samples.count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let estimation = session.latestEstimation {
                                    Text("\(estimation.state.displayName)  \(Int(estimation.confidence * 100))%")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                Button("Reload") {
                    store.reload()
                }
            }
        }
    }
}
