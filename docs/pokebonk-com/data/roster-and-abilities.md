# 本季角色、專屬 kit 與特性

Pokémon 基礎資料有 1,025 筆，本季篩選 151；手工角色名單是 79 個入口（含不同進化起點），不是 151 個獨立 starter。三個 starter id=1/4/7。`W.push` 合併五批角色，`news-DDcWCXrq-mvekcp7c.js:2577`；custom passive 與 Pokémon abilities.json 的原作特性是兩個資料層。下表列實際指定 passive，不把原作描述當效果。事件實作分布於 `main-DSroRSEE-mvekcp7c.js:12308`、`main-DSroRSEE-mvekcp7c.js:38544` 及 player/combat hooks。

| id | 繁中 | passive key | kit 依序 | 進化特例 | 稀有度 | 來源 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 妙蛙種子 | photosynthesis | vine-whip, razor-leaf, sleep-powder, solar-beam | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2228` |
| 4 | 小火龍 | blaze | ember, fire-spin, flamethrower, fire-blast | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2237` |
| 7 | 傑尼龜 | torrent-shell | water-gun, bubble, rapid-spin, hydro-pump | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2246` |
| 10 | 綠毛蟲 | metamorph | string-shot, bug-bite, gust, bug-buzz | [8, 36] | common | `news-DDcWCXrq-mvekcp7c.js:2255` |
| 13 | 獨角蟲 | venom-sting | poison-sting, twineedle, toxic-spikes, poison-jab | [8, 36] | common | `news-DDcWCXrq-mvekcp7c.js:2264` |
| 16 | 波波 | tailwind | quick-attack, feather-dance, wing-attack, hurricane | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2273` |
| 19 | 小拉達 | hustle | hyper-fang, pursuit, double-edge, super-fang | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2281` |
| 21 | 烈雀 | sniper | peck, fury-attack, drill-run, drill-peck | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2289` |
| 23 | 阿柏蛇 | serpent-glare | wrap, acid, sludge-bomb, gunk-shot | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2297` |
| 25 | 皮卡丘 | static | thunder-shock, electro-ball, thunderbolt, thunder | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2305` |
| 27 | 穿山鼠 | sand-rush | fury-swipes, rollout, crush-claw, bulldoze | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2313` |
| 29 | 尼多蘭 | poison-point | toxic, double-kick, body-press, sludge-wave | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2321` |
| 32 | 尼多朗 | rivalry | horn-attack, thrash, horn-drill, earth-power | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2329` |
| 35 | 皮皮 | lunar-blessing | draining-kiss, stored-power, gravity, moonblast | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2337` |
| 37 | 六尾 | flash-fire | will-o-wisp, flame-burst, extrasensory, heat-wave | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2345` |
| 39 | 胖丁 | cute-charm | pound, sing, round, hyper-voice | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2353` |
| 41 | 超音蝠 | vampire | leech-life, wing-attack, poison-fang, air-cutter | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2361` |
| 43 | 走路草 | chlorophyll | mega-drain, poison-powder, petal-blizzard, petal-dance | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2369` |
| 46 | 派拉斯 | effect-spore | slash, stun-spore, spore, energy-ball | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2377` |
| 48 | 毛球 | compound-eyes | supersonic, u-turn, silver-wind, signal-beam | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2385` |
| 50 | 地鼠 | arena-trap | scratch, mud-shot, tri-attack, fissure | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2393` |
| 52 | 喵喵 | pickup | pay-day, fake-out, assurance, play-rough | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2401` |
| 54 | 可達鴨 | headache | soak, zen-headbutt, aqua-tail, psyshock | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2409` |
| 56 | 猴怪 | anger-point | seismic-toss, rage-fist, stomping-tantrum, final-gambit | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2417` |
| 58 | 卡蒂狗 | loyal-guard | fire-fang, flame-wheel, extreme-speed, flare-blitz | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2425` |
| 60 | 蚊香蝌蚪 | swift-swim | bubble-beam, hypnosis, circle-throw, submission | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2433` |
| 63 | 凱西 | magic-guard | confusion, psybeam, psychic, future-sight | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2441` |
| 66 | 腕力 | guts | karate-chop, low-kick, cross-chop, dynamic-punch | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2449` |
| 69 | 喇叭芽 | carnivore | slam, gastro-acid, knock-off, power-whip | 通用公式 | common | `news-DDcWCXrq-mvekcp7c.js:2457` |
| 72 | 瑪瑙水母 | tentacles | brine, acid-spray, venoshock, whirlpool | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2465` |
| 74 | 小拳石 | sturdy | rock-throw, rollout, magnitude, rock-slide | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2477` |
| 77 | 小火馬 | blazing-hooves | flame-charge, bounce, inferno, sacred-fire | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1815` |
| 79 | 呆呆獸 | oblivious | yawn, scald, psychic-noise, expanding-force | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1823` |
| 81 | 小磁怪 | magnet-pull | thunder-wave, gyro-ball, magnet-bomb, flash-cannon | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1831` |
| 83 | 大蔥鴨 | leek-master | cut, false-swipe, brave-bird, meteor-assault | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1843` |
| 84 | 嘟嘟 | twin-heads | pluck, double-hit, uproar, acrobatics | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1855` |
| 86 | 小海獅 | ice-body | icy-wind, dive, aurora-beam, sheer-cold | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1863` |
| 88 | 臭泥 | sludge-body | poison-gas, sludge, shadow-sneak, belch | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1871` |
| 90 | 大舌貝 | skill-link | clamp, icicle-spear, ice-spinner, icicle-crash | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1879` |
| 92 | 鬼斯 | phantom | lick, night-shade, shadow-ball, hex | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2485` |
| 95 | 大岩蛇 | rock-head | rock-tomb, stealth-rock, iron-tail, head-smash | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1889` |
| 96 | 催眠貘 | pendulum | psywave, nightmare, dream-eater, focus-blast | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1897` |
| 98 | 大鉗蟹 | hyper-cutter | vice-grip, liquidation, crabhammer, guillotine | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1909` |
| 100 | 霹靂電球 | aftermath | spark, electroweb, rising-voltage, discharge | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1917` |
| 102 | 蛋蛋 | harvest | barrage, leech-seed, seed-bomb, wood-hammer | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1925` |
| 104 | 卡拉卡拉 | bone-keeper | bone-club, bonemerang, bone-rush, shadow-bone | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2497` |
| 106 | 飛腿郎 | limber-kicks | rolling-kick, blaze-kick, jump-kick, high-jump-kick | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:1933` |
| 107 | 快拳郎 | iron-fist | comet-punch, ice-punch, drain-punch, focus-punch | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:1944` |
| 108 | 大舌頭 | long-tongue | wring-out, snore, strength, heavy-slam | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:1955` |
| 109 | 瓦斯彈 | toxic-cloud | smog, clear-smog, self-destruct, explosion | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:1968` |
| 111 | 獨角犀牛 | rhino-charge | smack-down, rock-blast, high-horsepower, rock-wrecker | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:1976` |
| 113 | 吉利蛋 | natural-cure | sweet-kiss, echoed-voice, egg-bomb, boomburst | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:1987` |
| 114 | 蔓藤怪 | regenerator | bind, giga-drain, grass-knot, solar-blade | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:1998` |
| 115 | 袋獸 | parental-bond | dizzy-punch, mega-kick, reversal, mega-punch | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2009` |
| 116 | 墨海馬 | ink-sniper | snipe-shot, octazooka, scale-shot, hydro-cannon | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2020` |
| 118 | 角金魚 | water-veil | aqua-cutter, smart-strike, horn-leech, fishious-rend | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2028` |
| 120 | 海星星 | star-core | water-shuriken, confuse-ray, mirror-shot, photon-geyser | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2036` |
| 122 | 魔牆人偶 | barrier-wall | barrier, light-screen, trick-room, misty-explosion | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2046` |
| 123 | 飛天螳螂 | technician | fury-cutter, aerial-ace, air-slash, x-scissor | 通用公式 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2505` |
| 124 | 迷唇姐 | frost-kiss | lovely-kiss, frost-breath, heart-stamp, perish-song | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2054` |
| 125 | 電擊獸 | motor-drive | thunder-punch, wild-charge, thunder-cage, bolt-strike | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2065` |
| 126 | 鴨嘴火獸 | flame-body | fire-punch, mystical-fire, lava-plume, eruption | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2076` |
| 127 | 凱羅斯 | mold-breaker | storm-throw, lunge, vital-throw, superpower | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2087` |
| 128 | 肯泰羅 | stampede | payback, rock-climb, raging-bull, headlong-rush | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2098` |
| 129 | 鯉魚王 | persevere | tackle, flail, waterfall, hyper-beam | 40 | uncommon | `news-DDcWCXrq-mvekcp7c.js:2513` |
| 131 | 拉普拉斯 | water-absorb | water-pulse, ice-beam, surf, blizzard | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2522` |
| 132 | 百變怪 | imposter | transform, mimic, copycat, sketch | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2109` |
| 133 | 伊布 | adaptability | swift, quick-attack, bite, last-resort | [134, 135, 136] @36 | rare | `news-DDcWCXrq-mvekcp7c.js:2533` |
| 137 | 多邊獸 | download | lock-on, parabolic-charge, fusion-bolt, techno-blast | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2120` |
| 138 | 菊石獸 | spiral-shell | constrict, spike-cannon, water-spout, meteor-beam | [40] | rare | `news-DDcWCXrq-mvekcp7c.js:2137` |
| 140 | 化石盔 | battle-armor | aqua-jet, sacred-sword, stone-axe, razor-shell | [40] | rare | `news-DDcWCXrq-mvekcp7c.js:2149` |
| 142 | 化石翼龍 | ancient-wings | thunder-fang, dual-wingbeat, iron-head, dragon-ascent | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2161` |
| 143 | 卡比獸 | gluttony | tackle, body-slam, stomp, giga-impact | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2546` |
| 144 | 急凍鳥 | ice-pressure | freeze-dry, mist, bleakwind-storm, glaciate | 通用公式 | legendary | `news-DDcWCXrq-mvekcp7c.js:2172` |
| 145 | 閃電鳥 | volt-pressure | bolt-beak, wildbolt-storm, thunderclap, electro-shot | 通用公式 | legendary | `news-DDcWCXrq-mvekcp7c.js:2184` |
| 146 | 火焰鳥 | flame-pressure | incinerate, fly, searing-shot, overheat | 通用公式 | legendary | `news-DDcWCXrq-mvekcp7c.js:2200` |
| 147 | 迷你龍 | multiscale | twister, dragon-rage, dragon-pulse, draco-meteor | 通用公式 | rare | `news-DDcWCXrq-mvekcp7c.js:2557` |
| 150 | 超夢 | genome | psycho-cut, psystrike, prismatic-laser, psycho-boost | 通用公式 | legendary | `news-DDcWCXrq-mvekcp7c.js:2212` |
| 151 | 夢幻 | mew | psychic, aura-sphere, ancient-power, moonblast | 通用公式 | legendary | `news-DDcWCXrq-mvekcp7c.js:2568` |

