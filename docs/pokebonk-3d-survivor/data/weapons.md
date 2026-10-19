# 招式／武器資料

數值口徑：本表是 bundle 預設。已存的 api-config.json 快照另有線上覆寫；其作用依模式／難度／標籤而變，見 [bundle 分析的遠端平衡節](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/codex-bundle-analysis.md#遠端平衡-api-config)。例如 Thunderbolt bundle 傷害 27.2、快照全域值 28.8；Mega bundle 傷害 +60%／碎片值 0.14，Classic/Normal 線上覆寫分別為 +80%／0.22。

資料合併關係：新武器 `ne` 22 招，`Object.assign(ne, eu)` 再接入舊武器 `eu` 29 招；合計 51 招。通用 base schema 只有傷害、冷卻、數量、尺寸、速度、持續、穿透、擊退、連鎖，沒有共同的「射程」欄位；因此下表以每招描述和程式定位整理判定形狀，**數值射程未找到為共同資料**。`pierce=99` 表示程式採用的近似無限穿透值。 (schema `main:103`、新武器 `main:1668、main:1986`、舊武器 `main:532、main:793`)

| 行 | ID／pt-BR 名稱（中文） | 基礎數值 | 判定／距離形狀 | 升級池 |
|---:|---|---|---|---|
| main:1667 | `thunderbolt` · Choque do Trovão（電擊） | 傷害 27.2／CD 1.15 秒／數量 1／穿透 0／擊退 1／連鎖 3 | 自動連鎖附近敵人，基礎 3 次跳躍 | 傷害、冷卻、數量、連鎖次數 |
| main:1689 | `flamethrower` · Lança-Chamas（噴射火焰） | 傷害 5／CD 0.11 秒／數量 1／穿透 ∞／擊退 0.15／連鎖 0 | 玩家朝向的連續火焰射線，可穿透 | 傷害、範圍尺寸、持續時間、數量 |
| main:1710 | `hydropump` · Hidro Bomba（水炮） | 傷害 24／CD 1.1 秒／數量 1／穿透 3／擊退 7／連鎖 0 | 兩股水柱向前推退並穿刺 | 傷害、冷卻、數量、穿透、擊退 |
| main:1720 | `psychic` · Psíquico（精神強念） | 傷害 24／CD 1.6 秒／數量 1／穿透 0／擊退 1／連鎖 0 | 抓取一群近身敵人、升空後砸地 | 傷害、冷卻、數量、範圍尺寸 |
| main:1731 | `twister` · Tornado（龍捲風） | 傷害 8／CD 2.5 秒／數量 1／穿透 0／擊退 1／連鎖 0 | 遊走龍捲風，吸入並持續傷害 | 傷害、冷卻、數量、範圍尺寸、持續時間 |
| main:1741 | `judgment` · Julgamento（制裁光礫） | 傷害 30／CD 2.6 秒／數量 2／穿透 0／擊退 3／連鎖 0 | 從天空落下的光柱，基礎 2 道 | 傷害、冷卻、數量、範圍尺寸 |
| main:1752 | `shadowball` · Bola Sombria（暗影球） | 傷害 42／CD 1.35 秒／數量 1／穿透 1／擊退 3／連鎖 0 | 追蹤敵人的暗影球 | 傷害、冷卻、數量、穿透、飛行速度 |
| main:1772 | `razorleaf` · Folha Navalha（飛葉快刀） | 傷害 12／CD 1.6 秒／數量 3／穿透 ∞／擊退 1／連鎖 0 | 來回飛行的葉片迴力鏢，可穿透 | 傷害、冷卻、數量、飛行速度 |
| main:1792 | `icebeam` · Raio de Gelo（冰凍光束） | 傷害 28.8／CD 1.25 秒／數量 1／穿透 2／擊退 1／連鎖 0 | 基礎冰束附 slowT=2 秒；進化另有 1.5 秒暈眩與 3 秒減速（main:14105-14166、30394） | 傷害、冷卻、數量、穿透 |
| main:1813 | `earthquake` · Terremoto（地震） | 傷害 32／CD 3.3 秒／數量 1／穿透 0／擊退 9／連鎖 0 | 以玩家為中心的地面衝擊波 | 傷害、冷卻、範圍尺寸、擊退 |
| main:1823 | `surf` · Surfe（衝浪） | 傷害 22／CD 2.6 秒／數量 1／穿透 0／擊退 8／連鎖 0 | 從玩家向外擴大的環形水浪 | 傷害、冷卻、範圍尺寸、擊退 |
| main:1833 | `watershuriken` · Shuriken de Água（飛水手裡劍） | 傷害 14.3／CD 0.7 秒／數量 2／穿透 2／擊退 1.5／連鎖 0 | 快速直線手裏劍，可穿刺 | 傷害、冷卻、數量、穿透、飛行速度 |
| main:1852 | `dragonpulse` · Pulso do Dragão（龍之波動） | 傷害 32.4／CD 2.1 秒／數量 1／穿透 ∞／擊退 2／連鎖 0 | 全群貫穿的直線龍波 | 傷害、冷卻、數量、範圍尺寸 |
| main:1872 | `torchsong` · Canção da Tocha（閃焰高歌） | 傷害 14／CD 1.5 秒／數量 1／穿透 0／擊退 2／連鎖 0 | 追蹤敵人並爆炸的火鳥 | 傷害、冷卻、數量、範圍尺寸、飛行速度 |
| main:1881 | `ragefist` · Punho da Fúria（憤怒之拳） | 傷害 12／CD 0.65 秒／數量 1／穿透 0／擊退 4／連鎖 0 | 幽靈拳連擊，第三拳重擊；受擊增傷 | 傷害、冷卻、範圍尺寸、擊退 |
| main:1900 | `aurasphere` · Esfera de Aura（波導彈） | 傷害 23／CD 1.35 秒／數量 1／穿透 0／擊退 3／連鎖 0 | 蓄力後追蹤目標並爆炸的氣功彈 | 傷害、冷卻、數量、範圍尺寸、飛行速度 |
| main:1919 | `closecombat` · Close Combat（近身戰） | 傷害 28／CD 1.25 秒／數量 1／穿透 0／擊退 7／連鎖 0 | 前方四段踢擊，末段重擊並擊退 | 傷害、冷卻、數量、範圍尺寸、擊退 |
| main:1938 | `kowtow` · Corte Supremo（仆刀） | 傷害 30／CD 1.5 秒／數量 1／穿透 0／擊退 5／連鎖 0 | 左右交替的前方大弧斬 | 傷害、冷卻、範圍尺寸、擊退 |
| main:1947 | `makeitrain` · Chuva de Moedas（淘金潮） | 傷害 7／CD 1.7 秒／數量 2／穿透 0／擊退 1／連鎖 0 | 從敵人上方落下硬幣，可能轉為地面拾取物 | 傷害、冷卻、數量、範圍尺寸 |
| main:1956 | `earthpower` · Poder da Terra（大地之力） | 傷害 31.2／CD 2.1 秒／數量 1／穿透 0／擊退 3／連鎖 0 | 沿地面延伸並連續爆炸的裂縫 | 傷害、冷卻、數量、範圍尺寸 |
| main:1975 | `headlongrush` · Investida de Cabeça（突飛猛撲） | 傷害 30／CD 2.4 秒／數量 1／穿透 0／擊退 8／連鎖 0 | 沿直線突進，終點撞擊並炸開通道 | 傷害、冷卻、範圍尺寸、飛行速度 |
| main:1985 | `iciclecrash` · Queda de Estalactite（冰柱墜擊） | 傷害 16／CD 2.2 秒／數量 1／穿透 0／擊退 1／連鎖 0 | 目標範圍落下冰柱並暈眩 | 傷害、冷卻、數量、範圍尺寸 |
| main:531 | `xscissor` · Tesoura X（十字剪） | 傷害 24／CD 1.3 秒／數量 1／穿透 0／擊退 3／連鎖 0 | 玩家前方交叉兩刃，中央雙段命中 | 傷害、冷卻、數量、範圍尺寸 |
| main:541 | `quickattack` · Ataque Rápido（電光一閃） | 傷害 14／CD 0.95 秒／數量 2／穿透 ∞／擊退 2／連鎖 0 | 沿前向直線快速劃過，描述稱可掃過全場 | 傷害、冷卻、數量、飛行速度 |
| main:550 | `bubblebeam` · Raio de Bolhas（泡沫光線） | 傷害 14／CD 1 秒／數量 3／穿透 0／擊退 2／連鎖 0 | 慢速泡泡，命中後範圍爆開並控場 | 傷害、冷卻、數量、範圍尺寸 |
| main:559 | `needlestorm` · Agulhas Elétricas（電擊針雨） | 傷害 9／CD 1 秒／數量 5／穿透 1／擊退 1／連鎖 0 | 前方扇形連射，可穿刺 | 傷害、冷卻、數量、飛行速度 |
| main:568 | `firespin` · Rodamoinho de Fogo（火焰旋渦） | 傷害 9／CD 3.4 秒／數量 3／穿透 0／擊退 1／連鎖 0 | 環繞玩家的旋轉火柱 | 傷害、冷卻、數量、範圍尺寸、持續時間 |
| main:577 | `psybeam` · Psicoraio（幻象光線） | 傷害 15／CD 2.2 秒／數量 1／穿透 0／擊退 1／連鎖 0 | 向前以寬弧掃過的螺旋光束 | 傷害、冷卻、範圍尺寸、持續時間 |
| main:586 | `darkpulse` · Pulso Sombrio（惡之波動） | 傷害 22／CD 1.7 秒／數量 3／穿透 ∞／擊退 3／連鎖 0 | 前方扇形波動，可穿透 | 傷害、冷卻、數量、範圍尺寸 |
| main:595 | `leafblade` · Lâmina de Folha（葉刃） | 傷害 18／CD 0.9 秒／數量 1／穿透 0／擊退 2／連鎖 0 | 左右兩側短距離突刺 | 傷害、冷卻、範圍尺寸、數量 |
| main:604 | `iceshard` · Cacos de Gelo（冰礫） | 傷害 7／CD 0.7 秒／數量 3／穿透 1／擊退 1／連鎖 0 | 多枚冰片射向目標並凍結 | 傷害、冷卻、數量、飛行速度 |
| main:613 | `charmvoice` · Voz Encantadora（魅惑之聲） | 傷害 15／CD 2 秒／數量 2／穿透 0／擊退 4／連鎖 0 | 由玩家向外擴張的心形環 | 傷害、冷卻、數量、範圍尺寸 |
| main:622 | `blazekick` · Chute Flamejante（火焰踢） | 傷害 32／CD 2 秒／數量 1／穿透 0／擊退 5／連鎖 0 | 跳向目標後落地，形成火環 | 傷害、冷卻、範圍尺寸、數量 |
| main:631 | `blueflare` · Fogo Azul（青焰） | 傷害 40／CD 3 秒／數量 1／穿透 ∞／擊退 4／連鎖 0 | 直線穿群的大火球，命中後爆炸 | 傷害、冷卻、範圍尺寸、數量 |
| main:640 | `fusionbolt` · Raio de Fusão（交錯閃電） | 傷害 45／CD 2.4 秒／數量 1／穿透 0／擊退 4／連鎖 0 | 目標位置落雷並留地面電場 | 傷害、冷卻、數量、範圍尺寸 |
| main:649 | `behemothblade` · Lâmina Colossal（巨獸斬） | 傷害 38／CD 1.8 秒／數量 1／穿透 ∞／擊退 3／連鎖 0 | 前方大型斬擊並放出切波 | 傷害、冷卻、範圍尺寸、飛行速度 |
| main:658 | `behemothbash` · Escudada Colossal（巨獸彈） | 傷害 34／CD 2.2 秒／數量 1／穿透 0／擊退 10／連鎖 0 | 前方錐形盾擊波，推退和暈眩 | 傷害、冷卻、範圍尺寸、擊退 |
| main:667 | `dragondarts` · Dardos de Dragão（龍箭） | 傷害 22／CD 1.8 秒／數量 2／穿透 1／擊退 2／連鎖 0 | 兩枚跟隨玩家的飛彈，射出後返回 | 傷害、冷卻、數量、飛行速度 |
| main:676 | `sacredfire` · Fogo Sagrado（神聖之火） | 傷害 36／CD 2.6 秒／數量 1／穿透 0／擊退 3／連鎖 0 | 目標處十字火爆炸並留火地 | 傷害、冷卻、範圍尺寸、持續時間 |
| main:685 | `glaciate` · Glaciar（冰封世界） | 傷害 26／CD 2.3 秒／數量 1／穿透 0／擊退 3／連鎖 0 | 前方大型扇形冰浪 | 傷害、冷卻、範圍尺寸、持續時間 |
| main:694 | `spoonblades` · Colheres Psíquicas（精神利刃） | 傷害 18／CD 2.5 秒／數量 3／穿透 ∞／擊退 2／連鎖 0 | 玩家周圍旋轉，向最近敵人發射 | 傷害、冷卻、數量、飛行速度 |
| main:703 | `airslash` · Corte Aéreo（空氣斬） | 傷害 15／CD 0.9 秒／數量 2／穿透 3／擊退 2／連鎖 0 | 前方直線風刃，可多次穿透 | 傷害、冷卻、數量、穿透、飛行速度 |
| main:712 | `willowisp` · Chama Fantasma（鬼火） | 傷害 10／CD 2.8 秒／數量 3／穿透 0／擊退 1／連鎖 0 | 環繞後追蹤敵人的鬼火，持續燃燒 | 傷害、冷卻、數量、持續時間 |
| main:721 | `glasscage` · Jaula de Vidro（玻璃牢籠） | 傷害 55／CD 3 秒／數量 1／穿透 0／擊退 2／連鎖 0 | 定身範圍，延遲後碎裂 | 傷害、冷卻、範圍尺寸、持續時間 |
| main:730 | `metronome` · Metrônomo（揮指） | 傷害 30／CD 1.6 秒／數量 1／穿透 0／擊退 3／連鎖 0 | 隨機抽取一種攻擊形態 | 傷害、冷卻、數量、範圍尺寸 |
| main:739 | `megahorn` · Megachifre（超級角擊） | 傷害 40／CD 2 秒／數量 1／穿透 0／擊退 12／連鎖 0 | 前方直線突刺，擊飛命中目標 | 傷害、冷卻、範圍尺寸、擊退 |
| main:748 | `bonemerang` · Ossomerangue（骨頭回力鏢） | 傷害 26／CD 1.3 秒／數量 1／穿透 ∞／擊退 3／連鎖 0 | 骨頭向外再返回，往返各命中一次 | 傷害、冷卻、數量、範圍尺寸、飛行速度 |
| main:757 | `playrough` · Folguedo（嬉鬧） | 傷害 9／CD 2.6 秒／數量 1／穿透 0／擊退 1／連鎖 0 | 指定敵人處持續約 1.5 秒的連段雲 | 傷害、冷卻、範圍尺寸、持續時間 |
| main:766 | `oblivionwing` · Asa do Esquecimento（死亡之翼） | 傷害 15／CD 1.8 秒／數量 3／穿透 0／擊退 1／連鎖 0 | 追蹤光束命中並按傷害吸血 | 傷害、冷卻、數量、飛行速度 |
| main:775 | `eruption` · Erupção（噴火） | 傷害 24／CD 3.2 秒／數量 6／穿透 0／擊退 3／連鎖 0 | 玩家周圍大範圍隨機落下熔岩球 | 傷害、冷卻、數量、範圍尺寸 |
| main:784 | `psychoboost` · Psico Impulso（精神突進） | 傷害 55／CD 3.2 秒／數量 1／穿透 ∞／擊退 5／連鎖 0 | 穿越整個戰場的直線光束 | 傷害、冷卻、範圍尺寸、持續時間 |

## 通用每級成長與抽卡

基礎升級量為傷害 +15%、冷卻乘以 0.93、數量 +1、尺寸 +12%、速度 +15%、持續 +15%、穿透 +1、擊退 +0.25、連鎖 +1；稀有度會再乘數值係數，且一張卡抽取一至三種升級屬性。武器在等級 8 起仍可升級，但增量按 0.8 的冪次遞減；等級 8 還可觸發一次武器精通卡。 ( `main:3549、main:3577`、`main:4980、main:5028`)

| 稀有度 | 權重（未計幸運） | 一般增量倍率 | 每卡屬性數 | 整數欄位增量 |
|---|---:|---:|---:|---:|
| 普通 | 60 | 1.0 | 1 | 1 |
| 不普通 | 25 | 1.3 | 1 | 1 |
| 稀有 | 10 | 1.7 | 2 | 1 |
| 史詩 | 4 | 2.2 | 2 | 2 |
| 傳說 | 1 | 3.0 | 3 | 2 |

幸運會把第 n 階稀有度權重乘以 `(1 + luck)^(n × 1.2)`。常規升級卡三選一；候選池權重為每把已有武器升級 3、武器新招 0.9、維他命升級 2.5、新維他命 0.9、技能依稀有度 0.45／0.38／0.28／0.18／0.08。新招在前 3 級會保證至少有一張可選；武器上限 4、維他命 4、能力 3，能力從等級 3 開始出現。 ( `main:3550、main:3564`、`main:5029、main:5058`)

Mastery 在武器等級 8 發生：從相容 perk 中抽卡，效果包括低血斬殺雙倍、Boss／菁英 +60% 傷害、擊殺累積短時增傷、+20% 暴擊率、15% 機率追加 60% 傷害、尺寸與持續加成、冷卻降低 25%、穿透 +2；相容性依該武器可升級欄位過濾。 (`main:4850、main:4908`)

## 進化規則與結果

進化條件是未進化且武器等級至少 5，玩家已持有對應維他命；抽卡流程會優先把可進化武器放進選項。進化後此武器標記為 evolved，只進化一次；進化傷害額外乘上設定的 +80% 基礎傷害增幅。 (`main:4974、main:4977`、`main:3558、main:3567`)

| 行 | 招式 ID | 進化名 pt-BR（中文） | 所需維他命／被動 | 進化效果摘要 |
|---:|---|---|---|---|
| main:1997 | `thunderbolt` | Trovão（雷霆） | `zinc`／鋅 | 保留連鎖，另有大型落雷使區域麻痺 |
| main:2004 | `flamethrower` | Explosão de Fogo（爆裂火焰） | `protein`／蛋白質 | 火球星形爆開並留下燃燒地面 |
| main:2010 | `hydropump` | Hidro Canhão（水砲） | `carbos`／速度強化劑 | 每第三發追加貫穿全場的水砲 |
| main:2016 | `psychic` | Psicorruptura（精神崩壞） | `calcium`／鈣 | 抓取半徑擴大，砸地再暈眩殘敵 |
| main:2022 | `twister` | Furacão（颶風） | `dust`／銀粉 | 大型龍捲風把敵人吸向中心 |
| main:2028 | `judgment` | Laser Prismático（稜鏡雷射） | `clover`／幸運草 | 三道彩虹雷射持續環繞玩家 |
| main:2034 | `shadowball` | Força Sombria（暗影力量） | `ppmax`／PP 增加 | 每顆暗影球命中後分裂成三顆 |
| main:2040 | `razorleaf` | Tempestade de Folhas（葉片風暴） | `wing`／速度之羽 | 鋒利葉片環繞貼身旋轉 |
| main:2046 | `icebeam` | Nevasca（暴風雪） | `iron`／鐵 | 週期性暴風雪凍結周圍 1.5 秒 |
| main:2124 | `earthquake` | Lâminas do Precipício（懸崖之刃） | `hpup`／HP 增強 | 震動後長出三圈石刃 |
| main:2052 | `surf` | Hidro Vórtice（水漩渦） | `hpup`／HP 增強 | 水浪回捲拉向中心並爆出水柱 |
| main:2058 | `watershuriken` | Shuriken Gigante（巨大手裏劍） | `wing`／速度之羽 | 每第四次投擲追加巨大穿透手裏劍 |
| main:2064 | `dragonpulse` | Meteoro do Dragão（龍星群） | `calcium`／鈣 | 龍波之後在敵人頭上落下隕石 |
| main:2070 | `torchsong` | Canção Infernal（地獄之歌） | `protein`／蛋白質 | 每次命中提高招式傷害，最多 +60% |
| main:2076 | `ragefist` | Fúria Final（終極憤怒之拳） | `zinc`／鋅 | 第五拳成為巨大上勾拳並在接觸時放出幽靈波 |
| main:2082 | `aurasphere` | Aura Absoluta（絕對波導） | `calcium`／鈣 | 氣彈變大、增加一次蓄力並擴大爆炸 |
| main:2088 | `closecombat` | Combate Implacável（無情近身戰） | `protein`／蛋白質 | 每套追加兩腳並加強終結踢 |
| main:2094 | `kowtow` | Guilhotina（斷頭斬） | `clover`／幸運草 | 改成 360° 斬擊並處決低於 20% HP 的敵人 |
| main:2100 | `makeitrain` | Corrida do Ouro（淘金狂潮） | `magnet`／磁鐵 | 硬幣爆炸範圍更大且產出更多金錢 |
| main:2106 | `earthpower` | Fissura（大地裂隙） | `iron`／鐵 | 裂縫維持 3 秒，灼燒踩入者 |
| main:2112 | `headlongrush` | Atropelo（猛衝） | `carbos`／速度強化劑 | 爆炸後沿原路返回 |
| main:2118 | `iciclecrash` | Ruína Glacial（冰河遺跡） | `rarecandy`／神奇糖果 | 冰柱再碎裂爆炸並凍結 |
| main:794 | `xscissor` | Estrela Cortante（銳利星刃） | `iron`／鐵 | 追加一個旋轉 45° 的 X，組成八刃星 |
| main:801 | `quickattack` | Velocidade Extrema（神速） | `wing`／速度之羽 | 每道影子變寬並接續攻擊另一個敵人 |
| main:807 | `bubblebeam` | Bolhas Gigantes（巨大泡泡） | `carbos`／速度強化劑 | 每輪射擊追加巨大拘束泡泡，爆裂成波 |
| main:813 | `needlestorm` | Tempestade de Agulhas（針雨風暴） | `zinc`／鋅 | 針刺命中後電弧跳向最近敵人 |
| main:819 | `firespin` | Espiral Infernal（煉獄螺旋） | `protein`／蛋白質 | 兩圈反向旋轉火柱，攻擊半徑擴大 |
| main:825 | `psybeam` | Raio Prisma（稜鏡光束） | `calcium`／鈣 | 光束環繞 360° 並留下彩色軌跡 |
| main:831 | `darkpulse` | Aura Lunar（月光氣場） | `clover`／幸運草 | 同時向八個方向放出暗波 |
| main:837 | `leafblade` | Lâmina Verdejante（翠綠之刃） | `wing`／速度之羽 | 每次突刺再射出直線葉刃 |
| main:843 | `iceshard` | Chuva de Cacos（碎冰雨） | `dust`／銀粉 | 追加從天而降的冰晶 |
| main:849 | `charmvoice` | Voz Sedutora（魅惑之聲） | `clover`／幸運草 | 被光環命中者暫停並承受更多傷害 |
| main:855 | `blazekick` | Pé de Fogo Explosivo（爆裂火焰踢） | `protein`／蛋白質 | 連續跳向三個目標，每次落地爆炸 |
| main:861 | `blueflare` | Fogo Fusão（融合青焰） | `magnet`／磁鐵 | 火球裂成六枚環繞燃燒的青焰 |
| main:867 | `fusionbolt` | Trovão Azul（蒼雷） | `zinc`／鋅 | 連續落下三道雷並延長電場 |
| main:873 | `behemothblade` | Lâmina Real（王者之刃） | `iron`／鐵 | 切波分裂成三道扇形斬擊 |
| main:879 | `behemothbash` | Muralha Colossal（巨獸城壁） | `hpup`／HP 增強 | 盾擊擴為全周衝擊環並再推一次 |
| main:885 | `dragondarts` | Enxame de Dreepys（多龍箭群） | `calcium`／鈣 | 增加為四枚龍箭，每次撞擊爆炸 |
| main:891 | `sacredfire` | Fogo Sagrado Arco-íris（虹彩神聖之火） | `wing`／速度之羽 | 十字擴為八方向虹彩火並回復生命 |
| main:897 | `glaciate` | Zero Absoluto（絕對零度） | `dust`／銀粉 | 扇形冰浪擴為全周並刺出冰柱 |
| main:903 | `spoonblades` | Chuva de Colheres（湯匙暴雨） | `calcium`／鈣 | 增加至六把、變大且穿透 |
| main:909 | `airslash` | Ciclone Cortante（斬切旋風） | `wing`／速度之羽 | 風刃折返再次命中 |
| main:915 | `willowisp` | Chamas do Além（冥界鬼火） | `protein`／蛋白質 | 增加至六團，燃燒會傳染附近敵人 |
| main:921 | `glasscage` | Vitrine Quebrada（碎裂玻璃櫃） | `clover`／幸運草 | 同時出現兩座牢籠並向四周噴射碎片 |
| main:927 | `metronome` | Metrônomo Caótico（混沌揮指） | `clover`／幸運草 | 每次同時施展兩種隨機攻擊且傷害提高 |
| main:933 | `megahorn` | Megachifre Furioso（狂暴超級角擊） | `protein`／蛋白質 | 扇形三連突刺並震倒整個區域 |
| main:939 | `bonemerang` | Dança dos Ossos（骨舞） | `hpup`／HP 增強 | 增加骨頭數，每次返回時發出塵浪 |
| main:945 | `playrough` | Folguedo Total（全力嬉鬧） | `clover`／幸運草 | 兩團更大的連擊雲，追加重擊 |
| main:951 | `oblivionwing` | Asa da Destruição（毀滅之翼） | `hpup`／HP 增強 | 增加至五道光束並提高每次吸血 |
| main:957 | `eruption` | Erupção Total（全面噴發） | `carbos`／速度強化劑 | 熔岩球數量翻倍，玩家周圍先爆炸 |
| main:963 | `psychoboost` | Impulso Absoluto（極限精神突進） | `calcium`／鈣 | 相反方向兩道光束，留下精神火地 |

## 防疊加傷害折扣（非圖鑑 Combo）

「Tempestade Divina」是防止三招疊加過強的傷害折扣，不是套裝獎勵：同時持有 Dragon Pulse、Twister、Judgment 中兩招時，相關傷害乘 0.85；三招全持有時乘 0.60。定義在 main:3601，addWeapon 檢查在 main:27394-27409，傷害乘數套用在 main:7891、7914。

這與 16 組圖鑑 Combo 分開：Combo 只檢查持有條件並顯示完成橫幅，不改戰鬥數值。清單見 [Combo 資料](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/combos.md)（main:17232-17345、18497、31006-31024）。
