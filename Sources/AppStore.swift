import SwiftUI
import Combine

class AppStore: ObservableObject {
    @Published var members: [Member] = []
    @Published var currentApp: String = "—"
    @Published var activityLevel: ActivityLevel = .idle
    @Published var isLoggedIn: Bool = false
    @Published var isOnline: Bool = true

    /// 参加中の全チームプロフィール
    @Published var joinedTeams: [TeamProfile] = []
    /// 現在表示中のチームID
    @Published var activeTeamId: String = ""

    /// アクティブチームのプロフィール（nil = 未登録）
    var activeProfile: TeamProfile? {
        joinedTeams.first { $0.id == activeTeamId }
    }

    /// つぶやき履歴（自分のみ、最新10件）
    @Published private(set) var myTsubuyakiHistory: [TsubuyakiRecord] = []

    private let firebase = FirebaseService()
    private var syncStarted = false
    private var monitor: ActivityMonitor?
    private var cancellables = Set<AnyCancellable>()
    private var expiryTimer: Timer?
    /// 自分のリアクション操作がスナップショットで上書きされるのを防ぐためのタイムスタンプ
    private var lastReactionUpdateByMe: [String: Date] = [:]

    static var myId: String {
        if let id = UserDefaults.standard.string(forKey: "kehaiMemberId") {
            return id
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "kehaiMemberId")
        return newId
    }

    init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")

        // joinedTeams を UserDefaults から復元
        loadJoinedTeams()

        // activeTeamId を復元（存在しなければ最初のチームを選択）
        let savedActiveId = UserDefaults.standard.string(forKey: "activeTeamId") ?? ""
        if joinedTeams.contains(where: { $0.id == savedActiveId }) {
            self.activeTeamId = savedActiveId
        } else {
            self.activeTeamId = joinedTeams.first?.id ?? ""
        }

        loadHistory()
        startExpiryTimer()
    }

    // MARK: - Auth

    /// 初回ログイン（最初のチームを登録）
    func login(name: String, role: String, team: String, teamCode: String, teamName: String, ghostType: GhostType) {
        let profile = TeamProfile(
            id: teamCode,
            teamName: teamName,
            displayName: name,
            role: role,
            team: team,
            ghostType: ghostType,
            recentWork: "",
            tags: [],
            disclosureLevel: .all
        )
        joinedTeams = [profile]
        activeTeamId = teamCode
        isLoggedIn = true

        saveJoinedTeams()
        UserDefaults.standard.set(teamCode, forKey: "activeTeamId")
        UserDefaults.standard.set(true, forKey: "isLoggedIn")

        startSync()
        updateMyActivity(self.activityLevel, currentApp: self.currentApp)
    }

    /// 2つ目以降のチームを追加
    func addTeam(teamCode: String, teamName: String, name: String, role: String, team: String, ghostType: GhostType) {
        guard !joinedTeams.contains(where: { $0.id == teamCode }) else { return }

        let profile = TeamProfile(
            id: teamCode,
            teamName: teamName,
            displayName: name,
            role: role,
            team: team,
            ghostType: ghostType,
            recentWork: "",
            tags: [],
            disclosureLevel: .all
        )
        joinedTeams.append(profile)
        saveJoinedTeams()

        // Firebase に新チームを追加して再設定
        restartSync()
    }

    /// チームを削除（最後の1つは削除不可）
    func removeTeam(teamId: String) {
        guard joinedTeams.count > 1 else { return }
        joinedTeams.removeAll { $0.id == teamId }
        saveJoinedTeams()

        // アクティブチームが削除された場合、最初のチームへ切り替え
        if activeTeamId == teamId {
            switchTeam(to: joinedTeams.first!.id)
        } else {
            restartSync()
        }
    }

    /// チームを切り替え（表示を更新、リスナーを付け替える）
    func switchTeam(to teamId: String) {
        guard joinedTeams.contains(where: { $0.id == teamId }) else { return }
        activeTeamId = teamId
        UserDefaults.standard.set(teamId, forKey: "activeTeamId")

        // members をリセットして新チームのリスナーを開始
        self.members = []
        firebase.switchActiveTeam(teamId: teamId)
        firebase.subscribeAll { [weak self] snapshots in
            self?.applySnapshots(snapshots)
        }

        // 切り替え後のチームにも自分の状態を即時反映
        updateMyActivity(self.activityLevel, currentApp: self.currentApp)
    }

    func logout() {
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: historyKey)
        UserDefaults.standard.removeObject(forKey: joinedTeamsKey)
        KeychainHelper.delete(key: joinedTeamsKey)
        self.isLoggedIn = false
        self.syncStarted = false
        self.myTsubuyakiHistory = []
        self.joinedTeams = []
        self.activeTeamId = ""
        firebase.stopListening()
        self.members = []
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard monitor == nil else { return }
        let newMonitor = ActivityMonitor()
        self.monitor = newMonitor

        newMonitor.$activityLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.updateMyActivity(level, currentApp: self?.monitor?.currentApp ?? "—")
            }
            .store(in: &cancellables)

        newMonitor.$currentApp
            .receive(on: RunLoop.main)
            .sink { [weak self] app in
                self?.updateMyActivity(self?.monitor?.activityLevel ?? .idle, currentApp: app)
            }
            .store(in: &cancellables)
    }

    // MARK: - Firebase lifecycle

    func startSync() {
        guard isLoggedIn, !joinedTeams.isEmpty else { return }
        guard !syncStarted else { return }
        syncStarted = true

        let allTeamIds = joinedTeams.map { $0.id }
        firebase.configure(myId: AppStore.myId, allTeamIds: allTeamIds, activeTeamId: activeTeamId)
        firebase.onConnectionChange = { [weak self] connected in
            DispatchQueue.main.async { self?.isOnline = connected }
        }
        firebase.subscribeAll { [weak self] snapshots in
            self?.applySnapshots(snapshots)
        }
    }

    private func restartSync() {
        syncStarted = false
        startSync()
    }

    /// 任意のチームのプロフィールを更新（チームID指定）
    func updateTeamProfile(_ updated: TeamProfile) {
        guard let idx = joinedTeams.firstIndex(where: { $0.id == updated.id }) else { return }
        joinedTeams[idx] = updated
        saveJoinedTeams()

        // アクティブチームの場合はメンバーリストと Firebase も即時更新
        if updated.id == activeTeamId {
            update(id: AppStore.myId) { m in
                Member(id: m.id, name: updated.displayName, role: updated.role, team: updated.team,
                       activity: m.activity, currentApp: m.currentApp,
                       recentWork: updated.recentWork, tags: updated.tags, ghostType: updated.ghostType,
                       tsubuyaki: m.tsubuyaki, tsubuyakiSentAt: m.tsubuyakiSentAt,
                       layoutPosition: m.layoutPosition, tsubuyakiReactions: m.tsubuyakiReactions)
            }
        }
        pushSelf()
    }

    // MARK: - Mutators

    func updateMyTsubuyaki(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let tsubuyaki: String? = trimmed.isEmpty ? nil : trimmed
        let sentAt: Date? = tsubuyaki != nil ? Date() : nil

        update(id: AppStore.myId) { m in
            Member(id: m.id, name: m.name, role: m.role, team: m.team,
                   activity: m.activity, currentApp: m.currentApp,
                   recentWork: m.recentWork, tags: m.tags, ghostType: m.ghostType,
                   tsubuyaki: tsubuyaki, tsubuyakiSentAt: sentAt,
                   layoutPosition: m.layoutPosition,
                   tsubuyakiReactions: [:])
        }
        if let t = tsubuyaki, let at = sentAt {
            myTsubuyakiHistory.insert(TsubuyakiRecord(text: t, sentAt: at), at: 0)
            if myTsubuyakiHistory.count > 10 { myTsubuyakiHistory.removeLast() }
            saveHistory()
        }
        firebase.clearReactions(id: AppStore.myId)
        pushSelf()
    }

    /// アクティブチームのプロフィールを更新
    func updateProfile(tags: [String], recentWork: String, ghostType: GhostType, disclosureLevel: DisclosureLevel) {
        guard let idx = joinedTeams.firstIndex(where: { $0.id == activeTeamId }) else { return }
        joinedTeams[idx].recentWork = recentWork
        joinedTeams[idx].tags = tags
        joinedTeams[idx].ghostType = ghostType
        joinedTeams[idx].disclosureLevel = disclosureLevel
        saveJoinedTeams()

        update(id: AppStore.myId) { m in
            Member(id: m.id, name: m.name, role: m.role, team: m.team,
                   activity: m.activity, currentApp: m.currentApp,
                   recentWork: recentWork, tags: tags, ghostType: ghostType,
                   tsubuyaki: m.tsubuyaki, tsubuyakiSentAt: m.tsubuyakiSentAt,
                   layoutPosition: m.layoutPosition,
                   tsubuyakiReactions: m.tsubuyakiReactions)
        }
        pushSelf()
    }

    func updateMyActivity(_ level: ActivityLevel, currentApp: String) {
        self.activityLevel = level
        self.currentApp = currentApp

        guard let profile = activeProfile else { return }

        if let _ = members.firstIndex(where: { $0.id == AppStore.myId }) {
            update(id: AppStore.myId) { m in
                Member(id: m.id, name: profile.displayName, role: profile.role, team: profile.team,
                       activity: level, currentApp: currentApp,
                       recentWork: profile.recentWork, tags: m.tags, ghostType: profile.ghostType,
                       tsubuyaki: m.tsubuyaki, tsubuyakiSentAt: m.tsubuyakiSentAt,
                       layoutPosition: m.layoutPosition,
                       tsubuyakiReactions: m.tsubuyakiReactions)
            }
        } else {
            let me = Member(
                id: AppStore.myId,
                name: profile.displayName,
                role: profile.role,
                team: profile.team,
                activity: level,
                currentApp: currentApp,
                recentWork: profile.recentWork,
                tags: profile.tags,
                ghostType: profile.ghostType,
                tsubuyaki: nil,
                tsubuyakiSentAt: nil,
                layoutPosition: nil
            )
            self.members.append(me)
        }
        pushSelf()
    }

    /// アプリ名から作業カテゴリを推測する
    static func inferCategory(from appName: String) -> String? {
        let name = appName.lowercased()

        if name.contains("figma") || name.contains("sketch") || name.contains("photoshop") ||
           name.contains("illustrator") || name.contains("xd") || name.contains("framer") ||
           name.contains("canva") || name.contains("indesign") {
            return "デザイン作業かな？"
        }
        if name.contains("xcode") || name.contains("visual studio") || name.contains("code") ||
           name.contains("terminal") || name.contains("iterm") || name.contains("intellij") ||
           name.contains("android studio") || name.contains("pycharm") || name.contains("github") {
            return "プログラミングかな？"
        }
        if name.contains("word") || name.contains("pages") || name.contains("excel") ||
           name.contains("numbers") || name.contains("powerpoint") || name.contains("keynote") ||
           name.contains("notion") || name.contains("docs") || name.contains("sheets") ||
           name.contains("slides") || name.contains("notes") || name.contains("obsidian") ||
           name.contains("textedit") {
            return "書類作成かな？"
        }
        if name.contains("final cut") || name.contains("premiere") || name.contains("after effects") ||
           name.contains("davinci") || name.contains("obs") || name.contains("capcut") {
            return "映像制作かな？"
        }
        if name.contains("slack") || name.contains("teams") || name.contains("zoom") ||
           name.contains("discord") || name.contains("meet") || name.contains("messenger") ||
           name.contains("calendar") || name.contains("outlook") || name.contains("mail") {
            return "会議・連絡中かな？"
        }
        if name.contains("chrome") || name.contains("safari") || name.contains("firefox") || name.contains("edge") {
            return "調べものかな？"
        }
        return nil
    }

    func updateReaction(memberId: String, emoji: String, reacted: Bool) {
        let myId = AppStore.myId
        update(id: memberId) { m in
            var reactions = m.tsubuyakiReactions
            var list = reactions[emoji] ?? []
            if reacted {
                if !list.contains(myId) { list.append(myId) }
            } else {
                list.removeAll { $0 == myId }
            }
            if list.isEmpty { reactions.removeValue(forKey: emoji) }
            else { reactions[emoji] = list }

            return Member(id: m.id, name: m.name, role: m.role, team: m.team,
                          activity: m.activity, currentApp: m.currentApp,
                          recentWork: m.recentWork, tags: m.tags, ghostType: m.ghostType,
                          tsubuyaki: m.tsubuyaki, tsubuyakiSentAt: m.tsubuyakiSentAt,
                          layoutPosition: m.layoutPosition,
                          tsubuyakiReactions: reactions)
        }

        lastReactionUpdateByMe[memberId + emoji] = Date()
        if memberId == myId, let m = members.first(where: { $0.id == myId }), !myTsubuyakiHistory.isEmpty {
             myTsubuyakiHistory[0].reactions = m.tsubuyakiReactions
             saveHistory()
        }
        firebase.pushReaction(memberId: memberId, emoji: emoji, myId: myId, reacted: reacted)
    }

    // MARK: - Computed

    var teamActivityLevel: Double {
        let others = members.filter { $0.id != AppStore.myId }
        guard !others.isEmpty else { return 0.5 }
        let total = others.reduce(0.0) { $0 + $1.activity.numericLevel }
        return total / Double(others.count)
    }

    // MARK: - Private

    private func applySnapshots(_ snapshots: [String: MemberSnapshot]) {
        var newMembers: [Member] = []
        let existingMembers = self.members

        for (id, snap) in snapshots {
            let existing = existingMembers.first(where: { $0.id == id })

            let newActivity = ActivityLevel(rawValue: snap.activityRaw) ?? .offline
            let sentAt: Date? = (snap.tsubuyaki != nil && (snap.tsubuyaki != existing?.tsubuyaki)) ? Date() : existing?.tsubuyakiSentAt

            var mergedReactions = snap.reactions
            let now = Date()
            if let existing = existing {
                for (emoji, myStatus) in existing.tsubuyakiReactions {
                    if let lastUpdateAt = lastReactionUpdateByMe[id + emoji], now.timeIntervalSince(lastUpdateAt) < 2.5 {
                        var reactors = mergedReactions[emoji] ?? []
                        if myStatus.contains(AppStore.myId) {
                            if !reactors.contains(AppStore.myId) { reactors.append(AppStore.myId); mergedReactions[emoji] = reactors }
                        } else {
                            if reactors.contains(AppStore.myId) {
                                reactors.removeAll { $0 == AppStore.myId }
                                if reactors.isEmpty { mergedReactions.removeValue(forKey: emoji) } else { mergedReactions[emoji] = reactors }
                            }
                        }
                    }
                }
            }

            let ghostType = GhostType(rawValue: snap.ghostTypeRaw ?? "") ?? .standard
            let m = Member(
                id: id,
                name: snap.name,
                role: snap.role,
                team: snap.team,
                activity: newActivity,
                currentApp: snap.currentApp,
                recentWork: snap.recentWork,
                tags: snap.tags,
                ghostType: ghostType,
                tsubuyaki: snap.tsubuyaki,
                tsubuyakiSentAt: sentAt,
                layoutPosition: existing?.layoutPosition,
                tsubuyakiReactions: mergedReactions
            )
            newMembers.append(m)

            if id == AppStore.myId && !myTsubuyakiHistory.isEmpty {
                myTsubuyakiHistory[0].reactions = mergedReactions
            }
        }

        if !newMembers.contains(where: { $0.id == AppStore.myId }) {
            if let me = existingMembers.first(where: { $0.id == AppStore.myId }) {
                newMembers.insert(me, at: 0)
            }
        }

        DispatchQueue.main.async {
            self.members = newMembers.sorted { $0.id == AppStore.myId ? true : ($1.id == AppStore.myId ? false : $0.name < $1.name) }
        }
    }

    private func startExpiryTimer() {
        expiryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.expireOldTsubuyaki()
        }
    }

    private func expireOldTsubuyaki() {
        let limit = Date().addingTimeInterval(-3 * 3600)
        var didChange = false
        for i in members.indices {
            guard let sentAt = members[i].tsubuyakiSentAt, sentAt < limit else { continue }
            let m = members[i]
            members[i] = Member(
                id: m.id, name: m.name, role: m.role, team: m.team,
                activity: m.activity, currentApp: m.currentApp,
                recentWork: m.recentWork, tags: m.tags, ghostType: m.ghostType,
                tsubuyaki: nil, tsubuyakiSentAt: nil,
                layoutPosition: m.layoutPosition,
                tsubuyakiReactions: [:]
            )
            didChange = true
        }
        if didChange { pushSelf() }
    }

    private func pushSelf() {
        guard let me = members.first(where: { $0.id == AppStore.myId }) else { return }

        // 各チームのプロフィール・公開レベルに応じて個別に送信
        for profile in joinedTeams {
            var appToPush = me.currentApp
            switch profile.disclosureLevel {
            case .all: break
            case .categoryOnly:
                appToPush = AppStore.inferCategory(from: me.currentApp) ?? "作業中"
            case .hidden:
                appToPush = "—"
            }

            // つぶやきはアクティブチームのみ。他チームにはつぶやきを送らない。
            let tsubuyakiToPush: String? = (profile.id == activeTeamId) ? me.tsubuyaki : nil

            firebase.pushSelf(
                id: AppStore.myId,
                name: profile.displayName,
                role: profile.role,
                team: profile.team,
                activity: me.activity,
                currentApp: appToPush,
                tsubuyaki: tsubuyakiToPush,
                recentWork: profile.recentWork,
                tags: profile.tags,
                ghostType: profile.ghostType,
                teamIds: [profile.id]   // チームごとに個別送信
            )
        }
    }

    private func update(id: String, transform: (Member) -> Member) {
        guard let idx = members.firstIndex(where: { $0.id == id }) else { return }
        let m = members[idx]
        let updated = transform(m)
        let changed = m.activity != updated.activity ||
                      m.tsubuyaki != updated.tsubuyaki ||
                      m.currentApp != updated.currentApp ||
                      m.recentWork != updated.recentWork ||
                      m.tags != updated.tags ||
                      m.ghostType != updated.ghostType ||
                      m.tsubuyakiSentAt != updated.tsubuyakiSentAt ||
                      m.tsubuyakiReactions != updated.tsubuyakiReactions
        if changed {
            members[idx] = updated
        }
    }

    // MARK: - Persistence

    private let historyKey = "kehai_tsubuyaki_history"
    private let joinedTeamsKey = "kehai_joined_teams"

    private func saveJoinedTeams() {
        if let encoded = try? JSONEncoder().encode(joinedTeams) {
            // Keychain に保存（UserDefaults より安全）
            KeychainHelper.save(encoded, key: joinedTeamsKey)
        }
    }

    private func loadJoinedTeams() {
        // まず Keychain から読む
        if let data = KeychainHelper.load(key: joinedTeamsKey),
           let decoded = try? JSONDecoder().decode([TeamProfile].self, from: data) {
            self.joinedTeams = decoded
            return
        }

        // Keychain になければ UserDefaults からマイグレーション
        if let data = UserDefaults.standard.data(forKey: joinedTeamsKey),
           let decoded = try? JSONDecoder().decode([TeamProfile].self, from: data) {
            self.joinedTeams = decoded
            saveJoinedTeams()  // Keychain に移行して保存
            UserDefaults.standard.removeObject(forKey: joinedTeamsKey)  // UserDefaults から削除
            return
        }

        // 旧バージョンからの移行: teamCode が残っている場合
        let oldTeamCode = UserDefaults.standard.string(forKey: "teamCode") ?? ""
        if !oldTeamCode.isEmpty {
            let oldName = UserDefaults.standard.string(forKey: "myName") ?? "GUEST"
            let oldRole = UserDefaults.standard.string(forKey: "myRole") ?? ""
            let oldTeam = UserDefaults.standard.string(forKey: "myTeam") ?? ""
            let oldGhost = GhostType(rawValue: UserDefaults.standard.string(forKey: "myGhostType") ?? "") ?? .standard
            let oldRecent = UserDefaults.standard.string(forKey: "myRecentWork") ?? ""
            let profile = TeamProfile(
                id: oldTeamCode,
                teamName: "チーム",
                displayName: oldName,
                role: oldRole,
                team: oldTeam,
                ghostType: oldGhost,
                recentWork: oldRecent,
                tags: [],
                disclosureLevel: .all
            )
            self.joinedTeams = [profile]
            saveJoinedTeams()  // Keychain に保存
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(myTsubuyakiHistory) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([TsubuyakiRecord].self, from: data) {
            self.myTsubuyakiHistory = decoded
        }
    }
}

// MARK: - Date formatting helper
extension Date {
    var timeAgoJP: String {
        let diff = Int(Date().timeIntervalSince(self))
        if diff < 60 { return "たった今" }
        if diff < 3600 { return "\(diff / 60)分前" }
        return "\(diff / 3600)時間前"
    }
}
