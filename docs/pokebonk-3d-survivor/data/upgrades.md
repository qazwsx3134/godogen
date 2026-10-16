# 被動道具與升級規則

## 維他命（進化材料與角色升級）

升級量會按抽到的稀有度倍率調整，且持有等級達 20 後有 0.96 的遞減係數；下列是 base 的每級數值。(`main:2143、main:2236`、`main:3646、main:3679`)

| 行 | ID／pt-BR 名稱（中文） | 影響欄位 | 每級 base 增量 |
|---:|---|---|---:|
| main:2143 | `protein`／Proteína（蛋白質） | 傷害 | +0.1 |
| main:2153 | `carbos`／Carbos（速度強化劑） | 移動速度 | +0.08 |
| main:2162 | `iron`／Ferro（鐵） | 護甲 | +0.05 |
| main:2171 | `hpup`／HP Up（HP 強化劑） | 最大 HP | +20 |
| main:2172 | `calcium`／Cálcio（鈣） | 招式尺寸 | +0.1 |
| main:2181 | `zinc`／Zinco（鋅） | 攻擊速度 | +0.08 |
| main:2190 | `ppmax`／PP Máx（PP Max） | 招式數量 | +1 |
| main:2199 | `rarecandy`／Doce Raro（神奇糖果） | XP 獲得 | +0.12 |
| main:2208 | `magnet`／Ímã（磁鐵） | 拾取距離 | +0.9 |
| main:2209 | `clover`／Trevo（幸運草） | 幸運 | +0.1 |
| main:2218 | `wing`／Pena Veloz（速度之羽） | projSpeed | +0.12 |
| main:2227 | `dust`／Pó Prateado（銀粉） | 持續時間 | +0.12 |

## Pokébola 被動道具（32）

寶箱抽取時最多顯示 3 張；普通／不普通／稀有／史詩／傳說的初始權重是 60／25／10／4／1。商店寶箱基價依已開數量為 `12 × 1.32^opened + 4 × opened`，再乘稀有度係數 `[1, 1.6, 2.5, 4, 6.5]`；每 40 秒生一箱，地圖最多 22 箱；局內開局先放 18 箱。(`main:3875、main:3910`、`main:29899、main:29909`)

| 行 | ID／pt-BR 名稱（中文） | 稀有度 | 效果 | 最多持有 |
|---:|---|---|---|---:|
| main:2237 | `leftovers`／Restos（剩飯） | 普通 | 每秒回復 HP | 25 |
| main:2248 | `luckyegg`／Ovo da Sorte（幸運蛋） | 普通 | XP 獲得 +15% | 25 |
| main:2258 | `amuletcoin`／Moeda Amuleto（護符金幣） | 普通 | 金幣獲得 +30% | 25 |
| main:2268 | `softsand`／Areia Macia（柔軟沙） | 普通 | 招式持續時間 +8% | 25 |
| main:2278 | `choiceband`／Faixa Escolhida（講究頭帶） | 不普通 | 傷害 +15% | 25 |
| main:2288 | `scopelens`／Lente Mira（焦點鏡） | 不普通 | 暴擊率 +8% | 25 |
| main:2298 | `quickclaw`／Garra Rápida（先制之爪） | 不普通 | 攻擊速度 +10% | 25 |
| main:2308 | `widelens`／Lente Ampla（廣角鏡） | 不普通 | 招式尺寸 +10% | 25 |
| main:2318 | `shellbell`／Sino Concha（貝殼之鈴） | 稀有 | 造成傷害的 1% 轉為治療 | 25 |
| main:2328 | `razorclaw`／Garra Afiada（銳利之爪） | 稀有 | 暴擊傷害 +0.4 | 25 |
| main:2338 | `airballoon`／Balão（氣球） | 稀有 | 額外一次跳躍 | 25 |
| main:2348 | `expertbelt`／Cinto Expert（達人帶） | 稀有 | 傷害 +12%、移速 +6% | 25 |
| main:2358 | `focussash`／Faixa Foco（氣勢披帶） | 史詩 | 消耗一次以承受致命一擊 | 1 |
| main:2367 | `lifeorb`／Orbe Vida（生命寶珠） | 史詩 | 傷害 +35%、最大 HP ×0.9 | 25 |
| main:2377 | `kingsrock`／Pedra do Rei（王者之證） | 傳說 | 3% 機率即死一般敵人 | 25 |
| main:2387 | `muscleband`／Faixa Muscular（力量頭帶） | 普通 | 傷害 +7% | 25 |
| main:2397 | `soothebell`／Sino Calmante（安撫之鈴） | 普通 | 幸運 +8% | 25 |
| main:2407 | `bigroot`／Raiz Grande（大根莖） | 普通 | 每秒回復 0.5 HP、吸血 +0.4% | 25 |
| main:2417 | `wiseglasses`／Óculos Sábios（博識眼鏡） | 普通 | 效果觸發倍率 +20% | 25 |
| main:2427 | `rockyhelmet`／Capacete Rochoso（凹凸頭盔） | 不普通 | 護甲 +5% | 25 |
| main:2437 | `eviolite`／Evolitos（進化奇石） | 不普通 | 最大 HP +25 | 25 |
| main:2447 | `expshare`／Exp. Share（學習裝置） | 不普通 | XP +8%、拾取距離 +1.5m | 25 |
| main:2457 | `choicescarf`／Lenço Escolha（講究圍巾） | 不普通 | 移速 +8% | 25 |
| main:2467 | `dragonfang`／Presa de Dragão（龍之牙） | 稀有 | 同屬性招式傷害 +15% | 25 |
| main:2477 | `bindingband`／Faixa Atadora（緊束帶） | 稀有 | 所有招式穿透 +1 | 25 |
| main:2487 | `assaultvest`／Colete de Assalto（突擊背心） | 稀有 | 護甲 +10%、攻擊速度 -5% | 25 |
| main:2497 | `blackbelt`／Faixa Preta（黑帶） | 史詩 | 對 Boss／菁英傷害 +35% | 25 |
| main:2507 | `shinycharm`／Amuleto Brilhante（閃耀護符） | 史詩 | 幸運 +20%、XP +10% | 25 |
| main:2517 | `deepseatooth`／Dente Abissal（深海之牙） | 史詩 | 傷害 +22%、攻擊速度 -8% | 25 |
| main:2527 | `souldew`／Orvalho da Alma（心之水滴） | 傳說 | 最大 HP +40%、每秒回復 +1.5 HP | 25 |
| main:2537 | `griseousorb`／Orbe Platinado（白金寶珠） | 傳說 | 傷害 +45%、攻擊速度 +15% | 25 |
| main:2547 | `masterball`／Insígnia Mestre（大師徽章） | 傳說 | 所有招式數量 +1 | 25 |

一般 item 軟上限按稀有度分別是 99／99／99／8／3，所有 item 的全域上限 25；一次性道具例外只拿 1 個。達上限的寶箱改成三選一：全回復、Mega 充能 60%、或結算 +15 PB。 (`main:3646、main:3679`、`main:30600、main:30632`)

## 能力卡（14）

能力卡從玩家等級 3 開始出現，上限 3 張；權重由稀有度決定，不是每次保證有能力卡。 (`main:3550、main:3564`、`main:5029、main:5058`)

| 行 | ID／pt-BR 名稱（中文） | 稀有度 | 效果 |
|---:|---|---|---|
| main:3399 | `static`／Estática（靜電） | 不普通 | 20% 命中率使敵人麻痺 1 秒 |
| main:3409 | `flamebody`／Corpo Chamejante（火焰之軀） | 不普通 | 碰觸者承受反彈傷害 |
| main:3418 | `adaptability`／Adaptabilidade（適應力） | 稀有 | 同屬性招式 +40% 傷害 |
| main:3430 | `technician`／Técnico（技術高手） | 不普通 | 基礎傷害 ≤20 的招式傷害 +50% |
| main:3439 | `moxie`／Autoconfiança（自信過度） | 稀有 | 每次擊殺永久 +0.2% 傷害，本局上限 +60% |
| main:3448 | `speedboost`／Acelerar（加速） | 不普通 | 每存活 1 分鐘，攻擊速度 +5% |
| main:3457 | `multiscale`／Multiescamas（多重鱗片） | 不普通 | 滿 HP 時只承受一半傷害 |
| main:3466 | `skilllink`／Elo de Habilidade（技能連結） | 史詩 | 所有招式 +1 投射物、+1 連鎖、+1 穿透 |
| main:3478 | `sheerforce`／Força Bruta（強行） | 稀有 | 傷害 +35%，但擊退歸零 |
| main:3490 | `superluck`／Super Sorte（超幸運） | 不普通 | 暴擊率 +15%，暴擊傷害 +50% |
| main:3502 | `regenerator`／Regenerador（再生力） | 不普通 | 3 秒未受傷後，每秒回復最大 HP 的 3% |
| main:3511 | `serenegrace`／Graça Serena（天恩） | 稀有 | 幸運 +40%，效果觸發機率 ×2 |
| main:3523 | `hugepower`／Força Enorme（大力士） | 傳說 | 傷害 +80%，移速 -10% |
| main:3535 | `pressure`／Pressão（壓力） | 稀有 | 7 m 內敵人移動速度 -35% |

## 等級升級、reroll、banish、skip

- 每次等級提升給 3 張卡；普通加權池：每把現有武器升級權重 3、新武器 0.9、維他命升級 2.5、新維他命 0.9、能力依稀有度 0.45／0.38／0.28／0.18／0.08。每類候選各抽取一次後不重複；玩家前 3 級有新招時會保證保留至少一張新招。 (`main:3550、main:3577`、`main:5029、main:5058`)
- 武器上限 4、維他命上限 4、能力上限 3；未進化且武器等級 ≥5 並持有對應維他命時，會優先顯示進化卡。武器升級稀有度係數為 1／1.3／1.7／2.2／3；每卡抽 1／1／2／2／3 種屬性，整數成長量是 1／1／1／2／2。 (`main:3550、main:3567`、`main:4974、main:4977`、`main:4980、main:5018`)
- 初始 3 次 reroll、2 次 banish、3 次 skip；每 3 級得 1 次 reroll，每 4 級得 1 次 skip；單張升級畫面最多 reroll 3 次。Boss 再給 +2 reroll、+1 banish、+1 skip；banish 只排除新武器／新維他命／新能力卡，不會排除升級卡。 (`main:3558、main:3577`、`main:31100、main:31220`、`main:30460、main:30484`)
- Skip 會把該次等級轉成 `round(5 + level × 2)` 金幣；Boss 基礎獎勵含 20 份 XP、25 枚硬幣、2 個 Mega 碎片、2 個免費寶箱和 1 個磁鐵。 (`main:31210、main:31228`、`main:30460、main:30485`)

寶箱高稀有度可用降低維他命等級、消耗 reroll／banish／skip，或接受 run 內詛咒付款；這是寶箱付款選項，不是升級卡的常規價格。 (`main:30658、main:30710`)
