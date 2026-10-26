# 蓬蓬草原：系統文件與製作規劃

2026-10-26；狀態：Planning Draft。這套文件把已確認的手機、固定鏡頭與無連招要求，轉為 40 系統責任、文件清單、介面與驗收目標，以及 M0～M6 roadmap。

## 建議閱讀順序

1. [手機製作基準](../mobile-production-baseline.md)：已確認範圍與待決定的平台細節。
2. [遊戲摘要](../game-brief.md)：核心循環與切片範圍；[核心決策與遊玩節奏](../core-loop.md)：每分鐘的決策與 5～8 分鐘 session。
3. [系統索引](../gdd/systems-index.md)：40 系統、前置、優先層與設計順序。
4. [文件契約](document-contracts.md)：GDD、TDD、UX、資料、資產與 QA 各要寫什麼。
5. [Roadmap](../../production/roadmap.md)：M0～M6 工作包、必要文件、出口證據。
6. [Godot 架構草案](../../docs/architecture/architecture-draft.md)：權威、scene、命令、交易與漸進遷移。
7. [決策與風險](decision-register.md)：平台、方向、機型、數值後果與多人範圍。
8. [驗證計畫](../../production/verification-plan.md)：120 條初始 AC 如何變成證據。

## 四個職責如何落在文件上

| 職責 | 本次產出 | 實作前還要補齊 |
|---|---|---|
| Lead Game Designer | 玩家價值、核心循環、手機操作與範圍 | 各系統 Detailed Rules、技能／任務體驗、playtest 修正 |
| Lead Systems Designer | 屬性／物品／成長／寵物／精煉的責任、數值與狀態需求 | 公式、上下限、算例、成本模擬與資料樣本 |
| Godot Specialist | scene／Resource／節點、renderer、觸控、保存與 kit 整合方向 | 實際 API 查核、TDD、匯入與真機驗證 |
| Lead Programmer | 權威／命令／交易／保存邊界、依賴 DAG、遷移與驗收 | 正式接口、每 story owned files、code review 與測試證據 |

四個職責在本 session 集中完成；未派出子代理或宣稱獨立評審。這是規劃交付，不是功能完成報告。

## 40 系統文件工作包

每份都有：玩家價值、規則邊界、GDD／TDD／專屬附件／QA 清單、資料狀態、介面、Godot scene／模組、上游／下游、分階段 roadmap、3 條初始 AC 與風險。未建立的正式規格路徑用 code 標示，不冒充已交付文件。

| ID | 系統與工作包 | 首版里程碑 | 主要詳細文件要點 |
|---|---|---|---|
| S01 | [內容定義與資料登錄](systems/s01-content-registry.md) | M0 | 資料字典：ID 命名、型別、必填／預設、版本；內容引用規格：怪物→掉表→物品→圖示；QA：重複與失效引用。 |
| S02 | [權威狀態、命令與時間](systems/s02-authority-commands-clock.md) | M0 | 契約文件：命令結果與錯誤碼；時間規格：暫停／背景／離線；ADR 提案：本機與網路權威替換。 |
| S03 | [觸控輸入與互動優先權](systems/s03-touch-input.md) | M0 | UX：單指、多指、UI 穿透、密集目標與取消；TDD：輸入路由；QA：觸控操作矩陣。 |
| S04 | [固定鏡頭、構圖與遮擋](systems/s04-fixed-camera.md) | M0 | 相機構圖表：地標、角色佔屏、各 aspect；遮擋規格；QA：固定 yaw/pitch 與傳送重設。 |
| S05 | [世界場景、碰撞與導航](systems/s05-world-navigation.md) | M0 | 關卡文件：路線、視線、障礙、入口；TDD：地形與導航契約；資料：區域／spawn；QA：通路地圖。 |
| S06 | [角色移動、選取與追擊](systems/s06-movement-targeting.md) | M1 | GDD：追擊／換目標／中斷表；TDD：物理更新與路徑重查；UX：選取圈；QA：狀態轉移。 |
| S07 | [屬性、生命、回復與死亡](systems/s07-stats-vitals-death.md) | M1 | GDD：屬性、回復、死亡懲罰；公式：取整／上限／順序；TDD：modifier 生命週期；QA：死亡競態。 |
| S08 | [普攻、命中與傷害結算](systems/s08-combat-resolution.md) | M1 | GDD：普攻時序、miss／crit／減傷；公式與算例；TDD：取消 token／唯一事件；QA：低 FPS 與換目標。 |
| S09 | [主動技能與狀態效果](systems/s09-skills-statuses.md) | M1 | 每技能規格卡：定位、數值、事件時間線；狀態互動表；UX：冷卻與拒絕原因；QA：中斷／疊加。 |
| S10 | [怪物 AI、仇恨與生成](systems/s10-monster-ai-spawning.md) | M1 | 怪物卡：外觀、行為、數值、掉表、動畫；FSM 圖；出生／密度配置；QA：拉怪與回家。 |
| S11 | [掉落、地上物與拾取](systems/s11-loot-pickup.md) | M1 | 掉表與機率來源；拾取狀態機與權限表；UX：滿包／優先權；QA：同時拾取。 |
| S12 | [物品、背包、貨幣與交易原語](systems/s12-inventory-transactions.md) | M0 | 資料字典：堆疊／綁定／鎖定／容量；交易原語與錯誤碼；UX：選取、拆堆、比較；QA：溢位／回滾。 |
| S13 | [裝備屬性、紙娃娃與換裝](systems/s13-equipment-paperdoll.md) | M2 | GDD：欄位與限制；紙娃娃方向／遮擋矩陣；UX：數值比較；QA：換裝與存讀。 |
| S14 | [經驗、職業、技能成長與轉職](systems/s14-progression-jobs.md) | M1 | 成長曲線表與算例；職業定位／技能前置圖；點數 UI；QA：跨多級與重置。 |
| S15 | [NPC、對話與任務](systems/s15-quests-dialogue.md) | M2 | 任務卡／對話圖／事件映射；UX：接取、追蹤、提交；資料：文字與獎勵；QA：可達性／重複領獎。 |
| S16 | [NPC 商店、銀行與城鎮服務](systems/s16-vendors-bank.md) | M2 | 價格與容量表；購買／出售／存取流程；UX：數量與比較；QA：滿包／變價／重複操作。 |
| S17 | [寵物餵食、成長與進化](systems/s17-pet-care.md) | M3 | GDD：照護與失敗後果；公式：餵食／飢餓／進化；UX：材料與風險預覽；QA：背景／卸裝。 |
| S18 | [精煉、製作與材料消耗](systems/s18-refine-crafting.md) | M3 | 階梯／配方表；成功與失敗算例；期望成本模擬；UX：風險確認；QA：重送／結果落盤。 |
| S19 | [聲望、收藏與成就](systems/s19-fame-collections.md) | M5 | 聲望等級表、收藏清單與來源；解鎖矩陣；UX：下一目標；QA：舊存檔補發。 |
| S20 | [手機 HUD、窗口與提示](systems/s20-mobile-hud.md) | M0 | UX 線框、窗口優先權、資訊密度與安全區；UI style guide；可讀性／觸控 QA 矩陣。 |
| S21 | [小地圖、旅行與區域切換](systems/s21-map-travel.md) | M2 | 區域連接圖與傳送規則；小地圖投影公式；UX：載入／錯誤重試；QA：切區中斷。 |
| S22 | [角色美術、方向、動畫與資產管線](systems/s22-actor-art-animation.md) | M0 | Art Bible／角色規格卡；動作與命中事件表；atlas／壓縮預算；匯入／owner／instance 驗證。 |
| S23 | [特效、跳字與打擊回饋](systems/s23-combat-feedback.md) | M1 | VFX event sheet／時間線／優先表；shader 與 renderer 降級規格；QA：30 FPS、過載、靜音。 |
| S24 | [音樂、音效與環境音](systems/s24-audio.md) | M1 | 音訊方向、事件清單、混音與 loudness 記錄；背景／Web 手勢啟動行為；QA：喇叭／耳機。 |
| S25 | [存檔、設定與手機生命週期](systems/s25-persistence-lifecycle.md) | M0 | 存檔 schema／遷移表／恢復流程；背景與單機離線時鐘政策；QA：強制終止、損壞、舊版。 |
| S26 | [新手教學、設定、無障礙與文字](systems/s26-onboarding-accessibility.md) | M2 | 首次 5～10 分鐘 journey；教學事件矩陣；可讀性／字型／翻譯表；QA：跳過、重入與放大。 |
| S27 | [手機效能、測試、工具與匯出](systems/s27-performance-build-qa.md) | M0 | 目標機矩陣、效能預算／量測 protocol、測試策略、匯出流程、release checklist、授權清單。 |
| S28 | [帳號、多人權威、AOI 與重連](systems/s28-online-authority.md) | M4 | 拓樸 ADR、協定／channel 表、權威清單、DB schema、AOI／插值、重連／跨圖流程、負載與威脅測試。 |
| S29 | [隊伍、聊天與好友](systems/s29-party-chat-friends.md) | M4 | 社交狀態機、分配政策、頻道與邀請矩陣；UX：通知／鍵盤；QA：離線、隊長退出、限流。 |
| S30 | [玩家交易與擺攤](systems/s30-trade-stalls.md) | M4 | 雙方交易狀態機；原子提交／鎖生命週期；擺攤離線政策；UX：改價重確認；QA：競態／崩潰恢復。 |
| S31 | [公會與公會資源](systems/s31-guilds.md) | M5 | 公會規則、權限矩陣、銀行／捐獻 ledger、UX：職級與公告；QA：降權與同時操作。 |
| S32 | [情侶、雙人互動與表情](systems/s32-relationships-emotes.md) | M5 | 關係生命週期、同意／取消流程、雙人姿勢規格、UX／QA：斷線與互動衝突。 |
| S33 | [釣魚與休閒採集](systems/s33-fishing.md) | M5 | 釣點／掉表／餌與期望產出；背景規則；UX：停止與滿包；QA：時鐘與重送。 |
| S34 | [戰鬥寵物、守護者與乘坐](systems/s34-battle-pets-guarders.md) | M5 | 三種類型界線與生命週期；跟隨／傳送政策；技能與乘坐表；QA：切圖／下坐／死亡。 |
| S35 | [時裝、光環與外觀收藏](systems/s35-cosmetics-auras.md) | M5 | 外觀欄位／覆寫矩陣；取得／預覽流程；VFX cap；QA：切裝與遠距離裁減。 |
| S36 | [副本、首領與遭遇導演](systems/s36-dungeons-bosses.md) | M5 | 副本 layout／pacing、首領時間線與技能表、獎勵與重置、UX：團滅／預警、QA：重連／跨階段。 |
| S37 | [決鬥與 PvP 規則](systems/s37-duels-pvp.md) | M5 | 同意與結束狀態機、PvP 平衡表、技能互動矩陣、UX／QA：離線與越界。 |
| S38 | [活動、每日與限時獎勵](systems/s38-events-dailies.md) | M5 | 活動日曆、每日 reset／補領／claim 規格、獎勵經濟預算、UX：時區與剩餘時間、QA：邊界。 |
| S39 | [商城、付費與權益](systems/s39-commerce.md) | M5 | 商業模式／商品範圍、付款序列／恢復／退款、平台技術 ADR、QA：sandbox／中斷；發佈要求另作查核。 |
| S40 | [平衡、遙測、內容工具與營運稽核](systems/s40-balance-telemetry-operations.md) | M0 | 數值來源表、經濟模擬、事件字典／資料保留、營運命令與稽核、QA：事件對帳與工具權限。 |

## 狀態與來源

40 份是 **planning dossiers**：詳細列出要做的文件和工作，已有 120 條可測 AC，但尚非 40 份完整定案 GDD。`system-register.json` 是本次系統 ID／前置／反向消費者的結構化鏡像；後續改 Markdown 時同步維護 JSON，正常執行不使用生成器重新覆寫文件。

依據：[原作研究](../../../../docs/research/seal-online-deep-dive-2026-10-26/README.md)、現有原型 README／scene 結構與手機基準。原作資料只是參考，不自動成為功能與數值要求。新增 40 系統中的後期功能只是條件範圍，不表示使用者已批准一次實作全部系統。

下一個具體交付建議是 M0 可實作文件組與灰盒驗證；先收斂平台／機型，再讓相機、觸控、內容、交易、保存與 scene 管線達到本階段 Ready。
