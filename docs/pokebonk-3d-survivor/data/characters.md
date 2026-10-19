# 角色資料

數值口徑：角色表列的是 bundle 預設；線上覆寫見 [bundle 分析「遠端平衡」](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/codex-bundle-analysis.md#遠端平衡-api-config)。已存的 api-config.json 快照沒有角色專屬鍵；共用傷害、速度等係數仍可能間接改變角色實際值。被動欄保留 bundle 的 pt-BR 原文。

共用預設值見 `main:3970、main:3997`；下表的「基礎覆寫」只列角色覆寫預設的欄位，「每級」是每升一級直接相加的數值（不是百分比字串）。主 roster `Se` 有 44 筆，隨後 `Se.push(...Zh)` 又把 29 筆舊角色加入同一選擇資料，所以實際角色資料共有 73 筆。主要 roster 行號 `main:1048、main:1666`，舊角色 `main:123、main:529`。

## 主 roster（44）

| 行 | ID／中文名 | 屬性 | 起始招式（ID／中文） | 基礎覆寫 | 每級 | 跳躍 | 被動（pt-BR 原文） | 解鎖 | 
|---:|---|---|---|---|---|---:|---|---|
| main:1049 | `pikachu`／皮卡丘 | 電 | `thunderbolt`／電擊 | maxHp: 90, moveSpeed: 1.15 | attackSpeed: 0.02 | 1 | Estática: +2% velocidade de ataque por nível（main:1058） | 預設解鎖 |
| main:1063 | `charizard`／噴火龍 | 火／飛行 | `flamethrower`／噴射火焰 | maxHp: 115, damage: 1.1 | damage: 0.02 | 2 | Chama Interior: +2% dano por nível · Pulo duplo（main:1072） | 預設解鎖 |
| main:1077 | `blastoise`／水箭龜 | 水 | `hydropump`／水炮 | maxHp: 155, armor: 0.1, moveSpeed: 0.9 | armor: 0.01 | 1 | Casco: +1% armadura por nível（main:1086） | 預設解鎖 |
| main:1091 | `mewtwo`／超夢 | 超能力 | `psychic`／精神強念 | maxHp: 95, xpGain: 1.1 | size: 0.02 | 2 | Pressão: +2% tamanho por nível · Levitação (pulo duplo)（main:1100） | 任務：同局達到等級 40（任務 ID 名稱仍為 lv30） |
| main:1105 | `rayquaza`／烈空坐 | 龍／飛行 | `twister`／龍捲風 | maxHp: 120, moveSpeed: 1.1 | moveSpeed: 0.015 | 3 | Céu: +1.5% velocidade por nível · Pulo triplo（main:1114） | 任務：以 12 隻以上 Boss 陣容獲勝 |
| main:1119 | `arceus`／阿爾宙斯 | 一般 | `judgment`／制裁光礫 | maxHp: 130, luck: 0.15 | luck: 0.015 | 2 | Multitipo: +1.5% sorte por nível · Pulo duplo（main:1128） | 任務：累積勝利 5 局且至少通過 1 次 Bonk 傳送門 |
| main:1133 | `dragonite`／快龍 | 龍／飛行 | `earthquake`／地震 | maxHp: 140, damage: 1.05, moveSpeed: 0.95 | maxHp: 6, damage: 0.015 | 2 | Multiescama: +6 HP e +1.5% dano por nível · Pulo duplo（main:1142） | 任務：遊玩 10 局 |
| main:1147 | `lugia`／洛奇亞 | 超能力／飛行 | `icebeam`／冰凍光束 | maxHp: 125, projSpeed: 1.15, duration: 1.1 | duration: 0.02, projSpeed: 0.015 | 3 | Sopro Aéreo: +2% duração e +1.5% vel. dos projéteis por nível · Pulo triplo（main:1156） | 任務：以 6 隻以上 Boss 陣容獲勝 |
| main:1161 | `feraligatr`／大力鱷 | 水 | `surf`／衝浪 | maxHp: 150, knockback: 1.15, moveSpeed: 0.95 | maxHp: 8, knockback: 0.02 | 1 | Torrente: +8 HP e +2% empurrão por nível（main:1170） | 預設解鎖 |
| main:1175 | `greninja`／甲賀忍蛙 | 水／惡 | `watershuriken`／飛水手裡劍 | maxHp: 90, moveSpeed: 1.2, attackSpeed: 1.05 | attackSpeed: 0.025 | 3 | Proteano: +2.5% vel. de ataque por nível · Pulo triplo（main:1184） | 預設解鎖 |
| main:1189 | `flygon`／沙漠蜻蜓 | 地面／龍 | `dragonpulse`／龍之波動 | maxHp: 110, size: 1.1 | size: 0.02 | 3 | Levitação: +2% tamanho por nível · Pulo triplo（main:1198） | 商店 250 PB |
| main:1203 | `skeledirge`／骨紋巨聲鱷 | 火／幽靈 | `torchsong`／閃焰高歌 | maxHp: 135, damage: 1.05, moveSpeed: 0.92 | damage: 0.025 | 1 | Inabalável: +2.5% dano por nível（main:1212） | 商店 300 PB |
| main:1217 | `annihilape`／棄世猴 | 格鬥／幽靈 | `ragefist`／憤怒之拳 | maxHp: 130, lifesteal: 0.02 | damage: 0.015, lifesteal: 0.003 | 2 | Espírito Vital: +1.5% roubo de vida a cada 5 níveis · +1.5% dano por nível（main:1226） | 商店 300 PB |
| main:1231 | `kingambit`／仆刀將軍 | 惡／鋼 | `kowtow`／仆刀 | maxHp: 145, armor: 0.12, moveSpeed: 0.9 | armor: 0.01, crit: 0.01 | 1 | General Supremo: +1% armadura e +1% crítico por nível（main:1240） | 任務：至少 3 人在線存活 300 秒 |
| main:1245 | `gholdengo`／賽富豪 | 鋼／幽靈 | `makeitrain`／淘金潮 | maxHp: 115, moneyGain: 1.3, luck: 0.1 | moneyGain: 0.04, luck: 0.01 | 2 | Corpo de Ouro: +4% dinheiro e +1% sorte por nível（main:1254） | 任務：同局持有 800 金幣 |
| main:1259 | `landorus`／土地雲 | 地面／飛行 | `earthpower`／大地之力 | maxHp: 120, damage: 1.08 | damage: 0.015, moveSpeed: 0.01 | 2 | Intimidar: +1.5% dano e +1% velocidade por nível · Pulo duplo（main:1268） | 商店 400 PB |
| main:1273 | `greattusk`／雄偉牙 | 地面／格鬥 | `headlongrush`／突飛猛撲 | maxHp: 160, knockback: 1.2, moveSpeed: 0.93 | maxHp: 10, knockback: 0.02 | 1 | Protossíntese: +10 HP e +2% empurrão por nível（main:1282） | 商店 300 PB |
| main:1287 | `chienpao`／古劍豹 | 惡／冰 | `iciclecrash`／冰柱墜擊 | maxHp: 85, moveSpeed: 1.18, crit: 0.12 | crit: 0.015, critMult: 0.03 | 2 | Espada da Ruína: +1.5% crítico e +3% dano crítico por nível · Pulo duplo（main:1296） | 商店 350 PB |
| main:1301 | `celebi`／時拉比 | 超能力／草 | `razorleaf`／飛葉快刀 | maxHp: 90, regen: 1.2 | regen: 0.08, attackSpeed: 0.015 | 3 | Cura Natural: +0.08 regeneração e +1.5% vel. de ataque por nível · Pulo triplo（main:1310） | 任務：在 Noite Sombria（暗夜）模式獲勝 |
| main:1315 | `mew`／夢幻 | 超能力 | `psychic`／精神強念 | maxHp: 100, luck: 0.12 | luck: 0.012, xpGain: 0.015 | 3 | Sincronia: +1.2% sorte e +1.5% XP por nível · Pulo triplo（main:1324） | 任務：遊玩 30 局 |
| main:1329 | `zapdos`／閃電鳥 | 電／飛行 | `thunderbolt`／電擊 | maxHp: 115, attackSpeed: 1.08 | attackSpeed: 0.022 | 3 | Pressão: +2.2% vel. de ataque por nível · Pulo triplo（main:1338） | 商店 600 PB |
| main:1343 | `moltres`／火焰鳥 | 火／飛行 | `flamethrower`／噴射火焰 | maxHp: 115, damage: 1.1 | damage: 0.022 | 3 | Pressão: +2.2% dano por nível · Pulo triplo（main:1352） | 商店 600 PB |
| main:1357 | `articuno`／急凍鳥 | 冰／飛行 | `icebeam`／冰凍光束 | maxHp: 125, armor: 0.06 | armor: 0.008, duration: 0.02 | 3 | Pressão: +0.8% armadura e +2% duração por nível · Pulo triplo（main:1366） | 商店 600 PB |
| main:1371 | `entei`／炎帝 | 火 | `torchsong`／閃焰高歌 | maxHp: 150, damage: 1.06 | maxHp: 7, damage: 0.015 | 2 | Fogo Interior: +7 HP e +1.5% dano por nível · Pulo duplo（main:1380） | 商店 700 PB |
| main:1385 | `suicune`／水君 | 水 | `surf`／衝浪 | maxHp: 140, moveSpeed: 1.1 | moveSpeed: 0.012, regen: 0.05 | 2 | Absorção de Água: +1.2% velocidade e +0.05 regeneração por nível · Pulo duplo（main:1394） | 商店 700 PB |
| main:1399 | `raikou`／雷公 | 電 | `thunderbolt`／電擊 | maxHp: 125, moveSpeed: 1.15, crit: 0.08 | crit: 0.012, moveSpeed: 0.008 | 2 | Absorção de Volts: +1.2% crítico e +0.8% velocidade por nível · Pulo duplo（main:1408） | 商店 700 PB |
| main:1413 | `gardevoir`／沙奈朵 | 超能力／妖精 | `psychic`／精神強念 | maxHp: 100, size: 1.12 | size: 0.022 | 2 | Rastro: +2.2% tamanho por nível · Pulo duplo（main:1422） | 預設解鎖 |
| main:1427 | `lucario`／路卡利歐 | 格鬥／鋼 | `aurasphere`／波導彈 | maxHp: 110, attackSpeed: 1.05, crit: 0.08 | crit: 0.01, damage: 0.015 | 2 | Foco Interior: +1% crítico e +1.5% dano por nível · Pulo duplo（main:1436） | 預設解鎖 |
| main:1441 | `palkia`／帕路奇亞 | 水／龍 | `hydropump`／水炮 | maxHp: 150, size: 1.1 | size: 0.015, damage: 0.015 | 2 | Pressão: +1.5% tamanho e +1.5% dano por nível · Pulo duplo（main:1450） | 任務：累積 Mega 進化 15 次 |
| main:1455 | `dialga`／帝牙盧卡 | 鋼／龍 | `dragonpulse`／龍之波動 | maxHp: 160, armor: 0.1, moveSpeed: 0.92 | armor: 0.008, duration: 0.02 | 1 | Pressão: +0.8% armadura e +2% duração por nível（main:1464） | 任務：累積擊敗 40 隻 Boss |
| main:1469 | `giratina`／騎拉帝納 | 幽靈／龍 | `shadowball`／暗影球 | maxHp: 170, damage: 1.05, moveSpeed: 0.95 | maxHp: 9, damage: 0.012 | 2 | Pressão: +9 HP e +1.2% dano por nível · Pulo duplo（main:1478） | 任務：在 Bonk 模式通過傳送門 |
| main:1483 | `jirachi`／基拉祈 | 鋼／超能力 | `judgment`／制裁光礫 | maxHp: 95, luck: 0.2 | luck: 0.02 | 3 | Graça Serena: +2% sorte por nível · Pulo triplo（main:1492） | 任務：贏得 1v1 對戰 |
| main:1497 | `lapras`／拉普拉斯 | 水／冰 | `iciclecrash`／冰柱墜擊 | maxHp: 170, armor: 0.08, moveSpeed: 0.9 | maxHp: 9, armor: 0.006 | 1 | Casco Blindado: +9 HP e +0.6% armadura por nível（main:1506） | 預設解鎖 |
| main:1511 | `hitmonlee`／沙瓦郎 | 格鬥 | `closecombat`／近身戰 | maxHp: 105, moveSpeed: 1.15, knockback: 1.2 | knockback: 0.025, attackSpeed: 0.015 | 3 | Flexível: +2.5% empurrão e +1.5% vel. de ataque por nível · Pulo triplo（main:1520） | 預設解鎖 |
| main:1525 | `gengar`／耿鬼 | 幽靈／毒 | `shadowball`／暗影球 | maxHp: 100, damage: 1.08, moveSpeed: 1.08 | damage: 0.02, crit: 0.006 | 2 | Corpo Amaldiçoado: +2% dano e +0.6% crítico por nível · Pulo duplo（main:1534） | 預設解鎖 |
| main:1539 | `wobbuffet`／果然翁 | 超能力 | `earthquake`／地震 | maxHp: 190, armor: 0.1, moveSpeed: 0.88 | maxHp: 12, knockback: 0.02 | 1 | Sombra Presa: +12 HP e +2% empurrão por nível（main:1548） | 預設解鎖 |
| main:1553 | `meowth`／喵喵 | 一般 | `makeitrain`／淘金潮 | maxHp: 90, moveSpeed: 1.12, luck: 0.1 | luck: 0.012, moveSpeed: 0.008 | 2 | Coleta: +1.2% sorte e +0.8% velocidade por nível · Pulo duplo（main:1562） | 預設解鎖 |
| main:1567 | `psyduck`／可達鴨 | 水 | `psychic`／精神強念 | maxHp: 105, size: 1.05 | size: 0.015, xpGain: 0.015 | 1 | Cabeça Nas Nuvens: +1.5% tamanho e +1.5% XP por nível（main:1576） | 預設解鎖 |
| main:1581 | `kyogre`／蓋歐卡 | 水 | `surf`／衝浪 | maxHp: 165, damage: 1.08, moveSpeed: 0.93 | damage: 0.018, size: 0.012 | 1 | Chuvisco: +1.8% dano e +1.2% tamanho por nível（main:1590） | 任務：累積擊殺 20,000 隻 |
| main:1595 | `groudon`／固拉多 | 地面 | `earthpower`／大地之力 | maxHp: 175, armor: 0.1, moveSpeed: 0.9 | damage: 0.018, armor: 0.006 | 1 | Seca: +1.8% dano e +0.6% armadura por nível（main:1604） | 任務：在 Pedreira（採石場）模式獲勝 |
| main:1609 | `darkrai`／達克萊伊 | 惡 | `kowtow`／仆刀 | maxHp: 100, damage: 1.1, crit: 0.1 | crit: 0.012, damage: 0.015 | 2 | Pesadelo: +1.2% crítico e +1.5% dano por nível · Pulo duplo（main:1618） | 任務：在 Restrito（限制）模式獲勝 |
| main:1623 | `latios`／拉帝歐斯 | 龍／超能力 | `dragonpulse`／龍之波動 | maxHp: 110, damage: 1.08, moveSpeed: 1.15 | damage: 0.018, moveSpeed: 0.008 | 3 | Levitação: +1.8% dano e +0.8% velocidade por nível · Pulo triplo（main:1632） | 商店 800 PB |
| main:1637 | `latias`／拉帝亞斯 | 龍／超能力 | `twister`／龍捲風 | maxHp: 120, armor: 0.05, moveSpeed: 1.15 | armor: 0.007, moveSpeed: 0.008 | 3 | Levitação: +0.7% armadura e +0.8% velocidade por nível · Pulo triplo（main:1646） | 商店 800 PB |
| main:1651 | `arcanine`／風速狗 | 火 | `flamethrower`／噴射火焰 | maxHp: 135, moveSpeed: 1.2 | moveSpeed: 0.01, damage: 0.015 | 2 | Intimidar: +1% velocidade e +1.5% dano por nível · Pulo duplo（main:1660） | 預設解鎖 |

## 舊 roster（29，附加在主 roster 後）

這些記錄仍透過 `Se.push(...Zh)` 加入角色目錄，並都有 `jl.char` 商店價。

| 行 | ID／中文名 | 屬性 | 起始招式（ID／中文） | 基礎覆寫 | 每級 | 跳躍 | 被動（pt-BR 原文） | 解鎖 |
|---:|---|---|---|---|---|---:|---|---|
| main:124 | `eevee`／伊布 | 一般 | `quickattack`／電光一閃 | maxHp: 95, moveSpeed: 1.15, luck: 0.1 | luck: 0.012, moveSpeed: 0.008 | 2 | Adaptável: +1.2% sorte e +0.8% velocidade por nível · Pulo duplo（main:133） | 商店 200 PB |
| main:138 | `vaporeon`／水伊布 | 水 | `bubblebeam`／泡沫光線 | maxHp: 140, regen: 1.5 | regen: 0.08, maxHp: 5 | 1 | Absorção de Água: +0.08 regeneração e +5 HP por nível（main:147） | 商店 300 PB |
| main:152 | `jolteon`／雷伊布 | 電 | `needlestorm`／電擊針雨 | maxHp: 95, moveSpeed: 1.2, attackSpeed: 1.05 | attackSpeed: 0.02 | 2 | Absorção de Volts: +2% velocidade de ataque por nível · Pulo duplo（main:161） | 商店 300 PB |
| main:166 | `flareon`／火伊布 | 火 | `firespin`／火焰旋渦 | maxHp: 120, damage: 1.1 | damage: 0.02 | 1 | Fogo Interior: +2% dano por nível（main:175） | 商店 300 PB |
| main:180 | `espeon`／太陽伊布 | 超能力 | `psybeam`／幻象光線 | maxHp: 100, size: 1.1, xpGain: 1.05 | size: 0.018 | 2 | Sincronia: +1.8% tamanho por nível · Pulo duplo（main:189） | 商店 300 PB |
| main:194 | `umbreon`／月亮伊布 | 惡 | `darkpulse`／惡之波動 | maxHp: 150, armor: 0.1, moveSpeed: 0.95 | armor: 0.01, maxHp: 6 | 1 | Sincronia Lunar: +1% armadura e +6 HP por nível（main:203） | 商店 300 PB |
| main:208 | `leafeon`／葉伊布 | 草 | `leafblade`／葉刃 | maxHp: 110, armor: 0.06, crit: 0.06 | crit: 0.012, armor: 0.005 | 2 | Clorofila: +1.2% crítico e +0.5% armadura por nível · Pulo duplo（main:217） | 商店 300 PB |
| main:222 | `glaceon`／冰伊布 | 冰 | `iceshard`／冰礫 | maxHp: 100, attackSpeed: 1.05, crit: 0.06 | attackSpeed: 0.018, crit: 0.008 | 2 | Corpo de Gelo: +1.8% vel. de ataque e +0.8% crítico por nível · Pulo duplo（main:231） | 商店 300 PB |
| main:236 | `sylveon`／仙子伊布 | 妖精 | `charmvoice`／魅惑之聲 | maxHp: 115, regen: 1, luck: 0.05 | regen: 0.06, luck: 0.008 | 2 | Pele de Fada: +0.06 regeneração e +0.8% sorte por nível · Pulo duplo（main:245） | 商店 350 PB |
| main:250 | `scizor`／巨鉗螳螂 | 蟲／鋼 | `xscissor`／十字剪 | maxHp: 125, armor: 0.1, damage: 1.05, moveSpeed: 0.95 | damage: 0.015, armor: 0.008 | 1 | Técnico: +1.5% dano e +0.8% armadura por nível（main:259） | 商店 350 PB |
| main:264 | `blaziken`／火焰雞 | 火／格鬥 | `blazekick`／火焰踢 | maxHp: 115, damage: 1.1, moveSpeed: 1.05 | damage: 0.018, moveSpeed: 0.008 | 3 | Chama: +1.8% dano e +0.8% velocidade por nível · Pulo triplo（main:273） | 商店 350 PB |
| main:278 | `alakazam`／胡地 | 超能力 | `spoonblades`／精神利刃 | maxHp: 90, xpGain: 1.1, size: 1.05 | xpGain: 0.015, size: 0.012 | 2 | Mente Brilhante: +1.5% XP e +1.2% tamanho por nível · Pulo duplo（main:287） | 商店 350 PB |
| main:292 | `scyther`／飛天螳螂 | 蟲／飛行 | `airslash`／空氣斬 | maxHp: 100, moveSpeed: 1.2, attackSpeed: 1.08 | attackSpeed: 0.02, moveSpeed: 0.008 | 3 | Técnico: +2% vel. de ataque e +0.8% velocidade por nível · Pulo triplo（main:301） | 商店 350 PB |
| main:306 | `ninetales`／九尾 | 火 | `willowisp`／鬼火 | maxHp: 115, luck: 0.08, damage: 1.05 | luck: 0.01, damage: 0.012 | 2 | Chama Fantasma: +1% sorte e +1.2% dano por nível · Pulo duplo（main:315） | 商店 350 PB |
| main:320 | `mrmime`／魔牆人偶 | 超能力／妖精 | `glasscage`／玻璃牢籠 | maxHp: 110, armor: 0.08, size: 1.08 | armor: 0.007, size: 0.015 | 1 | Barreira: +0.7% armadura e +1.5% tamanho por nível（main:329） | 商店 300 PB |
| main:334 | `clefable`／皮可西 | 妖精 | `metronome`／揮指 | maxHp: 130, luck: 0.12 | luck: 0.015, maxHp: 5 | 1 | Encanto: +1.5% sorte e +5 HP por nível（main:343） | 商店 300 PB |
| main:348 | `heracross`／赫拉克羅斯 | 蟲／格鬥 | `megahorn`／超級角擊 | maxHp: 140, damage: 1.08, knockback: 1.15, moveSpeed: 0.95 | damage: 0.018, knockback: 0.02 | 2 | Moxie: +1.8% dano e +2% empurrão por nível · Pulo duplo（main:357） | 商店 350 PB |
| main:362 | `cubone`／卡拉卡拉 | 地面 | `bonemerang`／骨頭回力鏢 | maxHp: 110, armor: 0.05 | armor: 0.006, damage: 0.015 | 1 | Cabeça Dura: +0.6% armadura e +1.5% dano por nível（main:371） | 商店 250 PB |
| main:376 | `mimikyu`／謎擬Ｑ | 幽靈／妖精 | `playrough`／嬉鬧 | maxHp: 105, damage: 1.08 | damage: 0.015, attackSpeed: 0.01 | 1 | Disfarce: +1.5% dano e +1% vel. de ataque por nível（main:385） | 商店 350 PB |
| main:390 | `typhlosion`／火爆獸 | 火 | `eruption`／噴火 | maxHp: 135, damage: 1.08 | damage: 0.018, maxHp: 6 | 1 | Chama Interior: +1.8% dano e +6 HP por nível（main:399） | 商店 350 PB |
| main:404 | `reshiram`／萊希拉姆 | 龍／火 | `blueflare`／青焰 | maxHp: 150, damage: 1.1 | damage: 0.02, size: 0.01 | 2 | Turboblaze: +2% dano e +1% tamanho por nível · Pulo duplo（main:413） | 商店 800 PB |
| main:418 | `zekrom`／捷克羅姆 | 龍／電 | `fusionbolt`／交錯閃電 | maxHp: 155, damage: 1.08, moveSpeed: 0.95 | damage: 0.018, crit: 0.008 | 2 | Teravolt: +1.8% dano e +0.8% crítico por nível · Pulo duplo（main:427） | 商店 800 PB |
| main:432 | `zacian`／蒼響 | 妖精／鋼 | `behemothblade`／巨獸斬 | maxHp: 125, moveSpeed: 1.15, damage: 1.08, crit: 0.08 | damage: 0.015, crit: 0.01 | 2 | Espírito Intrépido: +1.5% dano e +1% crítico por nível · Pulo duplo（main:441） | 商店 800 PB |
| main:446 | `zamazenta`／藏瑪然特 | 格鬥／鋼 | `behemothbash`／巨獸彈 | maxHp: 165, armor: 0.12, moveSpeed: 0.9 | armor: 0.01, knockback: 0.02, maxHp: 6 | 1 | Espírito Intrépido: +1% armadura, +2% empurrão e +6 HP por nível（main:455） | 商店 800 PB |
| main:460 | `dragapult`／多龍巴魯托 | 龍／幽靈 | `dragondarts`／龍箭 | maxHp: 105, moveSpeed: 1.12, attackSpeed: 1.08 | attackSpeed: 0.02 | 3 | Perfurante: +2% vel. de ataque por nível · Pulo triplo（main:469） | 商店 600 PB |
| main:474 | `hooh`／鳳王 | 火／飛行 | `sacredfire`／神聖之火 | maxHp: 140, regen: 1.2, damage: 1.05 | regen: 0.08, damage: 0.012 | 3 | Renascimento: +0.08 regeneração e +1.2% dano por nível · Pulo triplo（main:483） | 商店 800 PB |
| main:488 | `kyurem`／酋雷姆 | 龍／冰 | `glaciate`／冰封世界 | maxHp: 160, armor: 0.08, moveSpeed: 0.92 | armor: 0.008, duration: 0.02 | 1 | Pressão Glacial: +0.8% armadura e +2% duração por nível（main:497） | 商店 800 PB |
| main:502 | `yveltal`／伊裴爾塔爾 | 惡／飛行 | `oblivionwing`／死亡之翼 | maxHp: 150, lifesteal: 0.03, damage: 1.05 | lifesteal: 0.003, damage: 0.012 | 3 | Aura Sombria: +0.3% roubo de vida e +1.2% dano por nível · Pulo triplo（main:511） | 商店 800 PB |
| main:516 | `deoxys`／代歐奇希斯 | 超能力 | `psychoboost`／精神突進 | maxHp: 95, damage: 1.12, moveSpeed: 1.12 | damage: 0.02, projSpeed: 0.01 | 2 | Pressão Cósmica: +2% dano e +1% vel. dos projéteis por nível · Pulo duplo（main:525） | 商店 700 PB |
