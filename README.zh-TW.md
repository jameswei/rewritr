# Rewritr

[![CI](https://github.com/jameswei/rewritr/actions/workflows/ci.yml/badge.svg)](https://github.com/jameswei/rewritr/actions/workflows/ci.yml)

語言：[English](README.md) | [简体中文](README.zh-CN.md) | 繁體中文 | [日本語](README.ja.md)

<p align="center">
  <img src="assets/app-icon.png" width="96" alt="Rewritr app icon"/>
</p>

**專案網站：** https://lifeplayer.space/rewritr/

Rewritr 是一個隱私優先的原生 macOS 選單列 app，面向希望把英文寫得更自然、更順暢、更接近母語表達的非英語母語使用者。

它刻意保持小而專注：在其他 app 裡選取英文文字，觸發 Rewritr，然後用更清楚自然的版本替換原文。Rewritr 會盡量保留原意，避免把內容改成學術論文式、過度正式、俚語化或充滿贅字的英文。

## 截圖

<table>
  <tr>
    <td><img src="assets/screenshot_settings.png" width="360" alt="Rewritr settings with provider configuration, rewrite behavior, HUD appearance, and shortcut"/></td>
    <td><img src="assets/screenshot_permissions.png" width="360" alt="Rewritr permission setup screen with Accessibility permission status"/></td>
  </tr>
  <tr>
    <td align="center"><em>設定</em></td>
    <td align="center"><em>權限設定</em></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="assets/screenshot_privacy.png" width="520" alt="macOS Privacy and Security Accessibility permission screen for Rewritr"/></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><em>macOS 輔助使用權限</em></td>
  </tr>
</table>

## 下載

從 [GitHub Releases](https://github.com/jameswei/rewritr/releases) 下載最新版本。

新版提供內容相同的兩種 macOS app 發布格式：

- **DMG（建議）：** 開啟 DMG，然後將 `Rewritr.app` 拖到 `Applications` 捷徑。
- **ZIP：** 解壓縮後，將 `Rewritr.app` 移到穩定位置，例如 `/Applications`。

舊版本可能只提供 ZIP。兩種格式包含同一個未經 Apple 簽署或公證的 App。請只從本專案的 GitHub Releases 頁面下載；如需驗證檔案，請使用所選檔案旁發布的 SHA-256 校驗和。

### 安裝並允許未簽署的 App

macOS 可能需要兩項授權：因為 Rewritr 未簽署且未經公證，需要選擇**仍要打開**；為了自動複製和貼上你選取的文字，需要授予**輔助使用**權限。

1. 將 `Rewritr.app` 安裝到最終位置，建議使用 `/Applications`。
2. 嘗試開啟 Rewritr。如果 macOS 阻止開啟，請前往**系統設定 > 隱私權與安全性**，向下捲動到**安全性**，按一下**仍要打開**，然後確認**打開**。
3. 再次開啟 Rewritr，並依提示授予輔助使用權限。
4. 在 Settings 中設定你的 OpenAI-compatible provider。雲端 provider 通常需要 API key；本機 provider 可能不需要。

**仍要打開**通常只需確認一次。輔助使用權限與具體的 app bundle 路徑綁定，因此之後移動 App 可能需要重新授權。

## 運作方式

1. 在任何可編輯 app 裡選取英文文字。
2. 按 `Control+Option+R`。
3. Rewritr 透過 macOS 自動化複製選取的文字。
4. Rewritr 將文字送到你設定的 OpenAI-compatible Chat Completions provider。
5. Rewritr 會先預覽改寫結果，或直接替換選取文字。

Rewritr 支援兩種改寫行為：

- `Preview before replacing`：先顯示改寫結果，再選擇 `Replace`、`Copy`、`Retry` 或 `Dismiss`。
- `Replace instantly`：provider 回傳結果後立即替換選取文字，並在工作過程中顯示一個小型浮動狀態 HUD。

選單列圖示會顯示輕量狀態：

- `hourglass`：正在改寫或替換
- `checkmark.circle`：替換成功
- `exclamationmark.triangle`：失敗

## 隱私

你的隱私很重要，也應該掌握在你自己手裡。Rewritr 沒有後端服務，不保存選取文字、改寫歷史、分析資料或帳號資料。

- 只有你明確選取的文字會被送出，而且只會送到你設定的 provider endpoint。
- 如果你使用本機 OpenAI-compatible 模型，選取文字可以留在你自己的機器或網路裡。
- 非敏感設定保存在 UserDefaults。
- 如果 provider 需要 API key，API key 會在 provider 測試成功後保存在本機 macOS Keychain。
- 剪貼簿自動化會暫時使用 macOS pasteboard，並在安全時恢復先前的剪貼簿內容。

## 相容性

Rewritr 適用於大多數支援正常複製貼上的 macOS app 和瀏覽器文字欄位。也有一些重要限制：

- 觸發改寫前必須明確選取文字。
- 目標 app 必須支援對選取文字執行正常的 `Command-C` 和 `Command-V`。
- 不應該改寫密碼輸入框等安全欄位。
- Terminal 支援有限，因為終端機裡選取的文字通常是輸出或歷史紀錄，而不是可編輯輸入。
- 遠端桌面、虛擬機、瀏覽器 IDE，以及焦點處理方式特殊的 app 可能表現不穩定。
- 剪貼簿管理工具可能會觀察到暫時的剪貼簿變化，即使 Rewritr 隨後恢復了剪貼簿。

## 開發要求

- macOS 15 或更新版本
- 支援 macOS app 建置的 Xcode

## 開發

用 Xcode 開啟 `Rewritr.xcodeproj`，建置 `Rewritr` scheme。

本機建置：

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived build CODE_SIGNING_ALLOWED=NO
```

建置測試：

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived build-for-testing CODE_SIGNING_ALLOWED=NO
```

執行測試：

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived test CODE_SIGNING_ALLOWED=NO
```

## 更新日誌

參見 [CHANGELOG.md](CHANGELOG.md)。

## 發布

當推送 `v*` tag，或手動執行 `Release` workflow 時，GitHub Actions 會建置發布包。workflow 會將 `Rewritr.app` 同時封裝成 DMG 與 ZIP，驗證兩種發布包，並將檔案及其 SHA-256 校驗和附加到 GitHub Release。
