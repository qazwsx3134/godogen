# 多人合作指南：文本、美術、主編

給一起做同一部視覺小說的人。假設大家**在不同地方、用 GitHub 同步**，文本與美術用 **GitHub Desktop**（不用打 git 指令），電腦是 Windows 或 macOS。

## 誰負責什麼檔案

一部作品就是 `stories/<作品>/` 一個資料夾（本作是 `data/` 與 `assets/`）。每個人只改自己那一欄的檔案，合併時就幾乎不會衝突。

| 檔案 | 誰改 | 內容 |
|---|---|---|
| `stories/<作品>/*_story.json`、`*.dialogue`、`*.blocks.json` | 文本 | 劇本、選項、旗標、調查點、吐槽回合 |
| `stories/<作品>/art/`（圖與 Godot 產生的 `.import`） | 美術 | 背景、立繪、表情、線索圖 |
| `stories/<作品>/catalog.json` | 美術（文本要新角色、背景時，請美術或主編加 id） | 角色、表情、背景、素材、音樂的 id、名稱、圖檔路徑與 `license` |
| `stories/<作品>/pack.json` | 主編 | 作品名、章節順序、封面、外觀包、署名 |
| `skins/<外觀>/` | 美術／UI | 配色、介面用語 |

例外：文本在編輯器存新故事、或在 Godot 第一次建置作品裡的 `.dialogue`，會自動在 `pack.json` 最後加一列（本篇章節）；順序與其他欄位仍由主編調整。

`catalog.json` 是文本與美術的**約定表**：角色 id、表情名、背景 id 先一起定好，文本照著寫，美術照著畫。最容易衝突的就是 `catalog.json` 與 `pack.json`，所以各只由一個人負責。

## 流程

```
① 開案（主編＋大家）
   編輯器「新作品」→ 在 catalog.json 定好角色 id、表情名、背景 id
   （先只寫名字與漸層色，還不用圖）
        │
   ┌────┴─────────────────────┐
   ↓                          ↓
② 文本                       ③ 美術
   在編輯器寫劇本、存檔          跑「作品：投稿檢查」拿到待辦清單
   沒圖的背景是漸層、            照 ART-SPEC.md 畫圖，放進 art/
   沒圖的角色是剪影，            catalog.json 補 path 與 license
   照樣能試玩                   交稿前再跑一次投稿檢查
   └────┬─────────────────────┘
        ↓
④ 整合（主編，每週）
   合併 → 投稿檢查 0 錯誤 → 匯出網頁版
        ↓
⑤ 試玩：網頁連結給大家玩，意見回到 ② ③
```

- **先灰盒、後精修。** 只改台詞文字，玩家的舊存檔照常能讀；增刪節點、改連線、改選項，這一章的舊存檔就會失效。流程在灰盒試玩時定案，之後只修文字。
- **美術的工作清單就是投稿檢查報告的「美術待辦」**，附尺寸、檔名與用在哪一場。

## 第一次準備

每個人都要：

1. 安裝 **Godot 4.7** 標準版與 **GitHub Desktop**，用 GitHub Desktop 把專案 clone 下來（主編先把大家加成 repo 的協作者）。
2. Godot 專案管理員按「匯入」，選 `prototypes/debt-commission/project.godot`。第一次打開會匯入所有圖，等它跑完。

文本另外要開**劇本節點編輯器的本機服務**（存檔時用遊戲的規則驗證，壞掉的劇本存不進去）。需要 Python 3.10 以上。在 `prototypes/debt-commission` 資料夾開終端機：

```bash
# macOS
python3 tools/story_editor/project_server.py --port 8000 --godot /Applications/Godot.app/Contents/MacOS/Godot
```

```powershell
# Windows（PowerShell；Godot 路徑換成你放 Godot.exe 的位置）
py tools\story_editor\project_server.py --port 8000 --godot "C:\Godot\Godot_v4.7-stable_win64.exe"
```

再用瀏覽器開 `http://127.0.0.1:8000/tools/story_editor/`。操作見 [STORY-EDITOR.md](STORY-EDITOR.md)「作品」。（Windows 的啟動指令目前沒有在 Windows 上實測過，遇到問題請告訴主編。）

美術只需要 Godot：投稿檢查在「專案 → 工具 → 作品：投稿檢查」，做法見 [ART-SPEC.md](ART-SPEC.md)「投稿檢查」。

## 用 GitHub Desktop 同步

```
開始工作前：Fetch origin → Pull
   ↓
換到自己的分支（一章一個，例如 ch2-text、ch2-art）
   ↓
做事 → 存檔
   ↓
Commit（寫一句做了什麼）→ Push
   ↓
完成一段：在 GitHub 開 Pull Request，主編合併
```

- **一章一個分支**，名稱帶上章節與工作（`ch2-text`、`ch2-art`）。人少時大家都在 `main` 上、勤 Pull 也可以。
- **圖要連同 `.import` 一起提交**（Godot 自動產生，在圖旁邊）。
- **不要提交** `build/`（投稿檢查報告、網頁版）與 `.godot/`：已在 `.gitignore`。
- **大檔案**：GitHub 單一檔案上限 100 MB。圖或音樂原稿很大時，原稿放 `art_src/` 以外的地方（雲端硬碟），只提交遊戲用的版本；整批推送失敗（HTTP 400）時，請主編處理。
- **衝突**：GitHub Desktop 說有衝突時不要自己硬選，把檔名告訴負責那個檔案的人（見上表）。

## 交稿檢查清單

文本：
- [ ] 編輯器「驗證並存檔」成功（沒有紅色問題）
- [ ] 新角色、新背景已請美術或主編加進 `catalog.json`
- [ ] 在遊戲裡從頭玩過一次（章節選擇裡就看得到作品）

美術：
- [ ] 投稿檢查 0 錯誤，負責的「美術待辦」都清掉
- [ ] 每張圖的 catalog 那一筆都有 `license`（作者會自動進製作名單）
- [ ] 圖與 `.import` 都提交了

主編（每週）：
- [ ] 合併各分支，投稿檢查 0 錯誤
- [ ] 匯出網頁版、更新試玩連結（見 README「開發與 Web 匯出」）
- [ ] 確認 `license` 的 `approved`、`pack.json` 的署名
