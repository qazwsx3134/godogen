# Pixel Monster iOS CI/CD

PR/push 會執行遊戲測試、iPhone 17 Pro／iPhone 12 的 Release 模擬器建置、安裝與啟動檢查，並編譯一次未簽署的 arm64 實機 App。驗證使用 `0000000000` / `org.godogen.pixelmonster.ci` 作為匯出所需的測試識別值，不需要 Apple 帳號。手動 `workflow_dispatch` 勾選 `confirm_release` 後，才進入 `ios-release` environment，以真實 Apple 憑證建立 signed IPA，並可選擇上傳 TestFlight。送審與正式發布由 App Store Connect 操作。

Godot PCK、Xcode project、原生引擎與 App sandbox 的分工見 [IOS-ARCHITECTURE.md](IOS-ARCHITECTURE.md)。本頁記錄目前已實作的 build pipeline；活動原生外掛的加入條件列在下方，尚未包含在現有 workflow。

workflow：[`../../../.github/workflows/pixel-monster-ios.yml`](../../../.github/workflows/pixel-monster-ios.yml)

## 固定版本與 runner 證據

- Godot：`4.7.stable.official.5b4e0cb0f`；editor 與 `4.7.stable` export templates 必須相同。
- Xcode：release/PR iOS job 固定選 `/Applications/Xcode_26.6.app`，期待 build `17F113`。
- runner：使用 `macos-26`，不是 `macos-latest`。GitHub 官方 image readme 目前列 Xcode 26.6（17F113）、iOS 26.5 SDK/runtime，以及預裝的 iPhone 17 Pro：[macos-26 included software](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)。
- iPhone 12 不在該 readme 的預裝 device 清單；workflow matrix 會指定 `com.apple.CoreSimulator.SimDeviceType.iPhone-12`，工具只在該 device type/runtime 可用時以 `simctl` 建立，否則 job 失敗並保留明確環境診斷。這不把「未預裝」捏造成「已驗證」。
- macOS 15 image 的 default Xcode 是 16.4；它只適合額外的舊版 Simulator 相容性工作，不可作 App Store release runner。Apple 自 2026-04-28 起要求 App Store Connect upload 使用 Xcode 26+ 與 iOS 26 SDK：[Apple Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/)。

Xcode 26 仍可把 deployment target 設為 iOS 16.0；這讓 iPhone 12（及更新機型）在產品支援範圍內，而非把最低 OS 誤設成 iOS 26。Xcode 的 SDK／deployment target 是兩個不同條件。

Apple Silicon simulator template：Godot 4.7 stock `ios.zip` 的 simulator library 可能只有 Intel slice；unsigned matrix 因此先以 pinned Godot source、官方 template、SCons 4.9.1 產生 matching arm64 simulator zip。背景參考 [Godot issue #122379](https://github.com/godotengine/godot/issues/122379) 與官方 [compiling for iOS](https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_for_ios.html)。補建只替換 simulator release 函式庫，device 函式庫保留官方版本。

## Export preset 的安全邊界

`export_presets.cfg` 只提交平台設定：iOS、iOS 16.0、arm64、iPhone device family、資源篩選與 `export_project_only=true`。它不包含 Apple Team ID、Bundle ID、certificate、profile、password 或 ASC key；marketing/build version 也由 pipeline 注入。Godot 4.7 官方明確要求 Team ID 與唯一 Bundle Identifier；即使是 Xcode project export，空值也會使 exporter 失敗：[Godot Exporting for iOS](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html)。

`tools/ios/build_ios.py` 會：

1. 驗證 Godot/Xcode/template 版本與 inputs。
2. unsigned `--simulator-only` 把 syntax placeholders 注入暫存 project copy；release 只接受真實 Team ID、Bundle ID（及 release signing option）。
3. unsigned simulator 若有 `IOS_SIMULATOR_TEMPLATE`，只在暫存 preset 的 `custom_template/release` 注入該絕對 zip；signed release 會拒絕這個環境輸入並使用官方 device template。呼叫 `godot --headless --path ... --export-release "iOS" ...`；`export_project_only=true` 會直接產生隔離目錄中的 `.xcodeproj` 與 `PocketDiary.pck`，不假設 Godot 會建立 zip；沒有使用 `--editorimport`，避免與 headless import/CI 狀態混淆。
4. 對 PR 用 `xcodebuild -configuration Release -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`，讓 production configuration 真正編譯。
5. 對 release 先把 profile 暫存安裝到 `~/Library/MobileDevice/Provisioning Profiles/<UUID>.mobileprovision`，保留同 UUID 舊檔；建立 temporary keychain、加入 keychain search list、匯入 p12、archive/export，再在所有成功/失敗路徑還原 search list、profile、keychain、certificate 暫存檔。
6. 若要求 TestFlight，使用 Xcode 26 內含的 `xcrun altool --upload-app` 搭配暫存 `API_PRIVATE_KEYS_DIR/AuthKey_<KEY_ID>.p8`；不改寫 HOME，private key 在 finally 清除，絕不進 artifact。Xcode 26.6 的 altool man page 明確支援 `API_PRIVATE_KEYS_DIR`。

所有 subprocess 以 argv 執行，不使用 `shell=True`；腳本不開啟 shell tracing，也不印出 secret environment 值。unsigned build 成功時會以 `ditto --keepParent` 將實際 `Release-iphonesimulator/*.app` 打成 `simulator-app.zip`，artifact 只上傳該 zip、`build-info.txt` 與 logs，不上傳 DerivedData 或 Godot 中間輸出；release artifact 只允許 IPA glob。

unsigned job 先以 `actions/cache` 快取由 helper 驗證的 runner-temp `ios-arm64.zip` 與 `ios-arm64.zip.provenance.json`；不快取 source workspace、DerivedData 或 logs。cache key 固定包含 Godot source commit `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`、runner architecture、Xcode 26.6 build `17F113`、iOS SDK `26.5` 與 `prepare_simulator_template.py` hash。cache miss 或驗證失敗時，workflow 在 isolated venv 安裝 `scons==4.9.1`，以 `--jobs 3` 重建；helper 是 cache validity 的唯一判定點。

`smoke_simulator.py` 安裝 App、確認啟動五秒後程序仍在執行，檢查腳本／資源錯誤並保存 `logs/simulator.png`。只關閉由這次檢查啟動的模擬器。iPhone 17 Pro job 另編譯 `iphoneos` arm64 target；這個未簽署產物用於驗證編譯，不能直接安裝到實體手機。手動 release 的 concurrency 獨立於 push/PR，後續 push 不會中斷已開始的發布建置。

## 活動原生外掛加入條件

目前 workflow 沒有 `CMPedometer`／HealthKit binary、`.gdip`、HealthKit entitlement 或用途說明。啟用活動加速前，pipeline 必須一併完成並驗證：

1. 用 Godot 4.7 對應 headers 建置 iOS plugin，輸出含 `iphoneos arm64` 與 Apple Silicon Simulator slice 的 `.xcframework`，連結 Core Motion 與 HealthKit；把 `.gdip` 和 binary 放入 `res://ios/plugins` 並確認 Godot export 實際啟用。
2. 在匯出的 target 加入 HealthKit capability／`com.apple.developer.healthkit` entitlement、`NSHealthShareUsageDescription` 與 `NSMotionUsageDescription`。只讀 workout 時不要求 HealthKit write permission。
3. Apple Developer 的 App ID 必須開啟 HealthKit；distribution provisioning profile 必須重新產生並包含相同 entitlement。CI 應以 `codesign -d --entitlements :-` 檢查 archive，而不是只相信 Xcode project 設定。
4. Simulator matrix 驗證兩個機型都能載入 plugin、啟動且在資料不可用時安全降級；實際授權、歷史查詢、空資料隱私語意與備份排除只能用 iPhone 17 Pro／iPhone 12 實機驗證。
5. 活動 ledger 與含活動結果的 save 要標記為不進入 iCloud／裝置備份；binary 不得把 HealthKit 或 Motion/Fitness 資料送到 analytics、廣告或遊戲伺服器。提交前同步更新隱私政策、App Store privacy answers 和 Review Notes。[Apple App Review Guidelines 2.5.1、5.1.1–5.1.3](https://developer.apple.com/app-store/review/guidelines/)

上述檢查進入 CI 後，才可把「原生活動資料」列為 release gate。現在的綠燈只證明無原生外掛版本能匯出、編譯與啟動。

## GitHub 設定：必要 inputs

先在 repository/environment 建立下列非秘密 Variables。這些值必須由 App Store Connect／Apple Developer 帳號提供，不能用範例值代替：

| Variable | 用途 |
| --- | --- |
| `IOS_TEAM_ID` | Apple Developer Membership 的 10 字元 Team ID；也是 Godot iOS exporter 的 required field |
| `IOS_BUNDLE_IDENTIFIER` | 已在 Apple Developer 註冊、且與 App Store Connect app 一致的 reverse-DNS Bundle ID |
| `IOS_MARKETING_VERSION` | `major.minor.patch` 的 App Store version；未設定時原型預設 `0.1.0` |
| `IOS_BUILD_NUMBER` | 本機 release 必填的 Apple-shaped build version（例如 `1` 或 `1.0.1`）；GitHub release 由 `GITHUB_RUN_NUMBER` + `GITHUB_RUN_ATTEMPT` 推導，不必手填 |
| `IOS_CODE_SIGN_IDENTITY` | 例如實際環境中的 Apple Distribution identity；由 signing setup 決定，不由 repo 捏造 |
| `IOS_PROVISIONING_PROFILE_NAME` | 可選；若留空，工具從上傳的 profile metadata 讀取 Name |

在 protected `ios-release` environment 放下列 Secrets：

| Secret | 內容 |
| --- | --- |
| `IOS_CERTIFICATE_P12_BASE64` | Apple signing certificate 的 base64 PKCS#12；不要提交 `.p12` |
| `IOS_CERTIFICATE_PASSWORD` | 該 p12 password |
| `IOS_PROVISIONING_PROFILE_BASE64` | 與 Bundle ID、Team、distribution method 相符的 profile base64 |
| `ASC_KEY_ID` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | App Store Connect API issuer UUID |
| `ASC_PRIVATE_KEY_P8` | 一次下載的 App Store Connect `.p8` private key 內容 |

`ASC_*` 只有在手動勾選 `upload_testflight` 時才必須存在。若只想建立 signed IPA，可不提供 ASC secrets。environment 必須設定 required reviewers／deployment protection；沒有 protected environment approval，release job 不應執行。

加入 HealthKit 後，`IOS_PROVISIONING_PROFILE_BASE64` 還必須來自已啟用 HealthKit 的 App ID，且 profile entitlement 必須與 archive 一致；沿用舊 profile 會讓簽署或安裝失敗。

PR/push simulator-only job 不需要上述 Team/Bundle values，因為它明確使用 syntax-only placeholders；這些值不會被 release 接受。signed release 仍需要真實 Team/Bundle/certificate/profile/ASC values。若本地 release 沒有 `GITHUB_RUN_NUMBER`，必須提供 `IOS_BUILD_NUMBER`；這是刻意的安全狀態，不是用 dummy identity 讓上架流程假綠。

## 本機流程

先做不觸碰 Apple 工具的 dry-run 與離線 mock contract tests：

```bash
cd prototypes/pixel-monster
python3 tools/ios/test_ios_pipeline.py
python3 tests/test_simulator_template.py
python3 tools/ios/test_smoke_simulator.py
python3 tools/ios/build_ios.py preflight --mode unsigned --dry-run
python3 tools/ios/build_ios.py build --mode unsigned \
  --simulator-only --simulator "iPhone 17 Pro" --dry-run
```

真正的 unsigned Simulator Release build（不需要 Apple account；成功後輸出 `simulator-app.zip`、`build-info.txt` 與 logs）：

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export IOS_XCODE_VERSION=26.6
xcodebuild -version  # 確認目前選用 Xcode 26.6

mkdir -p build/ios-template
touch build/.gdignore
python3 -m venv build/ios-tools
build/ios-tools/bin/python -m pip install 'scons==4.9.1'
python3 tools/ios/prepare_simulator_template.py \
  --template-zip "$HOME/Library/Application Support/Godot/export_templates/4.7.stable/ios.zip" \
  --output "$PWD/build/ios-template/ios-arm64.zip" \
  --scons "$PWD/build/ios-tools/bin/scons" --jobs 3
export IOS_SIMULATOR_TEMPLATE="$PWD/build/ios-template/ios-arm64.zip"

python3 tools/ios/build_ios.py preflight --mode unsigned --simulator-only
python3 tools/ios/build_ios.py build --mode unsigned \
  --simulator-only --simulator "iPhone 17 Pro" --output-dir build/ios-local
python3 tools/ios/smoke_simulator.py --build-dir build/ios-local
```

首次補建需要網路、Xcode 與數分鐘編譯時間；同版模板與工具鏈會重用已驗證的快取。本機原始碼或輸出只放在 `build/` 內，`.gdignore` 避免 Godot 編輯器掃描建置產物。

使用剛才 export 的 pack 驗證 release 資源（包含 `balance.json`、`opponents.json` 與 `assets/fonts/OFL.txt`）：

```bash
"${GODOT_BIN}" --headless \
  --main-pack build/ios-local/xcode/PocketDiary.pck \
  --script "${PWD}/tests/test_flow.gd" -- \
  --release-simulation --expect-packed \
  --save-path=/tmp/pixel-monster-test-packed.json
```

指定 iPhone 12 target（是否能建立取決於本機已安裝的 simulator runtime/device type）：

```bash
SIMULATOR_RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-26-5 \
SIMULATOR_DEVICE_TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-12 \
python3 tools/ios/build_ios.py build --mode unsigned --simulator-only \
  --simulator "iPhone 12" --output-dir build/ios-iphone12
python3 tools/ios/smoke_simulator.py --build-dir build/ios-iphone12
```

release 命令不在本文件提供任何假 credential；設好上述真實 variables/secrets 後，並在本機提供 `IOS_BUILD_NUMBER`，腳本會產生 `PocketDiary.ipa`。先不加 `--upload` 可只做 signed IPA，加入 `--upload` 才呼叫 altool：

```bash
export IOS_TEAM_ID='從 Apple Developer Membership 取得的真值'
export IOS_BUNDLE_IDENTIFIER='從 Apple Developer 註冊的真值'
export IOS_MARKETING_VERSION='0.1.0'
export IOS_BUILD_NUMBER='1'
unset IOS_SIMULATOR_TEMPLATE
python3 tools/ios/build_ios.py build --mode release --output-dir build/ios-release
python3 tools/ios/build_ios.py build --mode release --upload --output-dir build/ios-release
```

`install_godot.sh` 是 CI 使用的固定安裝器：從官方 Godot 4.7 stable release asset 下載 macOS universal editor 與 matching export templates；本機已存在同 exact version 時不重裝。沒有網路時可直接使用本機已安裝的 Godot/template，或只跑 dry-run/contract tests。

2026-09-22 本機驗證：iPhone 17 Pro、iPhone 12／iOS 26.5 的 arm64 simulator Release build、安裝、啟動與截圖皆通過；官方 device template 的未簽署 arm64 Release build 亦通過。補建模板及快取重用已有實際執行證據，詳見 [驗收紀錄](VALIDATION.md)。GitHub runner、Apple Distribution 簽署與 TestFlight 上傳尚未執行。

## TestFlight 與 App Store 最後人工步驟

Apple 文件允許用 Xcode、altool、Transporter 或 App Store Connect API 上傳；本 pipeline 的 altool 階段只上傳 build 到 TestFlight，不做審核提交：[Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)。上傳後仍需等待 Apple processing。

人工完成：

1. 在 App Store Connect 確認 build processing 完成，檢查 warnings、version/build、Bundle ID 與 export compliance。
2. 建立或更新 iOS app version、metadata、privacy、age rating、screenshots 與 iPhone 12/17 Pro 對應畫面。
3. 在 TestFlight 建立 internal/external tester group，邀請測試者並收集 crash/feedback。
4. 回到 app version 的 Build 區選取已處理的 build，回答 export compliance／加密問題；Apple 的選取 build 流程在 [Choose a build to submit](https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit)。
5. 由具權限的人員人工按 Submit for Review；審核通過後再按 release/publish。workflow 不代替這些決策，也不會自動送審。

## Xogot 邊界與後續風險

Xogot 是選配的 Apple-native Godot workflow，不是本 pipeline 的依賴，也不是付費才能執行本 repo 的必要工具。官方首頁描述在 iPad/iPhone build、run、debug、share，以及 Xogot Connect 的 remote deploy/live-test：[xogot.com](https://xogot.com/)。但 Xogot engine 版本跟桌面 exact 4.7 commit 不應假設相同；官方 4.7.1 文章目前描述的是 XogotBeta 測試／逐步轉換：[Xogot 4.7 update](https://blog.xogot.com/xogot-is-moving-to-godot-4-7/)。

Xogot iPad/iPhone 對 compiled language／compiled plugin 的支援限制也不能被忽略：[Xogot differences](https://docs.xogot.com/documentation/xogot/differences/)。本 repo 沒有原生 `CMPedometer`／HealthKit plugin、用途說明或 entitlement，也沒有 iPhone 實測；因此 Xogot local play 或 web export 都不能被記錄為原生活動串接通過。Android native path 延後。
