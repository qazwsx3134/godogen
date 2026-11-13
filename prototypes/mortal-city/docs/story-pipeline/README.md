# 劇情委託的寫作與審查流程

讓其他 AI（Claude、Codex 都可以）依這個原型寫劇情委託，先過機器檢查，再交給另一個 AI 審查，最後由作者在遊戲裡讀全文、判斷合不合理、用字與邏輯過不過。

```
寫手 AI ──► story-drafts/<id>.json ──► pnpm story:check ──► 審查員 AI ──► story-drafts/<id>.review.md
 (WRITER-BRIEF.md)                     (0 個錯誤才往下)    (REVIEWER-BRIEF.md，獨立、只判不修)
                                                                              │
作者：遊戲「紀錄 → 劇情總覽 → 草稿」讀全文＋機器檢查＋審查報告 ◄──────────────┘
      └► 要修：把審查報告與自己的意見交回寫手，重跑一輪
      └► 收下：照草稿改寫進 src/content/cases*.ts，接到街區（目前手動）
```

## 三道關卡

| 關卡 | 誰 | 看什麼 | 產出 |
|---|---|---|---|
| 1. 寫 | 寫手 AI，照 [WRITER-BRIEF.md](WRITER-BRIEF.md) | 世界觀、機制限制、場面模板、用語 | `story-drafts/<id>.json`、`story-drafts/<id>.writer.md`（10 行內的設計說明） |
| 2. 機器檢查 | `pnpm story:check`（規則在 `src/content/storyCheck.ts`） | 遊戲讀不讀得懂、會不會卡住、禁用詞、字數 | 終端機輸出；遊戲的草稿分頁也會即時顯示 |
| 3. 審查 | 另一個 AI，照 [REVIEWER-BRIEF.md](REVIEWER-BRIEF.md)；沒看過寫作過程 | 選項文字與欄位對不對得上、邏輯、世界觀、用字 | `story-drafts/<id>.review.md`（結論＋逐條 PASS／FAIL） |
| 4. 作者讀 | 你 | 好不好看、合不合理 | 收下、退回或改寫 |

## 指令

```bash
cd prototypes/mortal-city
pnpm story:check                              # 檢查 story-drafts/ 底下全部
pnpm story:check story-drafts/D-xxx.json      # 檢查一份
pnpm dev                                      # 開遊戲：紀錄 → 測試工具「劇情總覽」→「草稿」分頁
```

- 機器檢查的規則改了，`pnpm test` 會確認既有的 5 件案子（含測試案）仍然沒有錯誤；誤判代表規則寫錯，不是內容錯。
- `story-drafts/` 裡的草稿不會進 `pnpm test`，寫到一半不會讓測試變紅。

## 檔案

- `WRITER-BRIEF.md`：寫手派工單（自成一份，Codex 也能讀）。
- `REVIEWER-BRIEF.md`：審查員派工單與評分表。
- `example-P01-01.json`：01「終電包裹」匯出成 JSON，格式範例。
- `src/content/storyCheck.ts`：機器檢查；`src/content/drafts.ts`：遊戲讀草稿與審查報告；`scripts/story-check.ts`：命令列。

## 派工方式（Herdr）

依專案 `CLAUDE.md`：先寫、後審，依序開，不同時開。派工內容就是對應的 BRIEF 檔，`agent prompt` 只叫它讀檔並給參數（草稿 id、街區、中間人、題材）。完成訊號是指定的報告檔出現（寫手：`<id>.writer.md`；審查員：`<id>.review.md`），不是 agent 的狀態。
