# 素材授權 Manifest（草稿）

日期：2026-10-19。此表是盤點草稿，**不是公開／販售核准清單**。不變更匯出設定，不移動或刪除素材。權利人、可用範圍、證明文件未齊全者一律標待查；使用者提供、AI 加工、YouTube URL 均不能當成第三方授權。

## 判讀與已知來源

- 音樂：`assets/audio/music/sources.json` 有逐曲來源 URL／編號，沒有遊戲使用／公開發行的權利證明，13 首皆待取得必要權利或替換。預設第 35 首亦同。
- 角色／背景／表情：README「素材來源」僅記使用者提供，逐圖原作者與授權鏈待查。不可由檔名推斷是官方圖或 AI 圖。
- 和紙 UI：`assets/ui/GINTAMA-EXTRACTION.md` 記從參考圖以 imagegen 去背及衍生程序；參考圖權利、生成條款與可公開／販售範圍待查。
- Noto Serif TC：`assets/fonts/NotoSerifTC-SOURCE.md` 有 commit、SHA 與 OFL 1.1，全文 `NotoSerifTC-OFL.txt`；候選可用，出貨 notice 與實際字型對應仍需核對。
- WenQuanYi：`assets/fonts/COPYRIGHT.txt` 與 `LICENSE-GPL-2.txt` 記 GPL-2＋字型嵌入例外、M+。候選可用，需核對 story-cjk.ttc 與文件對應、修改鏈及出貨 notice。
- WAV：`tools/prepare_audio.py` 為本專案合成音效／稀疏音樂；需製作方確認自有權利歸屬。

## 逐檔盤點

以下含 assets/ 內的素材檔，不含 Godot `.import` 與說明文件；只表示 repo 有檔案，不保證出貨有用到。未引用參考圖也應由後續出貨稽核判斷。

| 路徑 | 作者／來源與證明 | 授權／允許用途 | 核准狀態 |
| --- | --- | --- | --- |
| `assets/audio/ambient.wav` | 專案 tools/prepare_audio.py 合成 | 自有製作紀錄；權利歸屬待作者確認 | 自製候選，待確認 |
| `assets/audio/knock.wav` | 專案 tools/prepare_audio.py 合成 | 自有製作紀錄；權利歸屬待作者確認 | 自製候選，待確認 |
| `assets/audio/music/gintama_01.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_02.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_03.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_05.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_08.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_10.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_13.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_19.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_20.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_21.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_22.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_34.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/music/gintama_35.ogg` | YouTube 原聲帶；music/sources.json 對應編號 | 必要權利證明搜尋不到；用途待查 | 未核准公開／販售 |
| `assets/audio/paper.wav` | 專案 tools/prepare_audio.py 合成 | 自有製作紀錄；權利歸屬待作者確認 | 自製候選，待確認 |
| `assets/audio/stamp.wav` | 專案 tools/prepare_audio.py 合成 | 自有製作紀錄；權利歸屬待作者確認 | 自製候選，待確認 |
| `assets/audio/step.wav` | 專案 tools/prepare_audio.py 合成 | 自有製作紀錄；權利歸屬待作者確認 | 自製候選，待確認 |
| `assets/editor/stand_in.svg` | 本地 icon／編輯器輔助圖，作者待確認 | 自製／第三方身分與授權待補 | 待查 |
| `assets/fonts/NotoSerifTC.ttf` | Noto；NotoSerifTC-SOURCE.md＋NotoSerifTC-OFL.txt | OFL 1.1；保留 copyright／license 等條件 | 候選可用，待出貨核對 |
| `assets/fonts/story-cjk.ttc` | README 指向 WenQuanYi；COPYRIGHT.txt＋LICENSE-GPL-2.txt | GPL-2＋嵌入例外／M+；二進位對應待核 | 候選可用，待出貨核對 |
| `assets/icon.svg` | 本地 icon／編輯器輔助圖，作者待確認 | 自製／第三方身分與授權待補 | 待查 |
| `assets/image/Otose-san.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/elisabeth.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/gintoki_angry.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/gintoki_annoyed.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/gintoki_nervous.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/gintoki_serious.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/gintoki_smug.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/gintoki_sweat.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/kagura_angry.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/kagura_annoyed.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/kagura_mock.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/kagura_nosepick.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/kagura_smile.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/kagura_smug.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/kagura_sweat.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/otose_angry.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/otose_annoyed.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/otose_serious.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/otose_sit_serious.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/otose_sit_talking.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/otose_smile.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/otose_smug.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/otose_thinking.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/sadaharu_cry.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/sadaharu_smile.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/sadaharu_smug.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/shinpachi_angry.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/shinpachi_nervous.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/shinpachi_panic.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/shinpachi_shout.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/expressions/shinpachi_thinking.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/gin-san.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/gintoki.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/kagura-chan.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/kitchen.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/sadaharu.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/shin-pa-chi.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/yorosuya-inside.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/yorosuya-outside.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/yorozuya-background.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/image/yorozuya-inside.png` | 使用者提供／表情衍生；逐圖原作者與來源待查 | 授權與修改鏈待查 | 未核准公開／販售 |
| `assets/ui/gintama_extracted_auto.png` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_extracted_log.png` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_extracted_menu.png` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_extracted_nameplate.png` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_extracted_paper.png` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_extracted_skip.png` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_heading_plaque.png` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_icon_advance.svg` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_icon_auto.svg` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_icon_log.svg` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_icon_menu.svg` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_icon_skip.svg` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_icon_voice.svg` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_nameplate.svg` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_panel_paper.png` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_paper.svg` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_reference_cutouts_v1.png` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_reference_cutouts_v2.png` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_sakura_corner.svg` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |
| `assets/ui/gintama_seigaiha.svg` | PNG／SVG 製作與衍生；GINTAMA-EXTRACTION.md（涵蓋範圍待逐件核） | 上游參考圖、各 SVG 作者與公開用途待查 | 待查，未核准公開／販售 |

## 工具、引擎與後續欄位

| 元件 | 證據 | 草稿判斷 |
| --- | --- | --- |
| Parley | addons/parley/LICENSE | MIT；若隨版本出貨須保留 notice |
| Dialogue Manager | addons/dialogue_manager/LICENSE | MIT；同上 |
| puzzle_dependencies | addons/puzzle_dependencies/LICENSE | MIT；同上 |
| Godot MCP Toolkit | addons/godot_mcp_toolkit/LICENSE | MIT；同上；目前 Web 排除工具 |
| Godot 4.7／Web 模板 | project.godot、現存 Web runtime | 正式模板 license bundle、第三方 attribution 與出貨 notice 待核 |
| proto_kit／story_tools | ../godot-kit/README.md、addons/story_tools/ | repo 共用／自製工具，權利歸屬及版本來源待製作方確認；不武斷視為外部閉源套件 |

下一輪逐項補：原作者／權利人、來源 URL、授權版本、允許的私人／公開／收費用途、書面證明位置、衍生修改鏈、檔案 hash、核准人與核准日期、實際出貨版本。公開／販售前再建立 allowlist 並驗產物；本草稿沒有宣告素材已獲授權。
