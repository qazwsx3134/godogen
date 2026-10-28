# 劇本節點編輯器

以場景為單位的靜態網頁：每張卡片是一個場景，內含背景、音樂與按順序排列的流程小節點；場景之間的線呈現故事走向。讀寫的就是 StoryRunner 已在讀的劇本 JSON（`data/*_story.json`，格式見 [IMPLEMENTATION.md](../IMPLEMENTATION.md)），遊戲端不用改。不用建置、沒有 npm 依賴；程式在 `tools/story_editor/`。

## 怎麼開

- **本機專案服務**：在 `prototypes/debt-commission` 目錄執行，再開網址。Python 3.10 以上，使用標準庫，不需安裝套件；Godot 用專案的 4.7 版本。

  ```bash
  python3 tools/story_editor/project_server.py --port 8000 --godot /Applications/Godot.app/Contents/MacOS/Godot
  # http://127.0.0.1:8000/tools/story_editor/          （?story=phase3 直接開那個故事）
  ```

  與其他 agent 共用 `.godot` 或 user:// 時，先設定 `GODOT_LOCK` 為雙方約定的同一個絕對路徑。本次協作使用：

  ```bash
  export GODOT_LOCK=/Users/peter/repo/godot/godogen/.claude/tasks/debt-commission-polish/godot.lock
  ```

- **靜態檢視與下載**：仍可用 `python3 -m http.server 8000 --bind 127.0.0.1` 在專案根目錄開啟。一般靜態服務與直接開檔都提供下載流程；本機專案服務才顯示「驗證並存檔」。

- **直接開檔**：雙擊 `tools/story_editor/index.html`（`file://`）也能用，從「開啟…」選任一 `*_story.json`。拿不到 catalog 時角色欄改成文字輸入，清單用內建值。

## 與 agent 共用人格與記憶

本機專案服務啟動後，按工具列「編劇參考」：

1. 展開角色或記憶的完整內容，檢視情境反應、聲線、關係與行為界線。
2. 勾選本次出場角色。記憶預設不選；先選擁有者才能勾選他的記憶。
3. 按「產生編劇參考」，複製下方內容或按「下載 JSON」交給外部 agent。
4. 和 agent 討論節拍與台詞，作者採納後，再用下方故事編輯流程製作。

```text
檢閱已確認人格 → 選角色／記憶 → 匯出參考 → 與 agent 編劇
                                                  ↓
                                            作者採納 → 編輯／試玩
```

本作三角色人格為 revision 2，三條基礎記憶維持 revision 1，均已由作者確認。此面板只讀 `authoring/` 正式庫，不讀 archive／proposals，不自動套用到獨立作品，也不修改人格、記憶或確認紀錄。新增設定仍須依 [authoring 規則](../authoring/README.md)另行與人類確認；不會從新劇情自動寫入記憶。

未確認或雜湊不符的內容可查看，但不可選取匯出。若面板開啟後資料已變更，即使新版已獲確認，也要重開面板檢閱。產物按 known_to 分配各角色能知道的記憶，與 CLI 相同，附 revision／SHA-256；它是產生當下的參考快照。修改勾選後會清除前一份結果，須重新產生。

需要本機專案服務，純靜態服務或 file:// 不顯示此入口。更新服務程式後須重啟 Python 服務，再重新整理頁面。尚無內建 AI 寫作、自動記憶檢索或 OOC 自動評分；作者與外部 agent 負責創作及內容審閱。

## 從零寫一篇故事

1. 按上方「新故事」，輸入英文、數字或底線組成的 id，例如 `first_short_story`。如果詢問作品 id，留空會放在本作的 `data/`。
2. 點「開場」卡片，在右側修改場景名稱和現有台詞；在上方「故事」區填中文標題。
3. 展開側欄底部「選擇步驟類型」，選對話、背景、立繪或其他步驟，再按「＋新增步驟」。用每個步驟右上的 ↑／↓ 調整先後順序。
4. 要分支時加入「選項」，以「＋節點」建立後續場景，將選項連到對應的卡片。沒有分支的短篇也可以先用一個場景與結尾。
5. 展開「試玩這個場景」，按「從這裡試玩」；未存檔的修改也會帶進獨立試玩視窗。
6. 按「驗證並存檔」。成功後故事存入 `data/<id>_story.json` 並登記到故事清單。桌面遊戲重新開啟後可在章節選擇中找到；既有 Web 匯出版需重新匯出才會包含新故事。

```text
新故事 → 寫台詞／安排角色 → 從場景試玩 → 驗證並存檔
                  ↑                │
                  └──── 修改後再試玩 ┘
```

上方故事清單可打開已有內容；`.dialogue` 建置的故事是唯讀，若想在網頁裡改，先按「轉成圖編輯來源」建立一份獨立副本。新故事或副本不會覆寫原故事。

已開始遊玩的故事若增刪步驟或分支，結構版本會更新，舊遊戲存檔可能無法續讀。想保留原進度時，可先建立獨立的圖編輯副本，或在遊戲設定中匯出存檔備份。

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
| 改步驟 | 點卡片裡的小節點直接定位側欄表單。側欄可刪除、↑↓排序；新增一般步驟插在終止步驟之前。表單沒列出的欄位可展開該步 JSON 修改，解析失敗會保留原資料。 |
| 試玩場景 | 選一張場景卡，展開側欄「試玩這個場景」，選好旗標／線索後按「從這裡試玩」（需要本機專案服務與 Godot） |
| 收合流程 | 同類連續步驟預設顯示「對話 ×N」等群組；點一下展開／收合。座標檔及 localStorage 都保存收合狀態，拖卡片、自動排版與匯入座標時一併保留。 |
| 新增步驟 | 展開側欄底部「選擇步驟類型」，選好後按「＋ 新增步驟」。七類：對話、旁白、立繪、背景・音樂、音效、事件、效果。對話 say 初始化角色，旁白 say 初始化 narrator。舊版 op 保持顯示與 JSON 編輯。 |
| 找問題 | 側欄「問題清單」，點一條就跳到那張卡片 |

`comedy` 選 `tsukkomi_impact` 時，可用「出場位置」選擇左側或右側；未選時從左側出場。這會記錄為 `side: "left"`／`"right"`，切換成其他 preset 時會清除。兩側的漫畫格、放射線與氣泡可在各自的 Godot scene 中調整；台詞與角色仍由劇本決定。

`comedy` 選 `emotion_band` 時多一個 `color`（色票或 `#rrggbb`；「清除」或空白＝不寫這個鍵，用 scene 的預設黃 `#ffd23f`）；換成別的 preset 時會移除它，因為 runner 只接受 `emotion_band` 有 `color`。

表單只改你動到的欄位：選填欄位清空就刪掉那個鍵（不會寫 `""`），表單沒列的欄位（`source_id`、`offscreen`、選項的 `tone`／`set_flags`／`require` …）原封不動；每一步底下的「JSON」框能看到並改全部欄位。

新場景的「尚未寫完」結尾是佔位：新增選項或其他終止步驟時會自動替換，且可以復原。已寫過的結尾或分支會保留，必須先刪除才能加入另一個；已連到後續場景時，也要先斷線才能加入選項或結尾。結尾、分支或跳轉後若還有步驟，問題清單與遊戲驗證都會指出那些步驟無法執行。

## 從場景試玩

選擇場景後，在側欄展開「試玩這個場景」。旗標預設為故事的初始值，可修改已宣告的文字、數字或布林值；線索從本故事的素材設定勾選。按「從這裡試玩」會開啟獨立的 Godot 遊戲視窗，關閉視窗後回到編輯器。

```text
編輯場景 → 選旗標與線索 → 驗證目前版本 → 開啟獨立試玩視窗
                  │                  └─ 有錯誤 → 顯示問題，保留編輯內容
                  └─ 關閉視窗 → 回編輯器繼續修改
```

- 試玩使用按下按鈕時的編輯器內容，包括尚未存檔的修改；不會寫入或登記故事，也不會清除未儲存提示。`.dialogue` 建置的唯讀故事也能直接試玩。
- 每次試玩使用獨立的暫存遊戲資料，存檔、設定和章節進度不會與正式遊戲共用；關閉遊戲後暫存資料會清理。作品故事使用該作品的素材設定與外觀。
- 不會自動重播前面場景，因此不會還原前面建立的背景、角色、音樂、調查進度或進行中的吐槽回合。需要這些狀態時，從較早的場景開始試玩。旗標與線索由上面的設定提供。
- 試玩仍會檢查整份故事的格式與素材引用，但容許其他場景從選定起點到不了；「驗證並存檔」仍會檢查整份故事的可達性。試玩不會取代從頭到尾的完整遊玩測試。

## 看圖

- 卡片標題列包含 title、node id、ENTRY／結局／到不了標記。其下的場景摘要顯示有效背景縮圖與 BGM 試聽。背景沒有 path 時用 catalog 的 top／bottom 漸層；BGM 沒有 path 時標示「佔位（無音檔）」。試聽可播放／停止，全頁同時只播一首；切換故事會停止。
- 有效背景／BGM：本場景最後一個 bg／bgm 決定出口；沒有該指令時，前驅出口一致標「沿用」，不同標「依路線不同」，沒有設定標「無」。bgm 的空 id 表示停止。圖推算包含各類連線與循環，不模擬條件是否實際可達或回合內部演出。
- 小節點以七類色條與文字標籤辨識；連續同類預設收合，點開後可逐步編輯。步驟數與出線數決定卡片高度；自動排版會按當前收合狀態留出間距。展開後若與鄰卡靠近，可拖開或自動排版。
- 線色：`next` 灰、`goto` 紫、選項橘、`then` 綠、`else` 紅；**虛線**是調查的熱區／話題（青、藍）、吐槽回合的反應與選項（粉紅）、逾時與 game over（黃）。
- **紅色**＝有問題：從 entry 走不到的卡片（紅框＋「到不了」）、指向不存在節點的出線（紅虛線＋✕）、空心橘圈＝還沒連線。
- 認得的連線：節點 `next`；`goto` 的 `target`；`choice.options[].next`；`condition` 的 `then`／`else`；`investigate` 的熱區 `goto`／`lines[]`、`talk[].goto`（含 `places[]`）；`boke_round` 的 `tsukkomi.options[].goto`／`timeout.goto`／`game_over`／`retry`，以及 v2 回合的 `clear`、`rules.super|combo_bonus|combo_break`、每句的 `listen|whiff|hint`、`slot.timeout`、`options[].goto`、`when[].goto`、`censor|placard.goto`、`qte.perfect|early|late`。`target` 只有 `goto` 算（`camera`、`move` 的 `target` 是舞台標記）；v1 回合句子的 `listen` 是補充台詞文字，不是連線。

## 素材與事件表單

- bg：背景下拉及縮圖；bgm：音樂下拉與播放／停止，空值停止故事音樂；se：catalog 音效下拉。
- char：選角色、表情與站位；「角色狀態」可選準備站位、立刻登場或退場。登場／退場的動畫可選淡化、從左或右滑動並淡化、直接切換；未指定使用淡入／淡出。「舞台」可拖曳角色到左、中、右，或按對應按鈕；站位下拉選單選「角色預設」會使用 catalog 的 `slot`。示意圖不會模擬其他角色、對話框或螢幕裁切；位置和大小的精調在 Godot 的 `scenes/stage.tscn` 與 `scenes/characters/<角色>.tscn`，實際構圖請從該場景試玩。表情選項只列該角色 catalog 有圖的值（neutral 用角色主圖）；匯入的其他值保留並標「目前的值」，不默默替換。say／comedy 也使用角色表情清單。
- 立繪動作：選已登場的角色，再選「抖動」或「彈跳」；把步驟放在台詞之前即可與台詞一起呈現。若緊接著角色登場，動作會在登場完成後接著播放；畫面效果設為「減少」或略讀時，動作會略過。角色尚未登場時，動作不會讓角色自動現身。
- 較長的 say 台詞會在固定閱讀框內分頁；出現「繼續閱讀」時，點擊後仍留在同一句，最後一頁才推進。試讀時可在設定調整字級。
- item：取得道具；flag：設定 JSON 純量或加減整數；condition：單一 flag/equals，或遞迴 AND／OR／NOT、旗標比較與持有道具，搭配 then／else 目標。
- 純量文字輸入要加雙引號，例如 `"已見面"`；數字與 true／false 直接填。新旗標先在故事的 flags 區宣告。條件值型別與合法性由 check_story 最終確認。

## 故事外觀與預設視角

「故事」資訊區可選外觀包、章節封面與預設視角。外觀包顯示 id 與 name；專案服務列出 `skins/*/skin.json`，靜態服務列出 registry 已使用的 id 加上 gintama。封面從 catalog 有圖片的背景中選取，可預覽；空白使用遊戲的自動封面。外觀包空白使用 gintama。

skin／cover 寫在 stories.json 的故事列，不進劇本 JSON。建置故事的文字仍唯讀，外觀欄位可編輯；專案服務的「存回外觀設定」只更新 registry，不重建或改寫劇本。既有列只改 skin／cover，其餘欄位保留；新故事及圖編輯副本保留來源列的外觀與未知欄位，並建立自己的 id、path、save 與 graph 來源。

預設視角寫入劇本根層 default_pov；空白移除該鍵，使用 catalog 的預設角色。根層 credits 與未編輯欄位原樣保留。角色、對話及喜劇演出的表單顯示 catalog voice_pitch（Hz），僅供查閱；音高應修改 catalog。

外觀儲存會核對開啟時的 registry SHA-256，避免覆蓋其他作者的修改；劇本與外觀一起送出時，驗證後再次核對兩份檔案。靜態下載須分別確認劇本 JSON 與 stories.json，兩份內容都確認後才解除未儲存提醒。registry 下載供作者合併至最新專案版本。

## 來源與轉成圖編輯來源

registry 的 `authoring` 是 `dialogue` 或 `graph`。帶 generated_from 或登記為 dialogue 的故事是唯讀，可檢視、搜尋、試聽與調整版面。按「轉成圖編輯來源」，指定未使用的新 id：建立獨立圖編輯副本，拿掉 generated_from，version 設為 s-unset，原故事保留。

轉出副本可立即改台詞。本機專案服務下按「驗證並存檔」，會驗證新故事、存進 data，再把 graph 新列合併到最新 registry，保留既有故事與其他欄位；新故事預設是 sample，使用獨立存檔。

一般靜態服務或直接開檔時，使用「匯出 JSON」及「下載 stories.json」。下載 registry 的新列由作者合併進專案最新 stories.json，避免覆蓋同期變更；草稿復原會一併還原這份待下載的 registry。

## 驗證並存檔

「驗證並存檔」呼叫遊戲使用的 `check_story.gd --write`，確認劇本與版本都正確後，才解除未儲存提醒；送出期間若繼續編輯，成功只確認送出那一版，後續修改仍需再次存檔。

```text
編輯 → 送出內容＋開檔 hash → 私有候選檔 → Godot 檢查
                                            ├─ 失敗 → 保留修改與待修草稿
                                            └─ 通過 → 再核對磁碟 hash
                                                       ├─ 衝突 → 不覆寫
                                                       └─ 相符 → 原子存回
                                                                 ＋新故事登記
```

- 可儲存 `data/<名稱>_story.json`：已登記的 graph 故事，或尚未登記的新故事。新故事的 id 與檔名須一致；服務拒絕 dialogue／generated_from 產物。
- 開啟專案或選取 JSON 時，編輯器記住當時原始內容的 SHA-256。磁碟檔案在開檔後或驗證期間有任何變化，就拒絕覆寫。遇到衝突先匯出本頁，再重新開啟專案版本比較；復原草稿保留原基底，不會默默繞過衝突。
- 驗證錯誤逐條顯示在「問題清單」。修改仍在瀏覽器草稿，服務也保留 `tools/story_editor/.drafts/<草稿編號>/<故事檔>`，可在檔案系統取回；這些候選檔不會被服務公開或登記到遊戲。驗證失敗時 data 裡的正式故事保持上次通過的版本，新故事不登記。
- 寫回採同目錄暫存檔、flush／fsync 與 rename。登記新故事若失敗，回復原目標並保留候選；不會報成功。這是兩個檔案依序發布，不是跨檔案的斷電交易：中途程序／系統崩潰可能留下有效但尚未登記的新故事，重新開啟該檔可再驗證登記。
- 服務只綁 127.0.0.1；寫入須帶同源服務憑證，只接受最多 4 MiB JSON，拒絕路徑跳脫、絕對路徑與符號連結。Godot 等鎖最多 45 秒、驗證最多 90 秒；未完成會保留草稿並顯示重試原因。
- 若連線在送出後中斷，畫面保留未儲存狀態；先匯出，再確認專案檔是否已寫入。重試若收到衝突，重新開啟專案版本比較。

## 草稿、下載與儲存確認

修改時會把整份故事、座標與原始來源快照存為瀏覽器草稿，與專案檔案分開。重新整理或重新開啟同名同 ID 的故事時，側欄會顯示「復原草稿／刪除草稿」，不會自動蓋掉剛開啟的來源。來源已變動會額外提醒；復原前可先匯出目前版本。未指定 `?story=` 時會找上次的本機／新故事草稿；草稿不跨瀏覽器或裝置。

- **匯出 JSON**：送出下載後仍顯示「未確認儲存」。瀏覽器無法證明下載已成功寫入磁碟。
- **確認下載檔…**：選回剛下載的 JSON，比對內容完全一致後才解除未儲存／離頁提醒。選錯檔、讀檔失敗或下載期間又修改，都保留未儲存狀態。比對不會替你寫入專案或執行 check_story。
- 確認成功且沒有後續修改時，清除本份未儲存草稿。座標另存 localStorage；要跨機保存仍需匯出座標。
- 空間不足／儲存被封鎖／草稿損壞會持續顯示錯誤，記憶體中的修改仍可匯出；成功重試後才清除儲存錯誤。損壞草稿不自動覆寫，可明確確認後刪除。
- 另一分頁變更同份草稿時，本頁停止覆寫並持續提示；請先匯出本頁版本，再重新開啟以決定復原哪一份。仍待處理的舊草稿不會被新的編輯默默覆蓋。
- Undo 歷史最多保留 80 個狀態，只在此頁生命週期內有效；切故事會重設。草稿復原後從該草稿建立新歷史。
- 快速切故事／開檔只採用最後啟動的讀取；讀取失敗保留目前故事與錯誤提示。

## 下載後的 check_story 檢查

本機服務會自動執行這一步。使用下載流程時，編輯器**不算** `version`（那是存檔位置的結構雜湊，只有 `check_story.gd` 用 `StoryBuilder.fingerprint()` 算）。沒改過的故事原樣寫回；改過的故事匯出時 `version` 是 `s-unset`，所以忘了這一步時，舊存檔會被安全地拒絕，不會還原到錯位的步驟。匯出的檔案放進 `data/`（或任何路徑）後：

```bash
godot --headless --path prototypes/debt-commission \
  --script res://tools/story_editor/check_story.gd -- data/my_story.json --write
```

- 做三件事：`StoryRunner.load_story()`（遊戲跑的同一套驗證，會查角色、素材、表情、旗標…）；每個節點都從 `entry` 到得了（`story_builder.gd` 的檢查）；`version` 等於 `StoryBuilder.fingerprint()`。
- 全過印 `OK` 並結束 0；否則逐條印 `ERROR …`、結束 1。沒加 `--write` 時**絕不改檔**，`version` 過期只回報。
- `--write` 只在前兩項都過時才會重寫：把 `version` 改對，並用建置的格式寫回（鍵排序）。
- 路徑相對於專案；絕對路徑照用。

編輯器自己只檢查結構（連線、到不了、`next` 規則）；素材 id、旗標、表情寫對沒有，以 check_story 為準。

## 作品（故事包）

本機專案服務會列出 `stories/*/pack.json` 的作品，故事選單裡每部作品一個分組（依資料夾名排序，與遊戲相同）。作品的故事讀自己的 `catalog.json`：相對路徑以作品資料夾為準，`extends` 先鋪上被繼承的 catalog，所以角色、表情、背景縮圖與封面選單都是那部作品的；`data/` 的故事仍用 `data/asset_catalog.json`。

- **新作品**：輸入作品 id（英文小寫、數字、底線）與名稱，服務建立 `stories/<id>/`，內含 `pack.json`、只有「主角」與一張漸層背景的 `catalog.json`、空的 `art/`，並開好第一章 `<id>_ch1`。按「驗證並存檔」後第一章登記進 `pack.json`（`kind` 為 `chapter`）。
- **新故事**：有作品時會先問放在哪個作品，留空就是 `data/`。
- **存回**：作品的故事存成 `stories/<作品>/<id>_story.json`，以作品的 catalog 驗證；新故事、外觀與封面寫進該作品的 `pack.json`（只寫 `id`、`kind`、`path`、`authoring` 與選填的 `skin`、`cover`；存檔位置、作品名由遊戲推導），不動 `data/stories.json`。外觀包選單的「預設」是作品的 `skin`。
- 故事 id 在所有作品與 `data/` 之間不能重複；轉成圖編輯來源時，作品的故事複製在同一個作品資料夾。
- 角色、背景、線索、音效、音樂與授權用「素材設定」改（見下節），不用手改 `catalog.json`。

## 素材設定

工具列「素材設定」開啟目前故事的素材設定檔：作品的故事開 `stories/<作品>/catalog.json`，`data/` 的故事開 `data/asset_catalog.json`。需要本機專案服務。

- 分頁：角色、背景、線索、音效、音樂；「＋新增」輸入 id（英文小寫、數字、底線）與顯示名稱。每一筆可以改名稱、名牌顏色、預設站位、打字音高、人物檔案、漸層色，從資料夾裡的圖選立繪、表情、背景圖、線索圖（有預覽），以及授權（作者、來源、授權、主編核准；作者會自動進製作名單）。還沒有圖或缺授權的會標出來。
- 圖要先放進資料夾：作品放在作品資料夾裡（例如 `art/`），本作放在 `assets/`。選單只列那個資料夾的圖與音檔；作品寫成相對路徑。
- 作品的 catalog 有 `extends` 時，繼承來的項目只列出 id，唯讀。
- **驗證並存檔**：用遊戲的規則檢查這份設定，以及每個讀它的故事（改 `data/asset_catalog.json` 時也包含 `extends` 它的作品）。劇本還在用的角色或背景被刪掉、欄位不合法、或檔案在開啟後被別人改過，都不會存，錯誤會列出是哪個故事。沒改的欄位與頁面不認得的欄位原樣保留。

## 缺圖標記

場景卡標題列的「缺圖 N」：這一場用到、還沒有圖的背景（漸層）、角色（剪影）與表情，滑鼠停在上面看清單。規則與投稿檢查相同（含遊戲自己換的臉：吐槽回合說話者的 annoyed、POV 選項時的 thinking；純色背景不算），素材設定存檔後立刻更新。

## 讓遊戲讀到新故事

在 `data/stories.json` 的 `stories` 陣列加一筆，順序就是章節選擇的順序：

```json
{ "id": "my_story", "kind": "sample", "path": "res://data/my_story.json", "save": "user://my_story.save", "authoring": "graph" }
```

`kind` 是 `chapter`（本篇，前一章有結算紀錄才開放）或 `sample`（試玩片段，一直開放）。「新故事」建出來的空白故事 `version` 是 `s-unset`，一定要先跑上面的 `--write`。

## 檔案與座標

- **匯出格式**同建置輸出（Godot `JSON.stringify(story, "  ", true)`：鍵排序、2 空格縮排、整數值寫成 `8.0`）。建置產生的檔案匯入後不改再匯出是 byte-equal；`debt`、`phase2`、`phase3` 三個手寫排版的檔（步驟物件寫在同一行）只能資料相等，匯出會變成標準格式。
- **`generated_from`**：是 `story_src` 建置的唯讀故事；修改來源檔後重新建置，或建立新 ID 的圖編輯副本。
- **卡片座標與收合狀態不進劇本 JSON**：存在瀏覽器的 localStorage（鍵 `debtStoryEditor.layout.<story id>`；每個 node 的 x、y 與 expanded 群組表），也可「匯出座標」下載 `<id>.layout.json`、「匯入座標」讀回（換電腦、進版控）。沒有座標的節點自動排版。

## 測試

```bash
node tools/story_editor/test_core.mjs --out <暫存資料夾>      # 10 個故事往返、可達性對照 Godot（每個節點當起點）、改名、新故事
node tools/story_editor/smoke.mjs --playwright <playwright-core 目錄> --chromium <chrome-headless-shell> \
     --godot godot --out <輸出資料夾>                            # 真的滑鼠拖線、匯出下載、截圖、file:// 檔案選擇器
node tools/story_editor/comedy_side_smoke.mjs --playwright <playwright-core 目錄> --chromium <Chrome 路徑> \
     --godot godot                                               # 漫畫格左右選擇、清除、驗證存檔與重開
node tools/story_editor/portrait_motion_smoke.mjs --playwright <playwright-core 目錄> --chromium <Chrome 路徑> \
     --godot godot                                               # 角色登退場與立繪動作的編輯、存檔與重開
```

新增回歸涵蓋 undo/redo（新增、刪除、改名、接線、拖動與合併文字）、草稿重整復原、下載內容確認、搜尋跳轉、讀檔失敗、空間不足、跨分頁衝突與快速切故事；`batch1_regression.mjs` 由 smoke 自動執行。

不需要在專案裡安裝套件：`--playwright` 指向現有的 playwright-core。

## 限制

- 作品清單、「新作品」與存回作品需要本機專案服務；靜態服務列不了資料夾，只列 `data/stories.json`。
- 下載檔比對確認只表示磁碟檔內容與匯出相同；存回專案請使用本機專案服務。未確認儲存時關頁面會提醒。
- 調查、吐槽回合、result 等大型 op 與舊版指令用 JSON 框編輯。
- 吐槽回合可能有數十條出線，卡片仍會很高；放大、搜尋定位或調整卡片位置。
- 編輯器認 `goto` op 的 `target`；`story_builder.gd` 的可達性把任何步驟的 `target` 都當連線，所以兩者只會在「節點 id 剛好等於舞台標記或角色 id」時不同。

場景檢視回歸由 smoke 自動執行 `scene_regression.mjs`：chapter1 96 張場景卡、有效背景解碼、唯讀與轉副本、收合的 sidecar／localStorage 往返、轉出編輯與下載 registry、音樂播放器互斥、240 節點及未改卡片 DOM 保留。`test_core.mjs` 另測分類、分支合流、停止／未設定音樂、循環與轉來源隔離。

與 Claude 共用工作樹時，使用 `run_coordinated.py` 包住會啟動 Godot 的測試；它為子程序提供暫存 HOME；設定 `GODOT_LOCK` 為共用鎖檔的絕對路徑時，以排他建立方式取得執行權，結束後釋放。沒設 `GODOT_LOCK` 時只隔離 HOME、不建立鎖。這次與 Claude 協作須設定為 `/Users/peter/repo/godot/godogen/.claude/tasks/debt-commission-polish/godot.lock`。效能可用 `measure_scene.mjs --playwright <目錄> --chromium <路徑> --out <json>` 重測；量測包含冷頁開啟、20 次滑鼠拖動輸入、一次同步欄位變更。

步驟名稱以中文呈現，op 是次要標記。立繪收合群組會列出角色名；新增／刪除或調整分類順序時，清除該場景的收合狀態，避免索引錯位；復原操作會還原原本的版面狀態。

本機服務回歸（在專案根目錄；Godot 實跑前須依協作設定 GODOT_LOCK）：

```bash
python3 tools/story_editor/test_project_server.py
node tools/story_editor/project_smoke.mjs --playwright <playwright-core 目錄> --chromium <Chrome 路徑> --out <輸出資料夾>
```

第一支使用暫存 data 與遊戲實際的 Godot validator，檢查成功寫入／版本、衝突、建置產物拒絕、路徑與請求限制、失敗候選保留、新故事登記與 registry 寫入失敗。第二支依派工驗收暫時修改 phase3，實跑存檔、check_story、遊戲的 test_phase3_story、並行輸入與衝突截圖，finally 還原原始 bytes 並確認 diff 空白；它要求先設定 GODOT_LOCK。

外觀包回歸使用暫存專案，不修改正式 data：

```bash
node tools/story_editor/skin_smoke.mjs --playwright <playwright-core 目錄> --chromium <Chrome 路徑> --out <輸出資料夾>
```

此測試涵蓋目錄與靜態外觀清單、唯讀故事的外觀存回、轉副本保留未知欄位、default_pov／credits、voice_pitch 及兩份下載確認。

作品回歸（同樣使用暫存專案）：

```bash
node tools/story_editor/pack_smoke.mjs --playwright <playwright-core 目錄> --chromium <Chrome 路徑> --out <輸出資料夾>
```

涵蓋作品分組、作品 catalog（相對路徑）、作品故事的存回與 pack.json 封面、「新作品」建立資料夾並存回第一章、新故事放進作品，以及回到 `data/` 故事時換回遊戲 catalog。服務與此測試內部自行取得 GODOT_LOCK；不要再包一層 run_coordinated.py，以免重複等自己的鎖。

場景試玩回歸（暫存專案與 headless Godot）：

```bash
node tools/story_editor/preview_smoke.mjs --playwright <playwright-core 目錄> --chromium <Chrome 路徑> --out <輸出資料夾>
```

這項測試由瀏覽器拖曳立繪選站位，檢查按鈕及復原／重做，再以未存稿、旗標和線索啟動遊戲；也檢查啟動期間切換場景、失敗提示及唯讀故事。另從空白建立三結局故事、存檔，再用遊戲的 StoryRunner 走完三條分支。`test_project_server.py` 另驗證遊戲實際收到的狀態、獨立 user://、作品素材與外觀。

人格參考回歸（全部確認紀錄只在暫存 fixture，不改正式資料）：

```bash
python3 tools/test_persona_context.py
python3 tools/story_editor/test_persona_service.py
node tools/story_editor/persona_smoke.mjs --playwright <playwright-core 目錄> --chromium <Chrome 路徑> --out <暫存證據目錄>
```

API 回歸不需要 Godot；瀏覽器回歸使用暫存專案、合成確認證據，檢查 UI 產物與 CLI 一致、未確認阻擋、記憶擁有者／知情隔離、版本更新、下載、窄視窗及故事不被改動。
