import SwiftUI

// MARK: - Trackpad Event Monitor
class TrackpadMonitor: ObservableObject {
    @Published var eventID: Int = 0

    private(set) var panDX: CGFloat = 0
    private(set) var panDY: CGFloat = 0
    private(set) var isPan: Bool = false

    private(set) var zoomDelta: CGFloat = 0
    private(set) var isZoom: Bool = false
    private(set) var zoomEnded: Bool = false

    private func resetEvents() {
        panDX = 0
        panDY = 0
        isPan = false
        zoomDelta = 0
        isZoom = false
        zoomEnded = false
    }

    @Published var isHoveringScrollable: Bool = false
    @Published var isHoveringMap: Bool = false

    private var scrollMonitor: Any?
    private var magnifyMonitor: Any?

    func start() {
        stop() 
        resetEvents()
        print("🔍 TrackpadMonitor: Started")
        guard scrollMonitor == nil else { return }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            
            DispatchQueue.main.async {
                if event.modifierFlags.contains(.option) {
                    if self.isHoveringMap {
                        self.isPan = false
                        self.isZoom = true
                        self.zoomDelta = event.scrollingDeltaY * 0.05
                        self.zoomEnded = (event.phase == .ended || event.momentumPhase == .ended || event.phase == .cancelled)
                        self.eventID += 1
                    }
                } else {
                    if self.isHoveringMap && !self.isHoveringScrollable {
                        self.isPan = true
                        self.isZoom = false
                        self.panDX = event.scrollingDeltaX
                        self.panDY = event.scrollingDeltaY
                        self.eventID += 1
                    }
                }
            }
            return event
        }

        magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            guard let self else { return event }
            if self.isHoveringMap {
                DispatchQueue.main.async {
                    self.isPan = false
                    self.isZoom = true
                    self.zoomDelta = event.magnification * 0.35
                    self.zoomEnded = (event.phase == .ended || event.phase == .cancelled)
                    self.eventID += 1
                }
            }
            return event
        }
    }

    func stop() {
        print("🔍 TrackpadMonitor: Stopped")
        if let m = scrollMonitor  { NSEvent.removeMonitor(m); scrollMonitor  = nil }
        if let m = magnifyMonitor { NSEvent.removeMonitor(m); magnifyMonitor = nil }
    }

    deinit {
        stop()
    }
}

// MARK: - Floor Map View
struct FloorMapView: View {
    @EnvironmentObject var store: AppStore
    let members: [Member]

    @StateObject private var trackpad = TrackpadMonitor()
    @State private var zoomScale:     CGFloat = UserDefaults.standard.double(forKey: "kehai_zoom") != 0 ? UserDefaults.standard.double(forKey: "kehai_zoom") : 1.0
    @State private var currentOffset: CGSize  = .zero
    @State private var lastOffset:    CGSize  = .zero
    @State private var selectedMember: Member? = nil

    private let mapWidth:  CGFloat = 480
    private let mapHeight: CGFloat = 300

    private var memberPositions: [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        let fixedMembers = members.filter { $0.layoutPosition != nil }
        let autoMembers = members.filter { $0.layoutPosition == nil }
        for m in fixedMembers { positions[m.id] = m.layoutPosition! }
        let centerX = mapWidth / 2
        let centerY = mapHeight / 2
        let radius: CGFloat = 90
        for (index, m) in autoMembers.enumerated() {
            let angle = Double(index) * (2.0 * .pi / Double(max(autoMembers.count, 1))) + .pi/4
            let x = centerX + cos(angle) * radius
            let y = centerY + sin(angle) * radius
            positions[m.id] = CGPoint(x: x, y: y)
        }
        return positions
    }

    private var bubbleAngles: [String: Double] {
        var angles: [String: Double] = [:]
        var placedRects: [CGRect] = []
        let posDict = memberPositions
        let iconRadius: CGFloat = 14
        var memberIconRects: [String: CGRect] = [:]
        for m in members {
            guard let p = posDict[m.id] else { continue }
            memberIconRects[m.id] = CGRect(x: p.x - iconRadius, y: p.y - iconRadius, width: iconRadius * 2, height: iconRadius * 2)
        }
        let tsubuyakiMembers = members.filter { $0.tsubuyaki != nil }.sorted { $0.id < $1.id }
        for member in tsubuyakiMembers {
            guard let pos = posDict[member.id] else { continue }
            let zoomed = zoomScale >= 1.4
            // ズームに合わせて滑らかに距離を調整（ワープを防ぐ）
            let baseRadius: CGFloat = zoomed ? 72 : 42
            // ズームの影響を減衰させる（3倍ズームでも距離は2倍程度に抑える）
            let dampedScale = 1.0 + (zoomScale - 1.0) * 0.5
            let radius = baseRadius * dampedScale
            let bWidth:  CGFloat = (zoomed ? 120 : 60) * zoomScale
            let bHeight: CGFloat = (zoomed ? 80 : 36) * zoomScale
            let cx = mapWidth / 2 * zoomScale; let cy = mapHeight / 2 * zoomScale
            let primaryDeg = atan2(pos.y * zoomScale - cy, pos.x * zoomScale - cx) * 180.0 / .pi
            let candidates = [0, 45, -45, 90, -90, 135, -135, 180].map { primaryDeg + $0 }
            let otherIconRects = memberIconRects.filter { $0.key != member.id }.map { $0.value }
            var bestAngle = candidates[0]
            for angle in candidates {
                let rad = angle * .pi / 180.0
                let rect = CGRect(x: pos.x * zoomScale + cos(rad) * radius - bWidth/2, y: pos.y * zoomScale + sin(rad) * radius - bHeight/2, width: bWidth, height: bHeight)
                if !otherIconRects.contains(where: { $0.intersects(rect) }) && !placedRects.contains(where: { $0.intersects(rect) }) {
                    bestAngle = angle
                    break
                }
            }
            angles[member.id] = bestAngle
            let rad = bestAngle * .pi / 180.0
            placedRects.append(CGRect(x: pos.x * zoomScale + cos(rad) * radius - bWidth/2, y: pos.y * zoomScale + sin(rad) * radius - bHeight/2, width: bWidth, height: bHeight))
        }
        return angles
    }

    var body: some View {
        ZStack {
            // LAYER 1: Map
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 85/255, green: 77/255, blue: 77/255).opacity(0.68))
                    .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))

                ZStack(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        Color.clear.frame(width: mapWidth * zoomScale, height: mapHeight * zoomScale)
                        floorPlanLayer
                        let posDict = memberPositions
                        ForEach(members) { member in
                            if let pos = posDict[member.id] {
                                MemberAvatarView(
                                    member: member,
                                    zoomScale: zoomScale,
                                    isSelected: selectedMember?.id == member.id,
                                    bubbleAngle: bubbleAngles[member.id] ?? -45,
                                    action: { handleMemberTap(member) }
                                )
                                .position(x: pos.x * zoomScale, y: pos.y * zoomScale)
                            }
                        }
                    }
                    .offset(currentOffset)
                }
                .frame(width: mapWidth, height: mapHeight).clipped()
            }
            .frame(width: mapWidth, height: mapHeight)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.76), lineWidth: 0.5))

            // LAYER 2: Interaction Overlay
            if selectedMember != nil {
                Color.black.opacity(0.15).contentShape(Rectangle())
                    .onTapGesture { deselect() }
                    .zIndex(7)
                
                if let member = selectedMember {
                    VStack(spacing: 8) {
                        if let text = member.tsubuyaki {
                            BubbleView(text: text, zoomed: true, angle: -90, sentAt: member.tsubuyakiSentAt, memberId: member.id, reactions: member.tsubuyakiReactions, zoomScale: zoomScale).shadow(radius: 5)
                        }
                        GhostBodyView(activity: member.activity, ghostType: member.ghostType, bodyWidth: 80).frame(width: 80, height: 88)
                        Text(member.name).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    }
                    .position(x: 120, y: mapHeight / 2).zIndex(8).contentShape(Rectangle()).onTapGesture { deselect() }
                }
            }

            // LAYER 3: Profile Card
            if let member = selectedMember {
                DetailProfileCardView(member: member)
                    .frame(width: 210).frame(maxHeight: mapHeight - 24)
                    .position(x: mapWidth - 120, y: mapHeight / 2)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: 18)), removal: .opacity))
                    .zIndex(9)
            }

            // LAYER 4: Fixed UI
            if selectedMember == nil {
                // チーム切り替えボタン（複数チームの場合は押せる）
                let teams = store.joinedTeams
                let isMultiTeam = teams.count > 1
                let activeTeamName = store.activeProfile?.teamName ?? "TEAM"

                Button {
                    if isMultiTeam {
                        if let currentIdx = teams.firstIndex(where: { $0.id == store.activeTeamId }) {
                            let nextIdx = (currentIdx + 1) % teams.count
                            store.switchTeam(to: teams[nextIdx].id)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isMultiTeam {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                        Text(activeTeamName)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .foregroundColor(Color(red: 85/255, green: 77/255, blue: 77/255))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(width: 84)           // ← 幅を固定してはみ出しを防止
                    .background(Color(white: 0.84))
                    .cornerRadius(4)
                    .overlay(
                        isMultiTeam
                        ? RoundedRectangle(cornerRadius: 4).stroke(Color.blue.opacity(0.4), lineWidth: 1)
                        : nil
                    )
                }
                .buttonStyle(.plain)
                .position(x: mapWidth - 46, y: mapHeight - 18)  // 幅の半分分だけ内側に
                .zIndex(5)

                zoomControls.position(x: 24, y: mapHeight - 40).zIndex(5)

                if zoomScale <= 1.02 {
                    Text("ピンチ または ⌥ スクロール でズーム").font(.system(size: 8)).foregroundColor(.white.opacity(0.35)).position(x: mapWidth / 2, y: mapHeight - 8).zIndex(5)
                }
            }

            // LAYER 5: Offline Warning
            if !store.isOnline {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 6, height: 6).opacity(0.8)
                    Text("オフラインです").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 10).padding(.vertical, 5).background(Color.black.opacity(0.6)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.red.opacity(0.4), lineWidth: 1)).position(x: mapWidth / 2, y: 24).zIndex(10).transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .environmentObject(trackpad)
        .onHover { h in trackpad.isHoveringMap = h }
        .gesture(MagnificationGesture().onChanged { delta in
            let diff = delta - 1.0; zoomScale = max(1.0, min(3.0, zoomScale + diff * 0.5))
        }.onEnded { _ in UserDefaults.standard.set(Double(zoomScale), forKey: "kehai_zoom") })
        .frame(width: mapWidth, height: mapHeight).clipShape(RoundedRectangle(cornerRadius: 6)).contentShape(Rectangle())
        .onAppear { trackpad.start() }.onDisappear { trackpad.stop() }
        .onChange(of: trackpad.eventID) {
            if trackpad.isZoom {
                zoomScale = max(1.0, min(3.0, zoomScale + trackpad.zoomDelta))
                if trackpad.zoomEnded {
                    UserDefaults.standard.set(Double(zoomScale), forKey: "kehai_zoom")
                    if zoomScale <= 1.05 { withAnimation(.spring(response: 0.35)) { zoomScale = 1.0; currentOffset = .zero; lastOffset = .zero } }
                }
            } else if trackpad.isPan {
                currentOffset.width += trackpad.panDX; currentOffset.height += trackpad.panDY; lastOffset = currentOffset
            }
        }
    }

    private var floorPlanLayer: some View {
        let tableSize: CGFloat = 140 * zoomScale
        return ZStack {
            Circle().fill(Color(white: 0.78)).frame(width: tableSize, height: tableSize).shadow(color: .black.opacity(0.1), radius: 8 * zoomScale, x: 0, y: 4 * zoomScale).position(x: mapWidth / 2 * zoomScale, y: mapHeight / 2 * zoomScale)
            Circle().stroke(Color(white: 0.85), lineWidth: 2 * zoomScale).frame(width: tableSize, height: tableSize).position(x: mapWidth / 2 * zoomScale, y: mapHeight / 2 * zoomScale)
        }
    }

    private var zoomControls: some View {
        VStack(spacing: 5) {
            zoomBtn(icon: "plus")  { zoomScale = min(zoomScale + 0.4, 3.0) }
            zoomBtn(icon: "minus") {
                zoomScale = max(zoomScale - 0.4, 1.0)
                if zoomScale <= 1.0 { currentOffset = .zero; lastOffset = .zero }
            }
        }
    }

    private func zoomBtn(icon: String, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.spring(response: 0.3)) { action() } } label: {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundColor(.white).frame(width: 22, height: 22).background(Color.white.opacity(0.14)).clipShape(Circle()).overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 0.5))
        }.buttonStyle(.plain)
    }

    private func handleMemberTap(_ member: Member) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
            if selectedMember?.id == member.id {
                deselect()
            } else {
                selectedMember = member
                let zoom: CGFloat = 2.0
                zoomScale = zoom
                
                if let pos = memberPositions[member.id] {
                    let cx = mapWidth / 2
                    let cy = mapHeight / 2
                    let targetX: CGFloat = 80
                    let targetY: CGFloat = mapHeight / 2
                    
                    // 計算式を分解してコンパイルエラーを回避
                    let offsetX = targetX - pos.x * zoom + cx * (zoom - 1)
                    let offsetY = targetY - pos.y * zoom + cy * (zoom - 1)
                    
                    currentOffset = CGSize(width: offsetX, height: offsetY)
                    lastOffset = currentOffset
                }
            }
        }
    }

    private func deselect() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            selectedMember = nil; zoomScale = 1.0; currentOffset = .zero; lastOffset = .zero
        }
    }
}

// MARK: - Detail Profile Card
struct DetailProfileCardView: View {
    @EnvironmentObject var store: AppStore
    let member: Member

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(member.name).font(.system(size: 13, weight: .bold)).foregroundColor(Color(white: 0.1))
                        Text("\(member.team) / \(member.role)").font(.system(size: 10)).foregroundColor(Color(white: 0.38))
                        HStack(spacing: 4) {
                            Text(member.activity.label).font(.system(size: 10)).foregroundColor(Color(white: 0.35))
                            Text("(Slack通知 OFF)").font(.system(size: 9)).foregroundColor(Color(white: 0.5))
                        }.padding(.top, 1)
                    }
                    Spacer()
                    Text("Slack ▶").font(.system(size: 9, weight: .medium)).foregroundColor(Color(white: 0.22)).padding(.horizontal, 8).padding(.vertical, 4).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.52), lineWidth: 0.6))
                }.padding(.bottom, 10)

                Divider().background(Color(white: 0.70)).padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(member.tags, id: \.self) { tag in
                        Text(tag).font(.system(size: 10)).foregroundColor(Color(white: 0.3))
                    }
                }.padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 6) {
                    // 自分か他人かで表示ロジックを変える（プライバシー設定反映）
                    let appDisplay: String = {
                        if member.id == AppStore.myId {
                            // 自分自身の場合は設定に基づいて表示
                            let category = AppStore.inferCategory(from: member.currentApp)
                            switch store.activeProfile?.disclosureLevel ?? .all {
                            case .all: return "\(member.currentApp)\(category != nil ? " (\(category!))" : "")"
                            case .categoryOnly: return category ?? "作業中"
                            case .hidden: return "—"
                            }
                        } else {
                            // 他人の場合はサーバーから降ってきた値をそのまま出す（サーバー側ですでにフィルタ済み）
                            return member.currentApp
                        }
                    }()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("●NOW").font(.system(size: 9, weight: .bold)).foregroundColor(Color(white: 0.25))
                        Text(appDisplay).font(.system(size: 10)).foregroundColor(Color(white: 0.38))
                    }
                    
                    if !member.recentWork.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("●FOCUS").font(.system(size: 9, weight: .bold)).foregroundColor(Color(white: 0.25))
                            Text(member.recentWork).font(.system(size: 10)).foregroundColor(Color(white: 0.38)).lineLimit(3)
                        }
                    }
                }.padding(.bottom, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("●history").font(.system(size: 10, weight: .bold)).foregroundColor(Color(white: 0.25))
                    Text("-株式会社○○様 導入支援（先週）").font(.system(size: 9)).foregroundColor(Color(white: 0.38))
                    Text("-2026年度 新規プラン策定MTG（昨日）").font(.system(size: 9)).foregroundColor(Color(white: 0.38))
                    Text("-「若手向けオンボーディング資料」を閲覧しました（1時間前）").font(.system(size: 9)).foregroundColor(Color(white: 0.38)).lineLimit(3)
                }
            }.padding(12)
        }.background(Color(white: 0.91)).cornerRadius(8).shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 6).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.65), lineWidth: 0.5))
    }
}

// MARK: - Visual Effect Blur
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material; v.blendingMode = blendingMode; v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material; v.blendingMode = blendingMode
    }
}
