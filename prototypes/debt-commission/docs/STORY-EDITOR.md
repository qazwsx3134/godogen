# 劇本節點編輯器

ComfyUI 手感的靜態網頁：把劇本 JSON 當成節點圖來拖、來連、來看哪條路到哪個結局。讀寫的就是 StoryRunner 已在讀的劇本 JSON（`data/*_story.json`，格式見 [IMPLEMENTATION.md](../IMPLEMENTATION.md)），遊戲端不用改。不用建置、沒有 npm 依賴；程式在 `tools/story_editor/`。

## 怎麼開

- **建議**：在專案根目錄服務，再開網址。會自動列出 `data/stories.json` 的故事、讀 `data/asset_catalog.json`（角色下拉）與 `scripts/story_runner.gd` 的 op、表情、漫畫 preset 清單。

  ```bash
  python3 -m http.server 8000 -d prototypes/debt-commission
  # http://127.0.0.1:8000/tools/story_editor/          （?story=ep00 直接開那個故事）
  ```

- **直接開檔**：雙擊 `tools/story_editor/index.html`（`file://`）也能用，從「開啟…」選任一 `*_story.json`。拿不到 catalog 時角色欄改成文字輸入，清單用內建值。

## 操作

| 想做的事 | 做法 |
|---|---|
| 平移／縮放 | 拖背景；滾輪（以游標為中心） |
| 看全部／重新排版 | 「符合畫面」／「自動排版」（依 entry 的 BFS 深度分層，左→右） |
| 移動節點 | 拖卡片 |
| 改一條出線的目標 | 從卡片右側的圓點拖線，放在另一張卡片上 |
| 從出線長出新節點 | 同上，放在空白處 |
| 斷線 | 點線（或點出線的圓點）→ 線中間的 ✂、側欄「斷線」、或 Delete |
| 新增節點 | 雙擊空白處，或「＋節點」 |
| 刪除節點 | 選取後 Delete／側欄「刪除節點」（指向它的出線會留著並標紅） |
| 設定 entry | 側欄「設為 entry」或「故事」區的 entry 下拉 |
| 復原／重做 | 工具列「復原／重做」，或 Ctrl/Cmd+Z、Ctrl/Cmd+Shift+Z／Ctrl+Y。新增、刪除、改名、接線、拖動、表單與自動排版都可復原；同一欄位一次聚焦中的連續輸入合併成一步。原始 JSON 未套用前使用文字框自己的 undo。 |
| 搜尋／跳轉 | 側欄「全文搜尋」（Ctrl/Cmd+F）：搜尋節點 ID、標題、台詞、角色與巢狀文字。點結果定位卡片與步驟；超過 100 筆先顯示前 100 筆，可縮小關鍵字。 |
| 改名 | 側欄節點 id；所有指向它的出線與 `entry` 一起改 |
| 改步驟 | 側欄步驟列表：新增（插在結尾的終止步驟 end／choice／goto… 之前）、刪除、↑↓；`say`、`choice`、`goto`、`end`、`comedy` 有表單，其他 op 直接改該步的 JSON（解析失敗不會覆寫，並提示原因） |
| 找問題 | 側欄「問題清單」，點一條就跳到那張卡片 |

`comedy` 選 `emotion_band` 時多一個 `color`（色票或 `#rrggbb`；「清除」或空白＝不寫這個鍵，用 scene 的預設黃 `#ffd23f`）；換成別的 preset 時會移除它，因為 runner 只接受 `emotion_band` 有 `color`。

表單只改你動到的欄位：選填欄位清空就刪掉那個鍵（不會寫 `""`），表單沒列的欄位（`source_id`、`offscreen`、選項的 `tone`／`set_flags`／`require` …）原封不動；每一步底下的「JSON」框能看到並改全部欄位。

## 看圖

- 卡片：標題列（title、node id；`ENTRY` 綠框、`結局` 含 `end`／`result` 的紅框）、左側一個輸入埠、右側每條出線一個輸出埠，埠旁寫明是哪條線；中間是步驟摘要（前幾句台詞、其他 op 的圖示計數）。
- 線色：`next` 灰、`goto` 紫、選項橘、`then` 綠、`else` 紅；**虛線**是調查的熱區／話題（青、藍）、吐槽回合的反應與選項（粉紅）、逾時與 game over（黃）。
- **紅色**＝有問題：從 entry 走不到的卡片（紅框＋「到不了」）、指向不存在節點的出線（紅虛線＋✕）、空心橘圈＝還沒連線。
- 認得的連線：節點 `next`；`goto` 的 `target`；`choice.options[].next`；`condition` 的 `then`／`else`；`investigate` 的熱區 `goto`／`lines[]`、`talk[].goto`（含 `places[]`）；`boke_round` 的 `tsukkomi.options[].goto`／`timeout.goto`／`game_over`／`retry`，以及 v2 回合的 `clear`、`rules.super|combo_bonus|combo_break`、每句的 `listen|whiff|hint`、`slot.timeout`、`options[].goto`、`when[].goto`、`censor|placard.goto`、`qte.perfect|early|late`。`target` 只有 `goto` 算（`camera`、`move` 的 `target` 是舞台標記）；v1 回合句子的 `listen` 是補充台詞文字，不是連線。

## 草稿、下載與儲存確認

修改時會把整份故事、座標與原始來源快照存為瀏覽器草稿，與專案檔案分開。重新整理或重新開啟同名同 ID 的故事時，側欄會顯示「復原草稿／刪除草稿」，不會自動蓋掉剛開啟的來源。來源已變動會額外提醒；復原前可先匯出目前版本。未指定 `?story=` 時會找上次的本機／新故事草稿；草稿不跨瀏覽器或裝置。

- **匯出 JSON**：送出下載後仍顯示「未確認儲存」。瀏覽器無法證明下載已成功寫入磁碟。
- **確認下載檔…**：選回剛下載的 JSON，比對內容完全一致後才解除未儲存／離頁提醒。選錯檔、讀檔失敗或下載期間又修改，都保留未儲存狀態。比對不會替你寫入專案或執行 check_story。
- 確認成功且沒有後續修改時，清除本份未儲存草稿。座標另存 localStorage；要跨機保存仍需匯出座標。
- 空間不足／儲存被封鎖／草稿損壞會持續顯示錯誤，記憶體中的修改仍可匯出；成功重試後才清除儲存錯誤。損壞草稿不自動覆寫，可明確確認後刪除。
- 另一分頁變更同份草稿時，本頁停止覆寫並持續提示；請先匯出本頁版本，再重新開啟以決定復原哪一份。仍待處理的舊草稿不會被新的編輯默默覆蓋。
- Undo 歷史最多保留 80 個狀態，只在此頁生命週期內有效；切故事會重設。草稿復原後從該草稿建立新歷史。
- 快速切故事／開檔只採用最後啟動的讀取；讀取失敗保留目前故事與錯誤提示。

## 匯出後一定要跑 check_story

編輯器**不算** `version`（那是存檔位置的結構雜湊，只有 `check_story.gd` 用 `StoryBuilder.fingerprint()` 算）。沒改過的故事原樣寫回；改過的故事匯出時 `version` 是 `s-unset`，所以忘了這一步時，舊存檔會被安全地拒絕，不會還原到錯位的步驟。匯出的檔案放進 `data/`（或任何路徑）後：

```bash
godot --headless --path prototypes/debt-commission \
  --script res://tools/story_editor/check_story.gd -- data/my_story.json --write
```

- 做三件事：`StoryRunner.load_story()`（遊戲跑的同一套驗證，會查角色、素材、表情、旗標…）；每個節點都從 `entry` 到得了（`story_builder.gd` 的檢查）；`version` 等於 `StoryBuilder.fingerprint()`。
- 全過印 `OK` 並結束 0；否則逐條印 `ERROR …`、結束 1。沒加 `--write` 時**絕不改檔**，`version` 過期只回報。
- `--write` 只在前兩項都過時才會重寫：把 `version` 改對，並用建置的格式寫回（鍵排序）。
- 路徑相對於專案；絕對路徑照用。

編輯器自己只檢查結構（連線、到不了、`next` 規則）；素材 id、旗標、表情寫對沒有，以 check_story 為準。

## 讓遊戲讀到新故事

在 `data/stories.json` 的 `stories` 陣列加一筆，順序就是章節選擇的順序：

```json
{ "id": "my_story", "kind": "sample", "path": "res://data/my_story.json", "save": "user://my_story.save" }
```

`kind` 是 `chapter`（本篇，前一章有結算紀錄才開放）或 `sample`（試玩片段，一直開放）。「新故事」建出來的空白故事 `version` 是 `s-unset`，一定要先跑上面的 `--write`。

## 檔案與座標

- **匯出格式**同建置輸出（Godot `JSON.stringify(story, "  ", true)`：鍵排序、2 空格縮排、整數值寫成 `8.0`）。建置產生的檔案匯入後不改再匯出是 byte-equal；`debt`、`phase2`、`phase3` 三個手寫排版的檔（步驟物件寫在同一行）只能資料相等，匯出會變成標準格式。
- **`generated_from`**：多半是 `story_src` 建置出來的檔案，重建會蓋掉這裡的修改。匯入這種檔案會顯示警告；要長期維護請改來源檔，編輯器匯出的 JSON 適合當新故事自己的來源。
- **卡片座標不進劇本 JSON**：存在瀏覽器的 localStorage（鍵 `debtStoryEditor.layout.<story id>`），也可「匯出座標」下載 `<id>.layout.json`、「匯入座標」讀回（換電腦、進版控）。沒有座標的節點自動排版。

## 測試

```bash
node tools/story_editor/test_core.mjs --out <暫存資料夾>      # 10 個故事往返、可達性對照 Godot（每個節點當起點）、改名、新故事
node tools/story_editor/smoke.mjs --playwright <playwright-core 目錄> --chromium <chrome-headless-shell> \
     --godot godot --out <輸出資料夾>                            # 真的滑鼠拖線、匯出下載、截圖、file:// 檔案選擇器
```

新增回歸涵蓋 undo/redo（新增、刪除、改名、接線、拖動與合併文字）、草稿重整復原、下載內容確認、搜尋跳轉、讀檔失敗、空間不足、跨分頁衝突與快速切故事；`batch1_regression.mjs` 由 smoke 自動執行。

不需要在專案裡安裝套件：`--playwright` 指向現有的 playwright-core。

## 限制

- 尚無直接存回專案檔案的服務；下載檔比對確認只表示磁碟檔內容與匯出相同，並不代表已搬進專案。刪除節點前會確認，尚未確認儲存時關頁面會提醒。
- 表單只涵蓋 `say`、`choice`、`goto`、`end`、`comedy`；調查、吐槽回合等大型 op 用 JSON 框改。
- 吐槽回合一個節點有幾十條出線，卡片會很高，反應節點在自動排版裡疊成長長一欄；放大看、自己拖。
- 編輯器認 `goto` op 的 `target`；`story_builder.gd` 的可達性把任何步驟的 `target` 都當連線，所以兩者只會在「節點 id 剛好等於舞台標記或角色 id」時不同。
