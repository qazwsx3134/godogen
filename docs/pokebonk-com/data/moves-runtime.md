# 招式轉換與 runtime 初值

`moves.json` 共 919 招，涵蓋多世代；離線依 xp/Sp 分類，可轉為 runtime 的 710 招，排除 209 招（主要是未映射 status）。不是只有關都招式。以目前名單計有 79 個角色 kit、310 個不同 kit key。下表是「轉換能力」，不是每局出現清單；Mew 可選 power≥60 的非 status，其他角色受自身／祖先 learnset、同屬性且已入 Liga 的角色 kit、等級與空槽限制。完整篩選見 `main-DSroRSEE-mvekcp7c.js:37398`、`main-DSroRSEE-mvekcp7c.js:37417`、`main-DSroRSEE-mvekcp7c.js:51255`。

所有值為初始 definition，尚未乘招式級數、玩家屬性、1.3 執行倍率、STAB、敵方抗性。dmg / cd 的 power clamp 與 5 組後覆寫已納入；count 後覆寫也納入。`關都 learnset` 僅標資料連結，不表示低等級立即可學。status 機率仍會受玩家修正。來源：每個 id 的 `data/moves.json`；轉換 `main-DSroRSEE-mvekcp7c.js:37417`，原型 `main-DSroRSEE-mvekcp7c.js:36598`，後覆寫 `main-DSroRSEE-mvekcp7c.js:36393`。

| id | 繁中 | key | 屬性 | arch | 資料入口 | dmg | cd 秒 | count | area | speed | dur 秒 | pierce | status/機率 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 拍擊 | pound | normal | strike | kit | 14.8554 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 2 | 空手劈 | karate-chop | fighting | strike | kit | 15.5092 | 0.817 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 3 | 連環巴掌 | double-slap | normal | barrage | 其他（未證實可選） | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | 無/0.12 |
| 4 | 連續拳 | comet-punch | normal | barrage | kit | 3.4 | 0.9775 | 5 | 0.35 | 30 | 0.6 | 0 | 無/0.12 |
| 5 | 百萬噸重拳 | mega-punch | normal | meteor | kit | 46.2462 | 3.68 | 1 | 4.2 | 0 | 0.7 | 99 | 無/0.12 |
| 6 | 聚寶功 | pay-day | normal | barrage | kit | 3.4954 | 0.9775 | 5 | 0.35 | 30 | 0.6 | 0 | 無/0.12 |
| 7 | 火焰拳 | fire-punch | fire | strike | kit | 17.1438 | 0.8645 | 1 | 3.3 | 0 | 0 | 99 | burn/0.16 |
| 8 | 冰凍拳 | ice-punch | ice | strike | kit | 17.1438 | 0.8645 | 1 | 3.3 | 0 | 0 | 99 | freeze/0.16 |
| 9 | 雷電拳 | thunder-punch | electric | strike | kit | 17.1438 | 0.8645 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.16 |
| 10 | 抓 | scratch | normal | strike | kit | 14.8554 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 11 | 夾住 | vice-grip | normal | strike | kit | 15.8362 | 0.8265 | 1 | 3.3 | 0 | 0 | 99 | root/0.3 |
| 12 | 斷頭鉗 | guillotine | normal | meteor | kit | 57.87 | 3.6 | 1 | 4.2 | 0 | 0.7 | 99 | stun/0.6 |
| 13 | 旋風刀 | razor-wind | normal | wave | 其他（未證實可選） | 15.4154 | 2.208 | 1 | 4 | 13 | 1.1 | 99 | 無/0.12 |
| 14 | 劍舞 | swords-dance | normal | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | 無/0.8 |
| 15 | 居合斬 | cut | normal | strike | kit | 15.5092 | 0.817 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 16 | 起風 | gust | flying | vortex | kit | 29.7108 | 3.06 | 1 | 5 | 7 | 2.2 | 99 | knock/0.12 |
| 17 | 翅膀攻擊 | wing-attack | flying | boomerang | kit | 13.3108 | 1.496 | 1 | 0.8 | 17 | 1.3 | 99 | knock/0.12 |
| 19 | 飛翔 | fly | flying | dash | kit | 23.4554 | 2.162 | 1 | 1.8 | 13 | 0 | 99 | knock/0.12 |
| 20 | 綁緊 | bind | normal | strike | kit | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | root/0.35 |
| 21 | 摔打 | slam | normal | strike | kit | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 22 | 藤鞭 | vine-whip | grass | strike | kit | 15.1823 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | root/0.12 |
| 23 | 踩踏 | stomp | normal | nova | kit | 21.34 | 2.314 | 1 | 6.5 | 0 | 0 | 99 | 無/0.12 |
| 24 | 二連踢 | double-kick | fighting | barrage | kit | 7.65 | 0.9775 | 2 | 0.35 | 30 | 0.6 | 0 | knock/0.12 |
| 25 | 百萬噸重踢 | mega-kick | normal | dash | kit | 23.6308 | 2.3 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 26 | 飛踢 | jump-kick | fighting | dash | kit | 22.0923 | 2.208 | 1 | 1.8 | 13 | 0 | 99 | knock/0.12 |
| 27 | 迴旋踢 | rolling-kick | fighting | spin | kit | 8.5569 | 0.704 | 1 | 3.2 | 0 | 0 | 99 | stun/0.3 |
| 29 | 頭錘 | headbutt | normal | strike | 關都 learnset | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 30 | 角撞 | horn-attack | normal | strike | kit | 16.49 | 0.8455 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 31 | 亂擊 | fury-attack | normal | barrage | kit | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | 無/0.12 |
| 32 | 角鑽 | horn-drill | normal | dash | kit | 24.7308 | 2.07 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 33 | 撞擊 | tackle | normal | dash | kit | 17.4769 | 1.955 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 34 | 泰山壓頂 | body-slam | normal | nova | kit | 23.0323 | 2.418 | 1 | 6.5 | 0 | 0 | 99 | paralysis/0.48 |
| 35 | 緊束 | wrap | normal | spin | kit | 7.65 | 0.68 | 1 | 3.2 | 0 | 0 | 99 | root/0.3 |
| 36 | 猛撞 | take-down | normal | dash | 關都 learnset | 21.3231 | 2.162 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 37 | 大鬧一番 | thrash | normal | spin | kit | 10.6338 | 0.8 | 1 | 3.2 | 0 | 0 | 99 | 無/0.12 |
| 38 | 捨身衝撞 | double-edge | normal | dash | kit | 23.6308 | 2.3 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 40 | 毒針 | poison-sting | poison | bolt | kit | 11.05 | 0.85 | 1 | 0.5 | 24 | 0.8 | 0 | poison/0.48 |
| 41 | 雙針 | twineedle | bug | barrage | kit | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | poison/0.32 |
| 42 | 飛彈針 | pin-missile | bug | barrage | 關都 learnset | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | poison/0.12 |
| 44 | 咬住 | bite | dark | strike | kit | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 47 | 唱歌 | sing | normal | nova | kit | 21.7631 | 2.34 | 1 | 6.5 | 0 | 0 | 99 | sleep/0.8 |
| 48 | 超音波 | supersonic | normal | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.4 |
| 49 | 音爆 | sonic-boom | normal | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 51 | 溶解液 | acid | poison | cone | kit | 2.7963 | 1.7 | 1 | 7 | 0 | 1 | 99 | poison/0.12 |
| 52 | 火花 | ember | fire | bolt | kit | 11.36 | 0.85 | 1 | 0.5 | 24 | 0.8 | 0 | burn/0.16 |
| 53 | 噴射火焰 | flamethrower | fire | cone | kit | 3.4117 | 1.88 | 1 | 7 | 0 | 1 | 99 | burn/0.16 |
| 54 | 白霧 | mist | ice | aura | kit | 4.4515 | 0.405 | 1 | 3.6 | 0 | 0 | 99 | freeze/0.35 |
| 55 | 水槍 | water-gun | water | bolt | kit | 11.36 | 0.85 | 1 | 0.5 | 24 | 0.8 | 0 | wet/0.12 |
| 56 | 水炮 | hydro-pump | water | beam | kit | 8.0015 | 2.156 | 1 | 1.1 | 18 | 0.45 | 99 | wet/0.12 |
| 57 | 衝浪 | surf | water | wave | kit | 15.9923 | 2.256 | 1 | 4 | 13 | 1.1 | 99 | wet/0.12 |
| 58 | 冰凍光束 | ice-beam | ice | beam | kit | 7.4631 | 2.068 | 1 | 1.1 | 18 | 0.45 | 99 | freeze/0.16 |
| 59 | 暴風雪 | blizzard | ice | cone | kit | 3.6578 | 1.96 | 1 | 7 | 0 | 1 | 99 | freeze/0.16 |
| 60 | 幻象光線 | psybeam | psychic | beam | kit | 6.79 | 1.958 | 1 | 1.1 | 18 | 0.45 | 99 | confusion/0.16 |
| 61 | 泡沫光線 | bubble-beam | water | barrage | kit | 4.85 | 1.0235 | 4 | 0.35 | 30 | 0.6 | 0 | wet/0.12 |
| 62 | 極光束 | aurora-beam | ice | beam | kit | 6.79 | 1.958 | 1 | 1.1 | 18 | 0.45 | 99 | freeze/0.25 |
| 63 | 破壞光線 | hyper-beam | normal | beam | kit | 9.0785 | 2.332 | 1 | 1.1 | 18 | 0.45 | 99 | 無/0.12 |
| 64 | 啄 | peck | flying | strike | kit | 14.5285 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 65 | 啄鑽 | drill-peck | flying | smite | kit | 24.6646 | 1.564 | 2 | 1.9 | 0 | 0 | 99 | knock/0.12 |
| 66 | 地獄翻滾 | submission | fighting | dash | kit | 20.5538 | 2.116 | 1 | 1.8 | 13 | 0 | 99 | knock/0.12 |
| 67 | 踢倒 | low-kick | fighting | spin | kit | 8.9031 | 0.72 | 1 | 3.2 | 0 | 0 | 99 | knock/0.12 |
| 68 | 雙倍奉還 | counter | fighting | strike | 關都 learnset | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 69 | 地球上投 | seismic-toss | fighting | smite | kit | 23.7415 | 1.53 | 2 | 1.9 | 0 | 0 | 99 | stun/0.5 |
| 70 | 怪力 | strength | normal | dash | kit | 20.5538 | 2.116 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 71 | 吸取 | absorb | grass | drain | 關都 learnset | 8.5 | 1.105 | 1 | 0.5 | 18 | 1.1 | 0 | root/0.12 |
| 72 | 超級吸取 | mega-drain | grass | drain | kit | 8.7385 | 1.105 | 1 | 0.5 | 18 | 1.1 | 0 | root/0.12 |
| 73 | 寄生種子 | leech-seed | grass | drain | kit | 9.8923 | 1.17 | 1 | 0.5 | 18 | 1.1 | 0 | root/0.25 |
| 74 | 生長 | growth | normal | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | 無/0.8 |
| 75 | 飛葉快刀 | razor-leaf | grass | barrage | kit | 4.6577 | 1.0005 | 4 | 0.35 | 30 | 0.6 | 0 | root/0.12 |
| 76 | 日光束 | solar-beam | grass | beam | kit | 8.2708 | 2.2 | 1 | 1.1 | 18 | 0.45 | 99 | root/0.12 |
| 77 | 毒粉 | poison-powder | poison | cone | kit | 3.1655 | 1.8 | 1 | 7 | 0 | 1 | 99 | poison/0.8 |
| 78 | 麻痺粉 | stun-spore | grass | cone | kit | 3.1655 | 1.8 | 1 | 7 | 0 | 1 | 99 | paralysis/0.35 |
| 79 | 催眠粉 | sleep-powder | grass | cone | kit | 3.1655 | 1.8 | 1 | 7 | 0 | 1 | 99 | sleep/0.8 |
| 80 | 花瓣舞 | petal-dance | grass | orbit | kit | 10.6338 | 5.5 | 3 | 3.2 | 3.2 | 4 | 99 | root/0.12 |
| 81 | 吐絲 | string-shot | bug | cone | kit | 3.1655 | 1.8 | 1 | 7 | 0 | 1 | 99 | root/0.35 |
| 82 | 龍之怒 | dragon-rage | dragon | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 83 | 火焰旋渦 | fire-spin | fire | vortex | kit | 29.0569 | 3.06 | 1 | 5 | 7 | 2.2 | 99 | root/0.8 |
| 84 | 電擊 | thunder-shock | electric | bolt | kit | 11.36 | 0.85 | 1 | 0.5 | 24 | 0.8 | 0 | paralysis/0.16 |
| 85 | 十萬伏特 | thunderbolt | electric | chain | kit | 13.86 | 1.316 | 3 | 8 | 0 | 0 | 0 | paralysis/0.16 |
| 86 | 電磁波 | thunder-wave | electric | chain | kit | 10.288 | 1.26 | 3 | 8 | 0 | 0 | 0 | paralysis/0.6 |
| 87 | 打雷 | thunder | electric | smite | kit | 27.4338 | 1.666 | 2 | 1.9 | 0 | 0 | 99 | paralysis/0.48 |
| 88 | 落石 | rock-throw | rock | lob | kit | 18.2462 | 1.634 | 1 | 3.2 | 15 | 3 | 0 | stun/0.12 |
| 89 | 地震 | earthquake | ground | nova | 關都 learnset | 24.3015 | 2.496 | 1 | 6.5 | 0 | 0 | 99 | stun/0.12 |
| 90 | 地裂 | fissure | ground | wave | kit | 19.29 | 2.16 | 1 | 4 | 13 | 1.1 | 99 | stun/0.35 |
| 91 | 挖洞 | dig | ground | dash | 關都 learnset | 20.5538 | 2.116 | 1 | 1.8 | 13 | 0 | 99 | stun/0.12 |
| 92 | 劇毒 | toxic | poison | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | poison/0.8 |
| 93 | 念力 | confusion | psychic | bolt | kit | 11.86 | 0.86 | 1 | 0.5 | 24 | 0.8 | 0 | confusion/0.16 |
| 94 | 精神強念 | psychic | psychic | nova | kit | 23.4554 | 2.444 | 1 | 6.5 | 0 | 0 | 99 | confusion/0.12 |
| 95 | 催眠術 | hypnosis | psychic | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | sleep/0.45 |
| 97 | 高速移動 | agility | psychic | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | confusion/0.8 |
| 98 | 電光一閃 | quick-attack | normal | dash | kit | 17.4769 | 1.6617 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 99 | 憤怒 | rage | normal | spin | 其他（未證實可選） | 7.65 | 0.68 | 1 | 3.2 | 0 | 0 | 99 | 無/0.12 |
| 101 | 黑夜魔影 | night-shade | ghost | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | curse/0.12 |
| 102 | 模仿 | mimic | normal | random | kit | 0 | 4.05 | 0 | 1 | 1 | 1 | 0 | 無/0.8 |
| 109 | 奇異之光 | confuse-ray | ghost | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.45 |
| 112 | 屏障 | barrier | psychic | orbit | kit | 8.9031 | 4.95 | 3 | 3.2 | 3.2 | 4 | 99 | confusion/0.8 |
| 113 | 光牆 | light-screen | psychic | wave | kit | 14.8385 | 2.16 | 1 | 4 | 13 | 1.1 | 99 | knock/1 |
| 117 | 忍耐 | bide | normal | strike | 其他（未證實可選） | 16.8169 | 0.7268 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 118 | 揮指 | metronome | normal | random | 關都 learnset | 0 | 4.05 | 0 | 1 | 1 | 1 | 0 | 無/0.8 |
| 120 | 自爆 | self-destruct | normal | nova | kit | 34.32 | 2.99 | 1 | 6.5 | 0 | 0 | 99 | 無/0.12 |
| 121 | 炸蛋 | egg-bomb | normal | lob | kit | 22.0923 | 1.824 | 1 | 3.2 | 15 | 3 | 0 | 無/0.12 |
| 122 | 舌舔 | lick | ghost | strike | kit | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.48 |
| 123 | 濁霧 | smog | poison | cone | kit | 2.72 | 1.7 | 1 | 7 | 0 | 1 | 99 | poison/0.64 |
| 124 | 污泥攻擊 | sludge | poison | orb | kit | 14.55 | 1.335 | 1 | 2.6 | 17 | 1.05 | 0 | poison/0.48 |
| 125 | 骨棒 | bone-club | ground | strike | kit | 16.49 | 0.8455 | 1 | 3.3 | 0 | 0 | 99 | stun/0.12 |
| 126 | 大字爆炎 | fire-blast | fire | orb | kit | 17.1462 | 1.47 | 1 | 2.6 | 17 | 1.05 | 0 | burn/0.16 |
| 127 | 攀瀑 | waterfall | water | dash | kit | 20.5538 | 2.116 | 1 | 1.8 | 13 | 0 | 99 | wet/0.12 |
| 128 | 貝殼夾擊 | clamp | water | strike | kit | 14.5285 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | root/0.5 |
| 129 | 高速星星 | swift | normal | homing | kit | 8.5569 | 1.1 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 130 | 火箭頭錘 | skull-bash | normal | strike | 其他（未證實可選） | 20.74 | 0.969 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 131 | 尖刺加農炮 | spike-cannon | normal | barrage | kit | 3.6125 | 0.9775 | 5 | 0.35 | 30 | 0.6 | 0 | 無/0.12 |
| 132 | 纏繞 | constrict | normal | spin | kit | 7.65 | 0.68 | 1 | 3.2 | 0 | 0 | 99 | root/0.3 |
| 136 | 飛膝踢 | high-jump-kick | fighting | smite | kit | 39.528 | 1.734 | 1 | 1.9 | 0 | 0 | 99 | knock/0.12 |
| 138 | 食夢 | dream-eater | psychic | drain | kit | 13.2554 | 1.248 | 1 | 0.5 | 18 | 1.1 | 0 | confusion/0.12 |
| 139 | 毒瓦斯 | poison-gas | poison | trail | kit | 5.9354 | 0.252 | 1 | 1.7 | 0 | 3 | 99 | poison/0.7 |
| 140 | 投球 | barrage | normal | barrage | kit | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | 無/0.12 |
| 141 | 吸血 | leech-life | bug | drain | kit | 10.2769 | 1.196 | 1 | 0.5 | 18 | 1.1 | 0 | poison/0.12 |
| 142 | 惡魔之吻 | lovely-kiss | normal | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | sleep/0.5 |
| 143 | 神鳥猛擊 | sky-attack | flying | meteor | 關都 learnset | 56.6308 | 4.16 | 1 | 4.2 | 0 | 0.7 | 99 | knock/0.12 |
| 144 | 變身 | transform | normal | random | kit | 0 | 4.05 | 0 | 1 | 1 | 1 | 0 | 無/0.8 |
| 145 | 泡沫 | bubble | water | barrage | kit | 4.3692 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | wet/0.12 |
| 146 | 迷昏拳 | dizzy-punch | normal | strike | kit | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | confusion/0.32 |
| 147 | 蘑菇孢子 | spore | grass | trap | kit | 27 | 2.34 | 2 | 3 | 0 | 14 | 0 | sleep/1 |
| 149 | 精神波 | psywave | psychic | wave | kit | 14.8385 | 2.16 | 1 | 4 | 13 | 1.1 | 99 | confusion/0.3 |
| 152 | 蟹鉗錘 | crabhammer | water | smite | kit | 26.5108 | 1.632 | 2 | 1.9 | 0 | 0 | 99 | wet/0.12 |
| 153 | 大爆炸 | explosion | normal | meteor | kit | 76.05 | 4.6 | 1 | 4.2 | 0 | 0.7 | 99 | 無/0.12 |
| 154 | 亂抓 | fury-swipes | normal | barrage | kit | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | 無/0.12 |
| 155 | 骨頭回力鏢 | bonemerang | ground | boomerang | kit | 12.7723 | 1.462 | 1 | 0.8 | 17 | 1.3 | 99 | stun/0.12 |
| 157 | 岩崩 | rock-slide | rock | smite | kit | 24.2031 | 1.547 | 2 | 1.9 | 0 | 0 | 99 | stun/0.12 |
| 158 | 必殺門牙 | hyper-fang | normal | strike | kit | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 161 | 三重攻擊 | tri-attack | normal | chain | kit | 13.36 | 1.288 | 3 | 8 | 0 | 0 | 0 | 無/0.12 |
| 162 | 憤怒門牙 | super-fang | normal | chain | kit | 12.86 | 1.26 | 3 | 8 | 0 | 0 | 0 | 無/0.12 |
| 163 | 劈開 | slash | normal | strike | kit | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 165 | 掙扎 | struggle | normal | strike | 其他（未證實可選） | 15.5092 | 0.817 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 166 | 寫生 | sketch | normal | random | kit | 0 | 4.05 | 0 | 1 | 1 | 1 | 0 | 無/0.8 |
| 167 | 三連踢 | triple-kick | fighting | barrage | 其他（未證實可選） | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | knock/0.12 |
| 168 | 小偷 | thief | dark | strike | 其他（未證實可選） | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 171 | 惡夢 | nightmare | ghost | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | curse/0.6 |
| 172 | 火焰輪 | flame-wheel | fire | trail | kit | 5.7046 | 0.2464 | 1 | 1.7 | 0 | 3 | 99 | burn/0.16 |
| 173 | 打鼾 | snore | normal | nova | kit | 20.0708 | 2.236 | 1 | 6.5 | 0 | 0 | 99 | stun/0.3 |
| 175 | 抓狂 | flail | normal | strike | kit | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 177 | 氣旋攻擊 | aeroblast | flying | beam | 其他（未證實可選） | 7.7323 | 2.112 | 1 | 1.1 | 18 | 0.45 | 99 | knock/0.12 |
| 178 | 棉孢子 | cotton-spore | grass | cone | 其他（未證實可選） | 3.1655 | 1.8 | 1 | 7 | 0 | 1 | 99 | root/0.3 |
| 179 | 起死回生 | reversal | fighting | nova | kit | 23.9394 | 2.34 | 1 | 6.5 | 0 | 0 | 99 | knock/0.12 |
| 181 | 細雪 | powder-snow | ice | cone | 關都 learnset | 2.7963 | 1.7 | 1 | 7 | 0 | 1 | 99 | freeze/0.16 |
| 183 | 音速拳 | mach-punch | fighting | barrage | 關都 learnset | 4.3692 | 0.8309 | 4 | 0.35 | 30 | 0.6 | 0 | knock/0.12 |
| 185 | 出奇一擊 | feint-attack | dark | homing | 其他（未證實可選） | 8.5569 | 1.1 | 2 | 0.5 | 15 | 1.6 | 0 | healblock/0.12 |
| 186 | 天使之吻 | sweet-kiss | fairy | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.45 |
| 188 | 污泥炸彈 | sludge-bomb | poison | lob | kit | 21.3231 | 1.786 | 1 | 3.2 | 15 | 3 | 0 | poison/0.48 |
| 189 | 擲泥 | mud-slap | ground | bolt | 關都 learnset | 11.05 | 0.85 | 1 | 0.5 | 24 | 0.8 | 0 | stun/0.12 |
| 190 | 章魚桶炮 | octazooka | water | orb | kit | 14.55 | 1.335 | 1 | 2.6 | 17 | 1.05 | 0 | charm/0.3 |
| 191 | 撒菱 | spikes | ground | trap | 關都 learnset | 27 | 2.34 | 2 | 3 | 0 | 14 | 0 | stun/0.8 |
| 192 | 電磁炮 | zap-cannon | electric | orb | 關都 learnset | 17.7231 | 1.5 | 1 | 2.6 | 17 | 1.05 | 0 | paralysis/0.8 |
| 195 | 滅亡之歌 | perish-song | normal | meteor | kit | 62.3215 | 3.6 | 1 | 4.2 | 0 | 0.7 | 99 | curse/1 |
| 196 | 冰凍之風 | icy-wind | ice | cone | kit | 2.9809 | 1.74 | 1 | 7 | 0 | 1 | 99 | freeze/0.4 |
| 198 | 骨棒亂打 | bone-rush | ground | orbit | kit | 7.65 | 4.675 | 2 | 3.2 | 3.2 | 4 | 99 | stun/0.12 |
| 199 | 鎖定 | lock-on | normal | homing | kit | 8.9031 | 1.125 | 3 | 0.5 | 15 | 1.6 | 0 | curse/0.5 |
| 200 | 逆鱗 | outrage | dragon | nova | 關都 learnset | 25.9938 | 2.6 | 1 | 6.5 | 0 | 0 | 99 | 無/0.12 |
| 201 | 沙暴 | sandstorm | rock | weather | 關都 learnset | 0 | 28.8 | 1 | 0 | 0 | 14 | 0 | stun/0.8 |
| 202 | 終極吸取 | giga-drain | grass | drain | kit | 10.0846 | 1.183 | 1 | 0.5 | 18 | 1.1 | 0 | root/0.12 |
| 205 | 滾動 | rollout | rock | boomerang | kit | 11.9 | 1.445 | 1 | 0.8 | 17 | 1.3 | 99 | stun/0.12 |
| 206 | 點到為止 | false-swipe | normal | boomerang | kit | 12.2338 | 1.445 | 2 | 0.8 | 17 | 1.3 | 99 | 無/0.12 |
| 209 | 電光 | spark | electric | dash | kit | 19.4 | 2.047 | 1 | 1.8 | 13 | 0 | 99 | paralysis/0.48 |
| 210 | 連斬 | fury-cutter | bug | strike | kit | 14.8554 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | poison/0.12 |
| 211 | 鋼翼 | steel-wing | steel | boomerang | 其他（未證實可選） | 13.8492 | 1.53 | 1 | 0.8 | 17 | 1.3 | 99 | knock/0.12 |
| 216 | 報恩 | return | normal | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 217 | 禮物 | present | normal | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 218 | 遷怒 | frustration | normal | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 221 | 神聖之火 | sacred-fire | fire | meteor | kit | 49.7077 | 3.84 | 1 | 4.2 | 0 | 0.7 | 99 | burn/0.8 |
| 222 | 震級 | magnitude | ground | nova | kit | 21.7631 | 2.34 | 1 | 6.5 | 0 | 0 | 99 | stun/0.12 |
| 223 | 爆裂拳 | dynamic-punch | fighting | nova | kit | 24.3015 | 2.496 | 1 | 6.5 | 0 | 0 | 99 | confusion/0.8 |
| 224 | 超級角擊 | megahorn | bug | dash | 關都 learnset | 23.6308 | 2.3 | 1 | 1.8 | 13 | 0 | 99 | poison/0.12 |
| 225 | 龍息 | dragon-breath | dragon | cone | 關都 learnset | 3.0425 | 1.76 | 1 | 7 | 0 | 1 | 99 | paralysis/0.48 |
| 228 | 追打 | pursuit | dark | homing | kit | 7.8646 | 1.0625 | 2 | 0.5 | 15 | 1.6 | 0 | healblock/0.12 |
| 229 | 高速旋轉 | rapid-spin | normal | spin | kit | 8.2108 | 0.688 | 1 | 3.2 | 0 | 0 | 99 | 無/0.12 |
| 231 | 鐵尾 | iron-tail | steel | strike | kit | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 232 | 金屬爪 | metal-claw | steel | strike | 關都 learnset | 15.5092 | 0.817 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 233 | 借力摔 | vital-throw | fighting | spin | kit | 8.9031 | 0.72 | 1 | 3.2 | 0 | 0 | 99 | knock/1 |
| 237 | 覺醒力量 | hidden-power | normal | homing | 其他（未證實可選） | 8.5569 | 1.1 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 238 | 十字劈 | cross-chop | fighting | strike | kit | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 239 | 龍捲風 | twister | dragon | vortex | kit | 29.7108 | 3.06 | 1 | 5 | 7 | 2.2 | 99 | 無/0.12 |
| 240 | 求雨 | rain-dance | water | weather | 關都 learnset | 0 | 28.8 | 1 | 0 | 0 | 14 | 0 | wet/0.8 |
| 241 | 大晴天 | sunny-day | fire | weather | 關都 learnset | 0 | 28.8 | 1 | 0 | 0 | 14 | 0 | burn/0.8 |
| 242 | 咬碎 | crunch | dark | strike | 關都 learnset | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 243 | 鏡面反射 | mirror-coat | psychic | homing | 關都 learnset | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.12 |
| 245 | 神速 | extreme-speed | normal | dash | kit | 20.5538 | 1.7986 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 246 | 原始之力 | ancient-power | rock | orbit | kit | 8.5569 | 4.84 | 2 | 3.2 | 3.2 | 4 | 99 | stun/0.12 |
| 247 | 暗影球 | shadow-ball | ghost | orb | kit | 15.4154 | 1.38 | 1 | 2.6 | 17 | 1.05 | 0 | curse/0.12 |
| 248 | 預知未來 | future-sight | psychic | meteor | kit | 53.1692 | 4 | 1 | 4.2 | 0 | 0.7 | 99 | confusion/0.12 |
| 249 | 碎岩 | rock-smash | fighting | strike | 關都 learnset | 14.8554 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 250 | 潮旋 | whirlpool | water | vortex | kit | 29.0569 | 3.06 | 1 | 5 | 7 | 2.2 | 99 | root/0.8 |
| 251 | 圍攻 | beat-up | dark | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 252 | 擊掌奇襲 | fake-out | normal | strike | kit | 14.8554 | 0.6864 | 1 | 3.3 | 0 | 0 | 99 | stun/0.6 |
| 253 | 吵鬧 | uproar | normal | nova | kit | 23.4554 | 2.444 | 1 | 6.5 | 0 | 0 | 99 | confusion/0.25 |
| 255 | 噴出 | spit-up | normal | homing | 關都 learnset | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 257 | 熱風 | heat-wave | fire | cone | kit | 3.4732 | 1.9 | 1 | 7 | 0 | 1 | 99 | burn/0.16 |
| 258 | 冰雹 | hail | ice | weather | 其他（未證實可選） | 0 | 28.8 | 1 | 0 | 0 | 14 | 0 | freeze/0.8 |
| 261 | 鬼火 | will-o-wisp | fire | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | burn/0.8 |
| 263 | 硬撐 | facade | normal | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 264 | 真氣拳 | focus-punch | fighting | meteor | kit | 72.9519 | 4.24 | 1 | 4.2 | 0 | 0.7 | 99 | stun/0.7 |
| 265 | 清醒 | smelling-salts | normal | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 276 | 蠻力 | superpower | fighting | nova | kit | 25.9938 | 2.6 | 1 | 6.5 | 0 | 0 | 99 | stun/0.4 |
| 279 | 報復 | revenge | fighting | strike | 其他（未證實可選） | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 280 | 劈瓦 | brick-break | fighting | strike | 關都 learnset | 17.1438 | 0.8645 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 281 | 哈欠 | yawn | normal | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | sleep/0.5 |
| 282 | 拍落 | knock-off | dark | boomerang | kit | 13.58 | 1.513 | 1 | 0.8 | 17 | 1.3 | 99 | knock/0.5 |
| 283 | 蠻幹 | endeavor | normal | strike | 關都 learnset | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 284 | 噴火 | eruption | fire | meteor | kit | 64.1977 | 4.24 | 1 | 4.2 | 0 | 0.7 | 99 | burn/0.8 |
| 290 | 秘密之力 | secret-power | normal | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 291 | 潛水 | dive | water | dash | kit | 20.5538 | 2.116 | 1 | 1.8 | 13 | 0 | 99 | wet/0.12 |
| 292 | 猛推 | arm-thrust | fighting | barrage | 其他（未證實可選） | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | knock/0.12 |
| 294 | 螢火 | tail-glow | bug | buff | 其他（未證實可選） | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | poison/0.8 |
| 295 | 潔淨光芒 | luster-purge | psychic | orb | 其他（未證實可選） | 16.2808 | 1.425 | 1 | 2.6 | 17 | 1.05 | 0 | confusion/0.12 |
| 296 | 薄霧球 | mist-ball | psychic | orb | 其他（未證實可選） | 16.2808 | 1.425 | 1 | 2.6 | 17 | 1.05 | 0 | confusion/0.12 |
| 297 | 羽毛舞 | feather-dance | flying | homing | kit | 8.9031 | 1.125 | 3 | 0.5 | 15 | 1.6 | 0 | charm/0.3 |
| 299 | 火焰踢 | blaze-kick | fire | strike | kit | 17.7977 | 0.8835 | 1 | 3.3 | 0 | 0 | 99 | burn/0.16 |
| 301 | 冰球 | ice-ball | ice | boomerang | 其他（未證實可選） | 11.9 | 1.445 | 1 | 0.8 | 17 | 1.3 | 99 | freeze/0.12 |
| 302 | 尖刺臂 | needle-arm | grass | strike | 其他（未證實可選） | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | root/0.12 |
| 304 | 巨聲 | hyper-voice | normal | nova | kit | 23.4554 | 2.444 | 1 | 6.5 | 0 | 0 | 99 | 無/0.12 |
| 305 | 劇毒牙 | poison-fang | poison | strike | kit | 15.5092 | 0.817 | 1 | 3.3 | 0 | 0 | 99 | poison/0.8 |
| 306 | 撕裂爪 | crush-claw | normal | strike | kit | 17.1438 | 0.8645 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 307 | 爆炸烈焰 | blast-burn | fire | meteor | 其他（未證實可選） | 58.3615 | 4.24 | 1 | 4.2 | 0 | 0.7 | 99 | burn/0.12 |
| 308 | 加農水炮 | hydro-cannon | water | beam | kit | 9.0785 | 2.332 | 1 | 1.1 | 18 | 0.45 | 99 | wet/0.12 |
| 309 | 彗星拳 | meteor-mash | steel | meteor | 關都 learnset | 47.9769 | 3.76 | 1 | 4.2 | 0 | 0.7 | 99 | knock/0.12 |
| 310 | 驚嚇 | astonish | ghost | bolt | 關都 learnset | 11.05 | 0.85 | 1 | 0.5 | 24 | 0.8 | 0 | curse/0.12 |
| 311 | 氣象球 | weather-ball | normal | orb | 其他（未證實可選） | 13.6846 | 1.29 | 1 | 2.6 | 17 | 1.05 | 0 | 無/0.12 |
| 314 | 空氣利刃 | air-cutter | flying | barrage | kit | 4.7538 | 1.012 | 4 | 0.35 | 30 | 0.6 | 0 | knock/0.12 |
| 315 | 過熱 | overheat | fire | meteor | kit | 54.9 | 4.08 | 1 | 4.2 | 0 | 0.7 | 99 | burn/0.6 |
| 317 | 岩石封鎖 | rock-tomb | rock | smite | kit | 22.8185 | 1.496 | 2 | 1.9 | 0 | 0 | 99 | root/0.4 |
| 318 | 銀色旋風 | silver-wind | bug | cone | kit | 3.0425 | 1.76 | 1 | 7 | 0 | 1 | 99 | poison/0.12 |
| 323 | 噴水 | water-spout | water | nova | kit | 28.5323 | 2.756 | 1 | 6.5 | 0 | 0 | 99 | wet/0.6 |
| 324 | 信號光束 | signal-beam | bug | beam | kit | 7.0592 | 2.002 | 1 | 1.1 | 18 | 0.45 | 99 | confusion/0.16 |
| 325 | 暗影拳 | shadow-punch | ghost | homing | 關都 learnset | 8.5569 | 1.1 | 2 | 0.5 | 15 | 1.6 | 0 | curse/0.12 |
| 326 | 神通力 | extrasensory | psychic | homing | kit | 9.2492 | 1.15 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.12 |
| 327 | 衝天拳 | sky-uppercut | fighting | strike | 其他（未證實可選） | 17.7977 | 0.8835 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 328 | 流沙地獄 | sand-tomb | ground | vortex | 關都 learnset | 29.0569 | 3.06 | 1 | 5 | 7 | 2.2 | 99 | root/0.8 |
| 329 | 絕對零度 | sheer-cold | ice | nova | kit | 25.0275 | 2.34 | 1 | 6.5 | 0 | 0 | 99 | freeze/0.9 |
| 330 | 濁流 | muddy-water | water | wave | 關都 learnset | 15.9923 | 2.256 | 1 | 4 | 13 | 1.1 | 99 | wet/0.12 |
| 331 | 種子機關槍 | bullet-seed | grass | barrage | 關都 learnset | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | root/0.12 |
| 332 | 燕返 | aerial-ace | flying | homing | kit | 8.5569 | 1.1 | 2 | 0.5 | 15 | 1.6 | 0 | knock/0.12 |
| 333 | 冰錐 | icicle-spear | ice | barrage | kit | 3.6125 | 0.9775 | 5 | 0.35 | 30 | 0.6 | 0 | freeze/0.12 |
| 337 | 龍爪 | dragon-claw | dragon | strike | 關都 learnset | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 338 | 瘋狂植物 | frenzy-plant | grass | meteor | 其他（未證實可選） | 58.3615 | 4.24 | 1 | 4.2 | 0 | 0.7 | 99 | root/0.12 |
| 339 | 健美 | bulk-up | fighting | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | knock/0.8 |
| 340 | 彈跳 | bounce | flying | smite | kit | 25.1262 | 1.581 | 2 | 1.9 | 0 | 0 | 99 | paralysis/0.48 |
| 341 | 泥巴射擊 | mud-shot | ground | bolt | kit | 12.11 | 0.87 | 1 | 0.5 | 24 | 0.8 | 0 | root/0.25 |
| 342 | 毒尾 | poison-tail | poison | strike | 其他（未證實可選） | 15.5092 | 0.817 | 1 | 3.3 | 0 | 0 | 99 | poison/0.16 |
| 343 | 渴望 | covet | normal | strike | 關都 learnset | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 344 | 伏特攻擊 | volt-tackle | electric | dash | 其他（未證實可選） | 23.6308 | 2.3 | 1 | 1.8 | 13 | 0 | 99 | paralysis/0.16 |
| 345 | 魔法葉 | magical-leaf | grass | homing | 其他（未證實可選） | 8.5569 | 1.1 | 2 | 0.5 | 15 | 1.6 | 0 | root/0.12 |
| 347 | 冥想 | calm-mind | psychic | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | confusion/0.8 |
| 348 | 葉刃 | leaf-blade | grass | boomerang | 關都 learnset | 14.9262 | 1.598 | 1 | 0.8 | 17 | 1.3 | 99 | root/0.12 |
| 349 | 龍之舞 | dragon-dance | dragon | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | 無/0.8 |
| 350 | 岩石爆擊 | rock-blast | rock | barrage | kit | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | stun/0.12 |
| 351 | 電擊波 | shock-wave | electric | homing | 關都 learnset | 8.5569 | 1.1 | 2 | 0.5 | 15 | 1.6 | 0 | paralysis/0.12 |
| 352 | 水之波動 | water-pulse | water | orb | kit | 14.2615 | 1.32 | 1 | 2.6 | 17 | 1.05 | 0 | confusion/0.32 |
| 353 | 破滅之願 | doom-desire | steel | meteor | 其他（未證實可選） | 56.6308 | 4.16 | 1 | 4.2 | 0 | 0.7 | 99 | knock/0.12 |
| 354 | 精神突進 | psycho-boost | psychic | meteor | kit | 65.1254 | 4.16 | 1 | 4.2 | 0 | 0.7 | 99 | confusion/0.12 |
| 356 | 重力 | gravity | psychic | vortex | kit | 33.6338 | 3.24 | 1 | 5 | 7 | 2.2 | 99 | stun/0.4 |
| 358 | 喚醒巴掌 | wake-up-slap | fighting | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 359 | 臂錘 | hammer-arm | fighting | nova | 關都 learnset | 24.3015 | 2.496 | 1 | 6.5 | 0 | 0 | 99 | knock/0.12 |
| 360 | 陀螺球 | gyro-ball | steel | spin | kit | 10.6837 | 0.72 | 1 | 3.2 | 0 | 0 | 99 | knock/0.12 |
| 362 | 鹽水 | brine | water | orb | kit | 14.55 | 1.335 | 1 | 2.6 | 17 | 1.05 | 0 | wet/0.12 |
| 363 | 自然之恩 | natural-gift | normal | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 364 | 佯攻 | feint | normal | strike | 關都 learnset | 14.45 | 0.6864 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 365 | 啄食 | pluck | flying | strike | kit | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 368 | 金屬爆炸 | metal-burst | steel | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 369 | 急速折返 | u-turn | bug | boomerang | kit | 13.8492 | 1.53 | 1 | 0.8 | 17 | 1.3 | 99 | poison/0.12 |
| 370 | 近身戰 | close-combat | fighting | spin | 關都 learnset | 10.6338 | 0.8 | 1 | 3.2 | 0 | 0 | 99 | knock/0.12 |
| 371 | 以牙還牙 | payback | dark | strike | kit | 15.5092 | 0.817 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 372 | 惡意追擊 | assurance | dark | dash | kit | 19.0154 | 2.024 | 1 | 1.8 | 13 | 0 | 99 | healblock/0.12 |
| 374 | 投擲 | fling | dark | strike | 關都 learnset | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 376 | 王牌 | trump-card | normal | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 378 | 絞緊 | wring-out | normal | strike | kit | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.4 |
| 380 | 胃液 | gastro-acid | poison | lob | kit | 19.7846 | 1.71 | 1 | 3.2 | 15 | 3 | 0 | curse/0.8 |
| 383 | 仿效 | copycat | normal | random | kit | 0 | 4.05 | 0 | 1 | 1 | 1 | 0 | 無/0.8 |
| 386 | 懲罰 | punishment | dark | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 387 | 珍藏 | last-resort | normal | meteor | kit | 56.6308 | 4.16 | 1 | 4.2 | 0 | 0.7 | 99 | 無/0.12 |
| 389 | 突襲 | sucker-punch | dark | dash | 關都 learnset | 19.7846 | 1.7595 | 1 | 1.8 | 13 | 0 | 99 | healblock/0.12 |
| 390 | 毒菱 | toxic-spikes | poison | trap | kit | 27 | 2.34 | 2 | 3 | 0 | 14 | 0 | poison/0.8 |
| 392 | 水流環 | aqua-ring | water | aura | 關都 learnset | 4.4515 | 0.405 | 1 | 3.6 | 0 | 0 | 99 | wet/0.8 |
| 394 | 閃焰衝鋒 | flare-blitz | fire | dash | kit | 23.6308 | 2.3 | 1 | 1.8 | 13 | 0 | 99 | burn/0.16 |
| 395 | 發勁 | force-palm | fighting | strike | 其他（未證實可選） | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.48 |
| 396 | 波導彈 | aura-sphere | fighting | homing | kit | 9.2492 | 1.15 | 2 | 0.5 | 15 | 1.6 | 0 | knock/0.12 |
| 397 | 岩石打磨 | rock-polish | rock | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | stun/0.8 |
| 398 | 毒擊 | poison-jab | poison | strike | kit | 13.1031 | 0.874 | 2 | 3.3 | 0 | 0 | 99 | poison/0.48 |
| 399 | 惡之波動 | dark-pulse | dark | nova | 關都 learnset | 22.6092 | 2.392 | 1 | 6.5 | 0 | 0 | 99 | healblock/0.12 |
| 400 | 暗襲要害 | night-slash | dark | strike | 關都 learnset | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 401 | 水流尾 | aqua-tail | water | strike | kit | 18.1246 | 0.893 | 1 | 3.3 | 0 | 0 | 99 | wet/0.12 |
| 402 | 種子炸彈 | seed-bomb | grass | lob | kit | 20.5538 | 1.748 | 1 | 3.2 | 15 | 3 | 0 | root/0.12 |
| 403 | 空氣斬 | air-slash | flying | boomerang | kit | 14.1185 | 1.547 | 1 | 0.8 | 17 | 1.3 | 99 | knock/0.12 |
| 404 | 十字剪 | x-scissor | bug | boomerang | kit | 14.3877 | 1.564 | 1 | 0.8 | 17 | 1.3 | 99 | poison/0.12 |
| 405 | 蟲鳴 | bug-buzz | bug | nova | kit | 23.4554 | 2.444 | 1 | 6.5 | 0 | 0 | 99 | poison/0.12 |
| 406 | 龍之波動 | dragon-pulse | dragon | beam | kit | 7.3285 | 2.046 | 1 | 1.1 | 18 | 0.45 | 99 | 無/0.12 |
| 407 | 龍之俯衝 | dragon-rush | dragon | dash | 關都 learnset | 22.0923 | 2.208 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 408 | 力量寶石 | power-gem | rock | barrage | 關都 learnset | 5.1385 | 1.058 | 4 | 0.35 | 30 | 0.6 | 0 | stun/0.12 |
| 409 | 吸取拳 | drain-punch | fighting | strike | kit | 17.1438 | 0.8645 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 410 | 真空波 | vacuum-wave | fighting | bolt | 關都 learnset | 11.36 | 0.7225 | 1 | 0.5 | 24 | 0.8 | 0 | knock/0.12 |
| 411 | 真氣彈 | focus-blast | fighting | orb | kit | 17.7231 | 1.5 | 1 | 2.6 | 17 | 1.05 | 0 | knock/0.12 |
| 412 | 能量球 | energy-ball | grass | orb | kit | 15.9923 | 1.41 | 1 | 2.6 | 17 | 1.05 | 0 | root/0.12 |
| 413 | 勇鳥猛攻 | brave-bird | flying | dash | kit | 23.6308 | 2.3 | 1 | 1.8 | 13 | 0 | 99 | knock/0.12 |
| 414 | 大地之力 | earth-power | ground | smite | kit | 25.5877 | 1.598 | 2 | 1.9 | 0 | 0 | 99 | stun/0.12 |
| 416 | 終極衝擊 | giga-impact | normal | meteor | kit | 58.3615 | 4.24 | 1 | 4.2 | 0 | 0.7 | 99 | 無/0.12 |
| 417 | 詭計 | nasty-plot | dark | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | healblock/0.8 |
| 418 | 子彈拳 | bullet-punch | steel | barrage | 關都 learnset | 4.3692 | 0.8309 | 4 | 0.35 | 30 | 0.6 | 0 | knock/0.12 |
| 419 | 雪崩 | avalanche | ice | meteor | 其他（未證實可選） | 42.7846 | 3.52 | 1 | 4.2 | 0 | 0.7 | 99 | freeze/0.12 |
| 420 | 冰礫 | ice-shard | ice | bolt | 關都 learnset | 11.36 | 0.7225 | 1 | 0.5 | 24 | 0.8 | 0 | freeze/0.12 |
| 421 | 暗影爪 | shadow-claw | ghost | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | curse/0.12 |
| 422 | 雷電牙 | thunder-fang | electric | strike | kit | 16.49 | 0.8455 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.35 |
| 423 | 冰凍牙 | ice-fang | ice | strike | 關都 learnset | 16.49 | 0.8455 | 1 | 3.3 | 0 | 0 | 99 | freeze/0.16 |
| 424 | 火焰牙 | fire-fang | fire | strike | kit | 16.49 | 0.8455 | 1 | 3.3 | 0 | 0 | 99 | burn/0.16 |
| 425 | 影子偷襲 | shadow-sneak | ghost | dash | kit | 17.4769 | 1.6617 | 1 | 1.8 | 13 | 0 | 99 | curse/0.35 |
| 426 | 泥巴炸彈 | mud-bomb | ground | lob | 其他（未證實可選） | 19.4 | 1.691 | 1 | 3.2 | 15 | 3 | 0 | stun/0.12 |
| 427 | 精神利刃 | psycho-cut | psychic | boomerang | kit | 9.6945 | 1.53 | 2 | 0.8 | 17 | 1.3 | 99 | confusion/0.12 |
| 428 | 意念頭錘 | zen-headbutt | psychic | dash | kit | 20.5538 | 2.116 | 1 | 1.8 | 13 | 0 | 99 | confusion/0.12 |
| 429 | 鏡光射擊 | mirror-shot | steel | orb | kit | 14.55 | 1.335 | 1 | 2.6 | 17 | 1.05 | 0 | charm/0.25 |
| 430 | 加農光炮 | flash-cannon | steel | beam | kit | 7.1938 | 2.024 | 1 | 1.1 | 18 | 0.45 | 99 | knock/0.12 |
| 431 | 攀岩 | rock-climb | normal | spin | kit | 9.5954 | 0.752 | 1 | 3.2 | 0 | 0 | 99 | confusion/0.3 |
| 433 | 戲法空間 | trick-room | psychic | vortex | kit | 33.6338 | 3.24 | 1 | 5 | 7 | 2.2 | 99 | stun/0.5 |
| 434 | 流星群 | draco-meteor | dragon | meteor | kit | 54.9 | 4.08 | 1 | 4.2 | 0 | 0.7 | 99 | 無/0.12 |
| 435 | 放電 | discharge | electric | nova | kit | 22.6092 | 2.392 | 1 | 6.5 | 0 | 0 | 99 | paralysis/0.48 |
| 436 | 噴煙 | lava-plume | fire | nova | kit | 22.6092 | 2.392 | 1 | 6.5 | 0 | 0 | 99 | burn/0.48 |
| 437 | 飛葉風暴 | leaf-storm | grass | nova | 關都 learnset | 26.84 | 2.652 | 1 | 6.5 | 0 | 0 | 99 | root/0.12 |
| 438 | 強力鞭打 | power-whip | grass | spin | kit | 10.6338 | 0.8 | 1 | 3.2 | 0 | 0 | 99 | root/0.12 |
| 439 | 岩石炮 | rock-wrecker | rock | meteor | kit | 58.3615 | 4.24 | 1 | 4.2 | 0 | 0.7 | 99 | stun/0.12 |
| 440 | 十字毒刃 | cross-poison | poison | boomerang | 關都 learnset | 13.8492 | 1.53 | 1 | 0.8 | 17 | 1.3 | 99 | poison/0.16 |
| 441 | 垃圾射擊 | gunk-shot | poison | meteor | kit | 53.1692 | 4 | 1 | 4.2 | 0 | 0.7 | 99 | poison/0.48 |
| 442 | 鐵頭 | iron-head | steel | dash | kit | 20.5538 | 2.116 | 1 | 1.8 | 13 | 0 | 99 | stun/0.3 |
| 443 | 磁鐵炸彈 | magnet-bomb | steel | homing | kit | 8.5569 | 1.1 | 2 | 0.5 | 15 | 1.6 | 0 | knock/0.12 |
| 444 | 尖石攻擊 | stone-edge | rock | orbit | 關都 learnset | 9.9415 | 5.28 | 2 | 3.2 | 3.2 | 4 | 99 | stun/0.12 |
| 446 | 隱形岩 | stealth-rock | rock | trap | kit | 27 | 2.34 | 3 | 3 | 0 | 14 | 0 | stun/0.8 |
| 447 | 打草結 | grass-knot | grass | smite | kit | 23.7415 | 1.53 | 2 | 1.9 | 0 | 0 | 99 | stun/0.3 |
| 448 | 喋喋不休 | chatter | flying | vortex | 其他（未證實可選） | 32.98 | 3.204 | 1 | 5 | 7 | 2.2 | 99 | confusion/0.8 |
| 449 | 制裁光礫 | judgment | normal | nova | 其他（未證實可選） | 24.3015 | 2.496 | 1 | 6.5 | 0 | 0 | 99 | 無/0.12 |
| 450 | 蟲咬 | bug-bite | bug | strike | kit | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | poison/0.12 |
| 451 | 充電光束 | charge-beam | electric | beam | 關都 learnset | 6.3862 | 1.892 | 1 | 1.1 | 18 | 0.45 | 99 | paralysis/0.12 |
| 452 | 木槌 | wood-hammer | grass | strike | kit | 20.0862 | 0.95 | 1 | 3.3 | 0 | 0 | 99 | root/0.12 |
| 453 | 水流噴射 | aqua-jet | water | dash | kit | 17.4769 | 1.6617 | 1 | 1.8 | 13 | 0 | 99 | wet/0.12 |
| 454 | 攻擊指令 | attack-order | bug | homing | 其他（未證實可選） | 9.5954 | 1.175 | 2 | 0.5 | 15 | 1.6 | 0 | poison/0.12 |
| 457 | 雙刃頭錘 | head-smash | rock | dash | kit | 33.72 | 2.438 | 1 | 1.8 | 13 | 0 | 99 | stun/0.12 |
| 458 | 二連擊 | double-hit | normal | barrage | kit | 6.8369 | 0.9775 | 2 | 0.35 | 30 | 0.6 | 0 | 無/0.12 |
| 459 | 時光咆哮 | roar-of-time | dragon | nova | 其他（未證實可選） | 28.5323 | 2.756 | 1 | 6.5 | 0 | 0 | 99 | 無/0.12 |
| 460 | 亞空裂斬 | spacial-rend | dragon | wave | 其他（未證實可選） | 16.5692 | 2.304 | 1 | 4 | 13 | 1.1 | 99 | 無/0.12 |
| 462 | 捏碎 | crush-grip | normal | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 463 | 熔岩風暴 | magma-storm | fire | vortex | 其他（未證實可選） | 37.5569 | 3.456 | 1 | 5 | 7 | 2.2 | 99 | root/0.8 |
| 465 | 種子閃光 | seed-flare | grass | beam | 其他（未證實可選） | 8.2708 | 2.2 | 1 | 1.1 | 18 | 0.45 | 99 | root/0.12 |
| 466 | 奇異之風 | ominous-wind | ghost | cone | 其他（未證實可選） | 3.0425 | 1.76 | 1 | 7 | 0 | 1 | 99 | curse/0.12 |
| 467 | 暗影潛襲 | shadow-force | ghost | strike | 其他（未證實可選） | 20.0862 | 0.95 | 1 | 3.3 | 0 | 0 | 99 | curse/0.12 |
| 468 | 磨爪 | hone-claws | dark | buff | 其他（未證實可選） | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | healblock/0.8 |
| 473 | 精神衝擊 | psyshock | psychic | orb | kit | 15.4154 | 1.38 | 1 | 2.6 | 17 | 1.05 | 0 | confusion/0.12 |
| 474 | 毒液衝擊 | venoshock | poison | chain | kit | 12.61 | 1.246 | 3 | 8 | 0 | 0 | 0 | poison/0.35 |
| 475 | 身體輕量化 | autotomize | steel | buff | 其他（未證實可選） | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | knock/0.8 |
| 479 | 擊落 | smack-down | rock | bolt | kit | 11.86 | 0.86 | 1 | 0.5 | 24 | 0.8 | 0 | stun/0.25 |
| 480 | 山嵐摔 | storm-throw | fighting | strike | kit | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 481 | 烈焰濺射 | flame-burst | fire | orb | kit | 14.8385 | 1.35 | 1 | 2.6 | 17 | 1.05 | 0 | burn/0.12 |
| 482 | 污泥波 | sludge-wave | poison | wave | kit | 16.2808 | 2.28 | 1 | 4 | 13 | 1.1 | 99 | poison/0.16 |
| 483 | 蝶舞 | quiver-dance | bug | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | poison/0.8 |
| 484 | 重磅衝撞 | heavy-slam | steel | smite | kit | 30.864 | 1.53 | 1 | 1.9 | 0 | 0 | 99 | stun/0.5 |
| 485 | 同步干擾 | synchronoise | psychic | homing | 其他（未證實可選） | 10.6338 | 1.25 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.12 |
| 486 | 電球 | electro-ball | electric | orb | kit | 14.8385 | 1.35 | 1 | 2.6 | 17 | 1.05 | 0 | paralysis/0.12 |
| 487 | 浸水 | soak | water | cone | kit | 3.7986 | 1.8 | 1 | 7 | 0 | 1 | 99 | wet/1 |
| 488 | 蓄能焰襲 | flame-charge | fire | dash | kit | 18.2462 | 1.978 | 1 | 1.8 | 13 | 0 | 99 | burn/0.12 |
| 489 | 盤蜷 | coil | poison | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | poison/0.8 |
| 490 | 下盤踢 | low-sweep | fighting | strike | 關都 learnset | 16.49 | 0.8455 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 491 | 酸液炸彈 | acid-spray | poison | lob | kit | 17.4769 | 1.615 | 1 | 3.2 | 15 | 3 | 0 | poison/0.12 |
| 492 | 欺詐 | foul-play | dark | smite | 其他（未證實可選） | 26.0492 | 1.615 | 2 | 1.9 | 0 | 0 | 99 | healblock/0.12 |
| 496 | 輪唱 | round | normal | homing | kit | 8.5569 | 1.1 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 497 | 回聲 | echoed-voice | normal | wave | kit | 13.1077 | 2.04 | 1 | 4 | 13 | 1.1 | 99 | 無/0.12 |
| 498 | 逐步擊破 | chip-away | normal | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 499 | 清除之煙 | clear-smog | poison | orb | kit | 13.6846 | 1.29 | 1 | 2.6 | 17 | 1.05 | 0 | poison/0.12 |
| 500 | 輔助力量 | stored-power | psychic | homing | kit | 7.65 | 1.0625 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.12 |
| 503 | 熱水 | scald | water | cone | kit | 3.2886 | 1.84 | 1 | 7 | 0 | 1 | 99 | burn/0.3 |
| 504 | 破殼 | shell-smash | normal | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | 無/0.8 |
| 506 | 禍不單行 | hex | ghost | chain | kit | 12.61 | 1.246 | 3 | 8 | 0 | 0 | 0 | curse/0.12 |
| 507 | 自由落體 | sky-drop | flying | boomerang | 其他（未證實可選） | 13.3108 | 1.496 | 1 | 0.8 | 17 | 1.3 | 99 | knock/0.12 |
| 508 | 換檔 | shift-gear | steel | buff | 其他（未證實可選） | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | knock/0.8 |
| 509 | 巴投 | circle-throw | fighting | spin | kit | 8.5569 | 0.704 | 1 | 3.2 | 0 | 0 | 99 | knock/1 |
| 510 | 燒盡 | incinerate | fire | cone | kit | 3.0425 | 1.76 | 1 | 7 | 0 | 1 | 99 | burn/0.4 |
| 512 | 雜技 | acrobatics | flying | dash | kit | 18.6308 | 2.001 | 1 | 1.8 | 13 | 0 | 99 | knock/0.12 |
| 514 | 報仇 | retaliate | normal | strike | 關都 learnset | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 515 | 搏命 | final-gambit | fighting | meteor | kit | 51.1927 | 3.6 | 1 | 4.2 | 0 | 0.7 | 99 | knock/0.12 |
| 517 | 煉獄 | inferno | fire | orb | kit | 16.5692 | 1.44 | 1 | 2.6 | 17 | 1.05 | 0 | burn/1 |
| 518 | 水之誓約 | water-pledge | water | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | wet/0.12 |
| 519 | 火之誓約 | fire-pledge | fire | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | burn/0.12 |
| 520 | 草之誓約 | grass-pledge | grass | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | root/0.12 |
| 521 | 伏特替換 | volt-switch | electric | boomerang | 其他（未證實可選） | 13.8492 | 1.53 | 1 | 0.8 | 17 | 1.3 | 99 | paralysis/0.12 |
| 522 | 蟲之抵抗 | struggle-bug | bug | cone | 其他（未證實可選） | 2.9194 | 1.72 | 1 | 7 | 0 | 1 | 99 | poison/0.12 |
| 523 | 重踏 | bulldoze | ground | nova | kit | 20.9169 | 2.288 | 1 | 6.5 | 0 | 0 | 99 | stun/0.12 |
| 524 | 冰息 | frost-breath | ice | cone | kit | 3.0425 | 1.76 | 1 | 7 | 0 | 1 | 99 | freeze/0.6 |
| 525 | 龍尾 | dragon-tail | dragon | strike | 關都 learnset | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 526 | 自我激勵 | work-up | normal | buff | 關都 learnset | 0 | 12.6 | 1 | 0 | 0 | 6 | 0 | 無/0.8 |
| 527 | 電網 | electroweb | electric | cone | kit | 2.9809 | 1.74 | 1 | 7 | 0 | 1 | 99 | root/0.3 |
| 528 | 瘋狂伏特 | wild-charge | electric | dash | kit | 21.3231 | 2.162 | 1 | 1.8 | 13 | 0 | 99 | paralysis/0.12 |
| 529 | 直衝鑽 | drill-run | ground | dash | kit | 20.5538 | 2.116 | 1 | 1.8 | 13 | 0 | 99 | stun/0.12 |
| 530 | 二連劈 | dual-chop | dragon | strike | 其他（未證實可選） | 14.8554 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 531 | 愛心印章 | heart-stamp | psychic | strike | kit | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | stun/0.3 |
| 532 | 木角 | horn-leech | grass | dash | kit | 20.1692 | 2.093 | 1 | 1.8 | 13 | 0 | 99 | root/0.12 |
| 533 | 聖劍 | sacred-sword | fighting | boomerang | kit | 10.4483 | 1.598 | 2 | 0.8 | 17 | 1.3 | 99 | knock/0.12 |
| 534 | 貝殼刃 | razor-shell | water | strike | kit | 12.8579 | 0.8645 | 2 | 3.3 | 0 | 0 | 99 | wet/0.12 |
| 535 | 高溫重壓 | heat-crash | fire | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | burn/0.12 |
| 536 | 青草攪拌器 | leaf-tornado | grass | vortex | 其他（未證實可選） | 32.98 | 3.204 | 1 | 5 | 7 | 2.2 | 99 | root/0.12 |
| 537 | 瘋狂滾壓 | steamroller | bug | strike | 其他（未證實可選） | 16.49 | 0.8455 | 1 | 3.3 | 0 | 0 | 99 | poison/0.12 |
| 539 | 暗黑爆破 | night-daze | dark | orb | 其他（未證實可選） | 15.7038 | 1.395 | 1 | 2.6 | 17 | 1.05 | 0 | healblock/0.12 |
| 540 | 精神擊破 | psystrike | psychic | orb | kit | 16.5692 | 1.44 | 1 | 2.6 | 17 | 1.05 | 0 | confusion/0.3 |
| 541 | 掃尾拍打 | tail-slap | normal | barrage | 其他（未證實可選） | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | 無/0.12 |
| 542 | 暴風 | hurricane | flying | vortex | kit | 38.8646 | 3.528 | 1 | 5 | 7 | 2.2 | 99 | confusion/0.48 |
| 543 | 爆炸頭突擊 | head-charge | normal | dash | 其他（未證實可選） | 23.6308 | 2.3 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 544 | 齒輪飛盤 | gear-grind | steel | barrage | 其他（未證實可選） | 4.5615 | 0.989 | 4 | 0.35 | 30 | 0.6 | 0 | knock/0.12 |
| 545 | 火焰彈 | searing-shot | fire | orb | kit | 16.5692 | 1.44 | 1 | 2.6 | 17 | 1.05 | 0 | burn/0.5 |
| 546 | 高科技光炮 | techno-blast | normal | beam | kit | 8.2708 | 2.2 | 1 | 1.1 | 18 | 0.45 | 99 | 無/0.12 |
| 547 | 古老之歌 | relic-song | normal | nova | 其他（未證實可選） | 22.1862 | 2.366 | 1 | 6.5 | 0 | 0 | 99 | sleep/0.16 |
| 548 | 神秘之劍 | secret-sword | fighting | boomerang | 其他（未證實可選） | 14.6569 | 1.581 | 1 | 0.8 | 17 | 1.3 | 99 | knock/0.12 |
| 549 | 冰封世界 | glaciate | ice | wave | kit | 14.55 | 2.136 | 1 | 4 | 13 | 1.1 | 99 | freeze/0.6 |
| 550 | 雷擊 | bolt-strike | electric | meteor | kit | 54.9 | 4.08 | 1 | 4.2 | 0 | 0.7 | 99 | paralysis/0.6 |
| 551 | 青焰 | blue-flare | fire | meteor | 其他（未證實可選） | 54.9 | 4.08 | 1 | 4.2 | 0 | 0.7 | 99 | burn/0.32 |
| 552 | 火之舞 | fiery-dance | fire | spin | 其他（未證實可選） | 9.2492 | 0.736 | 1 | 3.2 | 0 | 0 | 99 | burn/0.12 |
| 553 | 冰凍伏特 | freeze-shock | ice | strike | 其他（未證實可選） | 21.3938 | 0.988 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.48 |
| 554 | 極寒冷焰 | ice-burn | ice | bolt | 其他（未證實可選） | 16.36 | 1.04 | 1 | 0.5 | 24 | 0.8 | 0 | burn/0.48 |
| 555 | 大聲咆哮 | snarl | dark | cone | 其他（未證實可選） | 2.9809 | 1.74 | 1 | 7 | 0 | 1 | 99 | healblock/0.12 |
| 556 | 冰柱墜擊 | icicle-crash | ice | smite | kit | 16.332 | 1.581 | 3 | 1.9 | 0 | 0 | 99 | stun/0.3 |
| 557 | Ｖ熱焰 | v-create | fire | strike | 其他（未證實可選） | 22.1 | 1.064 | 1 | 3.3 | 0 | 0 | 99 | burn/0.12 |
| 558 | 交錯火焰 | fusion-flare | fire | orb | 其他（未證實可選） | 16.5692 | 1.44 | 1 | 2.6 | 17 | 1.05 | 0 | burn/0.12 |
| 559 | 交錯閃電 | fusion-bolt | electric | chain | kit | 14.36 | 1.344 | 3 | 8 | 0 | 0 | 0 | paralysis/0.3 |
| 560 | 飛身重壓 | flying-press | fighting | strike | 其他（未證實可選） | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 562 | 打嗝 | belch | poison | cone | kit | 4.3481 | 2 | 1 | 7 | 0 | 1 | 99 | poison/0.5 |
| 564 | 黏黏網 | sticky-web | bug | trap | 其他（未證實可選） | 27 | 2.34 | 2 | 3 | 0 | 14 | 0 | poison/0.8 |
| 565 | 致命針刺 | fell-stinger | bug | bolt | 關都 learnset | 11.86 | 0.86 | 1 | 0.5 | 24 | 0.8 | 0 | poison/0.12 |
| 566 | 潛靈奇襲 | phantom-force | ghost | dash | 其他（未證實可選） | 21.3231 | 2.162 | 1 | 1.8 | 13 | 0 | 99 | curse/0.12 |
| 570 | 拋物面充電 | parabolic-charge | electric | aura | kit | 4.365 | 0.4005 | 1 | 3.6 | 0 | 0 | 99 | paralysis/0.12 |
| 572 | 落英繽紛 | petal-blizzard | grass | nova | kit | 23.4554 | 2.444 | 1 | 6.5 | 0 | 0 | 99 | root/0.12 |
| 573 | 冷凍乾燥 | freeze-dry | ice | orb | kit | 14.8385 | 1.35 | 1 | 2.6 | 17 | 1.05 | 0 | freeze/0.4 |
| 574 | 魅惑之聲 | disarming-voice | fairy | nova | 關都 learnset | 19.2246 | 2.21 | 1 | 6.5 | 0 | 0 | 99 | charm/0.12 |
| 577 | 吸取之吻 | draining-kiss | fairy | drain | kit | 9.1231 | 1.118 | 1 | 0.5 | 18 | 1.1 | 0 | charm/0.12 |
| 583 | 嬉鬧 | play-rough | fairy | spin | kit | 9.5954 | 0.752 | 1 | 3.2 | 0 | 0 | 99 | charm/0.12 |
| 584 | 妖精之風 | fairy-wind | fairy | cone | 其他（未證實可選） | 2.7963 | 1.7 | 1 | 7 | 0 | 1 | 99 | charm/0.12 |
| 585 | 月亮之力 | moonblast | fairy | orb | kit | 16.2808 | 1.425 | 1 | 2.6 | 17 | 1.05 | 0 | charm/0.12 |
| 586 | 爆音波 | boomburst | normal | nova | kit | 27.6862 | 2.704 | 1 | 6.5 | 0 | 0 | 99 | 無/0.12 |
| 591 | 鑽石風暴 | diamond-storm | rock | nova | 其他（未證實可選） | 24.3015 | 2.496 | 1 | 6.5 | 0 | 0 | 99 | stun/0.12 |
| 592 | 蒸汽爆炸 | steam-eruption | water | nova | 其他（未證實可選） | 25.1477 | 2.548 | 1 | 6.5 | 0 | 0 | 99 | burn/0.48 |
| 593 | 異次元洞 | hyperspace-hole | psychic | homing | 其他（未證實可選） | 9.2492 | 1.15 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.12 |
| 594 | 飛水手裡劍 | water-shuriken | water | barrage | kit | 4.25 | 0.8309 | 4 | 0.35 | 30 | 0.6 | 0 | wet/0.12 |
| 595 | 魔法火焰 | mystical-fire | fire | homing | kit | 9.0762 | 1.1375 | 2 | 0.5 | 15 | 1.6 | 0 | burn/0.12 |
| 605 | 魔法閃耀 | dazzling-gleam | fairy | nova | 關都 learnset | 22.6092 | 2.392 | 1 | 6.5 | 0 | 0 | 99 | charm/0.12 |
| 609 | 蹭蹭臉頰 | nuzzle | electric | strike | 關都 learnset | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.8 |
| 610 | 手下留情 | hold-back | normal | strike | 其他（未證實可選） | 14.8554 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 611 | 死纏爛打 | infestation | bug | barrage | 其他（未證實可選） | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | root/0.8 |
| 612 | 增強拳 | power-up-punch | fighting | strike | 其他（未證實可選） | 14.8554 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 613 | 死亡之翼 | oblivion-wing | flying | drain | 其他（未證實可選） | 10.2769 | 1.196 | 1 | 0.5 | 18 | 1.1 | 0 | knock/0.12 |
| 614 | 千箭齊發 | thousand-arrows | ground | smite | 其他（未證實可選） | 25.5877 | 1.598 | 2 | 1.9 | 0 | 0 | 99 | stun/0.12 |
| 615 | 千波激盪 | thousand-waves | ground | wave | 其他（未證實可選） | 15.9923 | 2.256 | 1 | 4 | 13 | 1.1 | 99 | stun/0.12 |
| 616 | 大地神力 | lands-wrath | ground | strike | 其他（未證實可選） | 18.1246 | 0.893 | 1 | 3.3 | 0 | 0 | 99 | stun/0.12 |
| 617 | 破滅之光 | light-of-ruin | fairy | beam | 其他（未證實可選） | 8.8092 | 2.288 | 1 | 1.1 | 18 | 0.45 | 99 | charm/0.12 |
| 618 | 根源波動 | origin-pulse | water | nova | 其他（未證實可選） | 25.1477 | 2.548 | 1 | 6.5 | 0 | 0 | 99 | wet/0.12 |
| 619 | 斷崖之劍 | precipice-blades | ground | nova | 其他（未證實可選） | 25.9938 | 2.6 | 1 | 6.5 | 0 | 0 | 99 | stun/0.12 |
| 620 | 畫龍點睛 | dragon-ascent | flying | meteor | kit | 58.4862 | 4 | 1 | 4.2 | 0 | 0.7 | 99 | knock/0.12 |
| 621 | 異次元猛攻 | hyperspace-fury | dark | strike | 其他（未證實可選） | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 622 | 究極無敵大衝撞 | breakneck-blitz--physical | normal | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 623 | 究極無敵大衝撞 | breakneck-blitz--special | normal | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 624 | 全力無雙激烈拳 | all-out-pummeling--physical | fighting | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 625 | 全力無雙激烈拳 | all-out-pummeling--special | fighting | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | knock/0.12 |
| 626 | 極速俯衝轟烈撞 | supersonic-skystrike--physical | flying | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 627 | 極速俯衝轟烈撞 | supersonic-skystrike--special | flying | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 628 | 強酸劇毒滅絕雨 | acid-downpour--physical | poison | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | poison/0.12 |
| 629 | 強酸劇毒滅絕雨 | acid-downpour--special | poison | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | poison/0.12 |
| 630 | 地隆嘯天大終結 | tectonic-rage--physical | ground | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | stun/0.12 |
| 631 | 地隆嘯天大終結 | tectonic-rage--special | ground | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | stun/0.12 |
| 632 | 毀天滅地巨岩墜 | continental-crush--physical | rock | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | stun/0.12 |
| 633 | 毀天滅地巨岩墜 | continental-crush--special | rock | dash | 其他（未證實可選） | 19.7846 | 2.07 | 1 | 1.8 | 13 | 0 | 99 | stun/0.12 |
| 634 | 絕對捕食迴旋斬 | savage-spin-out--physical | bug | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | poison/0.12 |
| 635 | 絕對捕食迴旋斬 | savage-spin-out--special | bug | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | poison/0.12 |
| 636 | 無盡暗夜之誘惑 | never-ending-nightmare--physical | ghost | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | curse/0.12 |
| 637 | 無盡暗夜之誘惑 | never-ending-nightmare--special | ghost | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | curse/0.12 |
| 638 | 超絕螺旋連擊 | corkscrew-crash--physical | steel | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 639 | 超絕螺旋連擊 | corkscrew-crash--special | steel | dash | 其他（未證實可選） | 19.7846 | 2.07 | 1 | 1.8 | 13 | 0 | 99 | knock/0.12 |
| 640 | 超強極限爆焰彈 | inferno-overdrive--physical | fire | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | burn/0.12 |
| 641 | 超強極限爆焰彈 | inferno-overdrive--special | fire | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | burn/0.12 |
| 642 | 超級水流大漩渦 | hydro-vortex--physical | water | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | wet/0.12 |
| 643 | 超級水流大漩渦 | hydro-vortex--special | water | vortex | 其他（未證實可選） | 33.6338 | 3.24 | 1 | 5 | 7 | 2.2 | 99 | wet/0.12 |
| 644 | 絢爛繽紛花怒放 | bloom-doom--physical | grass | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | root/0.12 |
| 645 | 絢爛繽紛花怒放 | bloom-doom--special | grass | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | root/0.12 |
| 646 | 終極伏特狂雷閃 | gigavolt-havoc--physical | electric | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.12 |
| 647 | 終極伏特狂雷閃 | gigavolt-havoc--special | electric | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | paralysis/0.12 |
| 648 | 至高精神破壞波 | shattered-psyche--physical | psychic | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | confusion/0.12 |
| 649 | 至高精神破壞波 | shattered-psyche--special | psychic | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.12 |
| 650 | 激狂大地萬里冰 | subzero-slammer--physical | ice | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | freeze/0.12 |
| 651 | 激狂大地萬里冰 | subzero-slammer--special | ice | dash | 其他（未證實可選） | 19.7846 | 2.07 | 1 | 1.8 | 13 | 0 | 99 | freeze/0.12 |
| 652 | 究極巨龍震天地 | devastating-drake--physical | dragon | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 653 | 究極巨龍震天地 | devastating-drake--special | dragon | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 654 | 黑洞吞噬萬物滅 | black-hole-eclipse--physical | dark | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 655 | 黑洞吞噬萬物滅 | black-hole-eclipse--special | dark | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | healblock/0.12 |
| 656 | 可愛星星飛天撞 | twinkle-tackle--physical | fairy | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | charm/0.12 |
| 657 | 可愛星星飛天撞 | twinkle-tackle--special | fairy | dash | 其他（未證實可選） | 19.7846 | 2.07 | 1 | 1.8 | 13 | 0 | 99 | charm/0.12 |
| 658 | 皮卡皮卡必殺擊 | catastropika | electric | strike | 其他（未證實可選） | 22.1 | 1.0925 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.12 |
| 660 | 迎頭一擊 | first-impression | bug | dash | 其他（未證實可選） | 21.3231 | 1.8377 | 1 | 1.8 | 13 | 0 | 99 | poison/0.12 |
| 662 | 縫影 | spirit-shackle | ghost | boomerang | 其他（未證實可選） | 14.3877 | 1.564 | 1 | 0.8 | 17 | 1.3 | 99 | curse/0.12 |
| 663 | ＤＤ金勾臂 | darkest-lariat | dark | spin | 其他（未證實可選） | 9.4223 | 0.744 | 1 | 3.2 | 0 | 0 | 99 | healblock/0.12 |
| 664 | 泡影的詠歎調 | sparkling-aria | water | nova | 其他（未證實可選） | 23.4554 | 2.444 | 1 | 6.5 | 0 | 0 | 99 | wet/0.12 |
| 665 | 冰錘 | ice-hammer | ice | strike | 其他（未證實可選） | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | freeze/0.12 |
| 667 | 十萬馬力 | high-horsepower | ground | dash | kit | 21.7077 | 2.185 | 1 | 1.8 | 13 | 0 | 99 | stun/0.12 |
| 669 | 日光刃 | solar-blade | grass | beam | kit | 8.4054 | 2.222 | 1 | 1.1 | 18 | 0.45 | 99 | root/0.12 |
| 670 | 樹葉 | leafage | grass | bolt | 其他（未證實可選） | 11.36 | 0.85 | 1 | 0.5 | 24 | 0.8 | 0 | root/0.12 |
| 675 | 地獄突刺 | throat-chop | dark | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 676 | 花粉團 | pollen-puff | bug | lob | 其他（未證實可選） | 21.3231 | 1.786 | 1 | 3.2 | 15 | 3 | 0 | poison/0.12 |
| 677 | 擲錨 | anchor-shot | steel | boomerang | 其他（未證實可選） | 14.3877 | 1.564 | 1 | 0.8 | 17 | 1.3 | 99 | knock/0.12 |
| 679 | 猛撲 | lunge | bug | dash | kit | 20.5538 | 2.116 | 1 | 1.8 | 13 | 0 | 99 | poison/0.12 |
| 680 | 火焰鞭 | fire-lash | fire | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | burn/0.12 |
| 681 | 囂張 | power-trip | dark | strike | 其他（未證實可選） | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 682 | 燃盡 | burn-up | fire | nova | 其他（未證實可選） | 26.84 | 2.652 | 1 | 6.5 | 0 | 0 | 99 | burn/0.12 |
| 684 | 修長之角 | smart-strike | steel | homing | kit | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | knock/0.12 |
| 686 | 覺醒之舞 | revelation-dance | normal | homing | 其他（未證實可選） | 9.5954 | 1.175 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 687 | 核心懲罰者 | core-enforcer | dragon | wave | 其他（未證實可選） | 16.5692 | 2.304 | 1 | 4 | 13 | 1.1 | 99 | 無/0.12 |
| 688 | 熱帶踢 | trop-kick | grass | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | root/0.12 |
| 690 | 鳥嘴加農炮 | beak-blast | flying | nova | 其他（未證實可選） | 24.3015 | 2.496 | 1 | 6.5 | 0 | 0 | 99 | knock/0.12 |
| 691 | 鱗片噪音 | clanging-scales | dragon | nova | 其他（未證實可選） | 25.1477 | 2.548 | 1 | 6.5 | 0 | 0 | 99 | 無/0.12 |
| 692 | 龍錘 | dragon-hammer | dragon | strike | 其他（未證實可選） | 18.1246 | 0.893 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 693 | 狂舞揮打 | brutal-swing | dark | strike | 其他（未證實可選） | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 695 | 遮天蔽日暗影箭 | sinister-arrow-raid | ghost | strike | 其他（未證實可選） | 22.1 | 1.064 | 1 | 3.3 | 0 | 0 | 99 | curse/0.12 |
| 696 | 極惡飛躍粉碎擊 | malicious-moonsault | dark | strike | 其他（未證實可選） | 22.1 | 1.064 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 697 | 海神莊嚴交響樂 | oceanic-operetta | water | homing | 其他（未證實可選） | 11.7 | 1.4375 | 2 | 0.5 | 15 | 1.6 | 0 | wet/0.12 |
| 698 | 巨人衛士・阿羅拉 | guardian-of-alola | fairy | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | charm/0.12 |
| 699 | 七星奪魂腿 | soul-stealing-7-star-strike | ghost | strike | 其他（未證實可選） | 22.1 | 1.0925 | 1 | 3.3 | 0 | 0 | 99 | curse/0.12 |
| 700 | 駕雷馭電戲衝浪 | stoked-sparksurfer | electric | homing | 其他（未證實可選） | 11.7 | 1.3875 | 2 | 0.5 | 15 | 1.6 | 0 | paralysis/0.8 |
| 701 | 認真起來大爆擊 | pulverizing-pancake | normal | strike | 其他（未證實可選） | 22.1 | 1.0925 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 703 | 起源超新星大爆炸 | genesis-supernova | psychic | homing | 其他（未證實可選） | 11.7 | 1.4125 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.12 |
| 704 | 陷阱甲殼 | shell-trap | fire | trap | 其他（未證實可選） | 38.9077 | 2.756 | 2 | 3 | 0 | 14 | 0 | burn/0.12 |
| 705 | 花朵加農炮 | fleur-cannon | fairy | beam | 其他（未證實可選） | 8.54 | 2.244 | 1 | 1.1 | 18 | 0.45 | 99 | charm/0.12 |
| 706 | 精神之牙 | psychic-fangs | psychic | strike | 其他（未證實可選） | 17.7977 | 0.8835 | 1 | 3.3 | 0 | 0 | 99 | confusion/0.12 |
| 707 | 跺腳 | stomping-tantrum | ground | nova | kit | 22.1862 | 2.366 | 1 | 6.5 | 0 | 0 | 99 | stun/0.12 |
| 708 | 暗影之骨 | shadow-bone | ghost | boomerang | kit | 10.2598 | 1.581 | 3 | 0.8 | 17 | 1.3 | 99 | curse/0.12 |
| 709 | 衝岩 | accelerock | rock | dash | 其他（未證實可選） | 17.4769 | 1.6617 | 1 | 1.8 | 13 | 0 | 99 | stun/0.12 |
| 710 | 水流裂破 | liquidation | water | dash | kit | 20.9385 | 2.139 | 1 | 1.8 | 13 | 0 | 99 | wet/0.12 |
| 711 | 稜鏡鐳射 | prismatic-laser | psychic | beam | kit | 9.1 | 2.376 | 1 | 1.1 | 18 | 0.45 | 99 | confusion/0.12 |
| 712 | 暗影偷盜 | spectral-thief | ghost | strike | 其他（未證實可選） | 18.1246 | 0.893 | 1 | 3.3 | 0 | 0 | 99 | curse/0.12 |
| 713 | 流星閃衝 | sunsteel-strike | steel | dash | 其他（未證實可選） | 22.0923 | 2.208 | 1 | 1.8 | 13 | 0 | 99 | knock/0.12 |
| 714 | 暗影之光 | moongeist-beam | ghost | beam | 其他（未證實可選） | 7.7323 | 2.112 | 1 | 1.1 | 18 | 0.45 | 99 | curse/0.12 |
| 716 | 麻麻刺刺 | zing-zap | electric | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.12 |
| 717 | 自然之怒 | natures-madness | fairy | orb | 其他（未證實可選） | 14.8385 | 1.35 | 1 | 2.6 | 17 | 1.05 | 0 | charm/0.12 |
| 718 | 多屬性攻擊 | multi-attack | normal | strike | 其他（未證實可選） | 20.0862 | 0.95 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 719 | 千萬伏特 | 10-000-000-volt-thunderbolt | electric | chain | 其他（未證實可選） | 16.9 | 1.61 | 3 | 8 | 0 | 0 | 0 | paralysis/0.12 |
| 720 | 驚爆大頭 | mind-blown | fire | orb | 其他（未證實可選） | 19.4538 | 1.59 | 1 | 2.6 | 17 | 1.05 | 0 | burn/0.12 |
| 721 | 等離子閃電拳 | plasma-fists | electric | strike | 其他（未證實可選） | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.12 |
| 722 | 光子噴湧 | photon-geyser | psychic | beam | kit | 7.7323 | 2.112 | 1 | 1.1 | 18 | 0.45 | 99 | confusion/0.12 |
| 723 | 焚天滅世熾光爆 | light-that-burns-the-sky | psychic | homing | 其他（未證實可選） | 11.7 | 1.4375 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.12 |
| 724 | 日光迴旋下蒼穹 | searing-sunraze-smash | steel | strike | 其他（未證實可選） | 22.1 | 1.0925 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 725 | 月華飛濺落靈霄 | menacing-moonraze-maelstrom | ghost | homing | 其他（未證實可選） | 11.7 | 1.4375 | 2 | 0.5 | 15 | 1.6 | 0 | curse/0.12 |
| 726 | 親密無間大亂揍 | lets-snuggle-forever | fairy | strike | 其他（未證實可選） | 22.1 | 1.083 | 1 | 3.3 | 0 | 0 | 99 | charm/0.12 |
| 727 | 狼嘯石牙颶風暴 | splintered-stormshards | rock | vortex | 其他（未證實可選） | 44.2 | 4.104 | 1 | 5 | 7 | 2.2 | 99 | stun/0.12 |
| 728 | 熾魂熱舞烈音爆 | clangorous-soulblaze | dragon | homing | 其他（未證實可選） | 11.7 | 1.4125 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 729 | 電電加速 | zippy-zap | electric | strike | 其他（未證實可選） | 17.4708 | 0.7429 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.12 |
| 730 | 滔滔衝浪 | splishy-splash | water | bolt | 其他（未證實可選） | 13.86 | 0.94 | 1 | 0.5 | 24 | 0.8 | 0 | paralysis/0.48 |
| 731 | 飄飄墜落 | floaty-fall | flying | meteor | 其他（未證實可選） | 47.9769 | 3.76 | 1 | 4.2 | 0 | 0.7 | 99 | knock/0.12 |
| 732 | 閃閃雷光 | pika-papow | electric | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | paralysis/0.12 |
| 733 | 活活氣泡 | bouncy-bubble | water | drain | 其他（未證實可選） | 9.5077 | 1.144 | 1 | 0.5 | 18 | 1.1 | 0 | wet/0.12 |
| 734 | 麻麻電擊 | buzzy-buzz | electric | chain | 其他（未證實可選） | 12.36 | 1.232 | 3 | 8 | 0 | 0 | 0 | paralysis/0.8 |
| 735 | 熊熊火爆 | sizzly-slide | fire | strike | 其他（未證實可選） | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | burn/0.8 |
| 736 | 嘩嘩氣場 | glitzy-glow | psychic | homing | 其他（未證實可選） | 9.2492 | 1.15 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.12 |
| 737 | 壞壞領域 | baddy-bad | dark | orb | 其他（未證實可選） | 15.4154 | 1.38 | 1 | 2.6 | 17 | 1.05 | 0 | healblock/0.12 |
| 738 | 茁茁轟炸 | sappy-seed | grass | strike | 其他（未證實可選） | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | root/0.8 |
| 739 | 冰冰霜凍 | freezy-frost | ice | bolt | 其他（未證實可選） | 14.36 | 0.96 | 1 | 0.5 | 24 | 0.8 | 0 | freeze/0.12 |
| 740 | 亮亮風暴 | sparkly-swirl | fairy | orb | 其他（未證實可選） | 17.7231 | 1.5 | 1 | 2.6 | 17 | 1.05 | 0 | charm/0.12 |
| 741 | 砰砰擊破 | veevee-volley | normal | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 742 | 鋼拳雙擊 | double-iron-bash | steel | barrage | 其他（未證實可選） | 4.7538 | 1.012 | 4 | 0.35 | 30 | 0.6 | 0 | knock/0.12 |
| 744 | 極巨炮 | dynamax-cannon | dragon | beam | 其他（未證實可選） | 7.7323 | 2.112 | 1 | 1.1 | 18 | 0.45 | 99 | 無/0.12 |
| 745 | 狙擊 | snipe-shot | water | bolt | kit | 13.36 | 0.92 | 1 | 0.5 | 24 | 0.8 | 0 | wet/0.12 |
| 746 | 緊咬不放 | jaw-lock | dark | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 751 | 龍箭 | dragon-darts | dragon | homing | 其他（未證實可選） | 8.2108 | 1.075 | 2 | 0.5 | 15 | 1.6 | 0 | 無/0.12 |
| 754 | 電喙 | bolt-beak | electric | dash | kit | 20.9385 | 2.139 | 1 | 1.8 | 13 | 0 | 99 | paralysis/0.25 |
| 755 | 鰓咬 | fishious-rend | water | strike | kit | 17.7977 | 0.8835 | 1 | 3.3 | 0 | 0 | 99 | wet/0.12 |
| 757 | 極巨火爆 | max-flare | fire | strike | 其他（未證實可選） | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | burn/0.12 |
| 758 | 極巨蟲蠱 | max-flutterby | bug | strike | 其他（未證實可選） | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | poison/0.12 |
| 759 | 極巨閃電 | max-lightning | electric | chain | 其他（未證實可選） | 11.05 | 1.19 | 3 | 8 | 0 | 0 | 0 | paralysis/0.12 |
| 760 | 極巨攻擊 | max-strike | normal | strike | 其他（未證實可選） | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 761 | 極巨拳鬥 | max-knuckle | fighting | strike | 其他（未證實可選） | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 762 | 極巨幽魂 | max-phantasm | ghost | strike | 其他（未證實可選） | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | curse/0.12 |
| 763 | 極巨寒冰 | max-hailstorm | ice | vortex | 其他（未證實可選） | 28.9 | 3.06 | 1 | 5 | 7 | 2.2 | 99 | freeze/0.12 |
| 764 | 極巨酸毒 | max-ooze | poison | strike | 其他（未證實可選） | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | poison/0.12 |
| 765 | 極巨水流 | max-geyser | water | dash | 其他（未證實可選） | 17 | 1.955 | 1 | 1.8 | 13 | 0 | 99 | wet/0.12 |
| 766 | 極巨飛衝 | max-airstream | flying | boomerang | 其他（未證實可選） | 11.9 | 1.445 | 1 | 0.8 | 17 | 1.3 | 99 | knock/0.12 |
| 767 | 極巨妖精 | max-starfall | fairy | meteor | 其他（未證實可選） | 38.25 | 3.4 | 1 | 4.2 | 0 | 0.7 | 99 | charm/0.12 |
| 768 | 極巨龍騎 | max-wyrmwind | dragon | cone | 其他（未證實可選） | 2.72 | 1.7 | 1 | 7 | 0 | 1 | 99 | 無/0.12 |
| 769 | 極巨超能 | max-mindstorm | psychic | vortex | 其他（未證實可選） | 28.9 | 3.06 | 1 | 5 | 7 | 2.2 | 99 | confusion/0.12 |
| 770 | 極巨岩石 | max-rockfall | rock | meteor | 其他（未證實可選） | 38.25 | 3.4 | 1 | 4.2 | 0 | 0.7 | 99 | stun/0.12 |
| 771 | 極巨大地 | max-quake | ground | nova | 其他（未證實可選） | 18.7 | 2.21 | 1 | 6.5 | 0 | 0 | 99 | stun/0.12 |
| 772 | 極巨惡霸 | max-darkness | dark | strike | 其他（未證實可選） | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 773 | 極巨草原 | max-overgrowth | grass | strike | 其他（未證實可選） | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | root/0.12 |
| 774 | 極巨鋼鐵 | max-steelspike | steel | trap | 其他（未證實可選） | 25.5 | 2.21 | 2 | 3 | 0 | 14 | 0 | knock/0.12 |
| 776 | 撲擊 | body-press | fighting | nova | kit | 22.6092 | 2.392 | 1 | 6.5 | 0 | 0 | 99 | knock/0.12 |
| 778 | 鼓擊 | drum-beating | grass | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | root/0.12 |
| 779 | 捕獸夾 | snap-trap | grass | trap | 其他（未證實可選） | 25.6385 | 2.21 | 2 | 3 | 0 | 14 | 0 | root/0.8 |
| 780 | 火焰球 | pyro-ball | fire | lob | 其他（未證實可選） | 23.6308 | 1.9 | 1 | 3.2 | 15 | 3 | 0 | burn/0.16 |
| 781 | 巨獸斬 | behemoth-blade | steel | strike | 其他（未證實可選） | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 782 | 巨獸彈 | behemoth-bash | steel | strike | 其他（未證實可選） | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 783 | 氣場輪 | aura-wheel | electric | strike | 其他（未證實可選） | 19.4323 | 0.931 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.12 |
| 784 | 廣域破壞 | breaking-swipe | dragon | strike | 其他（未證實可選） | 16.1631 | 0.836 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 785 | 木枝突刺 | branch-poke | grass | strike | 其他（未證實可選） | 14.8554 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | root/0.12 |
| 786 | 破音 | overdrive | electric | chain | 其他（未證實可選） | 13.36 | 1.288 | 3 | 8 | 0 | 0 | 0 | paralysis/0.12 |
| 787 | 蘋果酸 | apple-acid | grass | lob | 其他（未證實可選） | 20.5538 | 1.748 | 1 | 3.2 | 15 | 3 | 0 | root/0.12 |
| 788 | 萬有引力 | grav-apple | grass | meteor | 其他（未證實可選） | 46.2462 | 3.68 | 1 | 4.2 | 0 | 0.7 | 99 | root/0.12 |
| 789 | 靈魂衝擊 | spirit-break | fairy | strike | 其他（未證實可選） | 17.1438 | 0.8645 | 1 | 3.3 | 0 | 0 | 99 | charm/0.12 |
| 790 | 神奇蒸汽 | strange-steam | fairy | cone | 其他（未證實可選） | 3.4117 | 1.88 | 1 | 7 | 0 | 1 | 99 | confusion/0.32 |
| 793 | 假跪真撞 | false-surrender | dark | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 794 | 流星突擊 | meteor-assault | fighting | meteor | kit | 70.0338 | 4.24 | 1 | 4.2 | 0 | 0.7 | 99 | knock/0.12 |
| 795 | 無極光束 | eternabeam | dragon | beam | 其他（未證實可選） | 9.1 | 2.376 | 1 | 1.1 | 18 | 0.45 | 99 | 無/0.12 |
| 796 | 鐵蹄光線 | steel-beam | steel | beam | 其他（未證實可選） | 8.8092 | 2.288 | 1 | 1.1 | 18 | 0.45 | 99 | knock/0.12 |
| 797 | 廣域戰力 | expanding-force | psychic | nova | kit | 22.6092 | 2.392 | 1 | 6.5 | 0 | 0 | 99 | confusion/0.12 |
| 798 | 鐵滾輪 | steel-roller | steel | trail | 其他（未證實可選） | 7.32 | 0.2856 | 1 | 1.7 | 0 | 3 | 99 | knock/0.12 |
| 799 | 鱗射 | scale-shot | dragon | barrage | kit | 3.6125 | 0.9775 | 5 | 0.35 | 30 | 0.6 | 0 | 無/0.12 |
| 800 | 流星光束 | meteor-beam | rock | beam | kit | 8.2708 | 2.2 | 1 | 1.1 | 18 | 0.45 | 99 | stun/0.12 |
| 801 | 臂貝武器 | shell-side-arm | poison | lob | 其他（未證實可選） | 21.3231 | 1.786 | 1 | 3.2 | 15 | 3 | 0 | poison/0.32 |
| 802 | 薄霧炸裂 | misty-explosion | fairy | nova | kit | 29.1618 | 2.496 | 1 | 6.5 | 0 | 0 | 99 | charm/0.35 |
| 803 | 青草滑梯 | grassy-glide | grass | dash | 其他（未證實可選） | 18.6308 | 2.001 | 1 | 1.8 | 13 | 0 | 99 | root/0.12 |
| 804 | 電力上升 | rising-voltage | electric | smite | kit | 23.7415 | 1.53 | 2 | 1.9 | 0 | 0 | 99 | paralysis/0.12 |
| 805 | 大地波動 | terrain-pulse | normal | orb | 其他（未證實可選） | 13.6846 | 1.29 | 1 | 2.6 | 17 | 1.05 | 0 | 無/0.12 |
| 806 | 爬擊 | skitter-smack | bug | strike | 其他（未證實可選） | 16.8169 | 0.855 | 1 | 3.3 | 0 | 0 | 99 | poison/0.12 |
| 807 | 妒火 | burning-jealousy | fire | orb | 其他（未證實可選） | 14.8385 | 1.35 | 1 | 2.6 | 17 | 1.05 | 0 | burn/0.8 |
| 808 | 洩憤 | lash-out | dark | strike | 其他（未證實可選） | 17.1438 | 0.8645 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 809 | 靈騷 | poltergeist | ghost | smite | 其他（未證實可選） | 27.4338 | 1.666 | 2 | 1.9 | 0 | 0 | 99 | curse/0.12 |
| 812 | 快速折返 | flip-turn | water | dash | 其他（未證實可選） | 19.0154 | 2.024 | 1 | 1.8 | 13 | 0 | 99 | wet/0.12 |
| 813 | 三旋擊 | triple-axel | ice | spin | 其他（未證實可選） | 7.65 | 0.68 | 1 | 3.2 | 0 | 0 | 99 | freeze/0.12 |
| 814 | 雙翼 | dual-wingbeat | flying | barrage | kit | 7.8646 | 0.9775 | 2 | 0.35 | 30 | 0.6 | 0 | knock/0.12 |
| 815 | 熱沙大地 | scorching-sands | ground | cone | 其他（未證實可選） | 3.1655 | 1.8 | 1 | 7 | 0 | 1 | 99 | burn/0.48 |
| 817 | 暗冥強擊 | wicked-blow | dark | strike | 其他（未證實可選） | 17.1438 | 0.8645 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 818 | 水流連打 | surging-strikes | water | barrage | 其他（未證實可選） | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | wet/0.12 |
| 819 | 雷電囚籠 | thunder-cage | electric | vortex | kit | 34.9415 | 3.312 | 1 | 5 | 7 | 2.2 | 99 | root/0.8 |
| 820 | 巨龍威能 | dragon-energy | dragon | beam | 其他（未證實可選） | 9.0785 | 2.332 | 1 | 1.1 | 18 | 0.45 | 99 | 無/0.12 |
| 821 | 冰冷視線 | freezing-glare | psychic | homing | 其他（未證實可選） | 9.5954 | 1.175 | 2 | 0.5 | 15 | 1.6 | 0 | freeze/0.16 |
| 822 | 怒火中燒 | fiery-wrath | dark | nova | 其他（未證實可選） | 23.4554 | 2.444 | 1 | 6.5 | 0 | 0 | 99 | healblock/0.12 |
| 823 | 雷鳴蹴擊 | thunderous-kick | fighting | strike | 其他（未證實可選） | 18.1246 | 0.893 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 824 | 雪矛 | glacial-lance | ice | strike | 其他（未證實可選） | 20.0862 | 0.95 | 1 | 3.3 | 0 | 0 | 99 | freeze/0.12 |
| 825 | 星碎 | astral-barrage | ghost | homing | 其他（未證實可選） | 10.6338 | 1.25 | 2 | 0.5 | 15 | 1.6 | 0 | curse/0.12 |
| 826 | 詭異咒語 | eerie-spell | psychic | homing | 其他（未證實可選） | 9.2492 | 1.15 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.12 |
| 827 | 剋命爪 | dire-claw | poison | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | poison/0.12 |
| 828 | 屏障猛攻 | psyshield-bash | psychic | dash | 其他（未證實可選） | 19.7846 | 2.07 | 1 | 1.8 | 13 | 0 | 99 | confusion/0.12 |
| 830 | 岩斧 | stone-axe | rock | trap | kit | 29.1 | 2.314 | 2 | 3 | 0 | 14 | 0 | stun/0.12 |
| 831 | 陽春風暴 | springtide-storm | fairy | vortex | 其他（未證實可選） | 37.5569 | 3.456 | 1 | 5 | 7 | 2.2 | 99 | charm/0.12 |
| 832 | 神秘之力 | mystical-power | psychic | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | confusion/0.12 |
| 833 | 大憤慨 | raging-fury | fire | strike | 其他（未證實可選） | 20.0862 | 0.95 | 1 | 3.3 | 0 | 0 | 99 | burn/0.12 |
| 834 | 波動衝 | wave-crash | water | dash | 關都 learnset | 23.6308 | 2.3 | 1 | 1.8 | 13 | 0 | 99 | wet/0.12 |
| 835 | 葉綠爆震 | chloroblast | grass | nova | 其他（未證實可選） | 28.5323 | 2.756 | 1 | 6.5 | 0 | 0 | 99 | root/0.12 |
| 836 | 冰山風 | mountain-gale | ice | meteor | 其他（未證實可選） | 49.7077 | 3.84 | 1 | 4.2 | 0 | 0.7 | 99 | freeze/0.12 |
| 837 | 勝利之舞 | victory-dance | fighting | buff | 其他（未證實可選） | 0 | 11.9 | 1 | 0 | 0 | 6 | 0 | knock/0.8 |
| 838 | 突飛猛撲 | headlong-rush | ground | meteor | kit | 63.8031 | 4 | 1 | 4.2 | 0 | 0.7 | 99 | stun/0.5 |
| 839 | 毒千針 | barb-barrage | poison | barrage | 其他（未證實可選） | 4.7538 | 1.012 | 4 | 0.35 | 30 | 0.6 | 0 | poison/0.12 |
| 840 | 氣場之翼 | esper-wing | psychic | boomerang | 其他（未證實可選） | 14.3877 | 1.564 | 1 | 0.8 | 17 | 1.3 | 99 | confusion/0.12 |
| 841 | 冤冤相報 | bitter-malice | ghost | cone | 其他（未證實可選） | 3.2271 | 1.82 | 1 | 7 | 0 | 1 | 99 | curse/0.12 |
| 843 | 三連箭 | triple-arrows | fighting | strike | 其他（未證實可選） | 18.1246 | 0.893 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 844 | 群魔亂舞 | infernal-parade | ghost | orbit | 其他（未證實可選） | 8.5569 | 4.84 | 2 | 3.2 | 3.2 | 4 | 99 | curse/0.12 |
| 845 | 秘劍・千重濤 | ceaseless-edge | dark | trap | 其他（未證實可選） | 29.1 | 2.314 | 2 | 3 | 0 | 14 | 0 | healblock/0.12 |
| 846 | 枯葉風暴 | bleakwind-storm | flying | cone | kit | 3.5348 | 1.92 | 1 | 7 | 0 | 1 | 99 | freeze/0.3 |
| 847 | 鳴雷風暴 | wildbolt-storm | electric | cone | kit | 3.5348 | 1.92 | 1 | 7 | 0 | 1 | 99 | paralysis/0.35 |
| 848 | 熱沙風暴 | sandsear-storm | ground | vortex | 其他（未證實可選） | 37.5569 | 3.456 | 1 | 5 | 7 | 2.2 | 99 | stun/0.12 |
| 851 | 太晶爆發 | tera-blast | normal | nova | 其他（未證實可選） | 22.6092 | 2.392 | 1 | 6.5 | 0 | 0 | 99 | 無/0.12 |
| 853 | 下壓踢 | axe-kick | fighting | smite | 關都 learnset | 28.3569 | 1.7 | 2 | 1.9 | 0 | 0 | 99 | knock/0.12 |
| 854 | 掃墓 | last-respects | ghost | meteor | 其他（未證實可選） | 41.0538 | 3.44 | 1 | 4.2 | 0 | 0.7 | 99 | curse/0.12 |
| 855 | 琉光衝激 | lumina-crash | psychic | nova | 其他（未證實可選） | 22.6092 | 2.392 | 1 | 6.5 | 0 | 0 | 99 | confusion/0.12 |
| 856 | 上菜 | order-up | dragon | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 857 | 噴射拳 | jet-punch | water | strike | 其他（未證實可選） | 16.1631 | 0.7106 | 1 | 3.3 | 0 | 0 | 99 | wet/0.12 |
| 859 | 疾速轉輪 | spin-out | steel | spin | 其他（未證實可選） | 9.9415 | 0.768 | 1 | 3.2 | 0 | 0 | 99 | knock/0.12 |
| 860 | 鼠數兒 | population-bomb | normal | barrage | 其他（未證實可選） | 4.25 | 0.9775 | 4 | 0.35 | 30 | 0.6 | 0 | 無/0.12 |
| 861 | 冰旋 | ice-spinner | ice | spin | kit | 9.2492 | 0.736 | 1 | 3.2 | 0 | 0 | 99 | freeze/0.3 |
| 862 | 巨劍突擊 | glaive-rush | dragon | dash | 其他（未證實可選） | 23.6308 | 2.3 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 864 | 鹽醃 | salt-cure | rock | aura | 其他（未證實可選） | 3.9323 | 0.3825 | 1 | 3.6 | 0 | 0 | 99 | stun/0.12 |
| 865 | 三連鑽 | triple-dive | water | dash | 其他（未證實可選） | 17 | 1.955 | 1 | 1.8 | 13 | 0 | 99 | wet/0.12 |
| 866 | 晶光轉轉 | mortal-spin | poison | spin | 其他（未證實可選） | 7.65 | 0.68 | 1 | 3.2 | 0 | 0 | 99 | poison/0.12 |
| 869 | 仆斬 | kowtow-cleave | dark | strike | 其他（未證實可選） | 17.7977 | 0.8835 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 870 | 千變萬花 | flower-trick | grass | homing | 其他（未證實可選） | 8.9031 | 1.125 | 2 | 0.5 | 15 | 1.6 | 0 | root/0.12 |
| 871 | 閃焰高歌 | torch-song | fire | homing | 其他（未證實可選） | 9.2492 | 1.15 | 2 | 0.5 | 15 | 1.6 | 0 | burn/0.12 |
| 872 | 流水旋舞 | aqua-step | water | spin | 其他（未證實可選） | 9.2492 | 0.736 | 1 | 3.2 | 0 | 0 | 99 | wet/0.12 |
| 873 | 怒牛 | raging-bull | normal | dash | kit | 24.5215 | 2.162 | 1 | 1.8 | 13 | 0 | 99 | 無/0.12 |
| 874 | 淘金潮 | make-it-rain | steel | smite | 其他（未證實可選） | 28.3569 | 1.7 | 2 | 1.9 | 0 | 0 | 99 | knock/0.12 |
| 875 | 精神劍 | psyblade | psychic | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | confusion/0.12 |
| 876 | 水蒸氣 | hydro-steam | water | bolt | 其他（未證實可選） | 13.36 | 0.92 | 1 | 0.5 | 24 | 0.8 | 0 | wet/0.12 |
| 877 | 大災難 | ruination | dark | orb | 其他（未證實可選） | 12.75 | 1.275 | 1 | 2.6 | 17 | 1.05 | 0 | healblock/0.12 |
| 878 | 全開猛撞 | collision-course | fighting | meteor | 其他（未證實可選） | 49.7077 | 3.84 | 1 | 4.2 | 0 | 0.7 | 99 | knock/0.12 |
| 879 | 閃電猛衝 | electro-drift | electric | chain | 其他（未證實可選） | 14.36 | 1.344 | 3 | 8 | 0 | 0 | 0 | paralysis/0.12 |
| 882 | 大掃除 | tidy-up | normal | buff | 其他（未證實可選） | 0 | 11.9 | 1 | 0 | 0 | 6 | 0 | 無/0.8 |
| 883 | 雪景 | snowscape | ice | weather | 關都 learnset | 0 | 27.2 | 1 | 0 | 0 | 14 | 0 | freeze/0.8 |
| 884 | 蟲撲 | pounce | bug | dash | 其他（未證實可選） | 18.2462 | 1.978 | 1 | 1.8 | 13 | 0 | 99 | poison/0.12 |
| 885 | 起草 | trailblaze | grass | strike | 其他（未證實可選） | 15.5092 | 0.817 | 1 | 3.3 | 0 | 0 | 99 | root/0.12 |
| 886 | 潑冷水 | chilling-water | water | cone | 其他（未證實可選） | 2.9194 | 1.72 | 1 | 7 | 0 | 1 | 99 | wet/0.12 |
| 887 | 強力鑽 | hyper-drill | normal | strike | 其他（未證實可選） | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | 無/0.12 |
| 888 | 雙光束 | twin-beam | psychic | beam | 其他（未證實可選） | 6.1169 | 1.87 | 1 | 1.1 | 18 | 0.45 | 99 | confusion/0.12 |
| 889 | 憤怒之拳 | rage-fist | ghost | homing | kit | 8.2108 | 1.075 | 2 | 0.5 | 15 | 1.6 | 0 | curse/0.12 |
| 890 | 鎧農炮 | armor-cannon | fire | beam | 其他（未證實可選） | 8.2708 | 2.2 | 1 | 1.1 | 18 | 0.45 | 99 | burn/0.12 |
| 891 | 悔念劍 | bitter-blade | fire | strike | 其他（未證實可選） | 18.1246 | 0.893 | 1 | 3.3 | 0 | 0 | 99 | burn/0.12 |
| 892 | 電光雙擊 | double-shock | electric | strike | 其他（未證實可選） | 20.0862 | 0.95 | 1 | 3.3 | 0 | 0 | 99 | paralysis/0.12 |
| 893 | 巨力錘 | gigaton-hammer | steel | nova | 其他（未證實可選） | 28.6 | 2.808 | 1 | 6.5 | 0 | 0 | 99 | knock/0.12 |
| 894 | 復仇 | comeuppance | dark | strike | 其他（未證實可選） | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 895 | 水波刀 | aqua-cutter | water | boomerang | kit | 13.8492 | 1.53 | 1 | 0.8 | 17 | 1.3 | 99 | wet/0.12 |
| 896 | 灼熱暴衝 | blazing-torque | fire | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | burn/0.12 |
| 897 | 黑暗暴衝 | wicked-torque | dark | strike | 其他（未證實可選） | 17.4708 | 0.874 | 1 | 3.3 | 0 | 0 | 99 | healblock/0.12 |
| 898 | 劇毒暴衝 | noxious-torque | poison | dash | 其他（未證實可選） | 22.0923 | 2.208 | 1 | 1.8 | 13 | 0 | 99 | poison/0.12 |
| 899 | 格鬥暴衝 | combat-torque | fighting | strike | 其他（未證實可選） | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 900 | 魔法暴衝 | magical-torque | fairy | homing | 其他（未證實可選） | 9.9415 | 1.2 | 2 | 0.5 | 15 | 1.6 | 0 | charm/0.12 |
| 901 | 血月 | blood-moon | normal | beam | 其他（未證實可選） | 8.8092 | 2.288 | 1 | 1.1 | 18 | 0.45 | 99 | 無/0.12 |
| 902 | 刷刷茶炮 | matcha-gotcha | grass | barrage | 其他（未證實可選） | 5.1385 | 1.058 | 4 | 0.35 | 30 | 0.6 | 0 | root/0.12 |
| 903 | 糖漿炸彈 | syrup-bomb | grass | lob | 其他（未證實可選） | 19.0154 | 1.672 | 1 | 3.2 | 15 | 3 | 0 | root/0.12 |
| 904 | 棘藤棒 | ivy-cudgel | grass | strike | 其他（未證實可選） | 18.7785 | 0.912 | 1 | 3.3 | 0 | 0 | 99 | root/0.12 |
| 905 | 電光束 | electro-shot | electric | beam | kit | 8.54 | 2.244 | 1 | 1.1 | 18 | 0.45 | 99 | paralysis/0.25 |
| 906 | 晶光星群 | tera-starstorm | normal | meteor | 其他（未證實可選） | 53.1692 | 4 | 1 | 4.2 | 0 | 0.7 | 99 | 無/0.12 |
| 907 | 隨機光 | fickle-beam | dragon | beam | 其他（未證實可選） | 7.1938 | 2.024 | 1 | 1.1 | 18 | 0.45 | 99 | 無/0.12 |
| 909 | 迅雷 | thunderclap | electric | smite | kit | 15.432 | 1.3005 | 3 | 1.9 | 0 | 0 | 99 | paralysis/0.5 |
| 910 | 強刃攻擊 | mighty-cleave | rock | strike | 其他（未證實可選） | 18.4515 | 0.9025 | 1 | 3.3 | 0 | 0 | 99 | stun/0.12 |
| 911 | 迅子利刃 | tachyon-cutter | steel | strike | 其他（未證實可選） | 15.5092 | 0.817 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 912 | 硬壓 | hard-press | steel | strike | 其他（未證實可選） | 14.45 | 0.8075 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 914 | 魅誘之聲 | alluring-voice | fairy | homing | 其他（未證實可選） | 9.2492 | 1.15 | 2 | 0.5 | 15 | 1.6 | 0 | charm/0.12 |
| 915 | 豁出去 | temper-flare | fire | strike | 其他（未證實可選） | 17.1438 | 0.8645 | 1 | 3.3 | 0 | 0 | 99 | burn/0.12 |
| 916 | 閃電強襲 | supercell-slam | electric | dash | 其他（未證實可選） | 22.0923 | 2.208 | 1 | 1.8 | 13 | 0 | 99 | paralysis/0.12 |
| 917 | 精神噪音 | psychic-noise | psychic | wave | kit | 15.1269 | 2.184 | 1 | 4 | 13 | 1.1 | 99 | healblock/0.5 |
| 918 | 快手還擊 | upper-hand | fighting | strike | 其他（未證實可選） | 16.49 | 0.7187 | 1 | 3.3 | 0 | 0 | 99 | knock/0.12 |
| 919 | 邪毒鎖鏈 | malignant-chain | poison | lob | 其他（未證實可選） | 22.0923 | 1.824 | 1 | 3.2 | 15 | 3 | 0 | poison/0.12 |

## 原型預設

| arch | dmg | cd | count | area | speed | dur | pierce | 可升級欄位 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bolt | 13 | 1 | 1 | 0.5 | 24 | 0.8 | 0 | dmg,cd,count,pierce,speed,crit,bounce |
| orb | 15 | 1.5 | 1 | 2.6 | 17 | 1.05 | 0 | dmg,cd,count,area,speed,status |
| lob | 20 | 1.9 | 1 | 3.2 | 15 | 3 | 0 | dmg,cd,count,area,status |
| barrage | 5 | 1.15 | 4 | 0.35 | 30 | 0.6 | 0 | dmg,cd,count,pierce,crit,speed |
| homing | 9 | 1.25 | 2 | 0.5 | 15 | 1.6 | 0 | dmg,cd,count,speed,crit |
| beam | 7 | 2.2 | 1 | 1.1 | 18 | 0.45 | 99 | dmg,cd,area,dur,count,crit |
| cone | 3.2 | 2 | 1 | 7 | 0 | 1 | 99 | dmg,cd,area,dur,status |
| nova | 22 | 2.6 | 1 | 6.5 | 0 | 0 | 99 | dmg,cd,area,status,crit |
| aura | 4.5 | 0.45 | 1 | 3.6 | 0 | 0 | 99 | dmg,cd,area,status |
| orbit | 9 | 5.5 | 2 | 3.2 | 3.2 | 4 | 99 | dmg,count,area,dur,speed,cd |
| strike | 17 | 0.95 | 1 | 3.3 | 0 | 0 | 99 | dmg,cd,area,count,crit |
| dash | 20 | 2.3 | 1 | 1.8 | 13 | 0 | 99 | dmg,cd,area,count,speed,crit |
| chain | 13 | 1.4 | 3 | 8 | 0 | 0 | 0 | dmg,cd,count,area,status |
| smite | 24 | 1.7 | 2 | 1.9 | 0 | 0 | 99 | dmg,cd,count,area,crit |
| meteor | 45 | 4 | 1 | 4.2 | 0 | 0.7 | 99 | dmg,cd,count,area,status |
| boomerang | 14 | 1.7 | 1 | 0.8 | 17 | 1.3 | 99 | dmg,cd,count,area,speed,crit |
| trap | 30 | 2.6 | 2 | 3 | 0 | 14 | 0 | dmg,cd,count,area,dur |
| vortex | 34 | 3.6 | 1 | 5 | 7 | 2.2 | 99 | dmg,cd,area,dur,count |
| wave | 15 | 2.4 | 1 | 4 | 13 | 1.1 | 99 | dmg,cd,area,speed,count,status |
| trail | 6 | 0.28 | 1 | 1.7 | 0 | 3 | 99 | dmg,area,dur,status |
| drain | 10 | 1.3 | 1 | 0.5 | 18 | 1.1 | 0 | dmg,cd,count,speed |
| spin | 9 | 0.8 | 1 | 3.2 | 0 | 0 | 99 | dmg,cd,area,crit |
| weather | 0 | 32 | 1 | 0 | 0 | 14 | 0 | cd,dur |
| buff | 0 | 14 | 1 | 0 | 0 | 6 | 0 | cd,dur |
| random | 0 | 4.5 | 0 | 1 | 1 | 1 | 0 | dmg,cd,count,area,dur,crit,status |

## 未轉換的 status key

whirlwind, sand-attack, tail-whip, leer, growl, roar, disable, meditate, teleport, screech, double-team, recover, harden, minimize, smokescreen, withdraw, defense-curl, haze, reflect, focus-energy, mirror-move, amnesia, kinesis, soft-boiled, glare, flash, splash, acid-armor, rest, sharpen, conversion, substitute, spider-web, mind-reader, curse, conversion-2, spite, protect, scary-face, belly-drum, foresight, destiny-bond, detect, endure, charm, swagger, milk-drink, mean-look, attract, sleep-talk, heal-bell, safeguard, pain-split, baton-pass, encore, sweet-scent, morning-sun, synthesis, moonlight, psych-up, stockpile, swallow, torment, flatter, memento, follow-me, nature-power, charge, taunt, helping-hand, trick, role-play, wish, assist, ingrain, magic-coat, recycle, skill-swap, imprison, refresh, grudge, snatch, camouflage, teeter-dance, mud-sport, slack-off, aromatherapy, fake-tears, odor-sleuth, metal-sound, grass-whistle, tickle, cosmic-power, iron-defense, block, howl, water-sport, roost, miracle-eye, healing-wish, tailwind, acupressure, embargo, psycho-shift, heal-block, power-trick, lucky-chant, me-first, power-swap, guard-swap, worry-seed, heart-swap, magnet-rise, switcheroo, defog, captivate, defend-order, heal-order, lunar-dance, dark-void, wide-guard, guard-split, power-split, wonder-room, rage-powder, telekinesis, magic-room, simple-beam, entrainment, after-you, quick-guard, ally-switch, heal-pulse, quash, reflect-type, bestow, cotton-guard, mat-block, rototiller, trick-or-treat, noble-roar, ion-deluge, forests-curse, parting-shot, topsy-turvy, crafty-shield, flower-shield, grassy-terrain, misty-terrain, electrify, fairy-lock, kings-shield, play-nice, confide, spiky-shield, aromatic-mist, eerie-impulse, venom-drench, powder, geomancy, magnetic-flux, happy-hour, electric-terrain, celebrate, hold-hands, baby-doll-eyes, shore-up, baneful-bunker, floral-healing, strength-sap, spotlight, toxic-thread, laser-focus, gear-up, psychic-terrain, speed-swap, purify, instruct, aurora-veil, extreme-evoboost, tearful-look, max-guard, stuff-cheeks, no-retreat, tar-shot, magic-powder, teatime, octolock, court-change, clangorous-soul, decorate, life-dew, obstruct, corrosive-gas, coaching, jungle-healing, power-shift, shelter, lunar-blessing, take-heart, silk-trap, spicy-extract, revival-blessing, doodle, fillet-away, shed-tail, chilly-reception, burning-bulwark, dragon-cheer

accuracy 只參與「必中 special→homing」分類，不做原作命中擲骰；PP、target、flavor 沒進 Sp 的武器欄位。drain、crit、flinch、weather、buff、spread、pulses 見主報告。

## 非預設附加欄位

未列的招式 drain/critBonus/flinch=0、weather/buff/spread/pulses未指定；cls沿用原始physical/special，原status轉special。flinch為定義欄位，不代表所有攻擊路徑都使用相同觸發規則。

| id | key | runtime cls | drain | critBonus | flinch | weather | buff | spread | pulses |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2 | karate-chop | physical | 0 | 0.15 | 0 | — | — | — | — |
| 13 | razor-wind | special | 0 | 0.15 | 0 | — | — | — | — |
| 14 | swords-dance | special | 0 | 0 | 0 | — | swords-dance | — | — |
| 23 | stomp | physical | 0 | 0 | 0.3 | — | — | — | — |
| 27 | rolling-kick | physical | 0 | 0 | 0.3 | — | — | — | — |
| 29 | headbutt | physical | 0 | 0 | 0.3 | — | — | — | — |
| 44 | bite | physical | 0 | 0 | 0.3 | — | — | — | — |
| 71 | absorb | special | 0.15 | 0 | 0 | — | — | — | — |
| 72 | mega-drain | special | 0.15 | 0 | 0 | — | — | — | — |
| 73 | leech-seed | special | 0.12 | 0 | 0 | — | — | — | — |
| 74 | growth | special | 0 | 0 | 0 | — | growth | — | — |
| 75 | razor-leaf | physical | 0 | 0.15 | 0 | — | — | — | — |
| 97 | agility | special | 0 | 0 | 0 | — | agility | — | — |
| 125 | bone-club | physical | 0 | 0 | 0.1 | — | — | — | — |
| 127 | waterfall | physical | 0 | 0 | 0.2 | — | — | — | — |
| 138 | dream-eater | special | 0.15 | 0 | 0 | — | — | — | — |
| 141 | leech-life | physical | 0.15 | 0 | 0 | — | — | — | — |
| 143 | sky-attack | physical | 0 | 0.15 | 0.3 | — | — | — | — |
| 152 | crabhammer | physical | 0 | 0.15 | 0 | — | — | — | — |
| 157 | rock-slide | physical | 0 | 0 | 0.3 | — | — | — | — |
| 158 | hyper-fang | physical | 0 | 0 | 0.1 | — | — | — | — |
| 163 | slash | physical | 0 | 0.15 | 0 | — | — | — | — |
| 173 | snore | special | 0 | 0 | 0.3 | — | — | — | — |
| 177 | aeroblast | special | 0 | 0.15 | 0 | — | — | — | — |
| 200 | outrage | physical | 0 | 0 | 0 | — | — | — | 3 |
| 201 | sandstorm | special | 0 | 0 | 0 | sand | — | — | — |
| 202 | giga-drain | special | 0.15 | 0 | 0 | — | — | — | — |
| 206 | false-swipe | physical | 0 | 0 | 0 | — | — | 0.4 | — |
| 238 | cross-chop | physical | 0 | 0.15 | 0 | — | — | — | — |
| 239 | twister | special | 0 | 0 | 0.2 | — | — | — | — |
| 240 | rain-dance | special | 0 | 0 | 0 | rain | — | — | — |
| 241 | sunny-day | special | 0 | 0 | 0 | sun | — | — | — |
| 252 | fake-out | physical | 0 | 0 | 1 | — | — | — | — |
| 253 | uproar | special | 0 | 0 | 0 | — | — | — | 2 |
| 258 | hail | special | 0 | 0 | 0 | hail | — | — | — |
| 294 | tail-glow | special | 0 | 0 | 0 | — | tail-glow | — | — |
| 299 | blaze-kick | physical | 0 | 0.15 | 0 | — | — | — | — |
| 302 | needle-arm | physical | 0 | 0 | 0.3 | — | — | — | — |
| 310 | astonish | physical | 0 | 0 | 0.3 | — | — | — | — |
| 314 | air-cutter | special | 0 | 0.15 | 0 | — | — | — | — |
| 326 | extrasensory | special | 0 | 0 | 0.1 | — | — | — | — |
| 339 | bulk-up | special | 0 | 0 | 0 | — | bulk-up | — | — |
| 342 | poison-tail | physical | 0 | 0.15 | 0 | — | — | — | — |
| 347 | calm-mind | special | 0 | 0 | 0 | — | calm-mind | — | — |
| 348 | leaf-blade | physical | 0 | 0.15 | 0 | — | — | — | — |
| 349 | dragon-dance | special | 0 | 0 | 0 | — | dragon-dance | — | — |
| 397 | rock-polish | special | 0 | 0 | 0 | — | rock-polish | — | — |
| 399 | dark-pulse | special | 0 | 0 | 0.2 | — | — | — | — |
| 400 | night-slash | physical | 0 | 0.15 | 0 | — | — | — | — |
| 403 | air-slash | special | 0 | 0 | 0.3 | — | — | — | — |
| 407 | dragon-rush | physical | 0 | 0 | 0.2 | — | — | — | — |
| 409 | drain-punch | physical | 0.15 | 0 | 0 | — | — | — | — |
| 417 | nasty-plot | special | 0 | 0 | 0 | — | nasty-plot | — | — |
| 421 | shadow-claw | physical | 0 | 0.15 | 0 | — | — | — | — |
| 422 | thunder-fang | physical | 0 | 0 | 0.1 | — | — | — | — |
| 423 | ice-fang | physical | 0 | 0 | 0.1 | — | — | — | — |
| 424 | fire-fang | physical | 0 | 0 | 0.1 | — | — | — | — |
| 427 | psycho-cut | physical | 0 | 0.15 | 0 | — | — | 0.25 | — |
| 428 | zen-headbutt | physical | 0 | 0 | 0.2 | — | — | — | — |
| 440 | cross-poison | physical | 0 | 0.15 | 0 | — | — | — | — |
| 442 | iron-head | physical | 0 | 0 | 0.3 | — | — | — | — |
| 444 | stone-edge | physical | 0 | 0.15 | 0 | — | — | — | — |
| 454 | attack-order | physical | 0 | 0.15 | 0 | — | — | — | — |
| 460 | spacial-rend | special | 0 | 0.15 | 0 | — | — | — | — |
| 468 | hone-claws | special | 0 | 0 | 0 | — | hone-claws | — | — |
| 475 | autotomize | special | 0 | 0 | 0 | — | autotomize | — | — |
| 480 | storm-throw | physical | 0 | 0.15 | 0 | — | — | — | — |
| 483 | quiver-dance | special | 0 | 0 | 0 | — | quiver-dance | — | — |
| 489 | coil | special | 0 | 0 | 0 | — | coil | — | — |
| 504 | shell-smash | special | 0 | 0 | 0 | — | shell-smash | — | — |
| 508 | shift-gear | special | 0 | 0 | 0 | — | shift-gear | — | — |
| 524 | frost-breath | special | 0 | 0.15 | 0 | — | — | — | — |
| 526 | work-up | special | 0 | 0 | 0 | — | work-up | — | — |
| 529 | drill-run | physical | 0 | 0.15 | 0 | — | — | — | — |
| 531 | heart-stamp | physical | 0 | 0 | 0.3 | — | — | — | — |
| 532 | horn-leech | physical | 0.15 | 0 | 0 | — | — | — | — |
| 533 | sacred-sword | physical | 0 | 0 | 0 | — | — | 0.3 | — |
| 537 | steamroller | physical | 0 | 0 | 0.3 | — | — | — | — |
| 556 | icicle-crash | physical | 0 | 0 | 0.3 | — | — | — | — |
| 570 | parabolic-charge | special | 0.15 | 0 | 0 | — | — | — | — |
| 577 | draining-kiss | special | 0.225 | 0 | 0 | — | — | — | — |
| 613 | oblivion-wing | special | 0.225 | 0 | 0 | — | — | — | — |
| 708 | shadow-bone | physical | 0 | 0 | 0 | — | — | 0.32 | — |
| 716 | zing-zap | physical | 0 | 0 | 0.3 | — | — | — | — |
| 719 | 10-000-000-volt-thunderbolt | special | 0 | 0.15 | 0 | — | — | — | — |
| 731 | floaty-fall | physical | 0 | 0 | 0.3 | — | — | — | — |
| 733 | bouncy-bubble | special | 0.25 | 0 | 0 | — | — | — | — |
| 742 | double-iron-bash | physical | 0 | 0 | 0.3 | — | — | — | — |
| 745 | snipe-shot | special | 0 | 0.15 | 0 | — | — | — | — |
| 817 | wicked-blow | physical | 0 | 0.15 | 0 | — | — | — | — |
| 818 | surging-strikes | physical | 0 | 0.15 | 0 | — | — | — | — |
| 822 | fiery-wrath | special | 0 | 0 | 0.2 | — | — | — | — |
| 837 | victory-dance | special | 0 | 0 | 0 | — | victory-dance | — | — |
| 882 | tidy-up | special | 0 | 0 | 0 | — | tidy-up | — | — |
| 883 | snowscape | special | 0 | 0 | 0 | hail | — | — | — |
