import SwiftUI

// MARK: - Ghost Shape
struct GhostShape: Shape {
    let ghostType: GhostType

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        switch ghostType {
        case .standard:
            return standardPath(w: w, h: h)
        case .maru:
            return maruPath(w: w, h: h)
        case .noppo:
            return noppoPath(w: w, h: h)
        case .sikaku:
            return sikakuPath(w: w, h: h)
        }
    }

    private func standardPath(w: CGFloat, h: CGFloat) -> Path {
        let topR = w / 2
        var path = Path()
        path.addArc(center: CGPoint(x: w / 2, y: topR), radius: topR, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        let scallopsY = h * 0.76
        path.addLine(to: CGPoint(x: w, y: scallopsY))
        let seg = w / 3.0
        let depth = h * 0.22
        path.addQuadCurve(to: CGPoint(x: w - seg, y: scallopsY), control: CGPoint(x: w - seg / 2, y: scallopsY + depth))
        path.addQuadCurve(to: CGPoint(x: seg, y: scallopsY), control: CGPoint(x: w / 2, y: scallopsY + depth))
        path.addQuadCurve(to: CGPoint(x: 0, y: scallopsY), control: CGPoint(x: seg / 2, y: scallopsY + depth))
        path.closeSubpath()
        return path
    }

    private func maruPath(w: CGFloat, h: CGFloat) -> Path {
        var path = Path()
        // 綺麗な円形だが、気配っぽく少しだけ下をどっしりさせる
        let rect = CGRect(x: 0, y: 0, width: w, height: h * 0.96)
        path.addEllipse(in: rect)
        return path
    }

    private func noppoPath(w: CGFloat, h: CGFloat) -> Path {
        var path = Path()
        let topR = w / 2 * 0.8
        path.addArc(center: CGPoint(x: w / 2, y: topR), radius: topR, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: w/2 + topR, y: h * 0.85))
        path.addQuadCurve(to: CGPoint(x: w/2 - topR, y: h * 0.85), control: CGPoint(x: w/2, y: h))
        path.closeSubpath()
        return path
    }

    private func sikakuPath(w: CGFloat, h: CGFloat) -> Path {
        // 美しい角丸四角形（スクワークル風）
        let cornerRadius = w * 0.3
        return Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h * 0.95), cornerRadius: cornerRadius)
    }
}

// MARK: - Ghost Body View
struct GhostBodyView: View {
    let activity: ActivityLevel
    let ghostType: GhostType
    var bodyWidth: CGFloat = 17

    var bodyColor: Color {
        switch activity {
        case .offline: return Color(white: 0.48)
        case .idle:    return Color(white: 0.72)
        default:       return Color(white: 0.87)
        }
    }
    var eyeColor: Color { activity == .offline ? Color(white: 0.32) : Color(white: 0.18) }

    private var eyeSize:    CGFloat { bodyWidth * (5.0 / 30.0) }
    private var eyeSpacing: CGFloat { bodyWidth * (6.0 / 30.0) }
    private var eyeOffsetY: CGFloat { bodyWidth * (2.0 / 30.0) }

    var body: some View {
        ZStack {
            GhostShape(ghostType: ghostType)
                .fill(bodyColor)
                .frame(width: bodyWidth, height: bodyWidth * (33/30))
            HStack(spacing: eyeSpacing) {
                Circle().fill(eyeColor).frame(width: eyeSize, height: eyeSize)
                Circle().fill(eyeColor).frame(width: eyeSize, height: eyeSize)
            }
            .offset(y: -eyeOffsetY)
        }
    }
}

// MARK: - Reusable Tsubuyaki Bubble
struct BubbleView: View {
    let text: String
    let zoomed: Bool
    let angle: Double
    var sentAt: Date? = nil
    var memberId: String = ""
    var reactions: [String: [String]] = [:]   // emoji → [userId]
    var zoomScale: CGFloat = 1.0

    // 地図のパンを止めるための状態
    @EnvironmentObject var trackpad: TrackpadMonitor

    // 文字数 or 改行でロングテキスト判定
    private var isLongText: Bool { text.count > 40 || text.contains("\n") }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            let fontSize: CGFloat = (zoomed ? 9 : 7) * min(max(zoomScale, 1.0), 1.5)
            
            if zoomed && isLongText {
                // 長文は常にScrollView（もっと見るは廃止）
                ScrollView(.vertical, showsIndicators: false) {
                    Text(text)
                        .font(.system(size: fontSize))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 140)
                .frame(maxHeight: 100) // 最大高さを制限
            } else {
                Text(zoomed ? text : "…")
                    .font(.system(size: fontSize))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(.leading)
                    .lineLimit(zoomed ? 4 : 1) // スクロールなしでも最大4行
                    .frame(maxWidth: zoomed ? 120 : 60, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if zoomed, let at = sentAt {
                Text(at.timeAgoJP)
                    .font(.system(size: 6 * min(zoomScale, 1.5)))
                    .foregroundColor(.white.opacity(0.4))
            }

            if zoomed {
                HStack(spacing: 3 * zoomScale) {
                    BubbleStampButton(emoji: "🤝", memberId: memberId,
                                      reactors: reactions["🤝"] ?? [], scale: zoomScale)
                    BubbleStampButton(emoji: "✋", memberId: memberId,
                                      reactors: reactions["✋"] ?? [], scale: zoomScale)
                    BubbleStampButton(emoji: "👀", memberId: memberId,
                                      reactors: reactions["👀"] ?? [], scale: zoomScale)
                }
                .padding(.top, 1)
            }
        }
        // ── 吹き出しの余白調整 ──
        .padding(.horizontal, zoomed ? 6 : 4)
        .padding(.vertical,   zoomed ? 8 : 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.28)))
        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
        .onHover { h in
            // ホバー中は地図のパン（移動）を無効にする
            trackpad.isHoveringScrollable = h
        }
    }
}

// MARK: - Member Avatar View
struct MemberAvatarView: View {
    let member: Member
    let zoomScale: CGFloat
    let isSelected: Bool
    let bubbleAngle: Double
    let action: () -> Void

    @State private var isHovering  = false
    @State private var isAnimating = false
    @State private var glowPulsing = false

    private var floatAmplitude: CGFloat {
        switch member.activity {
        case .active:             return 6.0  // エネルギッシュに大きく動かす
        case .moderate, .meeting: return 3.0  // ゆったりと、でも存在感はある
        default:                  return 0
        }
    }
    private var floatDuration: Double {
        switch member.activity {
        case .active:   return 0.60  // キビキビと
        case .moderate: return 2.00  // ゆったり（深い呼吸）
        case .meeting:  // ミーティング中は通常に近いが少し長め
            return 1.80
        default:        return 0
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Shadow glow (active / meeting only)
                Ellipse()
                    .fill(member.activity.color.opacity(0.45))
                    .frame(width: 14, height: 3)
                    .blur(radius: 4)
                    .opacity((member.activity == .active || member.activity == .meeting)
                             ? (glowPulsing ? 0.6 : 0.12) : 0)
                    .animation(
                        .easeInOut(duration: floatDuration)
                        .repeatForever(autoreverses: true),
                        value: glowPulsing
                    )
                    .offset(y: 9)

                fileIconLayer

                // 名前ラベル（アバターの下に配置、背景なし）
                if zoomScale >= 1.2 {
                    let scaledShift = (17 * zoomScale * (33/30) / 2) + 10 // アバターの半分 + マージン
                    Text(member.name)
                        .font(.system(size: 8 * min(zoomScale, 1.4), weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .offset(y: scaledShift)
                        .transition(.opacity)
                }

                if let text = member.tsubuyaki {
                    let zoomed = zoomScale >= 1.4
                    let baseRadius: CGFloat = zoomed ? 72 : 42
                    
                    // 距離の伸びを 0.5倍 に減衰（3倍ズームでも距離は2倍弱に留める）
                    let dampedFactor = 1.0 + (zoomScale - 1.0) * 0.5
                    let radius = baseRadius * dampedFactor
                    let rad    = bubbleAngle * .pi / 180.0
                    
                    // アバターの「浮き」と同期させるためのオフセット
                    let floatY = (isAnimating && floatAmplitude > 0) ? -floatAmplitude * zoomScale : 0
                    
                    let offsetX = cos(rad) * radius
                    let offsetY = sin(rad) * radius + floatY // 浮きを乗せる
                    
                    BubbleView(text: text, zoomed: zoomed,
                               angle: bubbleAngle, sentAt: member.tsubuyakiSentAt,
                               memberId: member.id, reactions: member.tsubuyakiReactions,
                               zoomScale: zoomScale)
                        .offset(x: offsetX, y: offsetY)
                        .zIndex(10)
                        .animation(.spring(response: 0.4), value: bubbleAngle)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.snappy(duration: 0.2)) { isHovering = h }
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onAppear { 
            // ライフサイクルに合わせて少し遅延させて確実に起動
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startFloat() 
            }
        }
        // アクティビティが変わった時だけでなく、ズームや選択状態の変更時にも
        // アニメーションが止まらないようにリセット & 再点火
        .onChange(of: member.activity) { restartAnimation() }
        .onChange(of: zoomScale)      { restartAnimation() }
        .onChange(of: isSelected)     { restartAnimation() }
    }

    private func restartAnimation() {
        isAnimating = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { startFloat() }
    }

    private func startFloat() {
        guard floatAmplitude > 0 else { isAnimating = false; return }
        isAnimating = true
        glowPulsing = true
    }

    // ── アイコン本体＋ホバー枠（同一ZStackで常に存在させることで浮きを同期）
    private var fileIconLayer: some View {
        let scaledWidth = 17 * zoomScale // 机と同じ倍率で拡大
        
        return ZStack {
            GhostBodyView(activity: member.activity, ghostType: member.ghostType, bodyWidth: scaledWidth)
                .frame(width: scaledWidth, height: scaledWidth * (33/30))

            GhostShape(ghostType: member.ghostType)
                .stroke(Color.white.opacity(0.9), lineWidth: 1.5 * min(zoomScale, 2.0))
                .frame(width: scaledWidth + 1, height: scaledWidth * (33/30) + 1)
                .opacity((isHovering || isSelected) ? 1 : 0)
        }
        .offset(y: (isAnimating && floatAmplitude > 0) ? -floatAmplitude * zoomScale : 0)
        .animation(
            floatAmplitude > 0
                ? .easeInOut(duration: floatDuration).repeatForever(autoreverses: true)
                : .default,
            value: isAnimating
        )
    }
}

// MARK: - Bubble Stamp Button
// Slack 式トグル: 押すとリアクション ON、もう一度で OFF。Firebase に永続化。
struct BubbleStampButton: View {
    let emoji: String
    let memberId: String
    let reactors: [String]   // userId の配列（Firebase から）
    var scale: CGFloat = 1.0
    @EnvironmentObject var store: AppStore
    @State private var bouncing: Bool = false

    private var myId: String { AppStore.myId }
    private var isReacted: Bool { reactors.contains(myId) }

    var body: some View {
        Button {
            store.updateReaction(memberId: memberId, emoji: emoji, reacted: !isReacted)
            bouncing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { bouncing = false }
        } label: {
            VStack(spacing: 0) {
                Text(emoji).font(.system(size: 8 * min(scale, 1.5)))
                if !reactors.isEmpty {
                    Text("\(reactors.count)")
                        .font(.system(size: 6 * min(scale, 1.5), weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(minWidth: 18 * min(scale, 1.5))
            .padding(.horizontal, 2 * min(scale, 1.5))
            .padding(.vertical, 2 * min(scale, 1.5))
            .background(Color.white.opacity(isReacted ? 0.25 : 0.08))
            .cornerRadius(4 * min(scale, 1.5))
            .overlay(RoundedRectangle(cornerRadius: 4 * min(scale, 1.5)).stroke(
                isReacted ? Color.white.opacity(0.65) : Color.white.opacity(0.22),
                lineWidth: (isReacted ? 0.8 : 0.4) * min(scale, 1.5)
            ))
            .scaleEffect(bouncing ? 1.15 : 1.0)
            .animation(.spring(response: 0.18), value: bouncing)
        }
        .buttonStyle(.plain)
    }
}
