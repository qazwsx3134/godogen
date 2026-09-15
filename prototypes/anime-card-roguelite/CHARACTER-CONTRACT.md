# 角色、職業與流派擴充契約

起始選牌、固定牌、排除與教學的現行規則見 [LOADOUT-CONTRACT.md](./LOADOUT-CONTRACT.md)，相關 API 以該文件為準。下列所有權是角色擴充當時的分工紀錄。

此增量契約優先於 CONTRACT.md 衝突部分。使用者要求可選角色、各角色不同特性／職業，戰利品卡與道具能形成多種流派與派生。單人登塔、跨宇宙接力及三種 CSS 主題沿用。文字原型，避免素材工作。

## 所有權

- wj-balance（既有 Luna Max）：data.js、engine.js、engine.test.js、balance.mjs。
- wj-layout（既有 Luna Max）：app.js、styles.css、index.html。
- commander：profile.js、profile.test.js、browser-check.mjs、文件與整合驗收。
- 不改其他 writer 的檔案，不再委派，不修改 repo skills。依契約平行實作，完成回報檔案、證據、風險。

## 角色與 data API

新增 CHARACTERS array：
{id,name,job,universe,maxHp,traitName,traitText,builds:[tag,tag],deck:[10 ids],starterPotion:potionId}。
恰好3角，免費可選，所有角色能使用全部宇宙的牌：
- shadow_ninja／影丸／忍者／ninja／72HP。影分身節奏：每回合第三張攻擊牌結算後抽1張（每回合限一次）。流派 combo、poison。
- ki_fighter／空悟／武鬥家／dragon／76HP。氣息循環：每回合第一張原印製費用至少2的牌結算後獲得2蓄氣（每回合限一次）。流派 charge、combo。
- silver_ronin／銀桑／浪人／samurai／80HP。萬事屋架勢：每回合第一張含 block 效果的卡結算後額外獲得3格擋（每回合限一次）。流派 guard、exhaust。
各10張starter：strike*3 defend*3 加4張具流派用途、不同宇宙的牌；每張nonbasic<=2。提供角色起始牌的實際預覽。角色確定身份不隨宇宙切換改變；宇宙是卡牌與畫風，職業是玩家特性。

新增 ARCHETYPES object 6 keys，每value {name,description,payoff}：combo連擊力量、poison毒術消耗、charge蓄氣爆發、guard格擋反擊、exhaust放逐循環、relay跨界共鳴。
CARDS 保留所有20舊IDs，擴到至少36張（以38左右為目標），每張增加 tags:[tag,..]、rarity:'common'|'uncommon'|'rare'。各流派至少4張相關卡，含啟動／收益／跨流派橋樑，而非全部純數值牌；中性strike/defend tags空或basic但不要算流派。所有卡仍精確 text + upgrade，getCard flatten如前。
推薦新增 IDs 可由engine worker定（UI勿寫死）。必要玩法：
- poison 舊op真正用於卡；可傷害+毒、格擋+毒、毒加倍等（可新增op poison_multiply amount2）。
- charge 新op {op:'charge',amount:n}，player.charge上限9跨回合、每場歸0；傷害仍op damage，可 {chargeMultiplier:2,spendCharge:true}，第一個此效果把已有蓄氣轉為額外傷害後扣完，只作用第一命中，不每段或每敵重複。UI牌文精確。
- guard 可新增 {op:'damage',blockMultiplier:1} 依當前格擋傷害（不消耗格擋），與格擋／荊棘搭配。
- exhaust 新op {op:'exhaust_guard',amount:3} 提供本場每有卡進放逐就獲得3格擋的持續效果，player.exhaustGuard。power本身入放逐也可觸發，文字說明。
- relay 既有共鳴強化；可新增 {op:'resonance',amount:1}；單卡不能用自己產生的charge支付強化。
- combo 多段+力量、低費、限次抽牌。
角色被動／遺物觸發有本回合旗標，禁止遞迴生成卡或無限免費能量。傷害／格擋加成在核心effect interpreter，不用每張card id分支。

RELICS 保留4舊IDs，擴至少10個（目標12），每個 {id,name,text,tags:[tag,..]}。新增建議 combo thirdattack+3block、poison第一次施毒額外2、charge戰鬥初始2氣、guard第一格擋card+2、exhaust每放逐回血1（每回合最多2）、relay每回合第一次接力抽1。各被動精確text且有觸發紀錄。遺物只在局內取得，所有角色可使用。

POTIONS array恰好3 {id,name,text,target:'enemy'|'self',effects:[..]}：venom_flask對敵毒6、energy_tonic+1能量、guard_tonic+12格擋。每角起始帶對應1瓶（忍毒／武能／浪格擋）。背包最多2瓶。普通戰40%掉1瓶，菁英必掉1瓶；滿時換10gold且log說明；boss終局不用掉。種子控制，收藏開包不含消耗品。

## Engine API

createRun({deck,seed,characterId='shadow_ninja'}) 驗證characterId，既有省略呼叫可用，run.characterId 保存。player.name/hp/maxHp取角色、currentUniverse初始取角色universe，跨戰鬥沿用；phase仍map。
player新增 charge:0..9、exhaustGuard>=0；既有stats重置方式沿用，角色每回合觸發計數也重置（開戰與下一回合）。
run.potions:[{uid,potionId}]；usePotion(run,uid,targetId=null) 僅battle、成本0、不需能量，目標與持有先驗證，失敗完全不改；效果與卡牌共用resolver，使用移除一次。消耗品不計cardsPlayed、不触发角色出牌被動、不切換宇宙。
新增 metrics.traitTriggers, potionsUsed（可再增其他）。
新增 getBuildSummary(run):純讀取 array [{id,name,count,description,payoff}]，依deck tags個數降序，忽略0，以穩定tag順序平手。升級版仍同tag。
新增 getLootHint(run,cardId):純讀取字串，根據角色builds／當前deck tags顯示具體用途，無符合則跨界新方向。

## 掉落與分支

戰後3張unique：1張角色builds相關；1張目前deck主要流派相關；1張wildcard盡量不同universe。不足回退remaining pool；所有牌對所有角可取得。各候選抽樣採rarity權重common3/uncommon2/rare1，契合只偏向，不硬鎖。
商店3張也有流派偏向（可使用同sample函式），價格保持每張50、遺物100、移除60。遺物掉落可加權相關tags但保留全部機會，去重。
現有7層路線沿用，可因擴充角色強度調整敵人數值。balance.mjs改為三角色各100seed對照endonly與策略（600局），至少兩種不同take-card策略或明確每角兩路線比較更佳。報告是模擬不是真人勝率。

## Profile（commander）

STORAGE_KEY='rift-cards.profile.v3'，version3，新profile.characterId='shadow_ninja'，deck該角起始牌。
初始collection涵蓋所有角色starter與PRESETS所需卡數；起始1000coins。
新增 applyCharacter(profile,characterId) atomic：驗證known，設characterId並套用該角starter。
applyPreset保留可將通用預組搭任何角色。setLoadout(profile,deck)仍10張owned/cap，不限制職業。
loadProfile支援v3/v2/v1不覆寫舊key，保留coins/stats/collection/合法10牌，舊profile預設shadow_ninja，v1IDmapping沿用。

## UI（wj-layout）

開局先呈現3張角色選擇卡 [data-character=id]，顯示名字／職業／HP／特性與2種流派導引、starter10卡預覽；目前選角明顯標示。選角色呼叫applyCharacter並draft更新+save。start傳characterId。
戰鬥顯示選角身份／職業／trait說明、蓄氣與放逐格擋狀態；被動觸發在log可讀。主題仍由成功出牌目前宇宙切換。
卡片顯示中文rarity與tags；reward/shop卡加入getLootHint字串，關鍵實際衍生原因要可看懂。reward/map提供getBuildSummary視圖（目前構築：連擊xN→搭配力量等），戰鬥不要大面積塞資訊，可收合。
消耗品顯示2格容量 [data-potion=uid]，點敵方瓶後選[data-enemy]，self立即使用。選卡或換節點需清消耗品target，成功用瓶要clear選擇，不妨礙已有empower選牌。run.potions/drop說明可見。
保留全部既有browser selectors/API；UI不自己抽隨機掉落。已升級card tags/rarity/說明正確，手機不橫溢、色彩不tween造成深淺主題對比問題。

## 驗收

3角確實不同HP/被動/starter；各兩條流派有可用卡牌+遺物能改變決策；跨角色／宇宙混搭可玩。新ops有正反例與guard，loot deterministic unique且偏向但不鎖死；消耗品atomic且只能一次。UI實際切角/被動/選牌/消耗品/通關/舊save遷移由commander瀏覽器驗證。保留原21測試的行為，更新硬編碼20卡/70HP等舊假設。
