#!/bin/bash

# --- 実行方法 (Usage) ---
# 1. ターミナルを開く
# 2. 以下のコマンドをコピーして実行：
#    cd /Users/somayamada/Desktop/kehai/KehaiApp && chmod +x build_all.sh && ./build_all.sh
# ------------------------

# プロジェクトのパス
PROJECT_DIR="/Users/somayamada/Desktop/kehai/KehaiApp"
CONFIG_FILE="$PROJECT_DIR/Sources/FirebaseConfig.swift"
DESKTOP_DIR="/Users/somayamada/Desktop"

cd "$PROJECT_DIR"

# 元のファイルをバックアップ
cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

# ID 1から6までループ
for i in {1..6}
do
    echo "------------------------------------------"
    echo "🚀 メンバー ID: $i のアプリをビルド中..."
    
    # FirebaseConfig.swift の myMemberId を書き換え
    # static let myMemberId = "..." の行を置換
    sed -i '' "s/static let myMemberId = \".*\"/static let myMemberId = \"$i\"/" "$CONFIG_FILE"
    
    # ビルド
    swift build -c release > /dev/null 2>&1
    
    # アプリ作成
    APP_NAME="Kehai_Member$i"
    APP_BUNDLE="$APP_NAME.app"
    BIN_PATH=".build/release/KehaiApp"
    
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/Kehai"
    
    # Info.plist 作成
    cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Kehai</string>
    <key>CFBundleIdentifier</key>
    <string>com.somayamada.kehai.member$i</string>
    <key>CFBundleName</key>
    <string>Kehai</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

    # デスクトップに移動（既存のものがあれば上書き）
    rm -rf "$DESKTOP_DIR/$APP_BUNDLE"
    mv "$APP_BUNDLE" "$DESKTOP_DIR/"
    
    echo "✅ $APP_NAME.app がデスクトップに完了しました！"
done

# 元のファイルを復元
mv "$CONFIG_FILE.bak" "$CONFIG_FILE"

echo "=========================================="
echo "🎉 全員のアプリがデスクトップに揃いました！"
