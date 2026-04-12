import SwiftUI

struct WidgetView: View {
    @EnvironmentObject var store: AppStore
    @State private var tsubuyakiText: String = ""
    @State private var showQuitAlert = false
    @State private var showSettings = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left Side: Floor Map
            FloorMapView(members: store.members)

            // Right Side: Tsubuyaki Input Box
            tsubuyakiInputView
        }
        .padding(14)
        .frame(width: 720, height: 340)
        .background(Color(white: 0.15))
        .overlay {
            if showSettings {
                SettingsMenuView(onClose: { showSettings = false })
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Submit

    private func submitTsubuyaki() {
        guard !tsubuyakiText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.updateMyTsubuyaki(tsubuyakiText)
        tsubuyakiText = ""
    }

    // MARK: - Right Side Input View

    private var tsubuyakiInputView: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerView
            inputField
            if !store.myTsubuyakiHistory.isEmpty {
                historyView
            }
            Spacer()
        }
        .frame(width: 192, height: 300)
        .background(Color(red: 85/255, green: 77/255, blue: 77/255).opacity(0.68))
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.white.opacity(0.76), lineWidth: 0.5)
        )
        .overlay(alignment: .bottomTrailing) {
            bottomActions
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Kehai")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                
                Text(store.activeProfile?.teamName ?? store.activeTeamId)
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(4)
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
            .padding(.top, 10)
            .padding(.horizontal, 12)

            Text("どうしたの？")
                .font(.custom("Hiragino Kaku Gothic ProN", size: 10).weight(.regular))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 0)
                .padding(.leading, 12)
        }
    }

    private var inputField: some View {
        HStack(spacing: 8) {
            HStack(alignment: .bottom) {
                TextField("つぶやく...", text: $tsubuyakiText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .lineLimit(1...5)
                    .padding(.vertical, 5)
                    .padding(.leading, 8)
                    .onSubmit { submitTsubuyaki() }

                Button { submitTsubuyaki() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(tsubuyakiText.isEmpty ? .white.opacity(0.2) : .white)
                        .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }
            .frame(minHeight: 28)
            .background(Color.white.opacity(0.12))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2), lineWidth: 0.5))

            Button {} label: {
                Image(systemName: "mic")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 2)
        }
        .padding(.horizontal, 10)
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("履歴")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .padding(.leading, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(store.myTsubuyakiHistory.prefix(10)) { record in
                        historyItem(record: record)
                    }
                }
            }
        }
    }

    private func historyItem(record: TsubuyakiRecord) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("›")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
            VStack(alignment: .leading, spacing: 2) {
                Text(record.text)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(3)
                Text(record.sentAt.timeAgoJP)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.35))
                
                if !record.reactions.isEmpty {
                    reactionList(reactions: record.reactions)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func reactionList(reactions: [String: [String]]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(["🤝", "✋", "👀"], id: \.self) { emoji in
                if let reactors = reactions[emoji], !reactors.isEmpty {
                    let nameList = reactors.map { uid in
                        if uid == AppStore.myId { return "自分" }
                        return store.members.first { $0.id == uid }?.name ?? "不明"
                    }.joined(separator: ", ")
                    
                    Text("\(emoji) \(nameList)")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 1)
    }

    private var bottomActions: some View {
        HStack(spacing: 0) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .help("設定")

            Button {
                showQuitAlert = true
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .help("アプリを終了")
            .alert("Kehaiを終了しますか？", isPresented: $showQuitAlert) {
                Button("終了", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("気配がなくなります")
            }
        }
    }
}
