import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    
    @State private var name: String = ""
    @State private var role: String = ""
    @State private var team: String = ""
    @State private var teamCode: String = ""
    @State private var selectedGhost: GhostType = .standard
    
    @State private var step: Int = 0
    @State private var isSubmitting: Bool = false
    
    // Tutorial states
    @State private var tutorialIconRotation: CGFloat = 0
    @State private var tutorialClosingAmount: CGFloat = 0
    @State private var tutorialIsBlinking: Bool = false
    @State private var tutorialReactionCounts: [String: Int] = ["🤝": 2, "🖐️": 0, "👀": 1]
    @State private var tutorialGhostsFloating: Bool = false
    
    @State private var tutorialTimer: Timer? = nil
    
    private let backgroundColor = Color(red: 30/255, green: 28/255, blue: 28/255)
    
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            backgroundColor.opacity(0.4).ignoresSafeArea()
            
            // Decorative background elements
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 500, height: 500)
                .blur(radius: 100)
                .offset(x: -250, y: -200)
            
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: 250, y: 200)
            
            VStack(spacing: 15) {
                Spacer()
                VStack(spacing: 15) {
                    if step == 0 {
                        welcomeStep
                    } else if step == 1 {
                        profileStep
                    } else if step == 2 {
                        teamStep
                    } else if step == 3 {
                        tutorialMenuBarStep
                    } else if step == 4 {
                        tutorialGhostStep
                    } else {
                        tutorialReactionStep
                    }
                    
                    HStack(spacing: 15) {
                        if step > 0 {
                            Button("戻る") {
                                withAnimation(.spring()) { step -= 1 }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        
                        Button(step < 5 ? (step == 2 ? "次へ（操作解説）" : "次へ") : "はじめる！") {
                            if step < 5 {
                                withAnimation(.spring()) { step += 1 }
                            } else {
                                handleJoin()
                            }
                        }
                        .disabled(isNextDisabled)
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.top, 5)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 35)
                .frame(width: 540)
                Spacer()
            }
        }
        .frame(minWidth: 720, minHeight: 500)
        .preferredColorScheme(.dark)
        .onAppear {
            startTutorialTimers()
        }
        .onDisappear {
            tutorialTimer?.invalidate()
        }
    }
    
    private func startTutorialTimers() {
        tutorialTimer?.invalidate()
        tutorialTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            tutorialIconRotation += 4.5 // チーム活動量 0.3 相当の回転
            if tutorialIconRotation >= 360 { tutorialIconRotation -= 360 }
            
            // 簡易的な瞬きロジック
            if !tutorialIsBlinking && Double.random(in: 0...100) < 1.5 {
                performTutorialBlink()
            }
        }
        
        tutorialGhostsFloating = false 
    }
    
    private func performTutorialBlink() {
        tutorialIsBlinking = true
        let sequence: [CGFloat] = [0, 0.5, 1.0, 1.0, 0.5, 0]
        var blinkStep = 0
        Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { t in
            if blinkStep < sequence.count {
                tutorialClosingAmount = sequence[blinkStep]
                blinkStep += 1
            } else {
                t.invalidate()
                tutorialIsBlinking = false
            }
        }
    }
    
    private var isNextDisabled: Bool {
        if step == 0 { return name.isEmpty }
        if step == 1 { return role.isEmpty || team.isEmpty }
        if step == 2 { return teamCode.isEmpty }
        return false
    }
    
    private var welcomeStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 36))
                .foregroundColor(.blue)
            
            VStack(spacing: 4) {
                Text("Kehai へようこそ")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("あなたの気配をチームに届けましょう")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("お名前")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                TextField("例: 山田 太郎", text: $name)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            .padding(.top, 10)
        }
    }
    
    private var profileStep: some View {
        VStack(spacing: 12) {
            Text("プロフィール設定")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                HStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("肩書")
                            .font(.system(size: 12, weight: .medium))
                        TextField("デザイナー / エンジニア", text: $role)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("所属チーム名")
                            .font(.system(size: 12, weight: .medium))
                        TextField("デザイン本部", text: $team)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("あなたのアバター")
                        .font(.system(size: 12, weight: .medium))
                    
                    HStack(spacing: 12) {
                        ForEach(GhostType.allCases) { type in
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(selectedGhost == type ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                                        .frame(width: 44, height: 44)
                                    
                                    GhostBodyView(activity: .active, ghostType: type, bodyWidth: 22)
                                }
                                .overlay(
                                    Circle()
                                        .stroke(selectedGhost == type ? Color.blue : Color.clear, lineWidth: 1.5)
                                )
                                .onTapGesture {
                                    withAnimation(.interactiveSpring()) { selectedGhost = type }
                                }
                                
                                Text(type.label)
                                    .font(.system(size: 9))
                                    .foregroundColor(selectedGhost == type ? .white : .white.opacity(0.5))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private var teamStep: some View {
        VStack(spacing: 15) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundColor(.purple)
            
            VStack(spacing: 4) {
                Text("チームに参加する")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("同じコードを入力した人同士でマップを共有します")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("チームコード")
                    .font(.system(size: 12, weight: .medium))
                TextField("例: team-alpha-2024", text: $teamCode)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            .padding(.top, 5)
        }
    }
    
    private var tutorialMenuBarStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("1. メニューバーの気配")
                    .font(.system(size: 18, weight: .bold))
                Text("画面上部のアイコンがチームの「活気」を表します")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 140)
                
                VStack(spacing: 15) {
                    let image = CuteBlobIconRenderer.drawFace(
                        closingAmount: tutorialClosingAmount,
                        angle: tutorialIconRotation
                    )
                    
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 44, height: 44)
                        .shadow(color: .blue.opacity(0.3), radius: 8)
                    
                    Text("アイコンが 回転 したり 瞬き している時は、\n誰かが 集中 していたり 活発 に動いているサイン。")
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.6))
                        .lineSpacing(4)
                }
            }
        }
    }
    
    private var tutorialGhostStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("2. アバターの動き")
                    .font(.system(size: 18, weight: .bold))
                Text("アバター自身の揺れで「今の集中状態」を伝えます")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            ZStack {
                // Table background
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200, height: 200)
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                
                HStack(spacing: 40) {
                    tutorialGhostItem(activity: .active, label: "作業中", desc: "激しく動く")
                    tutorialGhostItem(activity: .moderate, label: "休憩中", desc: "ゆったり")
                    tutorialGhostItem(activity: .offline, label: "離席中", desc: "止まる")
                }
            }
            .frame(height: 160)
            .padding(.vertical, 10)
            .onAppear {
                // 確実に「変化」を検知させるため、少しだけ遅延させてフラグを立てる
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    tutorialGhostsFloating = true
                }
            }
        }
    }
    
    private func tutorialGhostItem(activity: ActivityLevel, label: String, desc: String) -> some View {
        let amplitude: CGFloat = (activity == .active) ? 6.0 : ((activity == .moderate) ? 3.0 : 0)
        let duration: Double   = (activity == .active) ? 0.6 : 2.0
        
        return VStack(spacing: 10) {
            GhostBodyView(activity: activity, ghostType: selectedGhost, bodyWidth: 32)
                .offset(y: (tutorialGhostsFloating && activity != .offline) ? -amplitude : 0)
                .animation(
                    (tutorialGhostsFloating && activity != .offline)
                        ? .easeInOut(duration: duration).repeatForever(autoreverses: true)
                        : .default,
                    value: tutorialGhostsFloating
                )
            Text(label).font(.system(size: 12, weight: .bold))
            Text(desc).font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
        }
        .frame(width: 80)
    }
    
    private var tutorialReactionStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("3. 共感でつながる")
                    .font(.system(size: 18, weight: .bold))
                Text("つぶやきに対して、3つのリアクションで反応しましょう")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            VStack(spacing: 12) {
                // Mock Speech Bubble
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("山田（デザイナー）")
                            .font(.system(size: 10, weight: .bold))
                        Spacer()
                        Text("今")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    
                    Text("デザイン作業 集中します！ 🤝")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    HStack(spacing: 12) {
                        ForEach(["🤝", "🖐️", "👀"], id: \.self) { emoji in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    tutorialReactionCounts[emoji, default: 0] += 1
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(emoji)
                                    Text("\(tutorialReactionCounts[emoji, default: 0])")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(Color(white: 0.15))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .frame(width: 300)
                
                Text("(試しにリアクションを押してみよう！)")
                    .font(.system(size: 10))
                    .foregroundColor(.blue.opacity(0.8))
            }
        }
    }
    
    private func reactionPreview(emoji: String, label: String, desc: String) -> some View {
        VStack(spacing: 8) {
            Text(emoji).font(.system(size: 28))
            Text(label).font(.system(size: 11, weight: .bold))
            Text(desc).font(.system(size: 9)).foregroundColor(.white.opacity(0.5))
        }
    }
    
    private func handleJoin() {
        guard !isSubmitting else { return }
        isSubmitting = true
        
        // AppStore のログイン処理を呼ぶ（初回はチームコードをチーム名として登録）
        store.login(name: name, role: role, team: team, teamCode: teamCode, teamName: teamCode, ghostType: selectedGhost)
    }
}

// MARK: - Styles

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.18))
            .cornerRadius(8)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(10)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: 80)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppStore())
}
