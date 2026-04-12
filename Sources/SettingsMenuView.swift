import SwiftUI

struct SettingsMenuView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var updater: Updater
    let onClose: () -> Void

    @State private var tagsText: String = ""
    @State private var recentWorkText: String = ""
    @State private var selectedGhost: GhostType = .standard
    @State private var selectedDisclosure: DisclosureLevel = .all
    @State private var showAddTeam: Bool = false
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            // 背景ブラー
            Color.black.opacity(0.4)
                .onTapGesture { onClose() }
            
            VStack(spacing: 0) {
                headerView
                
                Divider().background(Color.white.opacity(0.1))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        TeamManagementSection(showAddTeam: $showAddTeam)

                        AvatarSelectionSection(selectedGhost: $selectedGhost)
                        
                        TagsSection(tagsText: $tagsText)
                        
                        DisclosureSection(selectedLevel: $selectedDisclosure)
                        
                        RecentWorkSection(recentWorkText: $recentWorkText)
                        
                        HistorySection(history: store.myTsubuyakiHistory, members: store.members)
                    }
                    .padding(20)
                }
                
                footerView
            }
            .frame(width: 480, height: 320)
            .background(Color(white: 0.12))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.5), radius: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .preferredColorScheme(.dark)
        .onAppear { loadCurrentProfile() }
        .sheet(isPresented: $showAddTeam) {
            AddTeamSheet { code, teamName, name, role, team, ghost in
                store.addTeam(teamCode: code, teamName: teamName, name: name, role: role, team: team, ghostType: ghost)
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("個人設定")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.leading, 4)

                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            // アクティブチームのコードを表示
            if let profile = store.activeProfile {
                HStack(spacing: 4) {
                    Text("チーム:")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Text(profile.teamName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue.opacity(0.8))
                    Text("(\(profile.id))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(profile.id, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .help("コード をコピー")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private var footerView: some View {
        HStack(spacing: 8) {
            Button(action: { store.logout() }) {
                Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Button(action: { NSApp.terminate(nil) }) {
                Label("終了", systemImage: "power")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Button(action: { updater.checkForUpdates() }) {
                Label("更新", systemImage: "arrow.clockwise.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!updater.canCheckForUpdates)

            Spacer()
            
            Button(action: saveProfile) {
                Text("保存")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.black.opacity(0.2))
    }
    
    private func loadCurrentProfile() {
        // アクティブチームのプロフィールから読み込む
        if let profile = store.activeProfile {
            self.tagsText = profile.tags.joined(separator: ", ")
            self.recentWorkText = profile.recentWork
            self.selectedGhost = profile.ghostType
            self.selectedDisclosure = profile.disclosureLevel
        }
    }
    
    private func saveProfile() {
        let tags = tagsText.components(separatedBy: CharacterSet(charactersIn: ", 　"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        store.updateProfile(tags: tags, recentWork: recentWorkText, ghostType: selectedGhost, disclosureLevel: selectedDisclosure)
        onClose()
    }
}

// MARK: - Add Team Sheet
struct AddTeamSheet: View {
    let onAdd: (String, String, String, String, String, GhostType) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var teamCode: String = ""
    @State private var teamName: String = ""
    @State private var displayName: String = ""
    @State private var role: String = ""
    @State private var teamDept: String = ""
    @State private var selectedGhost: GhostType = .standard
    @State private var errorMsg: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("チームを追加")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Group {
                labeledField(label: "チームコード", placeholder: "team-abc", text: $teamCode)
                labeledField(label: "チームの表示名", placeholder: "デザインチーム", text: $teamName)
                labeledField(label: "このチームでの名前", placeholder: "山田 壮真", text: $displayName)
                labeledField(label: "役割", placeholder: "サービスデザイナー", text: $role)
                labeledField(label: "部署", placeholder: "CI部門", text: $teamDept)
            }

            if !errorMsg.isEmpty {
                Text(errorMsg).font(.system(size: 11)).foregroundColor(.red)
            }

            HStack {
                Button("キャンセル") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Button("追加") {
                    let code = teamCode.trimmingCharacters(in: .whitespaces)
                    let name = displayName.trimmingCharacters(in: .whitespaces)
                    if code.isEmpty || name.isEmpty {
                        errorMsg = "チームコードと名前は必須です"
                        return
                    }
                    onAdd(code, teamName.isEmpty ? code : teamName, name, role, teamDept, selectedGhost)
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Color.green)
                .foregroundColor(.black)
                .cornerRadius(8)
            }
        }
        .padding(24)
        .frame(width: 380)
        .background(Color(white: 0.12))
        .preferredColorScheme(.dark)
    }

    private func labeledField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
                .foregroundColor(.white)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

// MARK: - Subviews

// チーム管理セクション
private struct TeamManagementSection: View {
    @EnvironmentObject var store: AppStore
    @Binding var showAddTeam: Bool
    @State private var editingTeam: TeamProfile? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("参加中のチーム", systemImage: "person.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Button {
                    showAddTeam = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("追加")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 1) {
                ForEach(store.joinedTeams) { profile in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.teamName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(profile.id == store.activeTeamId ? .white : .white.opacity(0.7))
                            Text("\(profile.displayName) · \(profile.id)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        Spacer()

                        // ✏️ 編集ボタン（全チームで表示）
                        Button {
                            editingTeam = profile
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 4)

                        if profile.id == store.activeTeamId {
                            Text("表示中")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        } else {
                            Button("切替") {
                                store.switchTeam(to: profile.id)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 9))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)

                            Button {
                                store.removeTeam(teamId: profile.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                    .foregroundColor(.red.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(profile.id == store.activeTeamId ? Color.white.opacity(0.08) : Color.clear)
                }
            }
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .sheet(item: $editingTeam) { team in
            TeamProfileEditSheet(teamId: team.id) { updated in
                store.updateTeamProfile(updated)
            }
        }
    }
}

// MARK: - Team Profile Edit Sheet
struct TeamProfileEditSheet: View {
    let teamId: String
    let onSave: (TeamProfile) -> Void
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var role: String = ""
    @State private var teamDept: String = ""
    @State private var recentWork: String = ""
    @State private var tagsText: String = ""
    @State private var selectedGhost: GhostType = .standard
    @State private var selectedDisclosure: DisclosureLevel = .all

    private var profile: TeamProfile? { store.joinedTeams.first { $0.id == teamId } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider().background(Color.white.opacity(0.1))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nameSection
                    avatarSection
                    disclosureSection
                    tagsSection
                }
                .padding(20)
            }
            Divider().background(Color.white.opacity(0.1))
            footerSection
        }
        .frame(width: 460, height: 500)
        .background(Color(white: 0.12))
        .preferredColorScheme(.dark)
        .onAppear { loadProfile() }
    }

    @ViewBuilder private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("プロフィール編集")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(profile?.teamName ?? teamId)
                    .font(.system(size: 10))
                    .foregroundColor(.blue.opacity(0.8))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    @ViewBuilder private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("このチームでのプロフィール", systemImage: "person")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            editField(label: "名前", placeholder: "山田 壮真", text: $displayName)
            editField(label: "役割", placeholder: "サービスデザイナー", text: $role)
            editField(label: "部署", placeholder: "CI部門", text: $teamDept)
        }
    }

    @ViewBuilder private var avatarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("アバター", systemImage: "person.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            HStack(spacing: 12) {
                ForEach(GhostType.allCases) { type in
                    let isSelected = selectedGhost == type
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.green.opacity(0.2) : Color.white.opacity(0.05))
                                .frame(width: 48, height: 48)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.green : Color.clear, lineWidth: 2))
                            GhostBodyView(activity: .active, ghostType: type, bodyWidth: 22)
                        }
                        Text(type.label)
                            .font(.system(size: 8))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                    }
                    .onTapGesture { withAnimation(.spring(response: 0.3)) { selectedGhost = type } }
                }
            }
        }
    }

    @ViewBuilder private var disclosureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("活動情報の公開範囲", systemImage: "eye.trianglebadge.exclamationmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            VStack(spacing: 1) {
                ForEach(DisclosureLevel.allCases) { level in
                    let isSelected = selectedDisclosure == level
                    Button { withAnimation { selectedDisclosure = level } } label: {
                        HStack {
                            Text(level.label)
                                .font(.system(size: 11))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.black.opacity(0.3)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    @ViewBuilder private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            editField(label: "タグ（カンマ区切り）", placeholder: "#デザイン, #SwiftUI", text: $tagsText)
            VStack(alignment: .leading, spacing: 4) {
                Text("最近何してる？").font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                TextEditor(text: $recentWork)
                    .font(.system(size: 12)).foregroundColor(.white)
                    .padding(6).frame(height: 56)
                    .scrollContentBackground(.hidden)
                    .background(Color.black.opacity(0.3)).cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }

    @ViewBuilder private var footerSection: some View {
        HStack {
            Spacer()
            Button("保存") { save() }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 24).padding(.vertical, 6)
                .background(Color.green).foregroundColor(.black).cornerRadius(8)
        }
        .padding(12)
        .background(Color.black.opacity(0.2))
    }

    private func editField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
            TextField(placeholder, text: text)
                .textFieldStyle(.plain).padding(8)
                .background(Color.black.opacity(0.3)).cornerRadius(6)
                .foregroundColor(.white)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private func loadProfile() {
        guard let p = profile else { return }
        displayName = p.displayName
        role = p.role
        teamDept = p.team
        recentWork = p.recentWork
        tagsText = p.tags.joined(separator: ", ")
        selectedGhost = p.ghostType
        selectedDisclosure = p.disclosureLevel
    }

    private func save() {
        guard var p = profile else { return }
        p.displayName = displayName.trimmingCharacters(in: .whitespaces)
        p.role = role
        p.team = teamDept
        p.recentWork = recentWork
        p.tags = tagsText.components(separatedBy: CharacterSet(charactersIn: ", 　"))
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        p.ghostType = selectedGhost
        p.disclosureLevel = selectedDisclosure
        onSave(p)
        dismiss()
    }
}

private struct AvatarSelectionSection: View {
    @Binding var selectedGhost: GhostType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("アバター", systemImage: "person.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            
            HStack(spacing: 15) {
                ForEach(GhostType.allCases) { type in
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedGhost == type ? Color.green.opacity(0.2) : Color.white.opacity(0.05))
                                .frame(width: 54, height: 54)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedGhost == type ? Color.green : Color.clear, lineWidth: 2)
                                )
                            
                            GhostBodyView(activity: .active, ghostType: type, bodyWidth: 24)
                        }
                        Text(type.label)
                            .font(.system(size: 9))
                            .foregroundColor(selectedGhost == type ? .white : .white.opacity(0.5))
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedGhost = type
                        }
                    }
                }
            }
            .padding(.vertical, 5)
        }
    }
}

private struct TagsSection: View {
    @Binding var tagsText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("タグ（カンマ or スペース区切り）", systemImage: "tag")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            
            TextField("#デザイン, #SwiftUI...", text: $tagsText)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
                .foregroundColor(.white)
                .font(.system(size: 12))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

private struct DisclosureSection: View {
    @Binding var selectedLevel: DisclosureLevel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("活動情報の公開範囲", systemImage: "eye.trianglebadge.exclamationmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            
            VStack(spacing: 1) {
                ForEach(DisclosureLevel.allCases) { level in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedLevel = level
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(selectedLevel == level ? .white : .white.opacity(0.7))
                                
                                Text(description(for: level))
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            Spacer()
                            if selectedLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedLevel == level ? Color.white.opacity(0.08) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    
                    if level != DisclosureLevel.allCases.last {
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
            }
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
    
    private func description(for level: DisclosureLevel) -> String {
        switch level {
        case .all: return "現在使用中の名前（例: Adobe Figma）をそのまま表示します。"
        case .categoryOnly: return "「Figma」を「デザイン作業」のように、おおまかな名称に変換します。"
        case .hidden: return "アプリ名を隠し、「作業中」などの状態のみを表示します。"
        }
    }
}

private struct RecentWorkSection: View {
    @Binding var recentWorkText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("最近何してる？", systemImage: "briefcase")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            
            TextEditor(text: $recentWorkText)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(6)
                .frame(height: 60)
                .scrollContentBackground(.hidden)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

private struct HistorySection: View {
    let history: [TsubuyakiRecord]
    let members: [Member]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("つぶやき履歴（全件）", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(history) { record in
                    HistoryItemView(record: record, members: members)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
        }
    }
}

private struct HistoryItemView: View {
    let record: TsubuyakiRecord
    let members: [Member]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
            
            HStack {
                Text(record.sentAt.timeAgoJP)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            }

            if !record.reactions.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(record.reactions.keys.sorted(), id: \.self) { emoji in
                        if let userIds = record.reactions[emoji], !userIds.isEmpty {
                            let names = userIds.map { id in
                                if id == AppStore.myId { return "自分" }
                                return members.first(where: { $0.id == id })?.name ?? "不明"
                            }.joined(separator: ", ")
                            
                            printReactionLine(emoji: emoji, names: names)
                        }
                    }
                }
                .padding(.top, 2)
            }

            Divider().background(Color.white.opacity(0.05))
        }
        .padding(.vertical, 2)
    }
    
    private func printReactionLine(emoji: String, names: String) -> some View {
        Text("\(emoji) \(names)")
            .font(.system(size: 9))
            .foregroundColor(.white.opacity(0.45))
    }
}
