import SwiftUI

struct UserSettingsView: View {
    @ObservedObject var store: WatchSessionStore
    @State private var isShowingCreateUserPrompt = false
    @State private var newUserName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("現在のユーザー") {
                    Text(currentUserName)
                        .font(.headline)
                }

                Section("ユーザー切り替え") {
                    Picker("ユーザー", selection: Binding(
                        get: { store.selectedUserID },
                        set: { store.selectUser($0) }
                    )) {
                        ForEach(store.profiles) { profile in
                            Text(profile.displayName).tag(profile.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("ユーザー追加") {
                    Button("新しいユーザーを追加") {
                        isShowingCreateUserPrompt = true
                    }
                }
            }
            .navigationTitle("ユーザー")
            .alert("ユーザー追加", isPresented: $isShowingCreateUserPrompt) {
                TextField("名前", text: $newUserName)
                Button("キャンセル", role: .cancel) {
                    newUserName = ""
                }
                Button("作成") {
                    store.createUser(named: newUserName)
                    newUserName = ""
                }
            } message: {
                Text("iPhoneで作成するとWatchへ同期されます。")
            }
        }
    }

    private var currentUserName: String {
        store.profiles.first(where: { $0.id == store.selectedUserID })?.displayName ?? "未設定"
    }
}
