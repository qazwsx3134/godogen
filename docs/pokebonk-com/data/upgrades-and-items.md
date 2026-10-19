# 升級、維他命與局內道具

道具 JSON 有 125 筆名稱／icon；真正裝備池由 shared kt 組出 102 種。下表只列 runtime 數值；空 mods 不等於沒效果，觸發型道具還有 player/combat 分支。上限未填者採 10，`main-DSroRSEE-mvekcp7c.js:39592`；抽取還受 itemsOwned/itemsOff 與 rarity 等條件限制，`main-DSroRSEE-mvekcp7c.js:51440`。稀有度倍率 1/1.2/1.45/1.75/2.1，`news-DDcWCXrq-mvekcp7c.js:2644`。

一般升級提供 3 選 1，研究 choice4 解鎖 4 選 1；招式最高 8、維他命最高 10。初始招式槽 3（局外解鎖第 4）、維他命槽 3（最多再加 2）。重抽／跳過／放逐初值 2/2/1，另加 lab 等級。

| key | 繁中名 | rarity 0–4 | 每份 mods | 持有上限 | 來源 |
| --- | --- | --- | --- | --- | --- |
| fairy-feather | 妖精之羽 | 0 | damage ×1.03; fairy 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| silk-scarf | 絲綢圍巾 | 0 | damage ×1.03; normal 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| metal-coat | 金屬膜 | 0 | damage ×1.03; steel 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| black-glasses | 黑色眼鏡 | 0 | damage ×1.03; dark 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| dragon-fang | 龍之牙 | 0 | damage ×1.03; dragon 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| spell-tag | 詛咒之符 | 0 | damage ×1.03; ghost 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| hard-stone | 硬石頭 | 0 | damage ×1.03; rock 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| silver-powder | 銀粉 | 0 | damage ×1.03; bug 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| twisted-spoon | 彎曲的湯匙 | 0 | damage ×1.03; psychic 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| sharp-beak | 銳利鳥嘴 | 0 | damage ×1.03; flying 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| soft-sand | 柔軟沙子 | 0 | damage ×1.03; ground 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| poison-barb | 毒針 | 0 | damage ×1.03; poison 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| black-belt | 黑帶 | 0 | damage ×1.03; fighting 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| never-melt-ice | 不融冰 | 0 | damage ×1.03; ice 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| magnet | 磁鐵 | 0 | damage ×1.03; electric 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| miracle-seed | 奇跡種子 | 0 | damage ×1.03; grass 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| mystic-water | 神秘水滴 | 0 | damage ×1.03; water 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| charcoal | 木炭 | 0 | damage ×1.03; fire 傷害 +30% | 10 | `news-DDcWCXrq-mvekcp7c.js:2645` |
| oran-berry | 橙橙果 | 0 | maxHp +15 | 10 | `news-DDcWCXrq-mvekcp7c.js:2694` |
| quick-powder | 速度粉 | 0 | moveSpeed ×1.07 | 10 | `news-DDcWCXrq-mvekcp7c.js:2695` |
| bright-powder | 光粉 | 0 | evasion +0.04 | 10 | `news-DDcWCXrq-mvekcp7c.js:2701` |
| amulet-coin | 護符金幣 | 0 | gold ×1.2 | 10 | `news-DDcWCXrq-mvekcp7c.js:2702` |
| scope-lens | 焦點鏡 | 0 | critChance +0.06 | 10 | `news-DDcWCXrq-mvekcp7c.js:2703` |
| wide-lens | 廣角鏡 | 0 | area ×1.1 | 10 | `news-DDcWCXrq-mvekcp7c.js:2709` |
| zoom-lens | 對焦鏡 | 0 | projSpeed ×1.15; critChance +0.03 | 10 | `news-DDcWCXrq-mvekcp7c.js:2715` |
| soothe-bell | 安撫之鈴 | 0 | healing ×1.15; regen +0.3 | 10 | `news-DDcWCXrq-mvekcp7c.js:2724` |
| lax-incense | 悠閒薰香 | 0 | armor +5 | 10 | `news-DDcWCXrq-mvekcp7c.js:2733` |
| honey | 甜甜蜜 | 0 | pickupRange +1.5 | 10 | `news-DDcWCXrq-mvekcp7c.js:2734` |
| cleanse-tag | 潔淨之符 | 0 | eliteDamage ×1.15 | 10 | `news-DDcWCXrq-mvekcp7c.js:2740` |
| potion | 傷藥 | 0 | regen +0.6 | 10 | `news-DDcWCXrq-mvekcp7c.js:2746` |
| lucky-punch | 吉利拳 | 0 | luck +10; critChance +0.03 | 10 | `news-DDcWCXrq-mvekcp7c.js:2752` |
| big-nugget | 巨大金珠 | 0 | gold ×1.05 | 5 | `news-DDcWCXrq-mvekcp7c.js:2761` |
| grip-claw | 緊纏鉤爪 | 0 | 事件型，mods 無靜態加成 | 5 | `news-DDcWCXrq-mvekcp7c.js:2768` |
| berry-juice | 樹果汁 | 0 | 事件型，mods 無靜態加成 | 8 | `news-DDcWCXrq-mvekcp7c.js:2775` |
| muscle-band | 力量頭帶 | 1 | physical ×1.15 | 10 | `news-DDcWCXrq-mvekcp7c.js:2782` |
| wise-glasses | 博識眼鏡 | 1 | special ×1.15 | 10 | `news-DDcWCXrq-mvekcp7c.js:2783` |
| quick-claw | 先制之爪 | 1 | attackSpeed ×1.1 | 10 | `news-DDcWCXrq-mvekcp7c.js:2789` |
| razor-claw | 銳利之爪 | 1 | critDamage +0.3 | 10 | `news-DDcWCXrq-mvekcp7c.js:2795` |
| shell-bell | 貝殼之鈴 | 1 | 事件型，mods 無靜態加成 | 10 | `news-DDcWCXrq-mvekcp7c.js:2796` |
| leftovers | 吃剩的東西 | 1 | regen +1.2 | 10 | `news-DDcWCXrq-mvekcp7c.js:2797` |
| rocky-helmet | 凸凸頭盔 | 1 | thorns +25 | 10 | `news-DDcWCXrq-mvekcp7c.js:2803` |
| light-clay | 光之黏土 | 1 | duration ×1.2 | 10 | `news-DDcWCXrq-mvekcp7c.js:2809` |
| air-balloon | 氣球 | 1 | extraJumps +1; jumpHeight ×1.15 | 10 | `news-DDcWCXrq-mvekcp7c.js:2815` |
| white-herb | 白色香草 | 1 | statusChance ×1.25 | 10 | `news-DDcWCXrq-mvekcp7c.js:2824` |
| power-herb | 強力香草 | 1 | statusDamage ×1.3 | 10 | `news-DDcWCXrq-mvekcp7c.js:2830` |
| sitrus-berry | 文柚果 | 1 | maxHp +10 | 10 | `news-DDcWCXrq-mvekcp7c.js:2836` |
| lucky-egg | 幸運蛋 | 1 | xpGain ×1.15 | 10 | `news-DDcWCXrq-mvekcp7c.js:2842` |
| big-root | 大根莖 | 1 | lifesteal +0.03; healing ×1.15 | 10 | `news-DDcWCXrq-mvekcp7c.js:2843` |
| smoke-ball | 煙霧球 | 1 | evasion +0.03 | 10 | `news-DDcWCXrq-mvekcp7c.js:2852` |
| metronome | 節拍器 | 1 | 事件型，mods 無靜態加成 | 10 | `news-DDcWCXrq-mvekcp7c.js:2858` |
| flame-orb | 火焰寶珠 | 1 | statusDamage ×1.1 | 5 | `news-DDcWCXrq-mvekcp7c.js:2859` |
| toxic-orb | 劇毒寶珠 | 1 | statusChance ×1.1 | 5 | `news-DDcWCXrq-mvekcp7c.js:2866` |
| snowball | 雪球 | 1 | armor +3 | 5 | `news-DDcWCXrq-mvekcp7c.js:2873` |
| binding-band | 緊綁束帶 | 1 | 事件型，mods 無靜態加成 | 5 | `news-DDcWCXrq-mvekcp7c.js:2880` |
| smooth-rock | 沙沙岩石 | 1 | bounces +1; projSpeed ×1.1 | 3 | `news-DDcWCXrq-mvekcp7c.js:2887` |
| white-flute | 白色玻璃哨 | 1 | enemyAmount ×1.12; xpGain ×1.1; luck +5 | 5 | `news-DDcWCXrq-mvekcp7c.js:2897` |
| adrenaline-orb | 膽怯球 | 1 | 事件型，mods 無靜態加成 | 3 | `news-DDcWCXrq-mvekcp7c.js:2908` |
| repel | 除蟲噴霧 | 1 | enemyAmount ×0.92; moveSpeed ×1.06 | 3 | `news-DDcWCXrq-mvekcp7c.js:2915` |
| life-orb | 生命寶珠 | 2 | damage ×1.3; maxHp ×0.9 | 5 | `news-DDcWCXrq-mvekcp7c.js:2925` |
| choice-band | 講究頭帶 | 2 | physical ×1.35; attackSpeed ×0.92 | 5 | `news-DDcWCXrq-mvekcp7c.js:2935` |
| choice-specs | 講究眼鏡 | 2 | special ×1.35; attackSpeed ×0.92 | 5 | `news-DDcWCXrq-mvekcp7c.js:2945` |
| choice-scarf | 講究圍巾 | 2 | moveSpeed ×1.2; attackSpeed ×1.1 | 5 | `news-DDcWCXrq-mvekcp7c.js:2955` |
| expert-belt | 達人帶 | 2 | superEffective ×1.3 | 10 | `news-DDcWCXrq-mvekcp7c.js:2965` |
| focus-band | 氣勢頭帶 | 2 | 事件型，mods 無靜態加成 | 4 | `news-DDcWCXrq-mvekcp7c.js:2971` |
| kings-rock | 王者之證 | 2 | flinch +0.06 | 10 | `news-DDcWCXrq-mvekcp7c.js:2978` |
| assault-vest | 突擊背心 | 2 | armor +12; maxHp ×1.12 | 10 | `news-DDcWCXrq-mvekcp7c.js:2984` |
| eviolite | 進化奇石 | 2 | 事件型，mods 無靜態加成 | 1 | `news-DDcWCXrq-mvekcp7c.js:2993` |
| exp-share | 學習裝置 | 2 | xpGain ×1.25; pickupRange +2 | 10 | `news-DDcWCXrq-mvekcp7c.js:3000` |
| macho-brace | 強制鍛鍊器 | 2 | xpGain ×1.5; moveSpeed ×0.9 | 3 | `news-DDcWCXrq-mvekcp7c.js:3009` |
| black-sludge | 黑色污泥 | 2 | regen +2; statusDamage ×1.2 | 10 | `news-DDcWCXrq-mvekcp7c.js:3019` |
| star-piece | 星星碎片 | 2 | luck +20 | 10 | `news-DDcWCXrq-mvekcp7c.js:3028` |
| stick | 大蔥 | 2 | 事件型，mods 無靜態加成 | 4 | `news-DDcWCXrq-mvekcp7c.js:3034` |
| razor-fang | 銳利之牙 | 2 | 事件型，mods 無靜態加成 | 4 | `news-DDcWCXrq-mvekcp7c.js:3041` |
| shed-shell | 美麗空殼 | 2 | 事件型，mods 無靜態加成 | 1 | `news-DDcWCXrq-mvekcp7c.js:3050` |
| cell-battery | 充電電池 | 2 | 事件型，mods 無靜態加成 | 2 | `news-DDcWCXrq-mvekcp7c.js:3057` |
| lum-berry | 木子果 | 2 | healing ×1.1 | 3 | `news-DDcWCXrq-mvekcp7c.js:3064` |
| focus-sash | 氣勢披帶 | 3 | 事件型，mods 無靜態加成 | 1 | `news-DDcWCXrq-mvekcp7c.js:3071` |
| pp-max | ＰＰ極限提升劑 | 3 | projectiles +1 | 10 | `news-DDcWCXrq-mvekcp7c.js:3078` |
| max-elixir | ＰＰ多項全補劑 | 3 | attackSpeed ×1.2 | 10 | `news-DDcWCXrq-mvekcp7c.js:3084` |
| shiny-stone | 光之石 | 3 | damage ×1.15; area ×1.15 | 10 | `news-DDcWCXrq-mvekcp7c.js:3090` |
| dusk-stone | 暗之石 | 3 | critDamage +0.4; critChance +0.08 | 10 | `news-DDcWCXrq-mvekcp7c.js:3099` |
| comet-shard | 彗星碎片 | 3 | gold ×1.4; luck +30 | 10 | `news-DDcWCXrq-mvekcp7c.js:3108` |
| thunder-stone | 雷之石 | 3 | critChance +0.04 | 5 | `news-DDcWCXrq-mvekcp7c.js:3117` |
| fire-stone | 火之石 | 3 | 事件型，mods 無靜態加成 | 3 | `news-DDcWCXrq-mvekcp7c.js:3124` |
| protector | 護具 | 3 | armor +20; maxHp ×1.15; thorns +40; moveSpeed ×0.95 | 3 | `news-DDcWCXrq-mvekcp7c.js:3125` |
| griseous-orb | 白金寶珠 | 3 | 事件型，mods 無靜態加成 | 2 | `news-DDcWCXrq-mvekcp7c.js:3137` |
| reaper-cloth | 靈界之布 | 3 | 事件型，mods 無靜態加成 | 2 | `news-DDcWCXrq-mvekcp7c.js:3146` |
| electirizer | 電力增幅器 | 3 | 事件型，mods 無靜態加成 | 3 | `news-DDcWCXrq-mvekcp7c.js:3153` |
| ice-stone | 冰之石 | 3 | statusChance ×1.1 | 3 | `news-DDcWCXrq-mvekcp7c.js:3160` |
| leaf-stone | 葉之石 | 3 | 事件型，mods 無靜態加成 | 3 | `news-DDcWCXrq-mvekcp7c.js:3169` |
| revive | 活力碎片 | 3 | 事件型，mods 無靜態加成 | 2 | `news-DDcWCXrq-mvekcp7c.js:3178` |
| max-revive | 活力塊 | 4 | 事件型，mods 無靜態加成 | 3 | `news-DDcWCXrq-mvekcp7c.js:3179` |
| rare-candy | 神奇糖果 | 4 | damage ×1.05 | 10 | `news-DDcWCXrq-mvekcp7c.js:3180` |
| master-ball | 大師球 | 4 | damage ×1.25 | 1 | `news-DDcWCXrq-mvekcp7c.js:3186` |
| moon-stone | 月之石 | 4 | projectiles +2; area ×1.25 | 2 | `news-DDcWCXrq-mvekcp7c.js:3193` |
| lustrous-orb | 白玉寶珠 | 4 | area ×1.2; projectiles +1 | 1 | `news-DDcWCXrq-mvekcp7c.js:3203` |
| adamant-orb | 金剛寶珠 | 4 | damage ×1.15 | 1 | `news-DDcWCXrq-mvekcp7c.js:3215` |
| dawn-stone | 覺醒之石 | 4 | damage ×1.3; attackSpeed ×1.2 | 2 | `news-DDcWCXrq-mvekcp7c.js:3224` |
| sun-stone | 日之石 | 4 | damage ×1.1 | 2 | `news-DDcWCXrq-mvekcp7c.js:3234` |
| soul-dew | 心之水滴 | 4 | special ×1.2; area ×1.15 | 1 | `news-DDcWCXrq-mvekcp7c.js:3243` |
| silver-wing | 銀色之羽 | 4 | extraJumps +1; moveSpeed ×1.12 | 1 | `news-DDcWCXrq-mvekcp7c.js:3253` |
| rainbow-wing | 虹色之羽 | 4 | healing ×1.15 | 1 | `news-DDcWCXrq-mvekcp7c.js:3265` |

## 維他命完整表

| key | stat | kind | per | 來源 |
| --- | --- | --- | --- | --- |
| protein | physical | mul | 0.1 | `news-DDcWCXrq-mvekcp7c.js:3277` |
| calcium | special | mul | 0.1 | `news-DDcWCXrq-mvekcp7c.js:3286` |
| iron | armor | add | 5 | `news-DDcWCXrq-mvekcp7c.js:3295` |
| zinc | shieldMax | add | 12 | `news-DDcWCXrq-mvekcp7c.js:3296` |
| carbos | moveSpeed | mul | 0.07 | `news-DDcWCXrq-mvekcp7c.js:3305` |
| hp-up | maxHp | add | 18 | `news-DDcWCXrq-mvekcp7c.js:3314` |
| pp-up | projectiles | add | 0.5 | `news-DDcWCXrq-mvekcp7c.js:3323` |
| ether | attackSpeed | mul | 0.08 | `news-DDcWCXrq-mvekcp7c.js:3332` |
| dire-hit | critChance | add | 0.05 | `news-DDcWCXrq-mvekcp7c.js:3341` |
| x-speed | projSpeed | mul | 0.12 | `news-DDcWCXrq-mvekcp7c.js:3350` |
| x-defense | evasion | add | 0.035 | `news-DDcWCXrq-mvekcp7c.js:3359` |
| x-attack | statusChance | mul | 0.15 | `news-DDcWCXrq-mvekcp7c.js:3368` |
| stardust | area | mul | 0.1 | `news-DDcWCXrq-mvekcp7c.js:3377` |
| elixir | duration | mul | 0.1 | `news-DDcWCXrq-mvekcp7c.js:3386` |
| super-potion | regen | add | 0.7 | `news-DDcWCXrq-mvekcp7c.js:3395` |
| nugget | gold | mul | 0.15 | `news-DDcWCXrq-mvekcp7c.js:3404` |
| exp-candy | xpGain | mul | 0.1 | `news-DDcWCXrq-mvekcp7c.js:3413` |
| star-piece-v | luck | add | 10 | `news-DDcWCXrq-mvekcp7c.js:3422` |
| max-potion | lifesteal | add | 0.02 | `news-DDcWCXrq-mvekcp7c.js:3431` |
| escape-rope | pickupRange | add | 1.2 | `news-DDcWCXrq-mvekcp7c.js:3440` |
| cursed | difficulty | mul | 0.12 | `news-DDcWCXrq-mvekcp7c.js:3449` |

## 局外 Lab

| id | max | stat | per | cost 原始公式 | 來源 |
| --- | --- | --- | --- | --- | --- |
| slot-move | 1 | 功能 | — | () => 1500 | `news-DDcWCXrq-mvekcp7c.js:828` |
| slot-vit | 2 | 功能 | — | (e) => [1200, 3e3][e] ?? 3e3 | `news-DDcWCXrq-mvekcp7c.js:836` |
| reroll | 6 | 功能 | — | h(120, 1.4) | `news-DDcWCXrq-mvekcp7c.js:844` |
| skip | 6 | 功能 | — | h(80, 1.4) | `news-DDcWCXrq-mvekcp7c.js:852` |
| banish | 6 | 功能 | — | h(150, 1.4) | `news-DDcWCXrq-mvekcp7c.js:860` |
| choice4 | 1 | 功能 | — | () => 3e3 | `news-DDcWCXrq-mvekcp7c.js:868` |
| dmg | 8 | damage | 0.04 | h(100, 1.4) | `news-DDcWCXrq-mvekcp7c.js:876` |
| hp | 8 | maxHp | 8 | h(100, 1.4) | `news-DDcWCXrq-mvekcp7c.js:886` |
| spd | 6 | moveSpeed | 0.025 | h(120, 1.45) | `news-DDcWCXrq-mvekcp7c.js:896` |
| xp | 6 | xpGain | 0.05 | h(120, 1.45) | `news-DDcWCXrq-mvekcp7c.js:906` |
| gold | 6 | gold | 0.08 | h(100, 1.45) | `news-DDcWCXrq-mvekcp7c.js:916` |
| luck | 6 | luck | 5 | h(140, 1.45) | `news-DDcWCXrq-mvekcp7c.js:926` |
| magnet | 5 | pickupRange | 0.6 | h(80, 1.45) | `news-DDcWCXrq-mvekcp7c.js:936` |
| regen | 5 | regen | 0.2 | h(120, 1.45) | `news-DDcWCXrq-mvekcp7c.js:946` |
| armor | 6 | armor | 2 | h(120, 1.45) | `news-DDcWCXrq-mvekcp7c.js:956` |
| revive | 1 | 功能 | — | () => 5e3 | `news-DDcWCXrq-mvekcp7c.js:966` |
| research | 4 | 功能 | — | h(250, 1.6) | `news-DDcWCXrq-mvekcp7c.js:974` |
| party | 1 | 功能 | — | () => 3500 | `news-DDcWCXrq-mvekcp7c.js:982` |
| archive | 3 | 功能 | — | (e) => [800, 1600, 3200][e] ?? 3200 | `news-DDcWCXrq-mvekcp7c.js:990` |

成本 h(base,growth)=round(base×growth^level/5)×5。招式每次升級 mods.dmg 另加 0.08，隨機抽 2 個欄位；稀有度倍率≥1.6 時抽 3 個。傷害 +.22×倍率、冷卻乘 1−min(.25,.08×倍率)、area/speed +.15×倍率、dur +.2×倍率、crit +.05×倍率、status +.25×倍率。`main-DSroRSEE-mvekcp7c.js:37583`。
