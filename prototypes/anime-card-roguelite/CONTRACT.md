# 裂界牌局：單人登塔實作契約

起始配置、固定牌與排除的現行 API 見 [LOADOUT-CONTRACT.md](./LOADOUT-CONTRACT.md)。

現行角色、卡池、道具與保存格式由 CHARACTER-CONTRACT.md 定義，並優先於本文件對應欄位；本文件保留通用登塔與接力 API。

使用者已要求專注 Slay the Spire 2 式的出牌／局內構築，並接受「跨宇宙接力」與隨出牌切換的銀魂、七龍珠、火影视覺風格。此契約為目前設計與 API。原生 ES modules、繁體中文、文字為主，所有工作限此原型目錄。

## 所有權

- wj-balance (Luna Max): data.js, engine.js, engine.test.js, balance.mjs。
- wj-layout (Luna Max): app.js, styles.css, index.html。
- commander: profile.js, profile.test.js, browser-check.mjs, package.json, 全部文件、整合驗收。
- 各自只能修改所屬檔案；依契約並行，不等其他檔案出現才工作。不要遞迴委派或修改 .agents。

## 核心玩法

單一「裂界旅人」70 HP。每回合 3 能量、抽 5 張、手牌上限 10；點卡直接攻擊／防禦／施加效果。結束回合只結算敵方與由卡牌施加的狀態。我方沒有留場隊員、站位、召喚、後備或固定自動攻擊。戰後不自動補滿生命；生命跨節點保留。全程牌組成長、休息／升級取捨、金幣／商店、菁英遺物與首領。

## 跨宇宙接力與畫風

UNIVERSES keys: neutral / ninja(火影) / dragon(七龍珠) / samurai(銀魂)。成功打出非 neutral 牌會設定 currentUniverse；與上一張非 neutral 牌不同時 +1 resonance (上限 3)。neutral 牌不累積也不中斷，跨玩家回合保留；新戰鬥 resonance=0、lastUniverse=null。currentUniverse 保留作畫面主题。主動用 3 resonance 強化一張有 damage/block 的牌，第一段 damage +4、第一個 block +4；單卡多段不能每段都 +4。先驗證/扣除舊共鳴，再結算卡牌與新接力，不能用本卡即將產生的共鳴支付自身。沒有共鳴仍可正常出牌。power/draw-only 卡不適用強化。

畫面必須明顯隨 currentUniverse 改變：銀魂紙感／墨線／漫畫框；七龍珠鮮明色彩／粗輪廓／放射線；火影卷軸紙／筆刷框／忍術印記。以 CSS 紋理、字體、線條、背景與框形實作，無重型素材與閃爍。顯示目前宇宙、上一個宇宙、共鳴 0..3 與接力原因；卡片自帶宇宙標籤。支援 reduced-motion。使用者明確接受此方向，不需重新訪談。

## 地圖與遭遇

七層線性向前的分支路線，每層全部候選連到下一層：
0 battle；1 battle/event；2 camp/elite；3 battle/shop；4 event/elite；5 camp/shop；6 boss。
點擊当前層其中一個節點後不可走同層其他節點。選擇影響 HP、牌組與遺物；seed 控制敵群、意圖、獎勵、商品、遺物。界面畫出所有層与連線/進度，僅當前層可選。目標10–20分鐘，可調數值。
戰鬥勝利給金幣與三選一卡（可跳過），不給一般戰後自動回血；菁英額外給一個未持有遺物。Boss 擊敗直接 won。若血歸零先 lost。
營火二選一：恢復 maxHp 的25%向上取整，或升級一張未升級的牌；也可跳過。每牌只升級一次。
商店：3 張技能各可買一次（50金）、一遺物（100金）、一次移除牌（60金，至少留1張），可離開。初始70金；普通戰勝利+25、菁英+40。
事件：消耗8HP（必須HP>8）取得一個未持有遺物，或恢復6HP。一次選擇後前進。
遺物至少4種：開戰8格擋、戰後3HP、強化加成+2、戰利品+15金。無可用新遺物時給30金，介面與紀錄清楚說明。

## data.js exports

UNIVERSES = {neutral:{name:'旅人',label:'裂界'},ninja:{name:'火影',label:'忍術'},dragon:{name:'七龍珠',label:'氣功'},samurai:{name:'銀魂',label:'武士'}}。
CARDS: 20種左右，array {id,name,type:'attack'|'skill'|'power',universe:(key),cost,target:'enemy'|'self'|'none'|'all',text,effects:[{op,...}],upgrade:{cost?,text,effects}}。
所有效果由小型 interpreter 執行，支援 damage/block/draw/energy/weak/poison/strength/thorns/exhaust 等必要 op；block 等作用玩家，不因 card.target=enemy 改變。power 使用後進 exile，效果維持當場。零費抽牌補能必須 exhaust。所有牌有精確描述與升級效果。
固定 IDs: strike、defend；kunai_barrage、shadow_rush、spiral_strike、ki_blast、pressure_point、kame_wave、wooden_guard、sarcastic_counter、spirit_barrier、rift_assault、ninja_smoke、team_tactics；leaf_stance、shadow_insight、turtle_guard、saiyan_spirit、silver_resolve、umbrella_strike。
保留這20個 ID 供 migration；不用 CHARACTERS 或 SKILLS exports。
getCard(id, upgraded=0): 回傳此版本的扁平卡片（upgraded=1 套 upgrade），不存在回 undefined，原資料不可改。
PRESETS: 兩組 {id,name,description,deck:[id x10]}。
第1組 id='relay': strike*3, defend*3, kunai_barrage*2, ki_blast*2。
第2組 id='adaptive': strike*3, defend*3, kunai_barrage, ki_blast, wooden_guard, pressure_point。
RELICS: array {id,name,text}，效果依 relic id 在引擎集中結算。

## engine.js 公開 API 與狀態

createRun({deck:[id x10],seed:string}): 驗證已知卡10張、basic最多5其他最多2；傳回 phase='map' 起始狀態。可選預組、收藏組牌；冒險規則不依賴 profile。
run 公開欄位：
- phase: 'map'|'battle'|'reward'|'camp'|'shop'|'event'|'won'|'lost'
- step:0..6, seed, currentNode:null或Node, map:Node[][]
- Node:{id,kind:'battle'|'elite'|'camp'|'shop'|'event'|'boss',label,description,visited:boolean}
- player:{name,hp,maxHp,block,strength,thorns}, gold, relics:[relicId]
- deck:持久卡牌實例 [{uid,cardId,upgraded:0|1}]，不是抽牌區；UID整局穩定，升級與移除用此uid
- hand,draw,discard,exile,resolving:當前戰鬥的卡牌實例array；每張在一個區域，deck不算區域。下一戰依deck重建區域，upgrade生效。維持每戰UID registry，reward/shop新增牌到下一戰才實例化。
- enemies:[{id,name,hp,maxHp,block,poison,weak,intent:{kind:'attack'|'defend'|'buff',label,amount,hits}}]
- turn,energy,currentUniverse,lastUniverse,resonance
- rewards:[cardId]，shop:{cards:[{id,price,sold}],relic:{id,price,sold}|null,removalPrice:60,removed:boolean}|null
- log:string[] oldest first bounded150
- metrics:{cardsPlayed,damageDealt,damageTaken,battlesWon,relays,empowered,cardsAdded,cardsUpgraded,...}

以下 mutate run 返回 {ok:boolean,error?:string}；無效操作完全不改狀態：
visitNode(run,nodeId): map current step only; battle開始第一回合；非戰鬥進相應phase。
playCard(run,uid,targetId=null,empowered=false): target enemy需存活敵人id；self/none/all不用target。先原子驗證能量／目標／empower，再移入resolving，扣費，按序effects，更新宇宙與共鳴、最後處理勝敗。未啟用強化不花共鳴。
endTurn(run): 棄手牌，敵方毒等狀態與意圖結算；玩家無固定自動攻擊。若存活，清玩家block、恢復3能量、抽5、更新敵意圖。卡片strength/thorns本戰保留；weak每個受影響敵人行動後減1，毒每敵方回合先扣HP再減1。死亡敵人停止所有命中。
getIntentDamage(enemy): 預告/实际攻擊的每段傷害，weak>0則floor(raw*.75)，defend/buff回0；UI不要直接把 raw amount 當成弱化後攻擊。
chooseReward(run,cardId=null): 選一張進deck或跳過，進下一層map。
rest(run): camp, heal25%, 前進。
upgradeCard(run,uid): camp一張未升級deck牌改upgraded=1，前進。
buyCard(run,cardId), buyRelic(run,relicId), removeCard(run,uid): shop only，價格/擁有/至少1牌先驗證。
leaveNode(run): camp/shop -> 下一層map。
chooseEvent(run,'risk'|'heal'): event only，一次後前進。
assertInvariants(run): 區域UID守恆、HP非負/不超max、能量/gold/resonance合法、牌組合法instance、有限状态等。map/camp的新增牌與現有戰鬥registry分開驗證。
戰鬥 phase 多次點擊終局按鈕不能重複獎勵。

## profile.js API (commander)

STORAGE_KEY='rift-cards.profile.v2'。createProfile/loadProfile/saveProfile 同原API，資料 {version:2,coins:1000,collection:{id:count},deck:[id x10],stats:{runs,wins},lastPack:[]}，無roster。basic cap5、其他cap2。初始兩預組需要卡皆擁有。loadProfile 可讀 v1，保留coins/stats/已知收藏並映射ID，起始deck回relay；不覆寫舊key。
setLoadout(profile,deck): 10張、known、cap、owned，atomic。
applyPreset(profile,presetId): 預組套用與儲存由UI處理。
openPack(profile):100幣3張非basic、等機率可重複，超cap每張退20，回{ok,cards,duplicates:number}。
grantCard/addTestCoins/recordResult/saveProfile API同原版。recordResult每局只呼叫一次。

## UI

標題裂界牌局，單人登塔主入口、兩起始牌、可輸seed。收藏／自訂牌組是次要入口，沒有角色選擇或隊伍欄。
初始map選路；戰場顯示玩家HP/格擋/能量與狀態，敵方意圖、技能牌、牌堆與共鳴強化開關；點卡選敵，self等立即結算。敵人與手牌在桌面同屏盡量可見，避免主操作被长收藏清單推走。所有牌有費用/宇宙/type/精確text。已升級標+；新獎勵不加入永久收藏。
地圖、休息升級、商店、事件、遺物欄與結算都要可操作。正在冒險的deck inspect可查升級與放逐；抽牌堆僅列組成不洩漏順序。
DOM selectors for commander browser tests: #start,[data-preset],[data-tab],[data-node],[data-play],[data-enemy],#end,#empower,[data-reward],#skip,#rest,[data-upgrade],[data-buy-card],[data-buy-relic],[data-remove],#leave,[data-event],#return,[data-pile],#close-modal,#modal,#seed,#pack,#coins,[data-grant]。
每次render設 document.documentElement.dataset.universe = run?.currentUniverse||'neutral'，CSS三宇宙主題必須明顯不同。無JS錯誤、手機無水平溢出、支援鍵盤與受限storage；不要用整個app aria-live。
