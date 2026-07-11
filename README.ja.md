# Rewritr

[![CI](https://github.com/jameswei/rewritr/actions/workflows/ci.yml/badge.svg)](https://github.com/jameswei/rewritr/actions/workflows/ci.yml)

言語：[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | 日本語

<p align="center">
  <img src="assets/app-icon.png" width="96" alt="Rewritr app icon"/>
</p>

**プロジェクトサイト：** https://lifeplayer.space/rewritr/

Rewritr は、英語をより自然でなめらか、ネイティブらしい表現に整えたい非ネイティブ英語話者のための、プライバシー重視のネイティブ macOS メニューバーアプリです。

機能は意図的に小さく絞っています。別のアプリで英文を選択し、Rewritr を起動すると、意味を保ったまま、より自然でわかりやすい英文に置き換えます。学術論文のような硬い英語、過度にフォーマルな英語、スラング寄りの英語、余計な言い回しの多い英語にはしません。

## スクリーンショット

<table>
  <tr>
    <td><img src="assets/screenshot_settings.png" width="360" alt="Rewritr settings with provider configuration and rewrite behavior"/></td>
    <td><img src="assets/screenshot_permissions.png" width="360" alt="Rewritr permission setup screen with Accessibility permission status"/></td>
  </tr>
  <tr>
    <td align="center"><em>設定</em></td>
    <td align="center"><em>権限設定</em></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="assets/screenshot_privacy.png" width="520" alt="macOS Privacy and Security Accessibility permission screen for Rewritr"/></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><em>macOS アクセシビリティ権限</em></td>
  </tr>
</table>

## ダウンロード

最新バージョンは [GitHub Releases](https://github.com/jameswei/rewritr/releases) からダウンロードできます。

現在のリリース成果物は、署名されていない macOS app zip です。解凍後：

- `Rewritr.app` を `/Applications` などの安定した場所へ移動します。
- Rewritr を開きます。
- 案内に従ってアクセシビリティ権限を付与します。
- Settings で OpenAI-compatible provider を設定します。クラウド provider は通常 API key が必要ですが、ローカルの OpenAI-compatible モデルでは不要な場合があります。

macOS のアクセシビリティ権限は、実行している app bundle のパスに紐づきます。権限付与後にアプリを移動した場合、再度権限を付与する必要があるかもしれません。

## 仕組み

1. 編集可能なアプリで英文を選択します。
2. `Control+Option+R` を押します。
3. Rewritr が macOS の自動化を使って選択テキストをコピーします。
4. Rewritr は設定済みの OpenAI-compatible Chat Completions provider にテキストを送信します。
5. Rewritr は書き換え結果をプレビューするか、選択テキストをすぐに置き換えます。

Rewritr は 2 つの書き換え動作をサポートしています：

- `Preview before replacing`：書き換え結果を先に表示し、`Replace`、`Copy`、`Retry`、`Dismiss` を選べます。
- `Replace instantly`：provider から結果が返るとすぐに選択テキストを置き換えます。処理中は小さなフローティングステータス HUD が表示されます。

メニューバーアイコンは軽量な状態を示します：

- `hourglass`：書き換え中または置き換え中
- `checkmark.circle`：置き換え成功
- `exclamationmark.triangle`：失敗

## プライバシー

あなたのプライバシーは重要であり、自分の手元で管理されるべきです。Rewritr にはバックエンドサービスがなく、選択テキスト、書き換え履歴、分析データ、アカウント情報を保存しません。

- 明示的に選択したテキストだけが送信され、送信先はあなたが設定した provider endpoint のみです。
- ローカルの OpenAI-compatible モデルを使う場合、選択テキストを自分の Mac やネットワーク内に留められます。
- 機密ではない設定は UserDefaults に保存されます。
- provider に API key が必要な場合、provider テスト成功後に macOS Keychain へローカル保存されます。
- クリップボード自動化では macOS pasteboard を一時的に使い、安全な場合は以前のクリップボード内容を復元します。

## 互換性

Rewritr は、通常のコピー＆ペーストに対応した多くの macOS アプリやブラウザのテキストフィールドで動作します。ただし重要な制限があります：

- 書き換えを実行する前に、必ずテキストを明示的に選択する必要があります。
- 対象アプリは、選択テキストに対する通常の `Command-C` と `Command-V` をサポートしている必要があります。
- パスワード入力欄などの安全なフィールドは書き換えるべきではありません。
- Terminal での利用は限定的です。ターミナルで選択される文字は、編集可能な入力ではなく出力や履歴であることが多いためです。
- リモートデスクトップ、仮想マシン、ブラウザベース IDE、フォーカス処理が特殊なアプリでは動作が不安定になる場合があります。
- Rewritr が後でクリップボードを復元しても、クリップボード管理ツールが一時的な変更を検知する場合があります。

## 開発要件

- macOS 15 以降
- macOS app build をサポートする Xcode

## 開発

Xcode で `Rewritr.xcodeproj` を開き、`Rewritr` scheme をビルドします。

ローカルビルド：

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived build CODE_SIGNING_ALLOWED=NO
```

テストをビルド：

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived build-for-testing CODE_SIGNING_ALLOWED=NO
```

テストを実行：

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived test CODE_SIGNING_ALLOWED=NO
```

## 変更履歴

[CHANGELOG.md](CHANGELOG.md) を参照してください。

## リリース

`v*` tag が push されたとき、または `Release` workflow を手動実行したときに、GitHub Actions がリリースをビルドします。workflow は `Rewritr.app` を zip にパッケージし、SHA-256 チェックサムと一緒に GitHub Release へ添付します。
