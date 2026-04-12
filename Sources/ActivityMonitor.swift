import Foundation
import Cocoa
import Combine

class ActivityMonitor: ObservableObject {
    @Published var currentApp: String = "—"
    @Published var activityLevel: ActivityLevel = .idle

    private var eventCount = 0
    private var timer: Timer?
    private var workspaceCancellable: AnyCancellable?

    /// 評価ウィンドウ（秒）— 2分間のイベント数で判定
    private let windowSeconds: TimeInterval = 120

    /// 2分間でのイベント数しきい値
    /// active  : キーボード・マウスを活発に使用
    /// moderate: 軽く作業中
    /// idle    : ほぼ無操作
    private let activeThreshold   = 100
    private let moderateThreshold = 15

    init() {
        setupAppMonitor()
        setupEventMonitor()
        startTimer()
    }

    private func setupAppMonitor() {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            self.currentApp = frontApp.localizedName ?? "Unknown"
        }
        workspaceCancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.currentApp = app.localizedName ?? "Unknown"
                }
            }
    }

    private func setupEventMonitor() {
        // [IMPORTANT] ダイアログが自動で出るのを防ぐため、プロンプトオプションを false にします。
        // これにより、起動時に勝手に「許可を求めています」ウィンドウが出るのを阻止します。
        let promptOptions: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        _ = AXIsProcessTrustedWithOptions(promptOptions)

        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged,
            .keyDown, .flagsChanged, .scrollWheel
        ]
        NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.eventCount += 1
        }
        NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.eventCount += 1
            return event
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: windowSeconds, repeats: true) { [weak self] _ in
            self?.evaluateActivity()
        }
    }

    private func evaluateActivity() {
        let newLevel: ActivityLevel
        if eventCount >= activeThreshold {
            newLevel = .active
        } else if eventCount >= moderateThreshold {
            newLevel = .moderate
        } else {
            newLevel = .idle
        }
        activityLevel = newLevel
        eventCount = 0
    }
}
