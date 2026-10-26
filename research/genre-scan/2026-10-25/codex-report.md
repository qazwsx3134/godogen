# Codex 第一批交接（規格第 1～3 節）

狀態：實作與 310 項 assertions 通過，待 Claude 實際 diff 審查。未 commit、push、stage；未接入原型。

## 改動檔

- `prototypes/godot-kit/addons/proto_kit/card_draft.gd`：新增 129 行；SHA256 `2f960424e1f3bfe22a839df1621b1df3378b86ebc71596abdf63def54fe25d83`。另有 Godot 自動產生的 `.uid`。
- `prototypes/godot-kit/addons/proto_kit/upgrade_tree.gd`：新增 99 行；SHA256 `69a32cbfa34e9517706e8e8c0da9897461ee9ee0805e1bc0726d6ec42c5b262b`。另有 Godot 自動產生的 `.uid`。
- `prototypes/godot-kit/addons/proto_kit/run_goals.gd`：新增 68 行；SHA256 `59870a9f816fbdb6752abec9008469d53ab3ade0e9101cbcc84561105b53580e`。另有 Godot 自動產生的 `.uid`。
- `prototypes/godot-kit/tests/test_genre_modules.gd`：新增 115 行；SHA256 `655fba321891fcd2e77ab703ed625922560495eab85be393426268892d706510`。另有 Godot 自動產生的 `.uid`。

## 測試指令與輸出原文

```sh
env XDG_DATA_HOME=/tmp/genre-scan-2026-10-25/godot-data XDG_CONFIG_HOME=/tmp/genre-scan-2026-10-25/godot-config prototypes/godot-kit/tools/run_tests.sh prototypes/godot-kit genre_modules
```

```
PASS genre_modules
logs: /tmp/godot-tests.1StBoW
```

測試日誌原文：

```
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

checks: 310
GENRE MODULES TESTS PASSED
```

覆蓋：同 seed、無重複、200 次放逐排除、重抽避開與額度歸零、技能欄位、前置牌、終極解鎖、滿級、JSON 存讀後 RNG 接續；五級成本、明訂價格、鄰接單向宣告視同無向、locked/maxed/short、preview、totals、退款與舊 id；單局重設、跨局累計、tier 過濾、一次完成、永久獎勵與 claimed 存讀。

初次無 XDG 路徑執行因 sandbox 不允許 user:// 日誌寫入而引擎崩潰（exit 134）；設定 /tmp 後已正常。修正測試常數 Tree 與原生類別撞名後重跑通過。最後一次 import 有 sandbox TCP listen 的 ERR_CANT_CREATE 訊息，沒有 SCRIPT ERROR / Parse Error；suite 日誌乾淨。

## 規格空白採用的保守解

- ultimate 的卡片資料增加可選 `ultimate_need`，預設 3；原規格未提供 offer 判斷分支所需的門檻來源。
- 存檔額外保留 RNG state（十進位字串避免 JSON 精度損失）與 offer_count，使讀檔後後續 offer/reroll 一致。呼叫端應給每個 draft 獨立 RNG；載入會恢復傳入 RNG 的 state。
- run_goals 保存非 per_run 的 persistent_counts；不保存局內計數與 tier。claimed 由已知、去重後的 completed 推導，不信任冗餘 claimed 數字。
- root 本身可購買；設定 root 後不相連的孤立節點鎖定。未設定 root 且無邊者可直接購買。
- preview now/after 為該節點提供的屬性；滿級 after 與 now 相同。重複 reward 僅回傳一次。
- reroll 需要目前有選牌；沒有 current 時不扣額度。

## 範圍與尚未完成

- 僅寫上述四個 `.gd`、其 Godot `.uid` 與本報告；未修改 README、研究文件、AGENTS、其他模組或 art_src。
- 修改前 tracked status 已記錄 `/tmp/genre-scan-2026-10-25/codex-status-before.txt`；共享工作樹的其他差異由其他工作產生，不代表本批改動。
- 按 brief 第 4 節 UI 尚未實作，等待第二批明確分工。
- 無參考 patch，無圖片產生，無視窗開啟。


## 第二批：UI 樣式與八個版型（完成，待 Claude 審查）

第一批 review-1 的兩項小修已完成：三個模組補 preload／資料格式檔頭，card_draft 說明 ultimate 不佔欄位與 RNG state 恢復；upgrade_tree 對 adj 存在但未設定 root 的資料 push_error，並有驗證。測試函式之間空兩行。

### 新增與修改

- `ui_styles.json` 完整照目錄轉錄三組色票、邊框、圓角、字級、間距、分類色與元素色；沒有更動 token。
- `ui_theme.gd` 提供 ids/build/tokens，建立 Button、Panel、PanelContainer、Label、ProgressBar、TabContainer/TabBar，另有 TitleLabel/CaptionLabel/SectionVBox/RoundButton 變體。
- 八個無根腳本的 scene，皆以 Container/anchor 排版、含代表內容、保存 Theme 與靜態字串，% 名稱逐一符合目錄。
- make_ui_layouts 為一次性製作工具，透過 scene_builder.save_scene，既存檔案一律跳過。初版尚未交付、無人工編輯時有一次性修訂；正式產生器沒有 overwrite 開關。
- ui_gallery 只載入保存的 scene，切換 root Theme 後截圖至 user://，不重建 scene。
- 原本規格第 4 節列六個版型，依 brief-2 與最新目錄完成八個（含 result_report、dialogue_portrait）。

Scene 節點數：idle_split_panel 42；tabbed_modal 47；card_draft 17；settings_list 26；quest_list 27；hud_arpg 27；result_report 24；dialogue_portrait 16。

### 測試與實際輸出

```sh
env XDG_DATA_HOME=/tmp/genre-scan-2026-10-25/godot-data XDG_CONFIG_HOME=/tmp/genre-scan-2026-10-25/godot-config prototypes/godot-kit/tools/run_tests.sh prototypes/godot-kit genre_modules proto_kit
```

```
PASS genre_modules
PASS proto_kit
logs: /tmp/godot-tests.mqNszs
```

完整 genre_modules 日誌：

```
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

ERROR: UpgradeTree: adjacency requires an explicit root
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _init (res://addons/proto_kit/upgrade_tree.gd:17)
       [1] _test_tree (res://tests/test_genre_modules.gd:98)
       [2] _run (res://tests/test_genre_modules.gd:23)
CONTRAST dark_gothic text/panel 12.599
CONTRAST dark_gothic text_dim/panel 5.448
CONTRAST dark_gothic accent/panel 7.621
CONTRAST dark_gothic danger/panel 4.671
CONTRAST pixel_gilded text/panel 13.911
CONTRAST pixel_gilded text_dim/panel 6.767
CONTRAST pixel_gilded accent/panel 9.149
CONTRAST pixel_gilded danger/panel 4.914
CONTRAST forest_vine text/panel 15.700
CONTRAST forest_vine text_dim/panel 8.504
CONTRAST forest_vine accent/panel 10.687
CONTRAST forest_vine danger/panel 5.602
checks: 700
GENRE MODULES TESTS PASSED
```

其中 adjacency requires an explicit root 是審查要求的刻意負例，屬預期 push_error；沒有 SCRIPT ERROR 或 Parse Error。測試還驗證 24 種樣式×版型的 390×844 邊界與主要按鈕可見性、scene owner、節點數、所有 % 名稱、手機按鈕高度、修改靜態文字與間距進入樹後保留、執行個體修改不污染來源。既有 proto_kit 完整原文在上述 logs 目錄。

對比全部達標：dark_gothic 的 text/dim/accent/danger = 12.599/5.448/7.621/4.671；pixel_gilded = 13.911/6.767/9.149/4.914；forest_vine = 15.700/8.504/10.687/5.602。沒有不足 4.5:1 的內文字色。

產生器重跑與雜湊驗證原文：

```
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

skip (exists): res://addons/proto_kit/ui/layouts/idle_split_panel.tscn
skip (exists): res://addons/proto_kit/ui/layouts/tabbed_modal.tscn
skip (exists): res://addons/proto_kit/ui/layouts/card_draft.tscn
skip (exists): res://addons/proto_kit/ui/layouts/settings_list.tscn
skip (exists): res://addons/proto_kit/ui/layouts/quest_list.tscn
skip (exists): res://addons/proto_kit/ui/layouts/hud_arpg.tscn
skip (exists): res://addons/proto_kit/ui/layouts/result_report.tscn
skip (exists): res://addons/proto_kit/ui/layouts/dialogue_portrait.tscn
UI LAYOUTS GENERATED

SCENE HASHES UNCHANGED: True
```

### 預覽

```sh
env -u WAYLAND_DISPLAY XDG_DATA_HOME=/tmp/genre-scan-2026-10-25/godot-data XDG_CONFIG_HOME=/tmp/genre-scan-2026-10-25/godot-config xvfb-run -a godot --path prototypes/godot-kit --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/ui_gallery.gd
```

輸出末行：`UI GALLERY PASSED: 24 images`。

- 24 張 PNG：`/tmp/genre-scan-2026-10-25/godot-data/godot/app_userdata/proto_kit/ui_gallery/`
- 完整 stdout/stderr：`/tmp/genre-scan-2026-10-25/gallery.log`
- 人工視覺檢查 pixel_gilded 全八版（最大字級）；修正標題按鈕搶寬、TabBar 內建箭頭截斷、面板伸展層級。再次確認 idle/settings/HUD/dialogue 修正後圖。
- xvfb 唯一警告為驅動不支援 V-Sync mode；沒有視窗出現在桌面。

### 整合說明與未做範圍

- 版型是靜態可編輯起點；不包含遊戲流程、Q/E signal binding、選牌抽屜開關或資料接線。TabContainer 內建切頁與 Button toggle 可操作；TabBar/箭頭由採用遊戲接線。
- 根節點以 390×844 作編輯參考，嵌入遊戲時將根 Control 設 full rect；內部排版都交給 Container。gallery 只在掛入時設定根 full rect。
- `Name`/`Portrait`/`Text` 等占位符供使用者換內容；未製作外部圖像或借用遊戲素材。對話版型不影響 debt-commission。
- 目錄指定 Noto 字體未隨模組打包，Theme 使用 SystemFont 指定該家族並提供現有 CJK 系統後備。要跨平台固定字形，採用遊戲應提供字體資源；Web 匯出須確認 JSON export include filter（本批不修改 export preset）。
- README 仍由 Claude 維護；未接入任何原型。未 commit/push/stage，也未修改其他工作者檔案。
- 協作：已核對 ui-style-catalog.md 的實際表格與八個名稱，token/版型對應 ACK；README 的最後整合由 Claude 負責。

### 本批檔案 SHA256

- `prototypes/godot-kit/addons/proto_kit/ui/layouts/card_draft.tscn` (575 行)：`0f60a005c4da2d70167bc443afffcd8615d9f309824757907244b6655961d551`
- `prototypes/godot-kit/addons/proto_kit/ui/layouts/dialogue_portrait.tscn` (561 行)：`612524970640cec2f77dc17800fc214268959efbe0ad55c2cc4c5fd7d7cadb25`
- `prototypes/godot-kit/addons/proto_kit/ui/layouts/hud_arpg.tscn` (640 行)：`2716b104a458cca3dd2c45559905c371b8331be65830af5fb8a03113b24d2b52`
- `prototypes/godot-kit/addons/proto_kit/ui/layouts/idle_split_panel.tscn` (716 行)：`e0adead2425254047fcb33dc96b401540f187a7c5c77bdb8aaac43d9556b12f4`
- `prototypes/godot-kit/addons/proto_kit/ui/layouts/quest_list.tscn` (622 行)：`83ce49b37d0b55fcbafb70f2afd6df54d74bec0c98773ad007ca21cd71221d60`
- `prototypes/godot-kit/addons/proto_kit/ui/layouts/result_report.tscn` (613 行)：`cc6f95a116ca6e3b212cef66043f4bdd1cefd3d07e862e28e908b85915e004aa`
- `prototypes/godot-kit/addons/proto_kit/ui/layouts/settings_list.tscn` (620 行)：`fe02b42e0321883c5c6832be13507c9c7d47a997152c93d01ebdd3c4ecd22646`
- `prototypes/godot-kit/addons/proto_kit/ui/layouts/tabbed_modal.tscn` (715 行)：`7eb16afacdde3a485032f28c1c71f75765f035676519febd6a76d50433fee9a7`
- `prototypes/godot-kit/addons/proto_kit/ui/ui_styles.json` (31 行)：`24241f270ebd636a83ab8370fe928d039a7dc6242634854a1032de0c0028733e`
- `prototypes/godot-kit/addons/proto_kit/ui/ui_theme.gd` (79 行)：`0ce374a9ba9738005ebf0b3ce4f8cd0f692c6851cda1ab3a3adfacc04a7cdedd`
- `prototypes/godot-kit/tools/make_ui_layouts.gd` (303 行)：`665729e3f2668830f224d53fff1b2eb98fe24eaa25f2cedc0d40809b191da5da`
- `prototypes/godot-kit/tools/ui_gallery.gd` (38 行)：`184d7f59de71d5ca3e08c3ea345e01295d314ac14009ae5a03f876af1eca146a`
- `prototypes/godot-kit/tests/test_genre_modules.gd` (207 行)：`7d44dbbc61ff2e57838e6a0073118ed4bc1391306b86416b594bd950ea4e4da5`

另含 Godot 自動產生的 `.gd.uid`。


## 第二批修正

review-2 兩項均已修正：

1. quest_list 的 %Count 設 AUTOWRAP_OFF，搭配 SIZE_SHRINK_END；三種樣式 390×844 預覽都確認「0 / 12」維持一行。
2. 新增 `addons/proto_kit/ui/themes/{dark_gothic,pixel_gilded,forest_vine}.tres`，八個 scene 根節點皆以 ext_resource 引用 dark_gothic.tres，沒有內嵌 Theme。gallery 仍以 build 切換 Theme。make_ui_layouts 只建立缺少的 Theme，既存 Theme／scene 均保留。

依審查授權以一次性工具重產八個 scene；前後節點數及所有指定 % 名稱逐一比對相同。正式產生器仍不覆寫；重跑另以 SHA256 證明八個 scene 與三個共享 Theme 全部不變。

測試新增：每個 scene 不含 Theme sub_resource、根 Theme 的 resource_path 為共用檔、三個 Theme 資源可載入；遍歷全部樣式×版型可見 Label，若未開 autowrap，其高度不得超過兩行字高、實際行數不超過兩行。

測試指令：

```sh
env XDG_DATA_HOME=/tmp/genre-scan-2026-10-25/godot-data XDG_CONFIG_HOME=/tmp/genre-scan-2026-10-25/godot-config prototypes/godot-kit/tools/run_tests.sh prototypes/godot-kit genre_modules proto_kit
```

輸出原文：

```
PASS genre_modules
PASS proto_kit
logs: /tmp/godot-tests.0N007g
```

完整 genre_modules 日誌：

```
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

ERROR: UpgradeTree: adjacency requires an explicit root
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _init (res://addons/proto_kit/upgrade_tree.gd:17)
       [1] _test_tree (res://tests/test_genre_modules.gd:98)
       [2] _run (res://tests/test_genre_modules.gd:23)
CONTRAST dark_gothic text/panel 12.599
CONTRAST dark_gothic text_dim/panel 5.448
CONTRAST dark_gothic accent/panel 7.621
CONTRAST dark_gothic danger/panel 4.671
CONTRAST pixel_gilded text/panel 13.911
CONTRAST pixel_gilded text_dim/panel 6.767
CONTRAST pixel_gilded accent/panel 9.149
CONTRAST pixel_gilded danger/panel 4.914
CONTRAST forest_vine text/panel 15.700
CONTRAST forest_vine text_dim/panel 8.504
CONTRAST forest_vine accent/panel 10.687
CONTRAST forest_vine danger/panel 5.602
checks: 725
GENRE MODULES TESTS PASSED
```

adjacency requires an explicit root 為第一批審查要求的刻意負例，預期 push_error，無 SCRIPT ERROR／Parse Error。

重產比對原文：

```
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

saved: res://addons/proto_kit/ui/layouts/idle_split_panel.tscn (42 nodes)
PRESERVED idle_split_panel: 42 nodes, 4 unique names
saved: res://addons/proto_kit/ui/layouts/tabbed_modal.tscn (47 nodes)
PRESERVED tabbed_modal: 47 nodes, 5 unique names
saved: res://addons/proto_kit/ui/layouts/card_draft.tscn (17 nodes)
PRESERVED card_draft: 17 nodes, 5 unique names
saved: res://addons/proto_kit/ui/layouts/settings_list.tscn (26 nodes)
PRESERVED settings_list: 26 nodes, 4 unique names
saved: res://addons/proto_kit/ui/layouts/quest_list.tscn (27 nodes)
PRESERVED quest_list: 27 nodes, 3 unique names
saved: res://addons/proto_kit/ui/layouts/hud_arpg.tscn (27 nodes)
PRESERVED hud_arpg: 27 nodes, 7 unique names
saved: res://addons/proto_kit/ui/layouts/result_report.tscn (24 nodes)
PRESERVED result_report: 24 nodes, 4 unique names
saved: res://addons/proto_kit/ui/layouts/dialogue_portrait.tscn (16 nodes)
PRESERVED dialogue_portrait: 16 nodes, 5 unique names
```

預覽重跑同前述 xvfb 指令，stdout/stderr 為 `/tmp/genre-scan-2026-10-25/gallery-review-2.log`，末行 `UI GALLERY PASSED: 24 images`。實際檢視三張 quest_list PNG，均無領取數換行。

修正後預覽圖路徑：

- `/tmp/genre-scan-2026-10-25/godot-data/godot/app_userdata/proto_kit/ui_gallery/dark_gothic__quest_list.png`
- `/tmp/genre-scan-2026-10-25/godot-data/godot/app_userdata/proto_kit/ui_gallery/pixel_gilded__quest_list.png`
- `/tmp/genre-scan-2026-10-25/godot-data/godot/app_userdata/proto_kit/ui_gallery/forest_vine__quest_list.png`

修改範圍：make_ui_layouts.gd、test_genre_modules.gd、八個 layouts/*.tscn、新增三個 themes/*.tres、本報告。無 token 改動，未修改 README、字體或原型，未 commit/push/stage。
