# Cyberpunk 文字 MMO RPG：進度與交接

由根目錄 `Progress.md` 拆出（2026-11-02）。文件入口 [README](README.md)；尚無程式專案。

## 2026-10-29｜概念深化與開發規劃

- **專案與分支**：新作尚未建立程式專案；分支 `master`。文件入口 `docs/cyberpunk-text-mmo/README.md`，概念、玩法設計與開發計畫均在同目錄。
- **使用者已確認**：參考 dev-sao 的文字 MMO RPG；Cyberpunk 2077 同一時空的另一座類似夜城城市，設定方向比照；主打任務、名聲、區域解鎖及排行榜。一般委託自動跑，重要劇情手動選。多人選擇 1＋2：各自接案競爭排行＋非同步合作推進城市事件。
- **本輪新確認**：原生網頁、主要為手機直式，電腦相容。城市改東京原型；每角色委託不重複，死亡後新角可重玩；永久死亡，重大危險節點停下等玩家選擇、離線不代選。有聊天／系統訊息、警方與MaxTac型單位、Trauma Team，以及等級提高神機錯亂免疫力。使用者進一步指定React、Cloudflare，可用shadcn/ui、Tailwind並提供三個視覺參考網址。
- **完成／未完成**：文件更新v0.2，新增 `risk-systems.md`、`content-plan.md`；移除重複刷案與不設永久死亡的舊提案。首六案「終電之後」、東京原型兩區、搶救在死亡前、神經負荷公式、通訊分流、先6案後24案及M0～M5均已規劃。程式整合粗估21～36人日另加文本製作，原12～20不適用。具體公式、名稱、保障與繼承細則、字數／內容量為提案。沒有遊戲實作、美術生成或多人驗證。
- **React／Cloudflare架構規劃**：新增 `architecture.md`、`ui-system.md`，開發計畫更新v0.3。React SPA／Vite、Router／Query、shadcn／Tailwind，Workers／Hono模組化單體、D1生死／經濟、每頻道DO聊天；列目錄、API、版本／重送與死亡交易、outbox、部署及手機元件／tokens。這些為架構設計，尚未建立package或跑runtime證據。
- **驗證與限制**：規劃層不跑程式測試。查閱CDPR警方／Trauma Team、R.Talsorian人性／義體／治療及Cloudflare DO官方文件，區分原作參考與本作規則。容量、成本、公式與文本交期未實測；2026-10-23～24原站研究只沿用歷史證據。本作東京地理／警方名稱未聲稱官方考證完成；Studio runtime catalog不存在，未宣稱完成正式流程。
- **視覺參考證據**：Figma原檔及oEmbed皆無法讀取，瀏覽器也受阻；Pinterest瀏覽器看見32 Pins與部分斜切／細線／警示縮圖，登入遮罩限制完整閱讀，截圖 `/tmp/tokyo-pinterest-reference.png`。Magnific只取得分類文字、瀏覽器存取受限；未挑選／下載素材，不宣稱完整解析三份參考。UI色票與尺寸為提案。
- **使用者Figma主檔**：作者另提供 `https://www.figma.com/design/xF0jgcnbonnTCs2UQzVHeQ/Untitled?node-id=0-1`，已列為主要元件來源；本次瀏覽器實際回403 ERROR，網頁工具／file路徑／oEmbed未能取得內容。未判定是否分享權限問題，未聲稱解析元件；架構規劃照常完成，精確樣式待可取得來源。
- **本機SVG已取得（取代等待Figma）**：使用者提供 `docs/cyberpunk-text-mmo/example.svg`（6616×3447、1,953,050 bytes、SHA256 `1d311e840d64197e1b427eb9110d70484d60b343a295e005c2a0fced9a190a82`）。已XML盤點及瀏覽器整張／局部檢視，確認紅黑按鈕、警告、標籤、圖示；文字為path、含一張base64 PNG。新增 `svg-reference.md`，UI規劃v0.2依SVG色碼調整為紅黑骨架／淺灰正文。原檔未改、尚未拆資產或實作元件；不透明色值對比量測不等於完整無障礙驗收。
- **ArtStation補充**：`https://www.artstation.com/artwork/18mLB8`的作者作品頁確認為Anna Kuźmińska的Cyberpunk 2077 UI Art作品；圖像／動態受載入限制未檢視完成，沒有據此宣稱抽色或動畫分析。具體視覺以本機SVG為依據。檢視截圖暫存在 `/tmp/tokyo-svg-sheet-full.png`、`/tmp/tokyo-svg-buttons-detail.png`。規劃層不跑遊戲測試。
- **本機UI圖集與規範（本輪最新）**：使用者已下載16張`ui/anna-kuzminska-*.jpg`並指定作參考／規範／目標；本次全部逐張以view_image檢視。新增 `ui/README.md`逐圖來源、HUD／背包／醫療／電梯／對講機等對應及手機轉譯限制。`ui-system.md`升v0.3實作／review基線：17類元件合約、共用狀態、手機字級／尺寸／切角／語意色、A～D製作順序及G01～G10驗收目標。靜態圖已取得，不再受前輪網頁圖片限制；動畫仍未取得，精確原圖字體未知。
- **本輪證據／狀態**：圖片metadata及全16張人工檢視完成；原JPG／SVG保留未改，未裁切生成遊戲素材。只更新規劃文件，沒有元件程式、遊戲測試或手機真人驗收；G01～G10皆待實作驗證。README、開發P03與SVG來源狀態同步。未commit／push或部署。
- **Lead設計評估（最新）**：使用者要求從lead game／systems designer角度檢查如何設計與好玩缺口。主session讀取玩法、風險與文本計畫後新增 `design-assessment.md`：優先補有取捨的任務方案、人物牽掛、失敗分層、有限經濟與多人成效；義體用途、城市援助及重玩差異為新提案，沒有覆寫已確認規格。建議先兩案證明體驗，再擴六案／24案。僅規劃評估，沒有派代理、試玩或遊戲測試；單純算例驗算獨立1%風險50次的累積死亡率約39.5%，非本作平衡值。未commit／push。
- **手機文字冒險系統藍圖（最新）**：使用者要求每個系統如何以手機優先文字冒險設計；新增 `mobile-systems-blueprint.md`，涵蓋17系統的手機呈現／玩家決策／規則／好玩目標、三種時間、診所撤離跨系統案例與兩案→六案→24案深度。保留共享城市與排行，不擅改純單機；新規則與係數仍為提案。只寫規劃、未實作／試玩／跑遊戲測試，未commit／push。
- **下一步／工作區**：先P01前兩案試讀及P02生死／醫療／通緝／抗性狀態表、有限經濟與週榜分組，再做手機直式風險原型。死亡交易與重送驗證先於真人風險及大量文本；聊天M3、城市排行M4、內容擴充M5。文件未commit／push，未建雲端資源或部署；保留其他原型修改，不恢復其開發。
