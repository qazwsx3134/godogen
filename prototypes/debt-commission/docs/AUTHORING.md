# 編劇指南：不寫程式也能新增、修改劇情

這份給負責劇情的人。你會在 Godot 編輯器裡用 **Parley**（拖曳節點、拉線的流程圖）寫劇情，按一個選單就能建置並試玩，不需要打任何指令或改程式。

## 一、第一次準備

1. 安裝 **Godot 4.7**（Windows 版，標準版即可，不需要 .NET 版）。
2. 打開 Godot，在專案管理員按「匯入」（Import），選這個檔：
   `D:\repo\godot\godogen\prototypes\debt-commission\project.godot`
3. 專案打開後，畫面最上方中間有一排分頁：2D、3D、Script、AssetLib……旁邊多了 **Parley**（流程圖）、**Dialogue**（文字寫法）與 **Puzzles**（解謎規劃）。

角色清單已經建好：新八、銀時、登勢、神樂、定春。寫台詞時直接從清單選。

## 二、打開或新增一個故事

- **打開現有故事**：點 Parley 分頁，左上的選單選 **Open Dialogue Sequence…**，打開 `story_src` 資料夾裡的 `.ds` 檔。`story_src/phase4.ds` 是完整範例，建議先打開來對照著看。
- **新增故事**：同一個選單選 **New Dialogue Sequence…**，存到 `story_src` 資料夾。檔名就是故事代號，用英文小寫加底線，例如 `chapter1.ds`。

## 三、怎麼畫

**先記住一條規則：一個框（Group）就是一段劇情。**

框的 Name 是這段劇情的代號，用英文小寫加底線，例如 `ask_first`，同一個故事裡不能重複。存檔會記住玩家停在哪個框，所以框要取好名字，之後不要隨便改。

| 想做的事 | 怎麼畫 |
|---|---|
| 故事從哪開始 | 從 **Start** 節點拉一條線，連到第一個框裡最上面的節點 |
| 一句台詞 | **Dialogue** 節點：Character 選說話的人，Text 填台詞。Character 不選就是旁白 |
| 讓玩家做選擇 | 先放一個**旁白**的 Dialogue 當問題，再從它拉線到幾個 **Dialogue Option**。每個選項的翻譯代號欄按「產生」鈕（或自己填英文代號），選項之後連到下一個框 |
| 選了某個選項就記下來 | 在選項和下一個框之間放 **Action**，說明欄填 `set asked = "kagura"` |
| 有某個素材才出現的選項 | 在問題和選項之間放 **Condition**，說明欄填 `has("milk_bottle")`，只接它的 **true** 出口 |
| 依照之前的選擇走不同路 | **Condition** 說明欄填 `asked == "kagura"`，**true** 出口連一個框，**false** 出口連另一個框 |
| 換背景、角色登場、給素材、結束 | **Action** 節點的說明欄寫一行指令（見下表） |
| 這段結束後接下一段 | 從這個框最後一個節點拉線，連到下一個框最上面的節點 |

### Action 指令表

說明欄一次寫一行，英文、引號、括號都要照抄：

| 指令 | 作用 |
|---|---|
| `bg("yorozuya_living_room")` | 換背景 |
| `char("kagura", "smile", "left")` | 角色登場。表情：`neutral` `smile` `annoyed` `surprised` `thinking`；位置：`left` `center` `right`。只寫 `char("kagura")` 就用預設 |
| `hide("kagura")` | 角色退場 |
| `item("milk_bottle")` | 取得素材 |
| `profile("kagura")` | 解鎖人物檔案 |
| `set asked = "kagura"` | 記下一個狀態，之後可以用 Condition 判斷 |
| `end("結尾文字")` | 故事結束。後面可以再接 End 節點，也可以不接 |
| `investigate("…")`、`boke_round("…")` | 調查、吐槽回合。熱區位置、吐槽選項這些參數寫在同名的 `.blocks.json` 檔裡，請照 `phase4.blocks.json` 的範例改，或請工程師幫忙 |

目前可以用的代號：

- 背景：`yorozuya_living_room`（客廳）、`yorozuya_kitchen`（廚房）、`yorozuya_exterior`（店門口）
- 角色：`shinpachi`、`gintoki`、`otose`、`kagura`、`sadaharu`
- 素材：`milk_bottle`、`milk_trace`、`kagura_kombu`、`sadaharu_footprint`、`debt_commission_letter`

要加新角色、背景或素材，請工程師先加進 `data/asset_catalog.json`。

## 四、建置並試玩

1. 在 Parley 按**存檔**（或 Ctrl+S）。
2. 在左下的「**檔案系統**」（FileSystem）面板，點一下你的 `.ds` 檔。
3. 上方選單 **專案（Project）→ 工具（Tools）→ 劇本：建置並試玩**。

**成功**時會開出遊戲視窗，從標題畫面開始玩你的故事。試玩有自己的存檔，不會動到正式存檔。

**有問題**時會跳出視窗，說明哪個框的第幾步出錯，遊戲資料不會被改掉。

只想檢查、不想開遊戲，就選「**劇本：建置選取的檔案**」。

> Parley 自己也有一個「Test」按鈕，那是 Parley 內建的播放器，不是我們的遊戲，請用上面的選單試玩。

## 五、常見錯誤訊息

| 訊息裡的關鍵字 | 意思與修正 |
|---|---|
| `unknown speaker` | 說話的人不在角色清單裡，重新從清單選 |
| `needs a text_translation_key` | 有選項還沒有代號，按翻譯代號旁的「產生」鈕 |
| `must be narration` | 選項前面那句是問題，要設成旁白，Character 不選 |
| `unsupported do …` | Action 說明欄的指令打錯，對照指令表 |
| `is not inside a group` | 有節點沒放進任何框，把它拖進框裡 |
| `must connect to the first node of group` | 連到別的框時，要連到那個框最上面的節點 |
| `unreachable from` | 有框永遠走不到，檢查是不是少連一條線 |
| `not connected to the group's chain` | 框裡有節點沒被連到 |
| `needs exactly one outgoing edge` | 這個節點要剛好接一條線往下（選項和 Condition 除外） |
| `unknown block` | `investigate("…")`／`boke_round("…")` 裡的名稱，在 `.blocks.json` 找不到 |

## 六、改完之後

- 建置成功會更新 `data/` 裡的遊戲資料。請把 `story_src` 和 `data` 裡改過的檔案交給工程師提交（commit），或用 GitHub Desktop 提交。
- **存檔相容性**：只改台詞文字，玩家的舊存檔照常能讀；增刪節點、改連線或改選項代號，這個故事的舊存檔就會失效。試玩期間不用在意，正式上線後改流程要先跟工程師確認。

## 七、其他工具

- **Dialogue 分頁（文字寫法）**：習慣像寫劇本一樣打字的人，可以改用 `.dialogue` 檔，範例是 `story_src/phase4.dialogue`，建置與試玩用同一個選單。兩種寫法效果完全相同，同一個故事選一種寫就好。
- **Puzzles 分頁（解謎規劃）**：畫「哪條線索解開哪個謎題」的依賴圖，只用來規劃，不會影響遊戲。

## 目前的限制

- 新故事試玩時，眼鏡與吐槽力的狀態列、素材按鈕和 Game Over 的重試按鈕還不會出現，目前只有 Phase 3 的技術試片有。工程師會一併處理（見 `docs/story-telling-game/STATUS.md`）。
- 吐槽回合結束後走到哪個框，是寫在 `.blocks.json` 裡的，所以流程圖上的吐槽回合節點不用往外接線。
