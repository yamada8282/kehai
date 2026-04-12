import Foundation
import Sparkle

/// Sparkleを利用した自動アップデートの管理クラス
final class Updater: ObservableObject {
    private let controller: SPUStandardUpdaterController
    
    @Published var canCheckForUpdates = false
    
    init() {
        // SPUStandardUpdaterController を初期化
        // ユーザーインターフェースが必要な場合はこれを使用します
        self.controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        // 更新チェックが可能かどうかを監視
        self.controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    /// 手動でアップデートを確認
    func checkForUpdates() {
        if canCheckForUpdates {
            controller.checkForUpdates(nil)
        }
    }
}
