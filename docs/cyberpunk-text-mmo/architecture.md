# React／Cloudflare 架構 v0.1

日期：2026-10-29。使用者已指定React、Cloudflare與手機直式，允許shadcn/ui、Tailwind並提供視覺參考。這是可實作的架構基線；尚未建立程式、雲端資源或驗證容量。

## 1. 整體決策

採React SPA＋一個模組化Worker＋D1遊戲資料庫，聊天室以頻道Durable Object分流。同一個專案建置前後端，共用型別與schema，不拆微服務。首版不需要Next.js／SSR；登入後的閱讀、操作與聊天是主要用途。

| 層 | 選擇 | 具體責任 |
|---|---|---|
| 網頁 | React、TypeScript、Vite | 手機直式介面、故事閱讀、操作回饋 |
| 元件與樣式 | shadcn/ui、Tailwind CSS、CSS tokens | 可客製的互動元件、版面、遊戲視覺 |
| 導覽 | React Router的SPA導覽 | 五個主要頁面、案件／生涯詳細頁、深層網址 |
| 遠端狀態 | TanStack Query | API快取、更新後同步、重連與錯誤狀態 |
| API | Workers＋Hono | 登入、指令、狀態、權限與資料交易的入口 |
| 規則 | 純TypeScript函式 | 任務、醫療、通緝、抗性及生死結果 |
| 遊戲資料 | D1、版本化SQL migration | 唯一的角色／生死／經濟／進度權威 |
| 聊天 | SQLite-backed Durable Objects＋WebSocket Hibernation | 每頻道訊息排序、保存、推播與補讀 |
| 定期工作 | Worker scheduled handler | 安全段到期推進、有限批次補結算、outbox重試 |
| 部署 | Workers Static Assets＋API同源 | JS／CSS／圖片與API同一網域 |

Tailwind指Tailwind CSS，元件先用shadcn/ui；不假設另外購買Tailwind Plus／其他付費元件包。套件精確版本在建立專案時依相容版本鎖入lockfile，不在規劃中填寫未安裝版本。

```text
手機直式 React App
  ├─ React Router：委託／角色／城市／排行／紀錄
  ├─ shadcn/ui＋Tailwind＋遊戲元件
  └─ TanStack Query＋API client
           │ HTTPS /api/*         │ WebSocket /ws/*
           ↓                     ↓
Workers：session／schema／權限   頻道 Durable Object
  ├─ 遊戲指令與查詢              ├─ 訊息與序號
  ├─ 規則函式                    ├─ 限流與補讀
  └─ D1交易                      └─ 頻道儲存
           ↓                          ↑
D1：角色／生死／案件／城市／排行       │
  └─ 已提交事件 outbox ────────────────┘
           ↑
Scheduled：到期安全段／補結算／廣播重試
```

## 2. 前端分層與狀態

React負責呈現伺服器允許的操作，不計算正式獎勵、可否復活或案件解鎖。模擬器可以在開發時使用同一批規則函式，正式瀏覽器bundle不包含秘密判定資料與全部未解鎖劇情。

| 狀態 | 保存位置 | 例子 |
|---|---|---|
| 遊戲持久狀態 | D1，Query保存可丟棄副本 | 生命、等級、金錢、案件、保障、城市 |
| 路由狀態 | URL | 當前分頁、案件ID、歷史生涯 |
| 短暫互動 | 元件state／必要的Context | 抽屜開關、選定方案、尚未送出的聊天 |
| 閱讀偏好 | 本機儲存 | 字級、減少動態、已讀位置；非任務權威 |
| 聊天 | 頻道儲存；前端有界訊息列表 | message_id、sequence、來源與時間 |

首版不額外加入Redux或Zustand。Query key至少包含world_id、account_id、character_id與資料範圍；登出、角色死亡後重建時清理舊角快取，避免新角看到前角的金錢與選項。

成功指令回傳新角色版本、結果與受影響資料；先更新角色快照，再精準invalidate城市／排行。跨裝置回來重新查詢；舊版本回應不能覆蓋新版本。瀏覽器倒數依server_time與due_at計算，只作顯示，不用每秒打API。

生死、發獎、投保與故事選擇不用樂觀成功；送出時顯示處理中，網路不明時以同一request_id查回結果。Query／mutation的重試策略顯式設定；致命指令不套用不明確的自動重送。聊天可先顯示「傳送中」，收到持久化確認後才顯示已送達。

前景重新聚焦、網路恢復及指令完成時同步。低頻城市／排行只在可見時查詢；聊天新訊息走socket。權限與生命狀態不可當作永不失效的靜態快取。

## 3. 目錄基線

建議遊戲根目錄：`prototypes/tokyo-text-mmo/`。以下是未來目錄，不代表檔案已存在。

```text
tokyo-text-mmo/
  src/
    app/                 AppShell、路由、providers
    components/
      ui/                選定後加入的shadcn元件來源
      game/              TerminalPanel、RiskPanel等
    features/
      missions/          委託、故事閱讀、危險選擇
      character/         裝備、等級、抗性與保單
      city/              區域與共同事件
      rankings/          存活／歷史名聲與週榜
      history/           個人生涯、死亡紀錄
      chat/              通訊抽屜與訊息
    lib/                 API client、Query keys
    styles/              tokens、全域閱讀與遊戲造型
  worker/
    index.ts             fetch與scheduled入口
    auth/                session與登入整合
    routes/              Hono handlers
    services/            遊戲用例與交易編排
    rules/               可測試的純規則
    db/                  prepared SQL與repository
    jobs/                到期推進與outbox
    chat/                ChatRoom Durable Object
  shared/                API契約與schema，不含隱藏劇情
  content/               伺服器用案件、區域、裝備與文字
  migrations/            D1 schema與資料遷移
  tests/                 規則／runtime／瀏覽器測試
  public/                公開圖示及經確認的視覺素材
  wrangler.jsonc
  components.json
```

先按需要建立檔案，不先生成空的repository／service介面層。feature間透過明確API契約互動，共用元件只處理展示與操作，不隱藏發獎副作用。

## 4. API契約與一次性指令

| API提案 | 用途 |
|---|---|
| `GET /api/me` | 帳號、當前生涯、存活狀態與伺服器時間 |
| `GET /api/game-state` | 當前角色摘要、執行中案子與可操作節點 |
| `GET /api/missions` | 依角色可見的獨立案件列表 |
| `POST /api/missions/:id/start` | 接案，驗證尚未消耗此案 |
| `POST /api/runs/:id/choose` | 一次性確認故事或危險節點 |
| `POST /api/character/equipment` | 合法狀態下換裝 |
| `POST /api/medical/coverage` | 合法狀態下購買保障 |
| `GET /api/city`、`GET /api/rankings` | 世界進度與排行 |
| `GET /api/careers/:id` | 有權查看的唯讀生涯紀錄 |
| `POST /api/characters` | 無活躍角色時建立新生涯 |
| `GET /ws/city` | 驗證後升級公共頻道連線 |

所有遊戲指令帶request_id、character_id、expected_version；節點選擇另帶run_id、node_id與action_id。伺服器不接受客戶端指定報酬、死亡機率或抗性結果。Zod等schema驗證在入口執行，共用型別不能取代runtime驗證。

成功回應包含request_id、server_time、character_version、result、當前快照與allowed_actions。錯誤用穩定code及可閱讀訊息區分登入失效、狀態過期、已結案與伺服器失敗；過期指令回409並要求同步，不能靜默套到新節點。

## 5. D1資料權威與永久死亡

沿用開發計畫的帳號／角色／任務／獎勵／醫療／城市／排行資料，新增command_receipts保存一次性指令結果。重點限制：

- 同角色案件唯一；新角新character_id，可以重玩。
- 每帳號最多一個活躍角色，死亡角色保存唯讀紀錄。
- 每角色最多一份執行／等待中的案件。
- 每個指令request_id與帳號範圍唯一，綁定payload摘要；相同ID帶不同內容必須拒絕。
- 獎勵、醫療出勤、城市貢獻與公告來源各有唯一業務ID。
- DEAD是生命終態；所有更新條件均不得把DEAD改回存活。

```text
選擇危險行動
    ↓
驗證session → 讀取既有指令結果（有則回同一結果）
    ↓ 無既有結果
讀快照／內容版本 → 算結果 → 以預期角色版本提交同一D1交易
    ├─ 狀態／版本／節點符合 → 生死＋收益＋紀錄＋outbox一起提交
    └─ 不符合／競態失敗 → 不改任何遊戲資料，重新同步
```

規則可先依快照計算，但提交時必須再次由SQL條件把角色版本、生命狀態與節點鎖定。D1的batch提供交易能力，仍需證明「條件更新0列」時其餘效果也完全不執行；不能只檢查API沒有拋錯。

建議在交易內先條件建立帶獨立attempt_token的指令憑證，再讓所有效果以本次token為條件，最後保存結果。重試不能用前次憑證解鎖第二次發獎。唯一衝突、0列條件、payload不符與資料寫入失敗都須有runtime競態測試。這是待實作驗證的交易設計，不是已證明正確的SQL。

## 6. 時間、內容版本與離線

一般段保存due_at，scheduled按索引掃描有限數量到期工作；狀態同步前亦可呼叫同一個advance函式。推進至重要選擇／重大危險節點便停止，不設定死亡倒數。

冒險確認時一起判定遭遇、醫療到達窗口與最終生命狀態；接下來的動畫／文字播放只是已提交結果的展示。重連可拿回同一結果。伺服器先提交後斷線不造成角色回到選擇前。

每次run保存content_version與裝備／保障快照；更新案件不改寫舊run。舊內容至少保留到仍引用的生涯與執行記錄可安全讀取；若移除舊邏輯，須先遷移或封存，不讓進行中任務找不到判定版本。

全文與分支放伺服器內容資料，API只傳角色已可見的文本與合法選項。公開bundle可含區域簡介／共用UI文字，不能把全部隱藏分支、秘密需求與未公開成果一次送到手機。

## 7. 聊天、身分與系統廣播

Worker驗證同源Origin、session與頻道資格後才升級socket，傳給DO的是伺服器可信的身份；不能相信客戶端提交的system、角色名或管理權限。內部廣播RPC不暴露成可由玩家呼叫的公開路由。

玩家訊息保存account_id、當時生涯ID、server_time與sequence。近期訊息分頁、有界補讀；斷線用last_sequence續讀，超出保留範圍則顯示歷史已截斷。先持久化再廣播，client_message_id去重，送達狀態有ACK。

長連線不等於永久通行證：發言驗證session／角色資格與禁言，配置到期或重新驗證；死亡舊角不能靠重連繼續冒充存活。聊天訊息送達與角色死亡分屬兩個儲存，不能承諾分散式同時提交；訊息以驗證／接受時間與生涯標示解讀，聊天不觸發遊戲指令或變更生死。

系統廣播由D1 outbox重試發往DO，依event_id去重；傳送後才標記已送。當「已送但尚未標記」中斷時可再次送達，但聊天室不新增第二則。廣播失敗不回滾角色死亡或獎勵。

採Hibernation時記憶體會重建；連線附件、訊息序號與頻道管理狀態不能只放記憶體。首版開一個城市公共頻道，後續按世界／頻道拆DO，不能把所有遊戲運算塞進單一DO。

## 8. Cloudflare部署與營運邊界

前後端同源，例如遊戲網址下的`/api`、`/auth`、`/ws`；Static Assets服務React，API與socket路徑先走Worker，不能讓未命中API回傳SPA的HTML。Wrangler的SPA fallback與run_worker_first依官方文件設定並做路由冒煙。

本機、staging、production有獨立D1與DO namespace、OAuth callback與secrets；測試角色死亡／重置不能碰正式資料。帳號cookie採HttpOnly、Secure、適當SameSite；遊戲寫入檢查Origin／CSRF，授權由server執行。供應者建議單一Google OIDC，實際成熟套件與D1 adapter在M0小型驗證後鎖定，不自製認證協定。

以wrangler.jsonc為配置來源，建立當日compatibility_date及相容flags，用wrangler types產生binding型別。Secrets不進瀏覽器bundle與Git；OAuth／session／聊天內容不寫進一般請求log。

API角色資料no-store；靜態帶hash檔案可長快取。首版不使用Service Worker離線寫入或自動排隊致命指令，避免斷線時玩家誤以為選擇已生效。

啟用結構化Logs／Traces並設定抽樣，記request_id、角色／事件版本、延遲、衝突／重試類型。監看到期積壓、outbox積壓、D1耗時與掃描量、DO連線與訊息量。容量與月費依封測實測，不因選Cloudflare就宣稱能直接承載萬人共享寫入。

資料遷移先相容舊版，再部署新程式；前端遇到不相容API顯示更新提示。回滾程式不等於回滾角色資料；永久死亡的人工修復只作有紀錄的事故處理提案，不作正常復活機制。封測前需有資料備份與隔離還原演練。

## 9. 決策紀錄與驗收

| 決策 | 採用原因 | 何時重看 |
|---|---|---|
| React SPA＋Vite | 直式閱讀／互動為主，前後端可同一套TS工具 | 需要公開SEO內容時另加公開頁 |
| Worker模組化單體 | 生死與經濟交易集中、便於驗證 | 實測延遲與責任需要拆分時 |
| D1遊戲資料、DO聊天 | SQL交易與頻道連線各有明確權威 | D1熱點／聊天扇出量測後 |
| shadcn來源元件＋自訂tokens | 保留互動行為並能做遊戲造型 | 元件實測無法支援閱讀／觸控時 |
| HTTP遊戲指令、socket通訊 | 結算重試容易追查，聊天即時送達 | 未來確有即時玩法需求時 |

實作最低證據：L1規則與內容schema；L2真實Workers／D1／DO runtime的版本競態、雙分頁、死亡終態、指令重送、socket補讀與outbox；手機360／390／430px直式瀏覽器冒煙與真人Safari。L3沿用repo規則，作者手動驗收後才跑完整suite。

第一個技術切片先串起React畫面→Hono API→D1→回傳快照，使用隔離測試案證明危險等待、確認一次、死亡終態與重連；再接DO聊天。視覺元件可用明示測試資料先做元件展示頁，不把假榜單交付成真正多人。

## 10. 查核來源

2026-10-29查閱：[Cloudflare React＋Vite](https://developers.cloudflare.com/workers/framework-guides/web-apps/react/)、[SPA路由](https://developers.cloudflare.com/workers/static-assets/routing/single-page-application/)、[Hono Workers](https://hono.dev/docs/getting-started/cloudflare-workers)、[D1 API](https://developers.cloudflare.com/d1/worker-api/d1-database/)、[DO WebSockets](https://developers.cloudflare.com/durable-objects/best-practices/websockets/)、[React Router](https://reactrouter.com/start/declarative/installation)、[Query預設](https://tanstack.com/query/latest/docs/framework/react/guides/important-defaults)、[shadcn Vite](https://ui.shadcn.com/docs/installation/vite)、[Tailwind Vite](https://tailwindcss.com/docs/installation/using-vite)。來源支持產品能力；本作整合尚未實作驗證。
