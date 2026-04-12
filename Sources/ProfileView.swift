import SwiftUI

struct ProfileView: View {
    let member: Member
    let onClose: () -> Void

    @State private var stampedIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.bottom, 8)

            // Header: avatar + name/role
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(member.activity.bgColor)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(member.activity.color.opacity(0.3), lineWidth: 1)
                        )
                    
                    GhostBodyView(activity: member.activity, ghostType: member.ghostType, bodyWidth: 22)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(member.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        Text(member.role)
                        Text("/")
                        Text(member.team)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                }
            }
            .padding(.bottom, 16)

            // Status indicator
            HStack(spacing: 6) {
                Image(systemName: member.activity.icon)
                    .font(.system(size: 9))
                    .foregroundColor(member.activity.color)
                Text(member.activity.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(member.activity.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(member.activity.color.opacity(0.12))
            .cornerRadius(6)
            .padding(.bottom, 14)

            // NOW section
            SectionLabel(icon: "●", text: "NOW", color: .green)
            let category = AppStore.inferCategory(from: member.currentApp)
            Text("\(member.currentApp)\(category != nil ? " (\(category!))" : "")")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .padding(.bottom, 10)

            // Focus section (formerly History)
            SectionLabel(icon: "●", text: "FOCUS", color: .blue)
            if !member.recentWork.isEmpty {
                Text("最近の仕事: \(member.recentWork)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.bottom, 12)
            } else {
                Text("特に設定なし")
                    .font(.system(size: 11))
                    .italic()
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 12)
            }

            // Tags
            FlowLayout(spacing: 5) {
                ForEach(member.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .cornerRadius(20)
                }
            }
            .padding(.bottom, 14)

            // Tsubuyaki
            if let tsubuyaki = member.tsubuyaki {
                VStack(alignment: .leading, spacing: 10) {
                    Text("「\(tsubuyaki)」")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.75))
                        .lineSpacing(4)

                    HStack(spacing: 6) {
                        StampButton(emoji: "🤝", label: "それな", index: 0, stampedIndex: $stampedIndex)
                        StampButton(emoji: "✋", label: "知ってるよ", index: 1, stampedIndex: $stampedIndex)
                        StampButton(emoji: "👀", label: "私も知りたい", index: 2, stampedIndex: $stampedIndex)
                    }
                }
                .padding(12)
                .background(Color(white: 0.18).opacity(0.6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .offset(y: 6)),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        ))
    }
}

// MARK: - Section Label
struct SectionLabel: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 6))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
                .tracking(0.5)
        }
        .padding(.bottom, 3)
    }
}

// MARK: - Stamp Button
struct StampButton: View {
    let emoji: String
    let label: String
    let index: Int
    @Binding var stampedIndex: Int?

    @State private var isHovered = false

    var isStamped: Bool { stampedIndex == index }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                stampedIndex = isStamped ? nil : index
            }
        } label: {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(isStamped ? .white : .white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isStamped ? Color.white.opacity(0.2) : Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(isStamped ? 0.3 : 0.12), lineWidth: 1)
            )
            .cornerRadius(20)
            .scaleEffect(isHovered ? 1.05 : (isStamped ? 1.02 : 1.0))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Flow Layout (simple horizontal wrap)
struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, proposal: proposal)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, proposal: proposal)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(subviews: Subviews, proposal: ProposedViewSize) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
