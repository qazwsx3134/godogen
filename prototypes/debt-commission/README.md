# 萬事屋吐槽 ADV（暫名）— V1 原型

目前已完成與待辦清單見[進度紀錄](../../docs/story-telling-game/STATUS.md)。

介面是「銀魂和紙」：和紙紙框、深藍銀框按鈕、明體字。早期試過的另外三款（月下映畫、萬事屋委託簿、吐槽分鏡）已刪除，比較紀錄留在 [UI-REDESIGN-OPTIONS](docs/UI-REDESIGN-OPTIONS.md)。

Godot 4.7 橫向視覺小說，依 [V1 Roadmap](../../docs/story-telling-game/ROADMAP.md) 與 [gintama0923](../../docs/gintama-like/new/gintama0923.md) 製作。狀態：**Phase 1、Phase 2 與 Phase 3 技術短循環已完成自動驗收；Phase 4 的回合玩法（逐句槽點、第四面牆消音條與伊莉莎白的牌子、條件式放棄吐槽、連擊、QTE、超必殺、演出效果）與調查的對話／移動話題有可玩的技術試片與自動驗收**；第一章草稿 v0.2 已做成上機試讀版，作者試讀修訂與真人手機試玩待完成。

遊戲以 16:9 橫向畫面呈現：立繪固定在舞台上，底部閱讀框可以遮住人物，長台詞在框內分頁。預設閱讀與選單字級較小，閱讀字級仍可在設定調整。作者只改 JSON 就能換場景、角色、分支與素材條件。[早期直式版比較](docs/UI-TRIAL.md)保留歷史畫面；橫向版仍待真人手機試玩。

劇情會走向《底特律：變人》、《黑鏡：潘達斯奈基》那種大量分支，所以有一個 ComfyUI 手感的網頁版[劇本節點編輯器](docs/STORY-EDITOR.md)（`tools/story_editor/`）：拖卡片、拉線接分支、標出到不了的節點與結局，讀寫同一份劇本 JSON；匯出後用 `tools/story_editor/check_story.gd` 重算 `version` 並驗證。

遊戲只附兩個故事：**功能展示**（`data/showcase_story.json`，預設）與作者的極短篇**《不是頭痛，是桂》**（`stories/katsura_dog_ears/`）。功能展示是故事編輯器的範本：目錄用選項分到「畫面：轉場與演出」「角色：立繪與文字」「玩法：分支、調查與吐槽」三段，每張卡片示範一組步驟（bg 的四種轉場、fade、shake／flash／freeze／cutin／placard／beam、bgm／se、立繪登場／表情／動作／明暗／退場、畫外音、心聲、文字標記、旗標與條件分支、四種漫畫吐槽、item／profile、調查、裝傻吐槽回合、結局），看完回到目錄。在編輯器打開同名卡片就看得到寫法。舊的第一章、討債、Phase 2–4、EP00 等片段已退出遊戲，只留在 `tests/fixtures/` 當測試夾具（見下方「測試夾具」）。

## 要驗證的玩法假設（草稿，待作者確認）

依 2026-11-09 評審建議 1 起草；通過條件的門檻、結論日期，以及「作品」與「創作者工具」誰優先（`docs/ROADMAP-COMMERCIAL.md` 開頭的決定），由作者定。

- **假設**：玩家能在 8 秒內看出哪個選項才是吐槽，並因為找對槽點而覺得好笑。
- **通過條件**（可判定）：
  1. 機器人：不操作的玩家過不了回合，知道答案的拿 S，全選普通吐槽最多 A（`tools/bot_players.gd`；2026-11-09 第一章夾具各 1000 局：不操作 1000 局卡在第一回合、隨便選 89.5% 三次 Game Over 後放棄、全選普通 1000 局 A、知道答案 1000 局 S）。
  2. 真人：5 人（至少 3 人用手機）照 `docs/SHORT-STORY-ACCEPTANCE.md` 試玩，至少 3 人願意再玩一章；每回合首次冷場率落在 15–35%。
- **結論**：繼續／轉向／放棄，日期（待填）。真人試玩前 `project.yaml` 的 `stage` 先標 Pre-Production（Studio 的階段名稱沒有 Prototype）。

## 試玩與操作

啟動下方的 Web 伺服器後，開啟 <http://127.0.0.1:5193/> 是功能展示；<http://127.0.0.1:5193/?sample=katsura_dog_ears> 是桂的極短篇。各用自己的本機存檔；桌機或編輯器直接執行時，在標題點故事名稱打開「章節選擇」換故事，沒選過時開清單第一個故事。

| 操作 | 效果 |
| --- | --- |
| 點畫面任一處 | 打字中顯示整句；長台詞先翻到下一頁，讀完才進下一句 |
| 長按畫面 | 隱藏全部 UI，再點一下恢復（恢復的那一下不推進） |
| 往上滑 | 開啟對話紀錄；調查時改為拖曳背景 |
| 目錄 | 開啟選單：存讀檔、設定及其他閱讀功能 |
| 流程圖 | 章節選擇右上的「流程圖」：一次看一個故事，‹ › 換故事；走過的場景方塊顯示標題、之間的線變金色，沒走過的是「？？？」；拖曳畫面移動。走過哪些節點記在 `progress.cfg` 的 `[visited]`，讀舊檔或回滾不會把看過的路線收回 |
| 章節選擇 | 標題上的故事名稱：本篇章節依序排列，前一章結算過才開放，顯示最佳評價；「結局收集」列出每章的結局，看過的顯示名稱、沒看過的是「？？？」；試玩片段一直開放。選了就回到標題，按「開始故事」或「繼續」 |
| 設定 | 標題或目錄裡：文字速度（慢／標準／快／瞬間）、自動播放速度、背景音樂與音效音量、字級及紙框透明度、畫面效果（減少震動、閃光、立繪與按鈕動作）、吐槽輔助（寬鬆：選詞時間 ×1.5、QTE 判定窗 ×2）、教學提示（顯示／不顯示，另有「重看教學」）與存檔備份，立刻生效並記住；目錄的「音效」開關仍可一鍵靜音 |
| 章節結算 | 章節最後：吐槽成功／出手、PERFECT、最高連擊、冷場、隱藏裝傻、剩下的眼鏡、Game Over 次數與評價（剩 5 副 S、4 副 A、3–2 副 B、1 副 C；S 還要抓到的槽點至少 60% 是 PERFECT，全選普通吐槽最多 A；每次 Game Over 降一級），依評價顯示一句話；「下一章」或「回標題」 |
| 冷場與調查回饋 | 冷場的提示寫出原因（時間到／這個選項不對／這句沒有槽點／時機沒抓到）；普通吐槽有自己的輕音效與短震動；調查時點到空處顯示「這裡沒什麼特別的」，連續落空 3 次改成提示還剩幾個地方沒查。第一次正常閱讀（不是快轉）時，教學會說明長按隱藏介面、往上滑看對話紀錄 |
| 推進鈕（›／續／→） | 補完當句、翻閱長台詞，讀完後推進劇情 |
| 選單／標題讀檔 | 選擇指定手動欄位；讀檔頁也可選自動續讀檔 |
| 工具列 | 閱讀框下方的 LOG、AUTO、SKIP、MENU；存讀檔、吐槽素材與人物檔案收在目錄裡 |
| 調查 | 線索是背景圖上的東西，不是按鈕：拖曳背景找（橫向畫面可上下或左右移動有裁切的部分），點那樣東西就取得線索，找到的會留下淡框與勾；有查看後台詞的會先演完再回來。按「收起 ▼」後，底部會留下半透明細列；可從列上拖曳或點擊背景，按「展開 ▲」叫回對話框。全部找到時會顯示「繼續」，收合後也能直接按「繼續」離開。`keep_cast` 調查保留角色，第一章的銀時嘴角跟隨立繪與拖曳；移往廚房時角色留在客廳 |
| 對話／移動 | 調查時對話框裡的兩排話題：「對話」點了演出那段對話，聊過的不再出現；「移動」換到另一個地點（例如廚房），那裡有自己的背景與熱區，查完會自動回到原地點，也可以按「移動」回去。各地點已查過的熱區保持打勾 |
| 裝傻發言 | ‹ › 切換句子；有補充時按「聽下去」；按「吐槽！」才進入 8 秒選詞 |
| 吐槽選詞 | 選吐槽詞；完美或普通吐槽會先顯示左右交替的漫畫格與台詞，點一下可快轉演出，再接回故事。素材會解鎖完美選項，逾時算冷場；選單、紀錄及存檔欄位會暫停倒數 |
| 第一次教學 | 第一次進入調查、第一次遇到裝傻回合時，畫面壓暗並框住要講的按鈕，和紙說明卡一步講一件事（各 3 步，`data/tutorials.json`）；「下一步」或「略過」，看過就不再出現。教學出現在倒數開始前。headless 測試與 `?qa=1` 的瀏覽器檢查預設不顯示（`DEBT_TUTORIAL=1`、`&tutorial=1` 可開） |
| Phase 4 證言回合 | 每句可能藏一個槽點，全部接住才結束。句數旁 ● 已接住、○ 還有槽點、· 沒有槽點；在沒有槽點的句子按「吐槽！」是揮空（冷場）；同一處失敗 3 次，神樂會提示 |
| 消音條 | 台詞裡出現發亮的黑色消音條時，點它就是吐槽：閱讀時不計時，選詞時也能點 |
| 伊莉莎白的牌子 | 牌子上出現字的那句（例如「犯人是神樂」），伊莉莎白會站到前面，直接點牌子就是吐槽：閱讀時不計時；按「吐槽！」後牌子發亮，8 秒內點也算。其他句子的牌子是空白或劇情寫的字，點了沒反應 |
| 連擊回合 | 每句講完直接進選詞，每接住一句時限縮短（8→6→5→4 秒）；吐槽之力集滿時眼鏡冒出金色氣焰，跳出「吐槽之力全滿！」；回合試片的「龜派氣功！」會用光束一次接住剩餘選詞句、力量歸零，QTE 仍須手動完成 |
| QTE | 白圈縮到黃圈時點畫面任一處；太早、太晚或沒點都算冷場 |
| Game Over | 眼鏡歸零時出現碎眼鏡畫面，可從該回合開頭重試 |
| 角色 | 開口說話才登場；說過話的人留在畫面上，說話的人在最前面、其他人在後面變暗。換背景（新場景）時全部退場，劇本也能用 `hide()` 讓人先退場 |
| 手感回饋 | 玩家的每種結果有固定的強弱（`scripts/stage_effects.gd` 的 `FEEDBACK`）：取得線索輕震並「啵」一聲、普通吐槽輕震、完美吐槽重震、揮空／冷場重震＋小晃動＋眼鏡裂開聲、吐槽之力全滿與 Game Over 最重；劇本的 `shake` 也會震。眼鏡碎掉那一副、吐槽之力與連擊數字上升時會跳一下；提示訊息彈出再淡出。震動只有 Android Chrome（iPhone Safari 沒有震動 API）；畫面效果「減少」時不震、不跳 |
| 狀態列 | 右上是眼鏡（生命，掉一副就碎一副）與吐槽之力；取得的線索依序列在右邊一欄 |

閱讀工具列提供目錄、回顧、自動與略讀；存檔、讀檔與素材集中在選單。Safe Area 只在 Android／iOS 原生匯出讀取；瀏覽器分頁本身已避開瀏海。讀到穩定劇本位置時寫入獨立的自動續讀檔；手動存檔有 3 頁、每頁 6 格，存入素材、背景、立繪與閱讀位置。新遊戲重設自動續讀進度，手動欄位保留。同一瀏覽器、同一網址重開後可按「繼續」或從指定欄位讀檔。選單的吐槽素材與人物檔案只在有調查或吐槽回合的故事出現。存檔也記住正在播的背景音樂。

[素材試版手機畫面](docs/preview-assets-dialogue-phone.png) · [UI 試版比較](docs/UI-TRIAL.md) · [Phase 2 手機畫面](docs/preview-phase2-phone.png) · [多欄位讀檔畫面](docs/preview-save-slots-phone.png) · [驗證紀錄](docs/VERIFICATION.md)

B 超必殺演出已接入回合玩法（測試夾具 `phase4_rounds`；功能展示的「畫面」段落有光束），使用既有素材與程序特效。眼鏡的 `charged` 可在 `scenes/ui/glasses_icon.tscn` Inspector 開啟，預覽金色氣焰；執行時由力量控制。`scenes/ui/beam.tscn` 的 `Strip`、`OriginGlow` 可在 Godot 調整光束位置與起點；同時出現的台詞位於 `scenes/ui/cutin.tscn` 的 `BeamCaptionArea`。後續 C → D → E 見 [TODO](TODO.md)。

漫畫吐槽的左右構圖分別存於 `scenes/comedy/tsukkomi_impact.tscn` 與 `scenes/comedy/tsukkomi_impact_right.tscn`。在 Godot 可調整 `CutInPanel`、`PanelLines` 與 `Burst`；劇情編輯器的 `comedy`／`tsukkomi_impact` 有「出場位置」可選，預設左側。純文字劇本可寫 `do comedy("tsukkomi_impact", "shinpachi", "現在是工作時間吧！", "right")`。既有新八吐槽的 `cutin` 會呈現為漫畫格；緊接光束的必殺台詞與連擊通知保留各自演出。如果選詞剛說過相同台詞，不會重播漫畫格。故事 JSON 與存檔版本不因這項呈現調整而改變。

## 做別部作品：外觀包

換掉外觀包、用語與故事資料，就能把這套系統做成別部作品的視覺小說（契約見 [IMPLEMENTATION.md「外觀包」](IMPLEMENTATION.md)）：

1. 建 `skins/<作品 id>/skin.json`，只寫要改的欄位，其他沿用 `skins/gintama/skin.json`。最少只要 `terms`（例如把「吐槽／眼鏡／吐槽之力」換成「反駁／刃／決心」）與 `texts`（標題、標語、目錄標題）。
2. 要換畫面風格：`look` 寫 `flat` 並給 `palette`，不需要任何圖；要做有質感的紙框或木框，就複製 `scenes/ui/*_gintama.tscn` 改圖，在 `scenes` 指過去（節點名稱不要改）。
3. 生命圖示：做一個有 `broken`、`charged`、`color`、`crack_color` 屬性的小 scene，填進 `life_icon`。
4. 在 `data/stories.json` 的故事加 `"skin": "<作品 id>"`。
5. 故事用到的角色、背景、音樂登記在 `data/asset_catalog.json`；作品包可使用自己的 `stories/<作品>/catalog.json`。`default_pov`、`default_background` 決定預設的心聲角色與開場背景，角色的 `voice_pitch` 是打字音高。

`tests/fixtures/skins/plain/` 是不用任何新圖的範例（扁平配色、刃形生命圖示、「反駁／決心」用語），`tests/test_skin.gd` 驗證它換得過去也換得回來。劇本沒有吐槽回合與調查時，HUD、案件檔與「輔助」設定都不出現，就是一般的視覺小說。

## 首篇極短篇協作原型

[不是頭痛，是桂](stories/katsura_dog_ears/README.md)已做成獨立可編輯故事包：桂分兩句，中間停頓，第二句認真、理直氣壯；玩家抓時機接新八吐槽。桂姿勢圖已依參考圖生成並接入，待作者試看；[參考與提示詞](stories/katsura_dog_ears/OPT-IMAGE-PROMPT.md)保留供後續修訂。編輯器開啟 `?story=katsura_dog_ears`；現有 Web 匯出版尚未包含本篇。

## 打開故事編輯器（網頁）

agent 共同編劇的人格與記憶資料放在 [authoring/](authoring/README.md)：三角色人格 revision 2 與三條基礎記憶 revision 1 已由作者確認，完整內容見 [確認清單](authoring/REVIEW.md)。本機編輯器上方「編劇參考」可查看、選取並下載給外部 agent 的上下文；記憶預設不選，未確認或修改過的內容會被阻擋。人格修改與確認仍走檔案／CLI，內建 AI Writer 尚未提供。最新系統／編輯器交接與驗證見 [HANDOFF.md](docs/HANDOFF.md)。

從 repo 根目錄開啟[預覽工作台](../../preview/README.md)，再點「開啟故事編輯器」。Windows 也可雙擊 `preview/start.bat`：

```bash
python3 preview/start.py
# http://127.0.0.1:8000/preview/
```

也可直接進入 `http://127.0.0.1:8000/tools/story_editor/`。預覽服務會自動尋找 PATH 上的 Godot；找不到時以 `--godot <執行檔路徑>` 指定。需要 Python 3.10 以上與 Godot 4.7，不用 npm。

本機專案服務提供「驗證並存檔」：圖編輯的故事直接存回 `data/`，新故事通過檢查後自動登記進 `data/stories.json`；開檔後磁碟上的檔案若被改過，會拒絕覆寫。驗證失敗時保留草稿，遊戲繼續使用上次通過的版本。用 `.dialogue` 建置的故事在編輯器裡唯讀，先「轉成圖編輯來源」建立新的故事 id 才能編輯。用一般靜態伺服器或直接雙擊 `index.html` 開啟時，改用匯出下載的流程。操作見 [編輯器說明](docs/STORY-EDITOR.md)。

在場景卡上按右鍵或點「⋮」，可更改場景出口類型、增加選項；點卡片內的小步驟，在右側「步驟類型」也可直接切換。取代已寫的內容會先確認，且可復原。

右側每個步驟前的「＋ 插入步驟」可直接選類型並插入到該位置，新增後自動定位，支援復原／重做。側欄底部也能繼續新增步驟。

在本機服務選取場景後，可從側欄「試玩這個場景」設定旗標與線索，直接開啟獨立遊戲視窗。尚未存檔的修改和唯讀故事都能試玩；正式遊戲存檔不受影響。前面場景的背景、角色與進行中的互動不會自動還原，需要時請從較早的場景開始。

立繪分成「角色登場／表情」、「角色退場」、「立繪明暗」與「立繪動作」。登場可選立刻上場或準備站位，開口時依所選動畫登場；立刻登場會把角色移到前景，已在場的角色也適用。退場獨立選淡出、左右滑出或直接退場。明暗可選變暗、恢復明亮或隨說話者自動切換，先顯示變化再接下一個動作。抖動／彈跳可放在台詞前，尚未登場時先登場再播放；緊接漫畫演出時先完成動作。台詞的「畫外音」勾選時說話者不會登場，可在表單直接取消。「台詞表情」選「沿用目前表情」可保留登場時的表情；指定另一表情則從這句開始覆蓋。

「素材設定 → 角色 → 身高 cm」會自動統一立繪比例，先設定桂 175、銀時 177、神樂 155。人物以頭頂到腳底計算，神樂的傘不算身高；表情沿用同一比例。留空沿用角色場景大小。繼承角色也能在作品內設定身高，存檔後重新試玩生效。舞台拖曳或左／中／右按鈕控制站位；Godot 場景控制舞台與水平取景。

- 直接開某個故事：網址後面加 `?story=<id>`，例如 `?story=katsura_dog_ears`（id 見 `data/stories.json`）。
- 8000 被占用就換 `--port`。遊戲試玩用的是 5193（`tools/serve_web.sh`），兩個可以同時開。
- 多個人或多個 agent 同時跑 Godot 時，先把環境變數 `GODOT_LOCK` 設成大家約定的同一個絕對路徑，驗證會排隊不互相干擾。

## 開發與 Web 匯出

此目錄是獨立的 Godot 專案，用 **Godot 4.7 stable** 開啟 `project.godot`，按 F5 試玩。設計尺寸 1920×1080（16:9），`stretch aspect=keep` 保持橫向構圖，比例不同的視窗會留邊；原生手機以橫向啟動。

```bash
cd prototypes/debt-commission
# 已安裝相符版本的 Godot Web export templates 可略過下一行。
python3 tools/fetch_web_templates.py
bash tools/build_web.sh
bash tools/serve_web.sh
```

`GODOT_BIN` 可指定 Godot 執行檔位置；`serve_web.sh` 可接受埠號，例如 `bash tools/serve_web.sh 5194`。伺服器綁定本機 `127.0.0.1`。產物為 `build/web/index.html` 及同目錄相關檔案。Compatibility renderer、單執行緒 Web 匯出。

`build_web.sh` 匯出後會修補 `index.js` 的 Emscripten IDBFS：存檔同步到 IndexedDB 的途中若檔案已被刪除（例如「重新開始」緊接在存檔之後刪掉存檔），略過那個檔案，不再報 `Failed to save IDB file system: undefined`；刪除本身會在 Godot 下一次同步時寫進 IndexedDB。換 Godot 版本後如果修補對不上，建置會直接失敗並說明原因。

## 檔案

| 檔案 | 用途 |
| --- | --- |
| `main.gd` | 橫向外殼：背景、立繪、特效、對話與選項、彈出視窗；手勢、AUTO／SKIP、選單、紀錄。底下四段各在自己的檔案，透過 `m`（main 的 `class_name DebtMain`）讀寫外殼的狀態：`scripts/main_investigation.gd` 調查、`main_round.gd` 裝傻回合與 QTE、`main_saves.gd` 存讀檔與備份、`main_tutorial.gd` 第一次教學，`main_qa.gd` 是 `?qa=1` 的 QA 快照。測試直接呼叫的舊名稱在 `main.gd` 末尾「轉接」保留一行 |
| `scripts/flow_graph.gd`、`scenes/ui/flowchart_panel.tscn`、`flow_box.tscn` | 流程圖：把劇本的節點收成場景方塊（`next`、選項、`condition`、`goto`、回合 `clear` 才算路線；調查反應、吐槽失敗、提示、重試與 Game Over 留在方塊裡），走過的顯示標題、其他是 ？？？。面板根節點的 `box_size`、`column_gap`、`row_gap`、`line_color`、`faint_line_color`、`line_width` 可在 Inspector 調；方塊外觀在 `flow_box.tscn`。由 `tools/add_flowchart_scenes.gd` 產生一次 |
| `shaders/scene_transition.gdshader` | 換背景的轉場：`bg` 步驟寫 `transition` 為 `brush`（筆刷）、`ink`（墨暈）或 `glitch`（故障），預設 `fade`；`.dialogue` 寫 `do bg("id", "brush")`。下一句等轉場結束；畫面效果「減少」時直接切換 |
| `scripts/skin.gd`、`skins/gintama/skin.json` | 外觀包：載入並合併 `skins/<id>/skin.json`（場景、外觀、生命圖示、標題、用語） |
| `scripts/ui_styles.gd` | 依外觀包的配色與素材畫按鈕與面板（依 node 的 `ui_style_role` 套用） |
| `scripts/ui_stage_style.gd` | 背景照片的和紙色調 |
| `scenes/stage.tscn` | 舞台：各背景的取景框、左中右通用站位（編輯器裡可拖曳） |
| `scenes/comedy/tsukkomi_impact.tscn`、`small_reaction.tscn`、`full_manga_panel.tscn`、`emotion_band.tscn` | 漫畫吐槽疊加層的四個 preset（`ComedyLayer` 實例化，腳本 `scripts/comedy_preset.gd`）。根節點的 `@export` 可調：`dim_in`、`cutin_at`、`cutin_slide`、`shake_at`、`sound_at`、`burst_at`、`hold_until`、`fade_at`、`end_at`（秒）、`shake_strength`、`sound_id`、`stage_zoom`、`font_max`、`cutin_exit`（從 `fade_at` 起 cut-in 往右滑出、只有 `Dim` 淡出）；`SpeedLines`（`speed_lines.gd`）調線數、顏色、中心空白；`Burst`（`burst_shape.gd`）調尖角數、填色、框線；`CutInPanel`／`Portrait` 是傾斜漫畫格與臉圖；`Text` 的字體與描邊在 scene 裡。編輯器未執行就看得到新八 `shout` 與「現在是工作時間吧！！！」。`emotion_band` 是驚訝之類情緒的橫向純色長條：從左滑入、停住、往右滑出，條上左邊是臉、右邊是台詞；預設顏色是 `CutInPanel` StyleBox 的 `bg_color`，每一句可在劇本用 `color` 自訂（`do comedy("emotion_band", "kagura", "欸！？", "#7ec8ff")`），條的位置與高度是它的 anchor。缺的 preset scene 由 `tools/make_comedy_scenes.gd` 補建，已有的不覆寫 |
| `scenes/ui/choice_sheet_gintama.tscn`、`choice_item_gintama.tscn` | POV 選項與限時吐槽的選項面板（腳本 `scripts/choice_sheet.gd`）。`choice_item_gintama.tscn` 的 `%Tone` 是語氣標記（只在有 `tone` 的列顯示：位置、大小、顏色在 scene 裡）；面板根節點的 `index_numerals`、`count_format` 可調 |
| `scenes/ui/choice_sheet_director.tscn`、`choice_item_director.tscn` | 導演選擇面板（腳本同上）。`%Banner` 抬頭文字、`%Note` 註腳樣式、`TopTape`／`BottomTape`／每列的 `Stick`（`scripts/stripe_bar.gd`：`color_a`、`color_b`、`stripe_width`、`lean`，編輯器裡直接看得到條紋）、`Panel` 的框線與底色、卡片列的 StyleBox（`choice_item_director.tscn`：一般／按下的邊框與底色、左邊 `content_margin_left` 留給「SCENE 01」）；根節點的 `index_format`（"SCENE %02d"）、`count_format`、`pop_seconds`（彈入秒數）、`pop_from_scale`（彈入起始縮放）可調。由 `tools/make_director_scenes.gd` 產生一次，之後 scene 是來源檔 |
| `scenes/characters/<角色>.tscn` | 每個角色的大小與取景（腳本 `scripts/placeholder_sprite.gd`） |
| `scripts/story_runner.gd` | 劇本節點執行、資料檢查、條件跳轉與閱讀位置 |
| `scripts/save_slots.gd` | 手動欄位命名、暫存寫入與備份還原 |
| `data/showcase_story.json` | 功能展示（圖編輯故事，`authoring: graph`）：每種步驟一張示範卡片，`tests/test_showcase.gd` 走完每條分支 |
| `tests/fixtures/stories/`、`tests/fixtures/story_src/`、`tests/fixtures/example_pack/example/` | 測試夾具：退出遊戲的舊故事（第一章、討債、Phase 2–4、回合、漫畫吐槽、選項、EP00、文字效果、轉場）與它們的建置來源、範例作品「末班車」。只給測試讀（登記在 `tests/fixtures/stories.json`，測試以 `stories_path` 指過去），不匯出 |
| `data/asset_catalog.json` | 背景、人物、吐槽素材及可替換圖片的統一設定 |
| `data/stories.json` | 章節選擇裡 `data/` 的故事（目前只有功能展示）：依序的本篇（`kind: "chapter"`）與試玩片段（`"sample"`），各自的劇本與存檔路徑。新增故事加一行，不用改程式；`stories/<作品>/pack.json` 的故事排在後面 |
| `scripts/story_library.gd` | 故事清單、標題與署名、通關評價、結局、跨章旗標與鑑賞解鎖（`progress.cfg`） |
| `data/credits.json` | 製作名單最後一段：引擎、劇本工具、字型、音樂、音效的來源與授權 |
| `docs/ART-SPEC.md` | 創作者美術規格：背景、立繪、表情、線索圖的尺寸與檔名；授權欄位與投稿檢查 |
| `docs/COLLABORATION.md` | 多人合作（文本、美術、主編）：檔案分工、流程、GitHub Desktop 同步、交稿清單 |
| `scripts/asset_usage.gd` | 劇本用到哪些素材（含遊戲自己換的表情）與素材作者；製作名單與投稿檢查共用 |
| `tools/art_check/` | 投稿檢查：缺圖待辦、規格建議、壞掉的路徑與劇本、缺授權；「專案 → 工具 → 作品：投稿檢查」或 `run.gd`，報告在 `build/art_check/` |
| `tools/text_fit_audit.gd` | 最大字級逐畫面檢查文字有沒有被切（同樣要開視窗跑），報告 `text_fit.json` 與每個畫面的截圖；有被切就結束碼 1 |
| `tools/shots_chapter1.gd` | 第一章遊玩畫面截圖（調查、收合列、toast、回合、QTE），要開視窗跑；Mac Retina 用 `--resolution 780x1688` 才是 390 CSS px 寬 |
| `IMPLEMENTATION.md` | StoryRunner、catalog 與外殼的介面契約 |

角色的名字、顏色與預設站位集中在 `data/asset_catalog.json`；有圖片時填入對應 `path` 即可替換背景或立繪；尚無圖片的角色透過姓名與台詞呈現。新故事用 `bg`、`char`、`say`、`choice`、`flag`、`goto`、`item`。舊劇本的 `move`／`face`／`camera` 屬於先前的俯視舞台，VN 版面略過它們；`show`／`hide`／`expression` 仍對應立繪。新增章節的欄位與驗證規則見 [介面契約](IMPLEMENTATION.md)。

## 驗證

```bash
# 在此 prototype 目錄執行；macOS 前面加 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot。
# 測試共用 user://（macOS 是 ~/Library/Application Support/debt-commission，不受 XDG_DATA_HOME 影響），要依序跑，不要同時開兩組。
bash ../godot-kit/tools/run_tests.sh .                          # 完整：tests/ 每個 test_*.gd（目前 57 個）
bash ../godot-kit/tools/run_tests.sh . chapter_flow chapter1    # 只跑指定幾組（名稱去掉 test_ 與 .gd）

# 三種機器人玩家（不進出貨）：不操作／隨便選／全選普通吐槽／知道答案，各跑 N 局，印評價分布與冷場數
godot --headless --path . --script res://tools/bot_players.gd -- --runs 1000 [--story res://tests/fixtures/stories/chapter1_story.json]

# 先匯出、啟動伺服器；需要已安裝 Playwright 及 Chromium 的 Node 環境。
node tools/browser_check.mjs --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --smoke --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --phase2 --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --slots --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --phase3 --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --rounds --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --investigate --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --comedy --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --choices --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --ep00 --playwright /path/to/node_modules/@playwright/test
node tools/browser_check.mjs --backup --playwright /path/to/node_modules/@playwright/test
```

分層驗收（見 repo 根目錄 AGENTS.md）：L1 跑改到的那一組；L2 再加簡易回歸——回合與評價改動加 `chapter_flow chapter1 phase4_rounds_ui game_feel`，調查加 `phase4_ui investigation`，教學加 `tutorial`；L3 跑完整。

`--url` 可指定試玩位址；`--chromium /path/to/chrome-headless-shell` 可指定 Chromium。瀏覽器檢查以真實 canvas 滑鼠與觸控操作（長按、上滑用 CDP 觸控事件）；預設走討債兩條路線，`--phase2` 走劇本測試兩條路線，`--slots` 驗證觸控存讀檔與 18 格分頁，`--phase3` 以橫向 800×450 與 640×360 走調查、吐槽及限時選詞讀檔，`--comedy` 在漫畫吐槽片段驗證疊加層播放中、點擊快轉不推進下一句（390×844 與 320×568，截圖與報告存 `docs/`），`--ep00` 在 EP00 走兩條路線（390×844：路徑 A 選 `loud`、看漫畫吐槽層、調查裡點銀時三次與草莓牛奶、委託書、導演選第三個；路徑 B 選 `tired`、不找委託書、導演選第一個，並在調查與導演選項各存手動欄位、重新整理後讀檔回到同一個事件），320×568 再跑路徑 A 到調查為止，截圖存 `docs/preview-ep00-*.png`、報告存 `docs/ep00-browser-report.json`；`--choices` 在兩種選項片段驗證 POV 選項（語氣標記、選了接對應的反應與旗標）、導演選擇（導演面板、註腳、卡片至少 48 CSS px、舞台不變、開關目錄後仍是導演面板、選一張卡走到結局與旗標；800×450 與 640×360，截圖與報告存 `test-results/`），`--rounds` 在回合試片用觸控點消音條、伊莉莎白的牌子（閱讀時與 320×568 的選詞面板旁，檢查牌子至少 48 CSS px 且沒被選項面板蓋住）、超必殺與 QTE，並在 320×568 檢查回合操作列；`--investigate` 在四線索試片用觸控點對話與移動話題（390×844 與 320×568）、到廚房查冰箱（畫面外台詞）再回到客廳；`--backup` 驗證設定裡的存檔匯出、壞檔拒絕與匯入。網址帶 `?qa=1` 時才啟用唯讀的 `window.__debtQA`；一般試玩網址不啟用。

## Godot MCP

`addons/godot_mcp_toolkit/` 已啟用，編輯器開著時 AI 可以讀場景、實跑遊戲、截圖與讀 console。WSL 裡的 Claude Code 連 Windows 編輯器的設定方式見 [Roadmap 的開發工具段落](../../docs/story-telling-game/ROADMAP.md#開發工具godot-mcp-toolkit)。Web 匯出已排除此 addon。

## 劇本與解謎編輯工具（只當編輯器用）

**不寫程式的人改劇情，請看 [編劇指南](docs/AUTHORING.md)**：在 Parley 流程圖寫劇情，從選單「專案 → 工具 → 劇本：建置並試玩」就能直接玩，不用打指令。這個選單由 `addons/story_tools/` 提供；`characters/`、`facts/`、`actions/` 是 Parley 的角色與狀態清單，角色由 `tools/story_build/make_parley_stores.gd` 依素材設定產生（新增角色後重跑一次）。

`addons/parley/` 是 [Parley](https://github.com/bisterix-studio/parley)（MIT），裝來試做 [Roadmap](../../docs/story-telling-game/ROADMAP.md#v1-之後) 的故事流程圖編輯器：在 Godot 編輯器底部的 Parley 面板拖曳節點、拉線連分支，存成 JSON 格式的 `.ds` 檔。版本釘在 commit `42f78c79e41da08b804c159ee616188afed76342`（`plugin.cfg` 寫 2.1.0，Asset Library 標 2.2.0，以 commit 為準）。

- **只當編輯器用。** 遊戲仍由 `StoryRunner` 讀 `data/*.json`；Web 匯出已排除 `addons/parley/*`。
- **plugin 直接登記在 `project.godot`，不要在 Project Settings 裡關掉再打開。** 從介面啟用時，Parley 與 Dialogue Manager 都會加一個 runtime autoload，而 Web 匯出排除了它們的檔案，匯出版會因找不到 autoload 而壞掉。`tools/build_web.sh` 偵測到這兩個 autoload（路徑或 uid）會直接停止匯出。
- **Parley 的角色、事實、動作清單已建好**，放在 `characters/`、`facts/`、`actions/`，編輯器打開時會自動登記進 `project.godot` 的 `[parley]` 區段。清單檔的 UID 不能變，`.ds` 檔裡的說話者就是靠它對應；要重建請用 `make_parley_stores.gd`，它會保留原本的 UID。
- **為什麼不換成 Dialogic 2：** 評估見 [docs/DIALOGIC-EVALUATION.md](docs/DIALOGIC-EVALUATION.md)。結論是保留 StoryRunner，Parley 只負責編寫：Dialogic 沒有流程圖編輯器，調查熱區、限時吐槽、檢查點都要自己寫；存檔不是原子寫入、會默默錯位；打錯的角色與指令要到執行時才發現。換過去會影響全部 7 個測試檔。
- **寫好的劇本怎麼進遊戲**：`tools/story_build/build_story.gd` 把 Parley 的 `.ds` 或 Dialogue Manager 的 `.dialogue` 建置成 `data/*.json`，兩種格式可以混用，產出相同。用法、語法與存檔版本規則見 [介面契約的「劇本建置」](IMPLEMENTATION.md#劇本建置story_src--data)；`story_src/phase4.*` 是同一段故事的兩種寫法，可以對照著看。
- **Parley 的圖怎麼畫**：一個 group 框是一個劇情節點（group 名稱就是節點 id）；框內從第一個節點往下連。ACTION 節點的 description 寫指令（例如 `char("kagura", "smile", "left")`、`set asked = "kagura"`），選項節點的 translation key 當選項 id。裝傻回合結束後的走向寫在 `story_src/*.blocks.json`，圖上的回合節點不接線。

同一套做法（登記在 `project.godot`、排除於 Web 匯出）另外裝了兩個工具：

- **[Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager)** v4.1.0（commit `a719088`，MIT，需 Godot 4.6+）：在 `.dialogue` 檔用類似劇本的文字語法寫分支對話，編輯器有語法高亮、搜尋與試跑。它和 Parley 都是劇本的編寫格式；**寫 converter 之前要先選定一種**（Parley 的 `.ds` 流程圖，或 DM 的 `.dialogue` 文字），遊戲端仍由 `StoryRunner` 執行。
- **[Puzzle Dependencies](https://github.com/nathanhoad/godot_puzzle_dependencies)** v3.0.1（commit `875a62f`，MIT）：畫冒險遊戲的[解謎依賴圖](https://www.grumpygamer.com/puzzle_dependency_charts)，規劃「拿到哪個素材才能解開哪個調查或吐槽」，可匯出 Graphviz。節點是可分類上色的文字卡片加箭頭，沒有條件運算，是解謎規劃工具，也可當流程圖編輯器的 UI 參考。
  - **圖表存在 `project.godot` 的 `[puzzle_dependencies]` 區段**，每次編輯都會改寫 `project.godot`。多人或多個 session 同時編輯時要注意衝突。
  - **不要按面板裡的更新按鈕**：它會從 GitHub 下載最新版覆寫 `addons/puzzle_dependencies/`，蓋掉固定的版本。
- headless 驗證過 Godot 4.7 能載入、既有測試與 Web 匯出不受影響；**面板本身要在有畫面的編輯器打開確認**。headless 編輯器結束時會多出幾行 `leaked at exit` 訊息，來自 Parley 的編輯器 UI，不影響遊戲。

## Scene 轉換進度

畫面原本全在 `main.gd` 執行時建立，編輯器裡看不到。依 repo 根目錄 `CLAUDE.md` 的原則，改到哪個畫面就轉成 `scenes/ui/` 裡的 scene，版面交給 node 與 Container，程式只負責填資料和行為。

2026-11-11 選定的介面圖位於 `assets/ui/selected/`：九宮格 StyleBox 在其 `styles/`，深藍與和紙按鈕四邊邊距各 48 px，分頁下邊為 8 px；吐槽按鈕使用整張圖。可在編輯器調整 `title_screen_gintama.tscn` 的 `LogoArt`、`chapter_result_gintama.tscn` 的 `GradeStamp`、`end_controls.tscn` 的 `EndingCard`／`EndingTitle`、`game_over_gintama.tscn` 的 `Glasses`、`gallery_picture.tscn` 的 `Thumb`，以及 `dialogue_box_gintama.tscn` 的 `BokeTsukkomi`。評價印章、結局名稱及未解鎖卡面由腳本依狀態填入；其位置與尺寸保存在 scene。開機圖與 App 圖示設定在 `project.godot`；Web 匯出排除候選原圖 `art_src/`。

| 畫面 | 狀態 | Scene |
|---|---|---|
| 舞台（背景取景、角色站位） | ✅ 已轉換 | `scenes/stage.tscn`（見下方「舞台」） |
| 角色立繪 | ✅ 已轉換 | `scenes/characters/<角色>.tscn`（腳本 `scripts/placeholder_sprite.gd`），`tools/make_character_scenes.gd` 補建 |
| 素材／人物檔案 | ✅ 已轉換 | `scenes/ui/case_file_panel.tscn`，卡片 `case_file_card.tscn` |
| 標題畫面 | ✅ 已轉換 | `scenes/ui/title_screen_gintama.tscn`（腳本 `scripts/title_screen.gd`） |
| 章節選擇、設定、章節結算 | ✅ 已轉換 | `scenes/ui/chapter_select.tscn`（每列 `chapter_row.tscn`；「結局收集」`EndingsHeading`／`%Endings`，每列 `ending_row.tscn`）、`settings_panel_gintama.tscn`（每列一個 ButtonGroup，最後是存檔備份；按鈕文字與間距可在 scene 改）、`chapter_result_gintama.tscn` |
| 素材圖片 | ✅ 已轉換 | `scenes/ui/item_picture.tscn`：catalog 有 `path` 就顯示圖，沒有就畫名稱第一個字的色卡；素材卡與素材詳細都用它 |
| 對話框與工具列 | ✅ 已轉換 | `scenes/ui/dialogue_box_gintama.tscn`（腳本 `scripts/dialogue_box.gd`），工具列是 `gintama_reading_*.tscn` |
| 目錄 | ✅ 已轉換 | `scenes/ui/menu_panel_gintama.tscn`（腳本 `scripts/menu_panel.gd`），每列是 `menu_row_gintama.tscn` |
| 第一次教學 | ✅ 新增 | `scenes/ui/tutorial_overlay.tscn`（`Card/Margin/Rows` 的 `Title`、`Body`、`Buttons`；`Focus` 框、四條 `Shade*`、`Arrow`）。只有框、壓暗與卡片的上下位置跟著目標，其餘在 scene；由 `tools/make_tutorial_scenes.gd` 產生一次，之後沒有 `-- --force` 不覆寫 |
| 對話紀錄 | ✅ 已轉換 | `scenes/ui/dialogue_log.tscn`、逐句 `log_entry.tscn`（`Avatar`＋`Body/Speaker`、`Body/Text`）。排版像聊天：其他角色靠左，有頭像與名字色；POV 角色與玩家的選擇靠右；旁白置中。名字色在銀魂和紙下使用 catalog 的 `ink`，沒填時由 `color` 加深到與和紙對比 ≥ 4.5（`ui_styles.ink_for`）。頭像預設為首字色卡，catalog 補上 `avatar` 圖片就會自動取代 |
| 流程圖 | ✅ 新增 | `scenes/ui/flowchart_panel.tscn`（`Header` 的 `Prev`／`StoryName`／`Next`／`Close`、`%Progress`、`%Scroll`／`%Canvas`），方塊 `flow_box.tscn`（`%Kind`、`%Title`）。方塊的位置依劇本在執行時排，線畫在 `Canvas` 上 |
| 存讀檔面板與覆寫確認 | ✅ 已轉換 | `scenes/ui/save_slots_panel.tscn`、`save_slot_card.tscn`、`save_overwrite_confirmation.tscn` |
| 結尾按鈕 | ✅ 已轉換 | `scenes/ui/end_controls.tscn` |
| 吐槽回合的操作列與消音條 | ✅ 已轉換 | 在對話框 scene 的 Actions 裡（‹ ›、句數、聽下去、吐槽！、`CensorBar`）；選項面板另有 `CensorBar` 與 `Super`；顯示什麼由 `scripts/round_view.gd` 決定 |
| 超必殺光束 | ✅ 已轉換 | `scenes/ui/beam.tscn`（`Strip` 調 anchors／offsets 與厚度，`Aura`／`Light`／`Core` 調顏色，根 node 的 `reveal_seconds` 調展開秒數；`shaders/beam.gdshader` 調脈動速度與邊緣；正常執行不重建） |
| QTE、cut-in、Game Over | ✅ 已轉換 | `scenes/ui/qte_ring.tscn`、`cutin.tscn`、`game_over_gintama.tscn` |
| 選項面板 | ✅ 已轉換 | POV 選項與限時吐槽：`scenes/ui/choice_sheet_gintama.tscn`（腳本 `scripts/choice_sheet.gd`），每列是 `choice_item_gintama.tscn`（`%Tone` 語氣標記）；導演選擇：`scenes/ui/choice_sheet_director.tscn`，每列 `choice_item_director.tscn` |
| 眼鏡／吐槽之力 HUD、線索小牌 | ✅ 已轉換 | `scenes/ui/round_hud.tscn`（`set_style` 套和紙資源），眼鏡 `glasses_icon.tscn`、線索 `clue_chip.tscn` |
| 調查點、收起後的調查列 | ✅ 已轉換 | `scenes/ui/hotspot.tscn`（依劇本放在背景圖上）、`scenes/ui/investigate_bar.tscn`（`Panel` 的 `self_modulate` 調整透明度）；「收起」鈕在對話框 scene 的 `Corner/CollapseTab`，按鈕外觀共用 `gintama_investigate_toggle.tscn` |
| 調查的對話／移動話題 | ✅ 已轉換 | 對話框 scene 的 `InvestigationTopics`（`TalkRow`／`MoveRow`，標籤與間距在 scene 裡），每個話題是 `scenes/ui/investigate_topic.tscn`（大小與字級在這裡，顏色跟著該款的「聽下去」） |
| 伊莉莎白的牌子 | ✅ 已轉換 | `scenes/characters/elisabeth.tscn` 的 `Placard`（對齊圖上白牌子的框，可拖曳、縮放、旋轉）、`Text`（字級與顏色）、`Glow`（選詞時的光框樣式）；牌子上的字由劇本決定 |
| 漫畫吐槽疊加層 | ✅ 已轉換 | `scenes/comedy/*.tscn`（四個 preset；`ComedyLayer` 在 `main.tscn`） |

**銀魂和紙**：`scenes/ui/dialogue_box_gintama.tscn` 的 `NameOverlap/SpeakerRow` 決定雲形名牌跨在紙框上方的位置；`NamePlate/CloudPlaque` 使用含喇叭的透明名牌 PNG，名字仍由 `SpeakerName` 更新。`Padding` 調整正文留白，`Frame/PaperCutout` 是含紙紋、波紋、櫻花與下一句三角的完整透明底圖；用 NinePatch 保留四角，`Frame.clip_contents` 限制繪製範圍。[去背素材與提示詞](assets/ui/GINTAMA-EXTRACTION.md)保留來源和製作紀錄。正文與名字的明體字重保存在 `FontVariation`，見[字型來源與授權](assets/fonts/NotoSerifTC-SOURCE.md)。紙框下方 `ToolbarMargin/Toolbar` 依序實例化 `gintama_reading_log.tscn`、`gintama_reading_auto.tscn`、`gintama_reading_skip.tscn`、`gintama_reading_menu.tscn`；小場景的 `Surface/CutoutArt` 是含圖示的透明按鈕底圖，`Contents/Caption` 調整標籤，根 Button 保留獨立觸控範圍，圖面維持原圖比例。另有 `title_screen_gintama.tscn`、`menu_panel_gintama.tscn`、`choice_sheet_gintama.tscn` 與 `choice_item_gintama.tscn`。標題卡 `CardArea/Card` 與設定卡 `Area/Card` 的底圖是去掉下一句三角的和紙 `gintama_panel_paper.png`（StyleBoxTexture 九宮格，只拉長第 140–168 列與第 280–805 欄的素紙，波紋與櫻花不變形），故事切換鈕與設定的 `Header/Plaque` 是去掉喇叭的雲形名牌 `gintama_heading_plaque.png`；按鈕樣式寫在 scene 裡：深藍銀框是主要動作，和紙色是一般選項，選中的設定是深藍金邊（選項是同一個 `ButtonGroup` 的 toggle）。目錄 `Area/Center/Panel` 也是這張和紙，標題 `Heading` 用雲形名牌，`Rows` 裡沒有 `ui_style_role` 的列是和紙色按鈕（快速存讀檔等三列沿用工具列的深藍）。Game Over 與章節結算 `game_over_gintama.tscn`、`chapter_result_gintama.tscn` 是和紙卡 `Center/Card`（結算卡外面包一層 `Scroll`，矮螢幕可捲），根節點 `z_index = 2` 讓卡片蓋過對話框的名牌。對話紀錄、存檔欄位、覆寫確認、章節選擇、人物檔案等共用面板在銀魂和紙下由 `ui_styles.gd` 依 `ui_style_role`（`menu`／`log`／`slots`／`confirmation`）換成同一張和紙（`GINTAMA_PAPER_ROLES`），`standard` 按鈕與存檔卡是和紙色圓角卡。這兩張圖與這些 scene 由 `tools/make_gintama_panels.gd` 產生一次（`-- textures`，`--import`，再 `-- scenes`），之後 scene 是來源檔，沒有 `--force` 不覆寫。場景是維護來源，正常執行不會重建；`tools/add_gintama_edition_scenes.gd` 是早期一次性製作紀錄，已存在新場景時會拒絕執行。

**舞台**：打開 `scenes/stage.tscn`。

- **站位（站哪裡）**：`StageArea` 底下的 `left`／`center`／`right` 是三個通用站位，任何角色都能站，由劇本 `char` 的位置決定（沒寫位置時用 catalog 的 `slot`）。拖曳框調整位置，拉上下邊調整高度；底邊是腳底線、中線是角色的中心。框裡分別以新八、銀時、神樂的角色場景作預覽，實際站進去的角色由劇本決定，預覽不會出現在遊戲裡。站位只有這三個名字，劇本和存檔都認這三個；要多一個位置得改程式（`scripts/story_runner.gd` 的 `VALID_CHARACTER_POSITIONS`）。
- **角色（多大、圖怎麼擺）**：每個角色一個 `scenes/characters/<角色>.tscn`。橘色框是站姿框，和站位框同一個大小；拖曳、縮放裡面的 `Art`，就決定這個角色不論站哪個位置的大小與位置（例如神樂的傘很大，她的 `Art` 比框大 1.13 倍）。框本身不用動。畫面上的大小是「站位高度 × 角色自己的比例」。
- **說話的人會移到最前面**，其他人變暗；站位靠得很近時，沒說話的人可能被擋住。
- **背景取景**：`Backgrounds` 底下每個 node 對應 catalog 的一個背景 id（`yorozuya_exterior` 就是萬事屋大樓），圖等比填滿框、置中裁切。把框拉得比畫面大，就能選要露出哪一段，例如左邊拉出去，畫面就往右偏。圖以 `data/asset_catalog.json` 為準，這裡的圖只是預覽。沒有自己 node 的背景（或只有漸層色的）用 `Default`。編輯器裡一次只顯示一張：在場景樹點眼睛圖示切換要調的背景；存檔時哪張開著都沒關係，遊戲會自己顯示當下的背景。
- `StageArea` 是固定的整個舞台，立繪位置不隨對話框高度或字數變動；對話框會遮住立繪下半部。`DialogueGuide` 是編輯器用的對話框示意。`main.tscn` 的 `stage_scene` 欄位可指定另一份舞台場景。
- 新角色：先在 `data/asset_catalog.json` 登記圖片，再跑 `godot --headless --path . --script res://tools/make_character_scenes.gd`，會替還沒有 scene 的角色建一個（已經有的不會動）。
- 編輯器畫框是 1920×1080；其他比例會保留橫向構圖並留邊。背景以填滿畫面為準，調完可用目標視窗尺寸試玩。
- 標題畫面的大樓是另一張：`scenes/ui/title_screen_gintama.tscn` 的 `Background`，一樣用拉框取景。

**在編輯器裡調整**：雙擊 `scenes/ui/*.tscn` 打開，左邊場景樹點選 node，右邊屬性面板改位置、大小、字級、間距；Container 的間距在 Theme Overrides 裡。對話框、選項面板、導演選擇面板、目錄與標題畫面的配色、字級與框線都存在 scene 裡（框線由 `scripts/ui_ornament.gd` 繪製，編輯器裡也畫得出來），看到的就是遊戲裡的樣子；其他畫面（對話紀錄、存讀檔欄位、結尾按鈕）的顏色與框線仍是執行時由 `ui_styles.gd` 套上，編輯器裡是 Godot 預設灰色。

## 發現

- 版面：預設橫向 16:9。閱讀框使用固定正文區，長文分頁；四個工具列按鈕保留透明底圖的原始比例。調查及吐槽控制需要時可增加面板高度，舞台仍保持固定。
- 觸控：以放開手指判定點擊，長按、拖曳、恢復 UI 的那一下都不會誤推進劇情。
- 劇本資料：不改 GDScript 即可切換背景、立繪、站位、表情與素材條件選項；兩條技術片段路線在 Web 實跑並可續讀。
- 核心短循環：調查熱區取得素材後，銀時的兩句發言可切換與聽補充；進入吐槽選詞才開始倒數。完美／普通／冷場／隱藏結果、眼鏡、吐槽之力與檢查點可由劇本資料與 UI 測試驗證。
- 尚待真人：Android／iOS 實機手感、按鈕大小與透明度是否合適、字級是否夠大。

## 素材來源

- 背景與立繪：使用者加入 `assets/image/` 的 PNG（外觀、客廳、廚房 `kitchen.png`；新八、銀時、神樂、登勢、定春、伊莉莎白），在 `data/asset_catalog.json` 登記。站位預覽直接實例化既有角色 scene，只在編輯器顯示。每個角色要畫哪些表情（生氣、慌張、緊張……）見 [表情清單](../../docs/story-telling-game/EXPRESSIONS.md)；表情圖登記在角色的 `expressions`，還沒有的先用原本那張。
- 介面新圖：作者從 imagegen 候選中選定，來源、檔案對照與雜湊見 [SOURCE.md](assets/ui/selected/SOURCE.md)；提示詞與原圖留在 `art_src/ui/gen-20261110/`。
- 音效與稀疏背景音：`tools/prepare_audio.py` 產生的原創 PCM WAV，可重建。
- 中文字型：WenQuanYi Zen Hei，隨附 `assets/fonts/COPYRIGHT.txt` 與 `LICENSE-GPL-2.txt`，包含字型嵌入例外及 M+ FONTS 授權文字。

## 第一章與閱讀功能（2026-10-06）

第一章「萬事屋冰箱草莓牛奶失竊事件」上機試讀版已退出遊戲，劇本留在測試夾具 `tests/fixtures/stories/chapter1_story.json`。它採用已核准 P1–P8 的草稿 v0.2，來源是 `tests/fixtures/story_src/chapter1.dialogue` 與 `chapter1.blocks.json`，台詞追溯見 `docs/chapter1-source-map.json`。玩法、驗證與真人待辦見 [C–E 交付紀錄](docs/READING-CHAPTER1.md)。

新增段落內「上一句」、獨立快速存檔／快速讀檔，均在目錄。字級與紙框透明度在設定，窄手機可捲動。文字支援重點色／放大／抖動、停頓／慢速與角色打字音；功能展示的「角色：立繪與文字」示範文字演出，「畫面：轉場與演出」依序示範筆刷、墨暈、故障與預設淡入淡出四種換背景轉場。新安裝預設銀魂和紙；後續對話框與按鈕沿用作者確認的 PNG 紙框與深藍銀框按鈕。

直接調整 `dialogue_log.tscn` 的 `Margins` 與 `Column` 間距、`LogClose` 文字；`save_slots_panel.tscn` 的 `OuterMargins`／`Padding`／`Cards`；`save_slot_card.tscn` 的 `Preview`／`SlotTitle`；`save_overwrite_confirmation.tscn` 的確認文案；`end_controls.tscn` 的 `Actions` anchors 與兩顆按鈕。正常執行不重建這些 scene。

## Studio 效能改善（2026-10-16）

此原型使用 `project.yaml` 保存 Godot 4.7、`scripts/` 程式根目錄與輕量工作流程。
共用工作流程目錄在 `../../studio/runtime/codex/`。本輪規格見
[quick spec](design/quick-specs/studio-polish-2026-10-16.md)，量測與限制見
[改善報告](production/polish/studio-polish-2026-10-16.md)，測試結果見
[smoke report](production/qa/smoke-2026-10-16.md)。

可重跑 CPU 微基準：`godot --headless --path . --fixed-fps 60 --script res://tools/studio_bench.gd`。 `test_comedy`／`test_ep00` 的時間斷言須用正常時間執行，不加 `--fixed-fps`。

2026-10-29 改善入口：[完整短篇驗收](docs/SHORT-STORY-ACCEPTANCE.md)；主程式維護邊界見 IMPLEMENTATION.md。

調查熱區的觸控範圍與重疊優先序由 `scripts/investigation_picker.gd` 負責；`main.gd` 保留拖曳、遮擋與劇情協調。可用 `investigation_picker` 測試單獨驗證選取規則。

調查背景的覆蓋尺寸與拖曳界線由 `scripts/investigation_layout.gd` 計算；對應單元測試 `investigation_layout`，畫面回歸使用 `phase3_ui`／`phase4_ui`。

2026-10-30 本地 Web 候選已更新，包含調查模組拆分與螢幕外角色熱區修正。[ZIP](build/debt-commission-web-candidate-20261030.zip)／[驗證與來源雜湊](production/qa/web-candidate-2026-10-30.json)。匯出及靜態檢查通過，本包瀏覽器與真機仍待驗。
