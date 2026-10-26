# Azeroth Idle（azerothidle.com）研究

- 日期：2026-10-26
- 方法：讀網站公開的前端原始碼（`index.html` 列出的 259 支 JS，註解很多）。沒有實際登入遊玩。
- 標記：**[原始碼]**＝前端註解或程式直接寫的；**[推論]**＝從通訊協定反推的伺服器行為（伺服器沒有公開）。
- 原始碼是第三方作品，不放進 repo；下次要查就重新下載（見文末）。

## 一句話

不是一般用計時器堆出來的放置遊戲，而是**真的魔獸世界 1.x（vanilla）伺服器**：英雄是伺服器上由 AI 操作的真角色，24 小時在真地圖上自己走、打怪、解任務。玩家用 **Rust 寫、編成 WASM 的魔獸客戶端**連進去，上面疊一層 JS 介面；玩家的身份是「經理」，只設策略、做決定，不親手操作。

## 架構

```
┌──────────── 瀏覽器 ─────────────────────────────┐
│ index.html（靜態外殼，載入前不會黑畫面）          │
│  ├ boot.js：下載約 15 MB 的 wasm（brotli 壓縮），  │
│  │   同時預先抓遊戲資料 /data/*                    │
│  ├ benilla wasm（Rust 魔獸客戶端：讀原版模型、     │
│  │   地圖，還跑原版的 Lua/FrameXML 介面）          │
│  │   └ 每幀呼叫 window.__wenilla_bridge            │
│  └ idle/*.js 介面層（背包、策略、決策收件匣、      │
│      英雄面板）                                    │
│      protocol.js → model.js（純 reducer）→ ui.js  │
└──────────┬──────────────────────────────────────┘
           │ 魔獸原生連線（wenilla-realm）
           │ 下指令：聊天輸入 `.azi start grind:…`
           │ 回資料：CHAT_MSG_ADDON，前綴 AZI，JSON 切成
           │         每塊 ≤240 bytes：`id|i/n|chunk`
┌──────────┴──────────────────────────────────────┐
│ azeroth-idle-server（類 vmangos 的 vanilla 伺服器）│
│  └ 英雄由伺服器端 AI 操作：練功點、任務、跑腿、     │
│    隊伍／副本、拍賣場、懸賞                         │
│    → 下線之後照常在玩                               │
└─────────────────────────────────────────────────┘
```

- **[原始碼]** `boot.js`：wasm 約 15 MB（brotli），下載時用計數 stream 顯示真實進度；平行預抓 `boot-manifest.json` 列出的開機資料，把「~100 次同步 XHR」變成只剩解析成本。`/data/*` 設成 immutable（max-age=1y）。
- **[原始碼]** `bridge.js`：wasm 每幀讀 `window.__wenilla_bridge`，呼叫 `onFrame(snapshot)`／`onEvent(name, payload)` 並取走指令佇列。
- **[原始碼]** `main.js`：介面層只透過客戶端跟伺服器講話——指令是聊天行 `wenilla.chat('.azi …')`，回覆是 `CHAT_MSG_ADDON`（前綴 AZI）。
- **[原始碼]** `protocol.js`：一則 JSON 訊息切成多塊 `<id>|<i>/<n>|<chunk>`（每塊 ≤240 bytes），介面端依 id 組回。
- **[原始碼]** `handoff.js`：三種模式——dev（網址帶帳密）、launched（啟動器把選擇存在 sessionStorage）、launcher（顯示開始畫面，不載 wasm）。

## 放置怎麼運作

- **不需要離線補算 [推論＋原始碼註解]**：註解寫「the hero keeps playing on the server」「The hero keeps working offline」。英雄本來就在伺服器上一直玩，所以沒有「離線 N 秒 → 一次算完」的公式；回來時的「While you were away」只是把這段時間的事件列出來。
- **背景分頁 [原始碼]** `bridge.js`：分頁隱藏後瀏覽器停掉 rAF、把計時器降到 1 秒一次（5 分鐘後 1 分鐘一次），所以改用 Worker 以 4 Hz 叫醒 wasm 跑一次 update（每次約 11 ms CPU），聊天、死亡、升級和桌面通知才會繼續。
- **數值來源 [原始碼]** `mock.js`：練功點、怪物、掉落機率、任務獎勵、經驗曲線都是真的 vanilla 資料（content pack／vmangos）；只有走路時間、距離和任務步驟是自己調的節奏。

## 遊戲機制（值得借的部分）

| 系統 | 內容 | 來源檔 |
|---|---|---|
| 策略 Policies | 血量多低逃跑、坐下吃東西的門檻與何時站起來、技能輪替（只放可施放的技能）、目標優先順序、職業專屬設定（獵人、德魯伊……） | `policy-con.js`、`combat-prio.js`、`policy-class.js` |
| 「不近戰」 | 法杖職業可勾選不近戰，預設關 | `never-melee.js` |
| 活動範圍 | 指定在哪些區域解任務、採集或釣魚；路過商人時順便賣東西 | `activity-policy.js` |
| 決策收件匣 | 一般事件是通知（學到技能、自動撤退、死亡摘要）；**選任務獎勵、要不要學某個專業、隊伍邀請**等英雄絕不自己決定，永不過期。通知可依天數／種類分組、靜音、過期 | `inbox.js` |
| 跑腿 errand | 英雄去做不是主活動的事（找訓練師、買賣、修裝、回旅店、跑屍體、飛行點、銀行、郵箱……），畫面寫出要做什麼、在哪、為什麼、還要多久，可按「停止」 | `errand.js` |
| 行動佇列＋懸賞 | 排「去某練功點打到條件達成為止」；懸賞只算在該練功點的擊殺 | `bounty-queue.js` |
| 隊伍／副本 | 進副本自動分坦／補／輸出角色；有傭兵與暫時合約 | `party-role.js`、`party-warband.js` |
| 拍賣場 | 花錢、上架要玩家先同意；郵件的貨到付款不自動付 | `market.js` |
| 帳號層 Legacy | 帳號升階、全伺服器首殺廣播、歡呼／噓 | `legacy2.js` |

核心循環：**AI 自動執行 → 玩家只設策略、只處理重大決定**。

## 模型與美術

沒有自己做模型：Rust 客戶端直接讀魔獸原版的模型與地圖資料，連原版 Lua 介面都在 WASM 裡跑。這條路我們學不來，版權風險也很高，只借機制與工程做法。

## 可借的工程做法

1. **伺服器說了算，介面只負責畫**：`model.js` 是純 reducer（訊息 → 新狀態＋要播的 toast），時鐘與物品查詢可注入；再搭一個說同一協定的 `mock.js`，不開伺服器就能做介面、跑測試，還有 `&scene=` 參數直接叫出固定場景來截圖。
2. **協定往前相容**：舊伺服器沒送的欄位就是 null，介面直接不畫那一區，不會壞掉。
3. **stale-cache rule**：新功能一律開新檔，避免瀏覽器快取的舊模組 import 不存在的 export 而整個掛掉。
4. **相同資料保留物件身分**：背包內容沒變就不重建 DOM，避免點擊途中元素被換掉。

## 對我們原型的意義

- 單機 Godot 版要搬這個循環，得自己寫離線補算（它不用，因為真的有伺服器 24 小時在跑）。
- 「策略面板＋決策收件匣＋跑腿說明」可以直接當 hero-horde-idle 或 skybound-blades 的設計參考。

## 重新取得原始碼

```bash
curl -sL https://azerothidle.com/ -o index.html
grep -oE "\./[a-zA-Z0-9_/-]+\.(js|wasm|json)" index.html | sort -u > list.txt
while read f; do curl -sL "https://azerothidle.com/$f" -o "src/$(echo $f | tr / _)"; done < list.txt
```
