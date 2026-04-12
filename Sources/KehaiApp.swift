import SwiftUI
import AppKit
import FirebaseCore
import Combine

// MARK: - App Entry Point
@main
struct KehaiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    
    private var animationTimer: Timer?
    private var blinkTimer: Timer?
    private var rotationAngle: CGFloat = 0
    private var currentClosingAmount: CGFloat = 0
    private var isBlinking: Bool = false

    let store = AppStore()
    let updater = Updater()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar app behavior
        NSApp.setActivationPolicy(.accessory)

        // Firebase Configuration
        let options = FirebaseOptions(
            googleAppID: FirebaseConfig.googleAppID,
            gcmSenderID: FirebaseConfig.gcmSenderID
        )
        options.apiKey     = FirebaseConfig.apiKey
        options.projectID  = FirebaseConfig.projectID
        options.databaseURL = FirebaseConfig.databaseURL
        FirebaseApp.configure(options: options)

        // Start Firebase sync
        store.startSync()
        store.startMonitoring()

        // 1. Setup status bar item
        setupStatusItem()

        // 2. Setup popover (WidgetView only)
        setupPopover()

        // 3. Observe login state to show/hide onboarding window
        observeLoginState()

        // Start menu bar animations
        startAnimationCycle()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = CuteBlobIconRenderer.drawFace(closingAmount: 0, angle: 0)
            button.imageScaling = .scaleProportionallyDown
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 720, height: 340)
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = NSHostingController(rootView: WidgetView()
            .environmentObject(store)
            .environmentObject(updater)
        )
        popover.delegate = self
    }

    private func observeLoginState() {
        store.$isLoggedIn
            .receive(on: RunLoop.main)
            .sink { [weak self] loggedIn in
                if loggedIn {
                    self?.closeOnboardingWindow()
                    // ログイン成功時にポップアップを一度出すなど、完了を知らせる挙動も可能
                } else {
                    self?.showOnboardingWindow()
                }
            }
            .store(in: &cancellables)
    }

    private func showOnboardingWindow() {
        guard onboardingWindow == nil else {
            onboardingWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView()
            .environmentObject(store)
            .environmentObject(updater)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Kehai Onboarding"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .vibrantDark)
        window.setFrameAutosaveName("KehaiOnboardingWindow")
        
        window.contentViewController = NSHostingController(rootView: view)
        
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeOnboardingWindow() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    // MARK: - Status Item Handlers
    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Kehaiを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.popUpMenu(menu)
        } else {
            if store.isLoggedIn {
                togglePopover()
            } else {
                showOnboardingWindow()
            }
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 確実にキーウィンドウにして、タッチイベント等を受け取れるようにする
            if let window = popover.contentViewController?.view.window {
                window.makeKey()
                // さらに前面に持ってくる
                NSApp.activate(ignoringOtherApps: true)
                window.orderFront(nil)
            }
        }
    }

    // MARK: - Animation Cycle
    private func startAnimationCycle() {
        // 1. 回転タイマー（常時動作）
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // チーム活動量 (0.0〜1.0) に応じて回転速度を変更
            // 変化を極端にして直感的にする (0.5度 〜 22.0度)
            let delta = 0.5 + (pow(self.store.teamActivityLevel, 1.5) * 21.5)
            self.rotationAngle += delta
            if self.rotationAngle >= 360 { self.rotationAngle -= 360 }
            
            self.updateIcon()
        }
        
        // 2. 瞬きのスケジューリング開始
        scheduleNextBlink()
    }

    private func updateIcon() {
        let image = CuteBlobIconRenderer.drawFace(
            closingAmount: currentClosingAmount,
            angle: rotationAngle
        )
        statusItem.button?.image = image
    }

    private func scheduleNextBlink() {
        let level = store.teamActivityLevel
        // 瞬き間隔: 稼働中(1.0)は0.3〜0.8秒, 非稼働(0.0)は4.0〜10.0秒
        let lo = 0.3 + pow(1.0 - level, 2.0) * 3.7
        let hi = lo + 0.5 + pow(1.0 - level, 2.0) * 5.5
        let interval = Double.random(in: lo...hi)
        
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.performBlink()
        }
    }

    private func performBlink() {
        guard !isBlinking else { return }
        isBlinking = true

        // パチパチのアニメーションシーケンス
        let sequence: [CGFloat] = [0, 0.45, 0.8, 1.0, 1.0, 0.8, 0.45, 0]
        var step = 0
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            
            if step < sequence.count {
                self.currentClosingAmount = sequence[step]
                step += 1
            } else {
                t.invalidate()
                self.isBlinking = false
                self.scheduleNextBlink()
            }
        }
    }
}

// MARK: - Blob Icon Renderer
enum CuteBlobIconRenderer {

    /// 回転と瞬きを考慮して描画
    /// closingAmount: 0.0(開)〜1.0(閉)
    /// angle: 回転角度（度数法）
    static func drawFace(closingAmount: CGFloat, angle: CGFloat) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            // 中心を軸に回転
            ctx.translateBy(x: 9, y: 9)
            ctx.rotate(by: angle * .pi / 180.0)
            ctx.translateBy(x: -9, y: -9)

            // 1. キャラクター本体（丸枠の四角）を描画
            // template用なので黒で塗りつぶす（システム側で色がつく）
            let boxSize: CGFloat = 14
            let boxRect = CGRect(x: (18 - boxSize)/2, y: (18 - boxSize)/2, width: boxSize, height: boxSize)
            let path = CGPath(roundedRect: boxRect, cornerWidth: 3.2, cornerHeight: 3.2, transform: nil)
            ctx.addPath(path)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()

            // 2. 目の描画
            // "キャラの周囲と、目の外側の円は透過" = Clearで描画
            ctx.setBlendMode(.clear)
            
            let eyeY: CGFloat = 10.2
            let eyeSpacing: CGFloat = 5.8
            let leftX = 9.0 - eyeSpacing / 2
            let rightX = 9.0 + eyeSpacing / 2
            
            let openness = 1.0 - closingAmount
            let eyeScaleY = max(openness, 0.1)
            
            if closingAmount >= 0.95 {
                // 閉じ目: 横線状の穴
                let h: CGFloat = 1.2
                let w: CGFloat = 3.8
                ctx.fill(CGRect(x: leftX - w/2, y: eyeY - h/2, width: w, height: h))
                ctx.fill(CGRect(x: rightX - w/2, y: eyeY - h/2, width: w, height: h))
            } else {
                // 開き目: 外側の透過リング（穴をあける）
                let outerR: CGFloat = 2.6
                let innerR: CGFloat = 1.1
                
                let rectL = CGRect(x: leftX - outerR, y: eyeY - outerR * eyeScaleY, width: outerR * 2, height: outerR * 2 * eyeScaleY)
                let rectR = CGRect(x: rightX - outerR, y: eyeY - outerR * eyeScaleY, width: outerR * 2, height: outerR * 2 * eyeScaleY)
                ctx.fillEllipse(in: rectL)
                ctx.fillEllipse(in: rectR)
                
                // 3. 瞳（再び黒で塗りつぶして見えるようにする）
                ctx.setBlendMode(.normal)
                ctx.setFillColor(NSColor.black.cgColor)
                
                let pRectL = CGRect(x: leftX - innerR, y: eyeY - innerR * eyeScaleY, width: innerR * 2, height: innerR * 2 * eyeScaleY)
                let pRectR = CGRect(x: rightX - innerR, y: eyeY - innerR * eyeScaleY, width: innerR * 2, height: innerR * 2 * eyeScaleY)
                ctx.fillEllipse(in: pRectL)
                ctx.fillEllipse(in: pRectR)
                
            }
            
            return true
        }
        
        image.isTemplate = true
        return image
    }
}
