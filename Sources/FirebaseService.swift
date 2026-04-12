import Foundation
import FirebaseDatabase

// MARK: - Member Snapshot (Dynamic profile from Firebase)
struct MemberSnapshot {
    let id: String
    let name: String
    let role: String
    let team: String
    let activityRaw: String
    let currentApp: String
    let tsubuyaki: String?
    let recentWork: String
    let tags: [String]
    let ghostTypeRaw: String?
    let reactions: [String: [String]]  // emoji → [userId]

    init?(id: String, dict: [String: Any]) {
        guard let name        = dict["name"]        as? String,
              let role        = dict["role"]        as? String,
              let team        = dict["team"]        as? String,
              let activityRaw = dict["activityRaw"] as? String,
              let currentApp  = dict["currentApp"]  as? String
        else { return nil }
        
        self.id          = id
        self.name        = name
        self.role        = role
        self.team        = team
        self.activityRaw = activityRaw
        self.currentApp  = currentApp
        
        let t            = dict["tsubuyaki"] as? String
        self.tsubuyaki   = (t == nil || t!.isEmpty) ? nil : t
        
        self.recentWork = dict["recentWork"] as? String ?? ""
        self.tags = dict["tags"] as? [String] ?? []
        self.ghostTypeRaw = dict["ghostType"] as? String

        // Parse reactions: {emoji: {userId: true/false}}
        if let rd = dict["reactions"] as? [String: Any] {
            var r: [String: [String]] = [:]
            for (emoji, usersAny) in rd {
                if let usersDict = usersAny as? [String: Any] {
                    let reacted = usersDict.compactMap { key, val -> String? in
                        (val as? Bool ?? (val as? NSNumber)?.boolValue ?? false) ? key : nil
                    }
                    if !reacted.isEmpty { r[emoji] = reacted }
                }
            }
            self.reactions = r
        } else {
            self.reactions = [:]
        }
    }
}

// MARK: - Firebase Realtime Database Service
final class FirebaseService {

    // アクティブチームの members ノードへの参照（リスナー用）
    private var activeRef: DatabaseReference?
    private var handle: DatabaseHandle?

    // 全チームへの参照（プッシュ専用、[teamId: ref]）
    private var allTeamRefs: [String: DatabaseReference] = [:]

    // 接続状態の変更通知コールバック
    var onConnectionChange: ((Bool) -> Void)?

    // MARK: - Configure

    /// 初期設定：全チームIDを登録し、アクティブチームのリスナーを開始
    func configure(myId: String, allTeamIds: [String], activeTeamId: String) {
        print("[Firebase] Configuring for teams: \(allTeamIds), active: \(activeTeamId), user: \(myId)")
        let db = Database.database(url: FirebaseConfig.databaseURL)

        // 全チームの参照を構築
        allTeamRefs = [:]
        for teamId in allTeamIds {
            allTeamRefs[teamId] = db.reference().child("teams").child(teamId).child("members")
        }

        // 接続監視と onDisconnect 設定（全チームに登録）
        let connectedRef = db.reference(withPath: ".info/connected")
        connectedRef.observe(.value) { [weak self] snapshot, _ in
            guard let self = self else { return }
            let connected = snapshot.value as? Bool ?? false
            self.onConnectionChange?(connected)

            if connected {
                for (_, ref) in self.allTeamRefs {
                    let myRef = ref.child(myId)
                    myRef.child("activityRaw").onDisconnectSetValue(ActivityLevel.offline.rawValue)
                    myRef.child("updatedAt").onDisconnectSetValue(ServerValue.timestamp())
                }
            }
        }

        // アクティブチームのリスナーを開始
        switchActiveTeam(teamId: activeTeamId)
    }

    /// アクティブチームを切り替え（既存リスナーを止め、新しいリスナーを開始）
    func switchActiveTeam(teamId: String) {
        // 既存リスナーを解除
        if let ref = activeRef, let h = handle {
            ref.removeObserver(withHandle: h)
            handle = nil
        }
        activeRef = allTeamRefs[teamId]
    }

    // MARK: - Subscribe (アクティブチームのみ)

    func subscribeAll(onChange: @escaping ([String: MemberSnapshot]) -> Void) {
        guard let ref = activeRef else { return }
        handle = ref.observe(.value) { snapshot in
            var result: [String: MemberSnapshot] = [:]
            for case let child as DataSnapshot in snapshot.children {
                guard let dict = child.value as? [String: Any],
                      let ms = MemberSnapshot(id: child.key, dict: dict)
                else { continue }
                result[child.key] = ms
            }
            DispatchQueue.main.async { onChange(result) }
        }
    }

    // MARK: - Push self's live state (全チームへ同時送信)

    func pushSelf(id: String,
                  name: String,
                  role: String,
                  team: String,
                  activity: ActivityLevel,
                  currentApp: String,
                  tsubuyaki: String?,
                  recentWork: String,
                  tags: [String],
                  ghostType: GhostType,
                  teamIds: [String]) {
        let payload: [String: Any] = [
            "name": name,
            "role": role,
            "team": team,
            "activityRaw": activity.rawValue,
            "currentApp": currentApp,
            "tsubuyaki": tsubuyaki ?? "",
            "recentWork": recentWork,
            "tags": tags,
            "ghostType": ghostType.rawValue,
            "updatedAt": ServerValue.timestamp()
        ]

        // 指定された全チームに送信
        for teamId in teamIds {
            guard let ref = allTeamRefs[teamId] else {
                print("[Firebase] Skip pushSelf to \(teamId): Not configured")
                continue
            }
            ref.child(id).updateChildValues(payload) { error, _ in
                if let error = error {
                    print("[Firebase] pushSelf error (\(teamId)): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Reaction push (アクティブチームのみ)

    func pushReaction(memberId: String, emoji: String, myId: String, reacted: Bool) {
        guard let ref = activeRef else { return }
        let val: Any = reacted ? true : NSNull()
        ref.child(memberId).child("reactions").child(emoji).child(myId).setValue(val)
    }

    /// つぶやき更新時にリアクションをリセット（アクティブチームのみ）
    func clearReactions(id: String) {
        guard let ref = activeRef else { return }
        ref.child(id).child("reactions").removeValue()
    }

    func stopListening() {
        if let ref = activeRef, let h = handle {
            ref.removeObserver(withHandle: h)
        }
    }
}

