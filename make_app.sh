#!/bin/bash

# 1. 引数の処理
VERSION="${1:-1.0}"
GH_USER="${2:-ユーザー名}"
echo "🚀 バージョン: $VERSION, GitHubユーザー: $GH_USER"

# 2. ビルド
echo "🛠 ビルド中..."
swift build -c release

# 3. フォルダ構造の作成
APP_NAME="Kehai"
APP_BUNDLE="$APP_NAME.app"
BIN_PATH=".build/release/KehaiApp"

# Sparkleのフレームワークを探す
SPARKLE_FRAMEWORK=$(find .build -name "Sparkle.framework" -type d | grep "release" | head -n 1)

echo "📦 アプリをパッケージ中..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

# 3. バイナリとフレームワークのコピー
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [ -n "$SPARKLE_FRAMEWORK" ]; then
    echo "📎 Sparkle.framework をコピー中..."
    cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/"
else
    echo "⚠️ Sparkle.framework が見つかりませんでした。ビルドを確認してください。"
fi

# 3.5 アイコンのコピー
if [ -f "AppIcon.icns" ]; then
    echo "🎨 アイコンをコピー中..."
    cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# 4. Info.plist の作成 (これがないとOSにアプリとして認めてもらえない)
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.somayamada.kehai</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/$GH_USER/kehai/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>QWR9HAVKDnn6unzowcLDGVuFNr+sjNuKv3hXKF6DFBk=</string>
</dict>
</plist>
EOF

# 5. RPATH の調整（Sparkleが見つかるように）
# 既に設定されている場合でも安全に実行
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true

# 5.5 アドホック署名と実行権限の付与
echo "✍️  アドホック署名を付与中..."
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
codesign --force --deep --sign - "$APP_BUNDLE"

# 6. デスクトップに移動
rm -rf ~/Desktop/"$APP_BUNDLE"
mv "$APP_BUNDLE" ~/Desktop/
echo "✅ 完了しました！"
echo "👉 デスクトップにある '$APP_BUNDLE' を使ってください。ターミナルは出ません。"
