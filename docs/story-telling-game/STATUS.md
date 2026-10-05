# 直式吐槽視覺小說：目前進度與待辦

更新：2026-10-02。範圍是 [V1 Roadmap](ROADMAP.md) 與 [debt-commission Godot 原型](../../prototypes/debt-commission/README.md)；詳細測試結果見[驗證紀錄](../../prototypes/debt-commission/docs/VERIFICATION.md)。本頁區分「技術片段已通過自動驗收」與「正式內容和真人體驗已完成」，避免把兩者混為一談。

## 已完成

| 範圍 | 目前可用的成果 | 驗證狀態 |
| --- | --- | --- |
| Phase 0：基礎工具 | Godot 4.7 Web 匯出、MCP 編輯器連線、舊原型保存；Web 包排除 MCP addon | 舊劇本測試、Web 匯出與觸控 smoke 通過 |
| Phase 1：直式 VN 外殼 | 9:16 六層畫面、placeholder 背景／立繪、逐字對話、紀錄、AUTO／SKIP、長按隱藏、上滑開紀錄；對話框內的工具列（目錄、回顧、自動、續），存讀檔與略讀收在目錄 | Godot headless 與桌機／手機尺寸的 Chromium 觸控模擬通過；選項及紀錄捲動回歸通過 |
| Phase 2：資料驅動劇本 | JSON 背景、人物站位／表情、台詞、分支、旗標、素材與條件選項；素材集中在 `asset_catalog.json`；草莓牛奶短篇有兩條可走到結尾的技術路線 | 資料驗證、缺失引用、素材門檻、存檔還原及 Web 兩路測試通過 |
| 手動存讀檔 | 自動續讀檔獨立；3 頁 × 6 格手動欄位；(S) 開欄位而非快速存檔；標題與遊戲內可選欄讀檔；覆寫確認、備份還原、跨故事隔離 | 引擎測試、Web 觸控選欄與重新整理後讀檔通過 |
| Phase 3 技術短循環 | 一個調查熱區取得素材；銀時發言切換與聆聽；按「吐槽！」才開始 8 秒選詞；perfect／weak／fail／hidden、逾時、眼鏡耐久、吐槽力、Game Over 與檢查點重試；調查與吐槽狀態可存讀 | 七套 headless 測試與 390×844 Web 觸控流程通過；320×568 選項位置檢查通過 |
| 底部對話層 UI 與素材 Web 試版 | 全寬半透明、無邊框對話層，層內說話者名稱；其他元件描邊淡化；店面與客廳照片、銀時剪影已套入。[原版與兩版試作截圖比較](../../prototypes/debt-commission/docs/UI-TRIAL.md) | Godot 資料／Phase 3 UI 測試、主線兩路、Phase 3 與存讀檔 Web 觸控通過；正式採用仍待實機試玩 |
| 三款 UI 風格改為 scene | 對話框與工具列、選項面板、目錄、標題卡，各做成月下映畫／委託簿／吐槽分鏡三款可在編輯器直接調整的 scene，換風格即換 scene；窄於 390 CSS px 的手機等比放大，按鈕維持 48 CSS px 以上 | 對照 HTML 樣稿的 `check_ui_parity`（三款 × 390／320 × 五個畫面）與全部 Web 觸控路線通過 |
| Phase 4 第二段：回合玩法 | 回合試片（`?sample=phase4_rounds`，台詞取自第一章草稿、非核准）：證言回合逐句槽點、聽下去取得素材、揮空、失敗三次提示、第四面牆消音條、兩句接住後出現的隱藏選項；連擊回合時限 8→6→5→4 秒、QTE 縮圈、超必殺、連擊中斷與獎勵；`shake`／`flash`／`cutin`／`freeze`／`bgm`／`se` 演出（音效為合成佔位音）；HUD 與碎眼鏡 Game Over 畫面 | 回合引擎、試片劇本、外殼流程三組 headless 測試；Web 觸控路線 `--rounds` 實點消音條、超必殺與 QTE；cut-in 不吞點擊有測試 |
| Phase 4 第三段：第一章上機前的引擎功能 | 伊莉莎白的舉牌槽點（`placard`：閱讀與選詞時點牌子，選詞時發亮、選項面板停在牌子下方；劇情用 `placard()` 改寫或清掉牌上的字；不說話的角色用 `enter()` 上場）；選項的條件結果 `when`（放棄吐槽一直都在，L1、L2 接住才是隱藏路線）；畫面外台詞 `[#offscreen]`；調查的「對話」話題、「移動」到其他地點（各自的背景、熱區與已查狀態）、熱區查看後台詞與可選熱區；`salary_envelope` 素材與六個角色的人物檔案文字。回合試片加了神樂的回合，四線索試片加了話題、廚房與畫面外台詞 | 新增調查測試，回合引擎、試片劇本與兩個外殼流程的測試擴充；Parley 與 `.dialogue` 仍建出相同 JSON；Web 觸控 `--rounds` 實點牌子（含 320×568），新增 `--investigate` 實點話題與移動 |
| Phase 4 第一段：資料層與編寫流程 | 四熱區、四素材的草莓牛奶技術試片（非核准內容）；每項素材解鎖對應的吐槽選項；人物檔案（`profile` 指令、`case_file()`）隨劇情解鎖並存讀；劇本改由 Parley 流程圖或 Dialogue Manager 文字寫成，建置時檢查語法、說話者、到不了的節點並自動產生存檔版本 | 劇本建置兩套、Phase 4 UI 流程與既有九套測試通過；Parley 與 `.dialogue` 兩種寫法建出相同 JSON；Web 匯出不含編輯器外掛與原始檔 |

標題畫面的副標題是故事切換鈕，點一下換下一個試玩內容（討債閱讀基線 → Phase 2 → Phase 3 → Phase 4 → 回合試片），桌機或編輯器執行會記住上次的選擇。Web 也可以用網址直接開：討債閱讀基線用預設網址；草莓牛奶技術片段用 `?sample=phase2`；調查與吐槽技術短循環用 `?sample=phase3`；四線索調查用 `?sample=phase4`；回合試片用 `?sample=phase4_rounds`。啟動與測試指令見[原型 README](../../prototypes/debt-commission/README.md#開發與-web-匯出)。討債第一場有作者核准的[閱讀文本](stories/002-debt-commission-draft-v0.1.md)；草莓牛奶兩個 JSON 都是**技術片段**，不是核准的第一章。

## v2 VN 框架 Prototype v0.1（2026-10-01 起；2026-10-02 技術驗收完成，待真人手機試玩；優先於下方 B–E 軌）

方向依 [v2 討論](v2/conversation4.md)：畫面分成 A＝一般 VN、B＝漫畫吐槽疊加；第一版驗收清單與實作順序在該檔第 900–960 行。順序上 InteractionLayer 已先做，接著 ComedyLayer，再來是 POV／Director 兩種選項、SaveManager，最後是 EP00「今天也沒有工作的萬事屋」的 vertical slice。

| 項目 | 內容 | 狀態 |
| --- | --- | --- |
| InteractionLayer | 角色熱區（`character`，範圍是立繪）、每次點都演出的 `lines` 熱區（點擊次數入存檔）、熱區 `set` 旗標、`keep_cast` 調查不清場；`main.tscn` 的分層全部改成 scene node | ✅ 2026-09-30（`ebee323`）；`test_interaction` 與其餘 19 組 headless 測試通過（2026-10-01 重跑） |
| ComedyLayer | `comedy` 指令，三個 preset（`tsukkomi_impact`／`small_reaction`／`full_manga_panel`）：速度線、顏藝 cut-in、爆炸框大字、震動、zoom、音效，播完回到 A 畫面；點擊快轉、略讀不播；技術試片 `?sample=comedy` | ✅ 2026-10-01，已合併進 master（`3b83cb1`）；2026-10-02 在 master 重跑：headless 21 組、Web `--comedy`（390×844、320×568）／`--rounds`／`--slots`／預設路線全部通過 |
| POV／Director Choice | `choice` 的 `perspective`：`pov`（預設，新八人格範圍內的反應，選項可標 `tone` 語氣）與 `director`（導演式「接下來發生什麼」，真分支、獨立的導演面板、註腳 `note`）；技術試片 `?sample=choices` | ✅ 2026-10-02，分支 `v2-choices`（未 commit）：headless 22 組（含 `test_choices` 699 個斷言）通過；Web `--choices`（390×844、320×568）／`--comedy`／`--rounds`／`--slots`／`--investigate`／預設路線通過；獨立驗收 11 條全過。彈入動畫與 `director_clap` 只用數字驗證，沒看過逐格動畫、沒聽過音效；選項太長時換行偶爾掉一個孤「！」（外觀）；從存檔還原到導演選項會重播彈入與音效 |
| EP00 vertical slice | 把前面各項串成一集（`?sample=ep00`，台詞取自 v2 草稿、非核准）：一般 VN → POV 選項 → 漫畫吐槽 → 互動調查 → 旗標條件 → 導演選項 → 三個結局，含存讀檔；v2 的 16 條驗收清單逐條對應到證據（[驗證紀錄](../../prototypes/debt-commission/docs/VERIFICATION.md) 最後一節） | ✅ 2026-10-02，分支 `v2-choices`（未 commit）：headless 23 組（`test_ep00` 894 個斷言，36 條路徑窮舉）通過；Web `--ep00`（390×844 兩條路徑、320×568 前半，真實觸控，含存檔→重新整理→讀檔）與其餘 9 條路線通過；獨立靜態審查 7 過 2 不過，兩項都是文件誠實度（偏離規格沒寫進專案、一條驗收證據誇大），已修正 |

**Web 存檔偶發錯誤（已修）**：「重新開始」在存檔後立刻刪檔，Emscripten IDBFS 同步到 IndexedDB 的途中找不到檔案（ENOENT），報 `Failed to save IDB file system: undefined`，預設路線瀏覽器檢查因此約兩次有一次失敗。`tools/build_web.sh` 匯出後修補 `index.js`，略過已消失的檔案（原理寫在原型 README「開發與 Web 匯出」）；修補後預設路線連續 10 次通過（實驗 6 次、正式建置 4 次），2026-10-02 的基準驗收也通過。

**EP00 的已知偏離與缺口（不擋這集）**：台詞只有 38 句（含選項與結局文字共 51，比派工規格「約 45–65」少）；搜尋前新八與神樂退場（三人同台時立繪蓋住背景熱區）；「草莓牛奶」熱區放在紅色筆筒（背景沒畫牛奶）；角色熱區是整張立繪含透明邊（銀時的矩形比螢幕寬，點到物件以外的地方都算點銀時）；有調查的故事整集顯示眼鏡 HUD；全部熱區選填時「繼續」仍寫「線索已取得」。16 條驗收清單中仍未驗證：Android／iOS 實機、音效試聽（全是合成佔位音）、遊玩時間（目標 5–8 分鐘）、電視熱區與結局 B 的瀏覽器觸控路線。

**`--phase3` 路線**：原版路線在存手動欄位 2 後立刻 `page.reload`，這台機器（軟體渲染）上 IndexedDB 寫入常來不及，原版路線共跑 11 次只過 2 次（含 3 次沒套 IDBFS 修補的對照、過 1 次，所以不是修補造成的）；`browser_check.mjs` 已在 `reload` 前加 1.5 秒等待，修改後連續 5 次通過（實作者 3 次、我 2 次）。真人手動存檔後幾秒才離開頁面，不受影響。

**下一步（待你決定）**：`TODO.md` 新增了一行「對話框要照著圖做銀魂風」，圖應是 v2 的 Option A（[`v2/story-telling-ui2.jpeg`](v2/story-telling-ui2.jpeg)：米色紙面、波紋與櫻花、名牌帶喇叭圖示、底部 LOG／AUTO／SKIP／MENU）。要新增成第四款 UI 風格，還是取代現有三款之一，需要你先定。

## 暫停：第一章上機與文字演出（2026-09-29 起）

目標：把第一章（[草稿 v0.2](stories/003-strawberry-milk-ch1-draft-v0.2.md)）放進遊戲，並補上逆轉裁判式的文字演出與 VN 閱讀便利功能。依序分軌進行，因為各軌都會改 `main.gd` 與 `asset_catalog.json`，不能平行。

| 軌 | 內容 | 狀態 |
| --- | --- | --- |
| 圖 | 定春 `smile`／`cry`／`smug`、登勢 `smile`／`thinking`／`smug`／`annoyed`（叉腰）／`sit_serious`／`sit_talking`、新八 `broken`；原圖移到 `art_src/expressions/`；`fit_expressions.gd` 支援單張 `rescale`（坐姿用） | ✅ 完成，見[表情清單](EXPRESSIONS.md) |
| A 第一章玩法 | 伊莉莎白舉牌槽點、條件式放棄吐槽（選項 `when`）、畫面外台詞（`[#offscreen]`）、調查的對話話題與移動（`talk`／`places`）、`enter()`、`salary_envelope` 與六人人物檔案 | ✅ 完成；19 組 headless 測試與 Web 各模式通過。語法見原型 `IMPLEMENTATION.md` |
| B 超必殺演出 | 吐槽之力集滿 cut-in、眼鏡金色氣焰、`beam` 光束 scene、可自訂的「龜派氣功！」按鈕、`power_up`／`beam` 合成佔位音；回合試片可玩 | ✅ 已完成（2026-10-06）：24 組 headless 回歸與 7 組 Web 觸控檢查通過，驗證見原型 `docs/VERIFICATION.md`；真人手機觀看與音效試聽待做 |
| C 文字演出 | 對話改 `RichTextLabel`：重點字上色、放大／抖動／慢速、句中停頓；標點自然停頓；依角色音高的打字音；語音接口（新八吐槽聲 `assets/audio/voice/shinpachi_tsukkomi_NN.ogg`，perfect 時隨機播）；`fade` 指令、背景交叉淡化、立繪淡入淡出與說話彈跳 | 待做 |
| D 閱讀便利 | 回滾（不能越過 choice／回合／調查／結算）、獨立快速存讀格、字級與對話框透明度設定；對話紀錄與存讀檔欄位轉成 scene | 待做 |
| E 第一章上機 | 草稿轉成 `story_src/chapter1.dialogue`＋`chapter1.blocks.json`，`stories.json` 加 `kind: "chapter"`；用 A–C 的語法 | 待做（等 A–C） |

A 回報的轉稿注意：草稿 `ch1_investigate` 在調查前有台詞，調查要拆成自己的節點；「吐槽之力」取代草稿內文的「戰鬥力」。A 另留兩個小缺口：320×568 時線索欄壓到牌子左上角；調查時立繪跟著背景捲動、熱區跟著立繪（草稿 4.1）未做。

## 尚未完成

| 優先 | 工作 | 完成判準 |
| --- | --- | --- |
| 先做 | 依 [共同編劇流程](STORY_WORKFLOW.md)寫並確認第一章至少一回合正式台詞，包含可察覺的槽點、素材依據、聆聽補充和四種結果；替換 Phase 3 技術台詞後驗證節奏 | 作者確認文字版，所有結果可到達，玩家能從台詞找到吐槽依據 |
| 先做 | 真人在 Android Chrome、iOS Safari 走完「調查 → 素材 → 裝傻 → 吐槽 → 讀檔」，觀察 8 秒是否足夠、誤觸、字級、按鈕遮擋與笑點節奏 | 留下裝置、瀏覽器、問題與調整結論；Phase 3 才能判定整體關卡完成 |
| 待實機 | 對照[原版、前一版與素材試版](../../prototypes/debt-commission/docs/UI-TRIAL.md)，核對長台詞、選項、懸浮鈕及窄螢幕可讀性；需求原文見[UI 備忘](../../prototypes/debt-commission/TODO.md) | Android Chrome 與 iOS Safari 手機試玩後決定層高、透明度及是否採用；若採用，回寫 Roadmap 的版面基準 |
| 探索 | 試一個用 shader 表現事件／場景轉換的短演出；ASCII 或駭客風是候選方向，尚未定稿 | 有可觀看的前後對照；確認文字可讀性、手機效能與是否符合故事氣質，再決定納入與否 |
| Phase 4 接 UI | 已完成：標題切換故事、素材／人物檔案畫面、回合畫面與演出（顯示邏輯在 `round_view.gd`、演出在 `stage_effects.gd`）。待做：把調查熱區也拆出 `main.gd` 並做成 item scene；對話紀錄、存讀檔欄位、結尾按鈕仍在程式裡建立，改到時轉成 scene | 拆分後既有測試仍通過 |
| Phase 4 | 回合玩法已有技術試片。待做：第一章三回合的正式台詞（[草稿 v0.2](stories/003-strawberry-milk-ch1-draft-v0.2.md)，提案 P1–P8 已於 2026-09-28 全部採納，待轉成 `story_src/chapter1.*`）；調查時立繪跟著背景捲動、熱區跟著立繪；手機試玩 QTE 判定窗（±0.12 秒）與連擊時限 | 作者核准的三回合都可結束；真人手機試玩後定下判定窗與時限 |
| Phase 5 | 系統已完成（2026-09-28）：設定（文字速度、自動播放、音量）、章節選擇（本篇依序開放、最佳評價）、章節結算（`result` 步驟，依剩下的眼鏡評價，Game Over 降級），故事清單改為 `data/stories.json`。待做：完成作者核准、約 80–100 句的草莓牛奶第一章；主線、隱藏路線和 Game Over 全流程驗收 | 真人可從標題玩到結算，重開與選欄讀檔正確；第一章內容經試讀修訂 |
| 對外試玩前 | 確認正式名稱、部署網址與同人作品的公開分享範圍；記錄手機首次載入時間與 Web 存檔限制 | 交付位置和分享方式明確，首次載入與保存行為在目標裝置實測 |

## 已知限制與下一步順序

- Chromium 觸控模擬不代表 Android／iOS 實機已通過；Web 存檔綁定同源本機儲存，換網域或清除網站資料後不會自動轉移。原生手機存檔持久性也尚未驗證。
- Safe Area 目前驗到瀏覽器避開系統安全區的情況；全螢幕或 PWA 顯示尚未驗。UI 已定為三款可切換風格；手繪的店面、客廳、廚房，以及新八、銀時、神樂、登勢、定春、伊莉莎白的立繪與第一章第一批表情已套入；音樂與音效仍是合成佔位音。
- 先用正式一回合台詞與 UI 試版做真人試玩，收斂計時與版面；再擴充 Phase 4 的四素材、三回合和特殊槽點；最後接 Phase 5 的完整章節與設定。每一階段都保留 Godot 測試、Web 操作與真人回饋的獨立證據。

2026-10-06：本次範圍依作者指示先完成 B；C、D、E 的接續順序與驗收項目集中在 [debt-commission TODO](../../prototypes/debt-commission/TODO.md#後續實作順序2026-10-06)。
