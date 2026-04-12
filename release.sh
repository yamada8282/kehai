#!/bin/bash

# --- 設定 ---
APP_NAME="Kehai"
# 秘密鍵をここに一時的にセットするか、環境変数から読み込むようにしてください
# ユーザーに実行時に聞く形にします。
PRIVATE_KEY=""

echo "🚀 Kehai リリーススクリプト"

# 1. GitHubユーザー名の確認
if [ ! -f .github_user ]; then
    read -p "GitHubのユーザー名を入力してください: " GH_USER
    echo "$GH_USER" > .github_user
else
    GH_USER=$(cat .github_user)
fi

# 2. バージョンの入力
VERSION="$1"
if [ -z "$VERSION" ]; then
    read -p "新しいバージョン番号を入力してください (例: 1.1): " VERSION
fi

NOTES="$2"
if [ -z "$NOTES" ]; then
    read -p "リリースノート（変更点）を入力してください: " NOTES
fi

# 3. アプリをビルド & パッケージ
./make_app.sh "$VERSION" "$GH_USER"

# デスクトップに移動されたアプリをカレントディレクトリにコピーして作業
cp -R ~/Desktop/$APP_NAME.app .

# 4. Zip作成
ZIP_NAME="$APP_NAME-$VERSION.zip"
echo "🤐 $ZIP_NAME を作成中..."
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$ZIP_NAME"

# 5. 署名とAppcastの更新
# Sparkleのツールを使用
SIGN_UPDATE=".build/artifacts/sparkle/Sparkle/bin/sign_update"
GENERATE_APPCAST=".build/artifacts/sparkle/Sparkle/bin/generate_appcast"

if [ ! -f "$SIGN_UPDATE" ]; then
    echo "❌ Sparkleのツールが見つかりません。先に swift build を実行してください。"
    exit 1
fi

# 秘密鍵の入力（保存していない場合）
if [ -z "$PRIVATE_KEY" ]; then
    read -sp "EdDSA秘密鍵を入力してください（以前保存したもの）: " PRIVATE_KEY < /dev/tty
    echo ""
fi

# 署名
echo "✍️  署名中..."
SIGNATURE=$(echo -n "$PRIVATE_KEY" | "$SIGN_UPDATE" --ed-key-file - -p "$ZIP_NAME")
if [ $? -ne 0 ]; then
    echo "❌ 署名に失敗しました。秘密鍵が正しいか確認してください。"
    exit 1
fi

# Appcastの更新 (本来は generate_appcast を使いたいが、手動生成の方が確実な場合がある)
# ここでは簡易的に appcast.xml を生成/更新します
echo "XMLを生成中..."
cat > appcast.xml <<EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>Kehai Changelog</title>
        <item>
            <title>Version $VERSION</title>
            <sparkle:releaseNotesLink>
                https://raw.githubusercontent.com/$GH_USER/kehai/main/releasenotes.html
            </sparkle:releaseNotesLink>
            <pubDate>$(date -R)</pubDate>
            <enclosure url="https://github.com/$GH_USER/kehai/releases/download/v$VERSION/$ZIP_NAME"
                       length="$(stat -f%z "$ZIP_NAME")"
                       type="application/octet-stream"
                       sparkle:edSignature="$SIGNATURE"
                       sparkle:version="$VERSION" />
        </item>
    </channel>
</rss>
EOF

echo "📝 リリースノートを作成中..."
cat > releasenotes.html <<EOF
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: sans-serif; color: #eee; background: #222;">
    <h3>Version $VERSION</h3>
    <p>$NOTES</p>
</body>
</html>
EOF

echo "--------------------------------------------------"
echo "✅ 準備完了！"
echo "デスクトップに $ZIP_NAME が作成されました。"
echo "--------------------------------------------------"

# 後片付け
rm -rf "$APP_NAME.app"
