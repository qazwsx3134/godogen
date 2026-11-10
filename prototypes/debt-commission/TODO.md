# UI 與轉場待試方向

全部未完成項目（誰來做、建議順序）集中在 [商業級打磨 Roadmap 的待辦總覽](docs/ROADMAP-COMMERCIAL.md#待辦總覽2026-10-23-更新)；本頁保留 UI 與第一章的細項紀錄。

## 評審建議（2026-11-09，game-critic）

依「影響 × 成本」排序，細節、證據與驗證方式見 [reviews/2026-11-09-game-critic.md](reviews/2026-11-09-game-critic.md) 第 4 節。分數：心流 4、隨機 6、Loop 3、回饋 6、八角 5、前期驗證 4、設計文件 5、QA 6。

- [ ] 1. 在 README 寫下玩法假設、可判定的通過條件與結論日期（半天內，影響最大）——2026-11-09 草稿已寫（README「要驗證的玩法假設」），`project.yaml` stage 改 Pre-Production；門檻、結論日期、作品／工具誰優先待作者定
- [ ] 2. 把可玩的核心 loop（第一章）放回正式內容：目前只在 `tests/fixtures/`，匯出會排除——與 2026-11-08 使用者要求「清掉故事只留 dog ear」衝突，待使用者決定
- [x] 3. 寫最小 bot，量「不操作／隨機選／知道答案」三種玩家的數字——`tools/bot_players.gd`
- [ ] 4. 真人試玩 5 人（至少 3 人用手機），照 `docs/SHORT-STORY-ACCEPTANCE.md`；依賴 1、2
- [x] 5. 讓 perfect 有價值、weak 不再是免費安全牌（全選 weak 也拿 S：`tests/test_chapter1.gd:93`）——S 需要 PERFECT ≥ 60%
- [x] 6. 補回饋空格
- [x] 7. 修過時的文件
- [ ] 8. 讓選錯有思考成本（需作者決定）
- [ ] 9. 重匯 Web，冒煙測試改指向現行內容
- [ ] 10. 實機量 QTE 與手感（需裝置）
- [ ] 11. 桂短篇收尾：三個結局有兩個「尚未寫完」（作者決定）
- [ ] 12. 量效能預算（後期）

- 2026-10-23：介面只留「銀魂和紙」，另外三款（月下映畫、萬事屋委託簿、吐槽分鏡）已刪除；早期比較紀錄見 [UI-REDESIGN-OPTIONS](docs/UI-REDESIGN-OPTIONS.md)。

- 重新設計對話框與常用元件。先試底部滿版、半透明對話層、上緣分隔線，再與目前畫面比較；參考：[圖一](example/image.jpg)、[圖二](example/螢幕擷取畫面%202026-09-24%20021146.jpg)、[圖三](example/螢幕擷取畫面%202026-09-24%20021221.jpg)。
- ~~試用 shader 做事件或場景轉換~~：2026-11-04 做了筆刷、墨暈、故障三種換背景轉場（`shaders/scene_transition.gdshader`，`bg` 的 `transition`；示範在功能展示的「畫面：轉場與演出」，原本的 `?sample=transitions` 已移進 `tests/fixtures/`）。第一章還沒套用，等作者看過試片選定。ASCII 字元畫風格沒做（要另備字形貼圖）。

[底部對話層與素材 Web 試版比較](docs/UI-TRIAL.md)保留早期試作截圖；介面是作者已確認的銀魂和紙，仍待 Android Chrome 與 iOS Safari 實機試玩。shader 換背景轉場已有示範（功能展示的「畫面：轉場與演出」），第一章待作者選定；優先順序與驗收方式見[進度紀錄](../../docs/story-telling-game/STATUS.md)。

對話框要照著圖做銀魂風：「銀魂和紙」以 [v2 Option A](../../docs/story-telling-game/v2/story-telling-ui2.jpeg) 為基準。2026-10-06 修正紙框比例、跨框雲形名字牌、明體字型、青海波與櫻花，底列補齊 LOG／AUTO／SKIP／MENU 的圖示與實際功能；[原圖與實際對話並排](docs/gintama-reference-comparison.png)、[驗證紀錄](docs/UI-REDESIGN-OPTIONS.md#第四款還原修正2026-10-06)。追加修正波紋溢出：使用原圖經 imagegen 去背／清字的透明 PNG，波紋與櫻花合在紙框底圖中，保留四角並加裁切限制。作者已確認可採用；後續對話框與新按鈕沿用此樣式。新安裝預設為銀魂和紙，既有風格偏好仍保留。

## 後續實作順序（2026-10-06）

已完成 **B 超必殺演出**：吐槽之力集滿時的 cut-in 與金色眼鏡氣焰、`beam` 光束、可自訂的「龜派氣功！」按鈕，以及 `power_up`／`beam` 合成佔位音。入口是 `?sample=phase4_rounds`。2026-10-06 已接續實作 C、D 與 E 的第一章上機試讀版，驗證見 [C–E 交付紀錄](docs/READING-CHAPTER1.md)。

### C 文字演出

- [x] 對話框正文改成 `RichTextLabel`，保留對話框 scene 的字型、顏色、陰影、行距與留白。
- [x] 重點字上色、放大與抖動；句中停頓、指定段落慢速、標點自然停頓。打字、快轉、補完、紀錄與 QA 都按可讀字元計數。
- [x] 依角色音高播放打字音；心聲／旁白的音效政策，以及靜音、音量與略讀行為一併驗證。
- [x] perfect 時的語音接口：`assets/audio/voice/shinpachi_tsukkomi_NN.ogg`；沒有錄音時正常運作。
- [x] `fade` 指令、背景交叉淡化、立繪淡入淡出與說話彈跳。重開、切章節、讀檔和略讀應取消舊演出，回復正確舞台。
- [x] 驗證 390×844／320×568 的長台詞、各款 UI（當時四款）、AUTO／SKIP／點擊補完與存讀檔。

### D 閱讀便利

- [x] 段落內回滾：還原台詞、旗標、素材、舞台、音樂和對話紀錄；不能越過 choice／吐槽回合／調查／章節結算；換章節與讀檔清除回滾歷史。
- [x] 獨立快速存讀格：與自動檔及 18 格手動檔隔離，沿用版本驗證、備份還原與錯誤提示。
- [x] 字級與對話框底色透明度設定：立即套用並記住，字與按鈕不跟著變透明；窄手機的設定項目可捲動。
- [x] 對話紀錄、存讀檔面板／欄位／覆寫確認、結尾按鈕轉成 `.tscn` 與重複 item scene；版面用 anchor／Container，保留現有風格。
- [x] Godot 存 scene 後檢查 owner、子 scene 參照與 pack 前後 node 數；驗證編輯器改字／間距後執行仍保留。
- [x] 回歸存讀檔分頁、覆寫、毀損備份、跨故事隔離與倒數暫停，並用 Web 實點新入口。

### E 第一章上機

- [x] 將已採納 P1–P8 的草稿 v0.2 轉成 `story_src/chapter1.dialogue`＋`chapter1.blocks.json`，由建置器產生 JSON；保留草稿句號的追溯資料。
- [x] 調查前台詞與調查拆節點；四個素材、可選話題、客廳↔廚房，以及跟隨銀時嘴角的熱區與背景捲動立繪。
- [x] 串接銀時證言、神樂證言、伊莉莎白牌子、條件式放棄吐槽、連擊 C1–C4、龜派氣功、C5 QTE、提示與 Game Over 檢查點。
- [x] 接薪水袋／定春反轉與 S／A／B／C 結算；`stories.json` 加 `kind: "chapter"`。使用「吐槽之力」名稱。
- [x] 引擎測試：主線、隱藏線、超必殺線、不發動超必殺、缺少聆聽素材、逾時與 Game Over 重試都能完成；各關鍵位置存讀不重複計分或給素材。
- [x] Web 自動精準點按 QTE 後到結算覆驗：`check_reading_chapter1.mjs` 兩尺寸走過早、過晚、對準兩圈重合的 QTE → 結算 → 依剩餘眼鏡的評價 → 重新整理後章節選擇仍顯示評價與結局（2026-10-19 連續 3 次通過）。
- [x] 保留「上機試讀版」標示；桌機／手機尺寸 Chromium 可玩。
- [ ] 作者試讀修訂、真人遊玩時間量測，以及 Android Chrome／iOS Safari 實機驗收。

### 音效待辦（2026-11-10 盤點）

`data/asset_catalog.json` 的 `sounds` 目前沒有一筆有 `path`，全部由 `scripts/stage_effects.gd` 的 `_placeholder()` 合成。換法：檔案放 `assets/audio/se/<id>.ogg`，在 catalog 那一筆補 `path`（和 `license`），不用改程式。規格：OGG、44.1 kHz、單聲道、0.1–1.5 秒，開頭不留空白。盤點與截圖見 `build/ui_assets_page/`（[展示頁](https://claude.ai/artifact/5PWktqSHkHipZ7YKbFxQpa)）。

**優先（玩家每回合都會聽到）**

- [ ] `crow`：冷場的烏鴉叫「阿呆～」，銀魂式冷場的招牌聲，約 1 秒
- [ ] `tsukkomi_hit`：完美吐槽命中，紙扇（ハリセン）用力拍下去的「啪！」
- [ ] `tsukkomi_weak`：普通吐槽，比命中輕的拍打聲；**catalog 還沒有這一筆，要先加**（`stage_effects.gd` 的 `FEEDBACK` 在用）
- [ ] `glass_crack`：冷場時眼鏡裂一條縫，短而脆
- [ ] `glass_shatter`：眼鏡全碎、Game Over，玻璃碎裂加一點喜劇感的落地聲
- [ ] `comedy_don`：漫畫吐槽格出現時的重低音「咚」，要有份量

**玩法系統**

- [ ] `comedy_pop`：小反應「啵」，取得線索也用這個
- [ ] `qte_hit`：QTE 點中，清脆的「叮」
- [ ] `combo_up`：連擊上升，音高可以一次比一次高的短音
- [ ] `combo_break`：連擊中斷，下滑的洩氣聲
- [ ] `tear`：撕下消音條，撕膠帶聲
- [ ] `censor_beep`：消音嗶聲（現在的 1 kHz 合成音本來就是標準嗶聲，可以最後再換或保留）
- [ ] `director_clap`：導演選擇出現時的場記板「啪」

**超必殺（三個做成一組）**

- [ ] `super_charge`：超必殺發動前的蓄力聲，往上爬
- [ ] `power_up`：吐槽之力全滿，金色氣焰冒出來的「轟」
- [ ] `beam`：龜派氣功光束射出，約 1.5 秒

**介面音（目前完全沒有，要新增並接到程式）**

- [ ] 按鈕點擊：和紙按鈕的輕「喀」
- [ ] 開啟面板：目錄、設定、存讀檔、案件檔打開時的翻紙聲
- [ ] 關閉面板：較短的收紙聲
- [ ] 翻頁：存讀檔、對話紀錄換頁
- [ ] 存檔完成：蓋章「咚」（可以沿用或重錄 `stamp.wav`）

這五個要新增 catalog id（建議 `ui_click`、`ui_open`、`ui_close`、`ui_page`、`ui_save`），並在 `ui_styles.apply_button()` 或主程式開關面板的地方接上播放。

**劇情音效（故事用，可以晚點換）**

- [ ] `fridge`：冰箱門開關
- [ ] `door_slide`：日式拉門
- [ ] `bite`：定春咬人
- [ ] `gulp`：大口喝牛奶
- [ ] `assets/audio/` 的 `paper`、`knock`、`step`、`stamp`、`ambient` 五個 WAV：檔案存在，但也是 `tools/prepare_audio.py` 合成的，要換成正式錄音

**系統 BGM**

- [ ] `bgm_result`：章節結算（現在是合成的四音循環）
- [ ] `bgm_boke`：裝傻回合
- [ ] `bgm_combo`：連擊回合
- [ ] 標題 BGM：目前用原聲帶第 35 首（`bgm_gintama_35`），沒有公開或販售權利，上架前要換

**選用**

- [ ] 打字音：現在依角色 `voice_pitch` 合成，可以保留，或每個角色錄一個短音
- [ ] 完美吐槽語音 `assets/audio/voice/shinpachi_tsukkomi_01.ogg`～`08.ogg`（0／8；沒有檔案時靜音，這是設計上的行為）

### B 交付後待真人驗收

- [ ] 手機實機觀看金色氣焰與光束，確認強度、時長與可讀性。
- [ ] 試聽合成佔位音；錄音或正式音效替換另行提供資產。

