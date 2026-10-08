# 美術進度（2026-10-08 收工時）

## 已定案
| 素材 | 核准檔 | 備註 |
|---|---|---|
| 男主角 | `heroes/man/master-green/master.json`（來源 `man/edit-02.png`） | 綠幕 key（紅領帶偏洋紅） |
| 女主角 | `heroes/woman/master-green/master.json`（來源 `woman/edit-01.png`） | 綠幕 key；眼睛仍有虹膜，使用者選定照用 |

`heroes/man/master/` 是沒用到的洋紅版，可刪。

## 候選待選（Codex 第四輪，派工單 `BRIEF-assets.md`）

候選目前在 Codex 的工作區，**還沒複製進專案**：
`~/repo/agent-sprite-forge/.forge/survivor-assets-20261008-r2/<類別>/<名稱>/candidates-contact.png`

| 素材 | 張數 | Claude 建議 | 看到的問題 |
|---|---|---|---|
| 抽菸者 smoker | 3 | **01**（輪廓最飽滿，小尺寸好認） | 03 偏暖褐，和背景對比弱 |
| 臭臭胖子 fatty | 3 | **02**（得意表情最明顯） | 三張都叼菸（提示詞沒要求），和抽菸者主題重疊；選定後可用 edit 拿掉 |
| 機車 motorcycle（朝右下） | 3 | **02**（臉清楚、車身乾淨） | 三張差異小；03 低頭看不到表情 |
| 汽車 car（朝右下） | 3 | **03**（最厚重、保險桿誇張、駕駛不耐煩） | 01 車身偏輕，不像比機車重 |
| 夜市背景 street_block | 3 | **02**（方格地磚對齊畫面，中央空） | 01 地磚是斜菱形格（違反提示詞）；尺寸 948×1659／979×1606 都不是 5:7，接入時要裁或縮 |

## 進行中（出門時的狀態）
- 階段二圖示（11 個，每個 2 張）生成中：Codex 的子 agent `wt-icons`（`wT:pJ`）在做，17:58 時 coin、firecracker、gem 已有候選。
- 出門時（17:59）三個 Codex pane 都還在跑：主控 `wT:pE`、`wt-assets`（`wT:pH`）、`wt-icons`（`wT:pJ`）。走 Codex 登入額度，不扣 API 費用。
- 階段一報告 `ASSETS-REPORT-1.md` 還沒寫（舊的失敗版改名為 `ASSETS-REPORT-1.blocked.md`）；`ASSETS-REPORT-2.md` 是第一次失敗時留下的舊檔。

## 回來後
1. 到 `wT:pE` 按核准讓 Codex 跑完；它會寫 `ASSETS-REPORT-1.md`、`ASSETS-REPORT-2.md`，並把候選複製進 `art_src/`。想少按幾次：在 Codex 輸入 `/approvals` 放寬。
2. 看上表，選每項要哪張（或要 edit 什麼，例如胖子拿掉菸）。
3. 選定後：Claude 用 `master_still.py approve` 核准角色與交通工具；交通工具再派 Codex 做其餘 4 個方向（s、e、ne、n），以核准圖當 identity 參考。
4. 動畫／影片暫停中，等靜態圖都定案再做（`heroes/MANUAL-VIDEO.md`、`heroes/man/set/` 保留可續用）。

## 環境備忘
- 生圖一律 `--route codex-cli`：config 裡的 API key（Gemini、OpenAI 無效；xAI 沒額度；BytePlus、fal 無效）會讓預設路由失敗。BytePlus 有兩筆「送出結果不明」（clientRequestId `6f5394908dc249518ad1f0a9d1aae991` 等），可到後台確認有無扣款。
- 流程說明：skill `character-sprite-forge`（`prototypes/godot-kit/skills/character-sprite-forge/`）。
