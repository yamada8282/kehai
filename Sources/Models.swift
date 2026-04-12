import SwiftUI

// MARK: - Member
struct Member: Identifiable {
    let id: String
    let name: String
    let role: String
    let team: String
    let activity: ActivityLevel
    let currentApp: String
    let recentWork: String
    let tags: [String]
    let ghostType: GhostType
    let tsubuyaki: String?
    let tsubuyakiSentAt: Date?
    let layoutPosition: CGPoint?
    let tsubuyakiReactions: [String: [String]]  // emoji → [userId]

    var initial: String { String(name.prefix(1)) }

    init(id: String, name: String, role: String, team: String,
         activity: ActivityLevel, currentApp: String,
         recentWork: String, tags: [String], ghostType: GhostType = .standard,
         tsubuyaki: String?, tsubuyakiSentAt: Date?,
         layoutPosition: CGPoint?,
         tsubuyakiReactions: [String: [String]] = [:]) {
        self.id = id; self.name = name; self.role = role; self.team = team
        self.activity = activity; self.currentApp = currentApp
        self.recentWork = recentWork; self.tags = tags; self.ghostType = ghostType
        self.tsubuyaki = tsubuyaki; self.tsubuyakiSentAt = tsubuyakiSentAt
        self.layoutPosition = layoutPosition
        self.tsubuyakiReactions = tsubuyakiReactions
    }

    static func fromSnapshot(_ snap: MemberSnapshot, layoutPosition: CGPoint?) -> Member {
        Member(
            id: snap.id,
            name: snap.name,
            role: snap.role,
            team: snap.team,
            activity: ActivityLevel(rawValue: snap.activityRaw) ?? .offline,
            currentApp: snap.currentApp,
            recentWork: snap.recentWork,
            tags: snap.tags,
            ghostType: GhostType(rawValue: snap.ghostTypeRaw ?? "") ?? .standard,
            tsubuyaki: snap.tsubuyaki,
            tsubuyakiSentAt: nil, // Will be managed by AppStore based on change detection
            layoutPosition: layoutPosition,
            tsubuyakiReactions: snap.reactions
        )
    }
}

// MARK: - Ghost Type
enum GhostType: String, CaseIterable, Identifiable, Codable {
    case standard
    case noppo
    case maru
    case sikaku
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .standard: return "STANDARD"
        case .noppo:    return "NOPPO"
        case .maru:     return "MARU"
        case .sikaku:   return "SIKAKU"
        }
    }
}

// MARK: - Activity Level
enum ActivityLevel: String, CaseIterable {
    case active
    case moderate
    case idle
    case meeting
    case offline

    var color: Color {
        switch self {
        case .active:   return Color(red: 0.26, green: 0.65, blue: 0.96)
        case .moderate: return Color(red: 0.40, green: 0.73, blue: 0.42)
        case .idle:     return Color(red: 1.0,  green: 0.84, blue: 0.31)
        case .meeting:  return Color(red: 0.73, green: 0.41, blue: 0.78)
        case .offline:  return Color.gray.opacity(0.4)
        }
    }

    var bgColor: Color {
        switch self {
        case .active:   return Color(red: 0.10, green: 0.46, blue: 0.82).opacity(0.35)
        case .moderate: return Color(red: 0.30, green: 0.69, blue: 0.31).opacity(0.25)
        case .idle:     return Color(red: 1.0,  green: 0.76, blue: 0.03).opacity(0.15)
        case .meeting:  return Color(red: 0.61, green: 0.15, blue: 0.69).opacity(0.30)
        case .offline:  return Color.white.opacity(0.04)
        }
    }

    var label: String {
        switch self {
        case .active:   return "作業中"
        case .moderate: return "ゆるく作業"
        case .idle:     return "離席中"
        case .meeting:  return "会議中"
        case .offline:  return "オフライン"
        }
    }

    var icon: String {
        switch self {
        case .active:   return "bolt.fill"
        case .moderate: return "leaf.fill"
        case .idle:     return "moon.fill"
        case .meeting:  return "video.fill"
        case .offline:  return "powersleep"
        }
    }

    var numericLevel: Double {
        switch self {
        case .active:   return 1.00
        case .meeting:  return 0.80
        case .moderate: return 0.65
        case .idle:     return 0.25
        case .offline:  return 0.00
        }
    }
}

// MARK: - Privacy / Disclosure Level
enum DisclosureLevel: String, CaseIterable, Identifiable, Codable {
    case all
    case categoryOnly
    case hidden

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:          return "アプリ名を公開"
        case .categoryOnly: return "カテゴリのみ（デザイン等）"
        case .hidden:       return "すべて隠す"
        }
    }
}

// MARK: - Mock Data
let mockMembers: [Member] = [
    Member(
        id: "1", name: "山田 壮真", role: "サービスデザイナー", team: "CI",
        activity: .offline, currentApp: "—",
        recentWork: "", tags: [""], ghostType: .standard,
        tsubuyaki: nil, tsubuyakiSentAt: nil,
        layoutPosition: CGPoint(x: 340, y: 150)
    ),
    Member(
        id: "2", name: "橋本 健太郎", role: "アートディレクター", team: "空デ",
        activity: .offline, currentApp: "—",
        recentWork: "", tags: [""], ghostType: .standard,
        tsubuyaki: nil, tsubuyakiSentAt: nil,
        layoutPosition: CGPoint(x: 290, y: 236)
    ),
    Member(
        id: "3", name: "片桐 章太郎", role: "コミュニケーションプランナー", team: "CI",
        activity: .offline, currentApp: "—",
        recentWork: "", tags: [""], ghostType: .standard,
        tsubuyaki: nil, tsubuyakiSentAt: nil,
        layoutPosition: CGPoint(x: 190, y: 236)
    ),
    Member(
        id: "4", name: "蜂須賀 太球", role: "映像ディレクター", team: "映像",
        activity: .offline, currentApp: "—",
        recentWork: "", tags: [""], ghostType: .standard,
        tsubuyaki: nil, tsubuyakiSentAt: nil,
        layoutPosition: CGPoint(x: 140, y: 150)
    ),
    Member(
        id: "5", name: "高田 将吾", role: "映像ディレクター", team: "映像",
        activity: .offline, currentApp: "—",
        recentWork: "", tags: [""], ghostType: .standard,
        tsubuyaki: nil, tsubuyakiSentAt: nil,
        layoutPosition: CGPoint(x: 190, y: 64)
    ),
    Member(
        id: "6", name: "丹羽 蓮一郎", role: "", team: "映像",
        activity: .offline, currentApp: "—",
        recentWork: "—",
        tags: [""],
        tsubuyaki: nil, tsubuyakiSentAt: nil,
        layoutPosition: CGPoint(x: 290, y: 64)
    )
]


// MARK: - Tsubuyaki Record（スタンプ履歴付き）
struct TsubuyakiRecord: Identifiable, Codable {
    let id: UUID
    let text: String
    let sentAt: Date
    var reactions: [String: [String]]   // emoji → [userId]

    init(id: UUID = UUID(), text: String, sentAt: Date, reactions: [String: [String]] = [:]) {
        self.id = id
        self.text = text
        self.sentAt = sentAt
        self.reactions = reactions
    }
}

// MARK: - Team Profile（チームごとのプロフィール）
struct TeamProfile: Identifiable, Codable {
    var id: String          // = teamCode（チームID）
    var teamName: String    // チームの表示名（ユーザーがつける名前）
    var displayName: String // このチームでの自分の名前
    var role: String        // 役割
    var team: String        // 部署名
    var ghostType: GhostType
    var recentWork: String
    var tags: [String]
    var disclosureLevel: DisclosureLevel

    // GhostType と DisclosureLevel は RawRepresentable なので Codable 実装は自動
}
