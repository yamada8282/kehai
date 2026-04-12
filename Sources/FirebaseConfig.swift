import Foundation

// ============================================================
// ⚠️  SETUP: Firebaseコンソールで作成したプロジェクトの値を入力
//
//  1. https://console.firebase.google.com/ でプロジェクトを作成
//  2. 「アプリを追加」→ iOS/macOS を選択（バンドルIDは任意）
//  3. GoogleService-Info.plist をダウンロードして下記の値をコピー
//  4. Realtime Database を有効化し、databaseURL を設定
//
//  myMemberId: このデバイスが担当するメンバーID（"1"〜"15"から選ぶ）
//  チームの各メンバーが別々の番号に設定すること
// ============================================================
enum FirebaseConfig {
    static let googleAppID  = "1:459395178357:ios:3a3fc0f1e6d34acc89fd3c" // GOOGLE_APP_ID
    static let gcmSenderID  = "459395178357"                              // GCM_SENDER_ID
    static let apiKey       = "AIzaSyCDbWkMiyIfuoPW03MHcfUC-i7PERxz-vE"   // API_KEY
    static let projectID    = "kehai-83147"                               // PROJECT_ID
    static let databaseURL  = "https://kehai-83147-default-rtdb.firebaseio.com" // ⚠️ DatabaseURLは自動生成のデフォルトルールに従います

    /// このデバイスが担当するメンバーID（mockMembersの "1"〜"15" から選ぶ）
    static let myMemberId   = "1"
}
