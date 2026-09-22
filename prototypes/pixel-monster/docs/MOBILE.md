# iOS 優先手機流程

目前的可交付平台是「桌面 Godot 4.7 → Xcode → iPhone」。主測試裝置是 iPhone 17 Pro；部署目標設為 iOS 16.0，因此產品範圍涵蓋 iPhone 12 及更新機型。這是工程目標，不是已完成的實機驗證：本專案尚未編寫 `CMPedometer` 原生外掛、尚未包含 Swift/Objective-C/GDExtension bridge，也沒有在 iPhone 17 Pro 或 iPhone 12 實機安裝測試。

2026-09-22 已完成 iPhone 17 Pro 與 iPhone 12／iOS 26.5 模擬器的 Release 建置、安裝、啟動及畫面擷取，亦通過未簽署的 arm64 實機 target 編譯。[驗收紀錄與截圖](VALIDATION.md)

## 正式開發路徑

1. 在 macOS 安裝固定的 Godot `4.7.stable.official.5b4e0cb0f`、相符的 iOS export template，以及 Xcode 26.6。
2. 在 `prototypes/pixel-monster/export_presets.cfg` 使用 iOS preset：iOS 16.0、`targeted_device_family=0`（iPhone）、arm64。Team ID 與 Bundle ID 故意保持空白。
3. PR/push 的 simulator-only smoke 可使用明確標記的 syntax placeholders `0000000000` / `org.godogen.pixelmonster.ci`，不需要 Apple 帳號；release 永遠拒絕這兩個值。真正裝置/archive 則以本機真實 `IOS_TEAM_ID` 與自己註冊的 `IOS_BUNDLE_IDENTIFIER` 執行工具。工具會把值注入暫存 project copy；不會改寫或提交 preset。
4. Godot 只負責輸出隔離的 Xcode project 與 `PocketDiary.pck`；Xcode 以 Simulator 做 unsigned smoke，或以 Apple Developer certificate/profile 做 device archive。iPhone 17 Pro 是主要實機目標，iPhone 12 是最低支援檢查點。
5. 以 protected `ios-release` environment 的 workflow_dispatch 進行簽署；需要時才把 signed IPA 上傳至 TestFlight。CI 不會自動送 App Review 或發布。

Apple Silicon Simulator 的 unsigned 路徑另外使用 matching-source template：workflow 以 Godot 4.7 stable 的官方 `ios.zip`、固定 SCons 4.9.1 與 pinned source 產生 arm64 simulator zip，並只把絕對路徑 `IOS_SIMULATOR_TEMPLATE` 注入 unsigned simulator 的暫存 preset。signed device export 不使用這個 override，仍走官方 device template；不採用 Intel/Rosetta fallback。這是針對 Godot 4.7 simulator template 架構問題的明確 workaround，背景與 upstream 討論見 [Godot issue #122379](https://github.com/godotengine/godot/issues/122379) 及 [Godot compiling for iOS](https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_for_ios.html)。

Godot 官方說明 iOS export 需要 macOS、Xcode 與相符的 export templates，且 Team ID 及唯一 Bundle Identifier 即使只輸出 Xcode project 也必填：[Exporting for iOS — Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html)。Apple 自 2026-04-28 起要求上傳 App Store Connect 的 app 以 Xcode 26 或更新版及 iOS 26 SDK 建置：[Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/)。

完整 CI 輸入、暫存 keychain、dry-run、unsigned build 與人工上架步驟見 [`docs/IOS-CICD.md`](IOS-CICD.md)。

## 本機可驗證命令

不需要 Apple 身分或網路的檢查：

```bash
cd prototypes/pixel-monster
python3 tools/ios/test_ios_pipeline.py
python3 tools/ios/build_ios.py preflight --mode unsigned --dry-run
python3 tools/ios/build_ios.py build --mode unsigned \
  --simulator "iPhone 17 Pro" --dry-run
```

若本機要重建 Apple Silicon matching-source simulator template，使用與 CI 相同的 isolated SCons 4.9.1 venv，再把輸出路徑傳給 unsigned pipeline：

```bash
python3 -m venv /tmp/pixel-monster-scons-4.9.1
/tmp/pixel-monster-scons-4.9.1/bin/python -m pip install 'scons==4.9.1'
python3 tools/ios/prepare_simulator_template.py \
  --template-zip "$HOME/Library/Application Support/Godot/export_templates/4.7.stable/ios.zip" \
  --output /tmp/pixel-monster-template/ios-arm64.zip \
  --scons /tmp/pixel-monster-scons-4.9.1/bin/scons --jobs 3
export IOS_SIMULATOR_TEMPLATE=/tmp/pixel-monster-template/ios-arm64.zip
python3 tools/ios/build_ios.py build --mode unsigned \
  --simulator-only --simulator "iPhone 17 Pro" --output-dir /tmp/pixel-monster-ios-local
python3 tools/ios/smoke_simulator.py --build-dir /tmp/pixel-monster-ios-local
```

`IOS_SIMULATOR_TEMPLATE` 必須是存在的絕對 `.zip`；工具會拒絕把它帶入 signed release。

這個 unsigned 路徑會把 `0000000000` / `org.godogen.pixelmonster.ci` 只注入暫存 export copy，使用 Godot Release template、Xcode Release、`CODE_SIGNING_ALLOWED=NO` 與 `CODE_SIGNING_REQUIRED=NO`，不建立 certificate、profile 或 ASC token。這兩個值不是 Apple identity，release path 會硬拒絕它們。裝置/archive 路徑仍需真實值：

```bash
export IOS_TEAM_ID='你的 Apple Team ID'
export IOS_BUNDLE_IDENTIFIER='你已註冊的 reverse-DNS Bundle ID'
export IOS_BUILD_NUMBER='1'
unset IOS_SIMULATOR_TEMPLATE
python3 tools/ios/build_ios.py build --mode release
```

Simulator 目標可透過 `SIMULATOR_UDID` 固定既有裝置；否則工具會以 `simctl` 嘗試建立指定的 iPhone 12／17 Pro 裝置。建立失敗會明確報出缺少的 runtime/device type。

Unsigned build 成功後的 `simulator-app.zip` 是實際 `Release-iphonesimulator/*.app` 的壓縮檔。同一 workflow 會檢查打包資源、安裝與啟動 App，並保存模擬器畫面；簽署憑證、profile 與完整本機設定見 [IOS-CICD](IOS-CICD.md)。

## Xogot：選配試玩，不是發佈工具

Xogot 官方首頁把 iPad/iPhone 版本描述為可在裝置上 build、run、debug、share，也把 Xogot Connect 描述為桌面 Godot 對 iPhone/iPad 的區域網路 deploy/debug/live-test：[Xogot 官方首頁](https://xogot.com/)。這適合快速看觸控 UI 與 mock flow，但不取代 Xcode export、簽署、App Store Connect 或實機原生 API 驗證。

可行的低風險試玩方式：複製 `prototypes/pixel-monster/`，將 zip 解壓並在 Files 複製 project folder 到 Xogot 的 `On My iPad/Xogot`，再從 Project Manager 開啟；這是 Xogot 官方既有專案匯入流程：[Getting Started](https://docs.xogot.com/documentation/xogot/getting-started/)。不要讓第一次匯入／升級覆寫 canonical desktop copy。

Xogot 的 engine 版本不能從首頁推定為本專案 exact Godot build。Xogot 官方近期文章只承諾 Godot 4.7.1-based builds 先在 XogotBeta TestFlight 驗證，之後才逐步進入正式 TestFlight/App Store：[Xogot Is Moving to Godot 4.7](https://blog.xogot.com/xogot-is-moving-to-godot-4-7/)。因此本 project 仍以桌面 `4.7.stable.official.5b4e0cb0f` 為 canonical；在 Xogot About／TestFlight 確認版本前，不宣稱相容，首次開啟使用可回復副本。

Xogot 官方差異說明把 iPad/iPhone workflow 的 game logic 限於 GDScript，C#、C++、Swift 等 compiled code／plugins 不應假設可用：[Differences from Godot](https://docs.xogot.com/documentation/xogot/differences/)。本專案沒有驗證 Xogot 能載入或編譯 `CMPedometer`，也沒有把 Xogot 的 Web export 當成 iOS native export。若要取得系統步數，後續仍須做真正的 Core Motion bridge、`NSMotionUsageDescription`、權限與 callback lifecycle；目前只可用既有 MockStepProvider。

## 後續 iOS 驗證順序

- 持續以 CI 重跑已通過的 iPhone 17 Pro／12 模擬器測試，另補 iOS 16 最低 OS 的相容性驗證。
- 以 Xcode archive 在 iPhone 17 Pro 實機驗證啟動、觸控、安全區、鎖屏／前景恢復、存檔與直式 layout。
- 另建最小 `StepProvider` 原生橋接，先驗證 `CMPedometer` 支援、授權、最近可查詢區間、背景／終止後補讀與回到 Godot 主執行緒；此項尚未實作。
- 取得 plugin 的可重現 desktop/Xcode build log 後，才評估它是否能被 Xogot 使用；在此之前假設 Xogot 不能使用該 compiled plugin。
- Android native steps／Health Connect 延後，不在此文件宣稱已支援。
