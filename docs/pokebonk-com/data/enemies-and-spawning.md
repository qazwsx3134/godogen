# 敵人候選與生成曲線

下表是本季森林／沙漠 stage1–3 的主池、居民池與後段池聯集（123 species）。不是固定關卡敵人清單；初始只抽三張生成卡，後續輪換。Boss／傳說／事件不在一般候選表內。來源：`main-DSroRSEE-mvekcp7c.js:40627` 建池、`main-DSroRSEE-mvekcp7c.js:11830` 生成。HP/speed/dmg/XP 是未乘 director、難度、旗標與 toughness 的基底，讓比例可比較；不是線上實際最終值。

| id | 繁中 | types | BST | evoStage | HP基底 | speed基底 | dmg基底 | XP基底 | 候選來源 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 妙蛙種子 | grass,poison | 318 | 0 | 29.49 | 3.8182 | 10.7708 | 2.06 | forest/1/主池; forest/1/後段; forest/2/主池; forest/2/後段 |
| 2 | 妙蛙草 | grass,poison | 405 | 1 | 34.275 | 4.0909 | 12.2083 | 2.35 | forest/2/主池; forest/2/後段; forest/3/主池; forest/3/後段 |
| 3 | 妙蛙花 | grass,poison | 525 | 2 | 40.875 | 4.4545 | 14.2917 | 2.75 | forest/3/主池; forest/3/後段 |
| 4 | 小火龍 | fire | 309 | 0 | 28.995 | 4.1818 | 10.75 | 2.03 | desert/1/後段; desert/2/後段 |
| 5 | 火恐龍 | fire | 405 | 1 | 34.275 | 4.4545 | 12.3333 | 2.35 | desert/2/後段; desert/3/後段 |
| 6 | 噴火龍 | fire,flying | 534 | 2 | 41.37 | 4.8182 | 14.7917 | 2.78 | forest/3/主池; desert/3/後段 |
| 10 | 綠毛蟲 | bug | 195 | 0 | 22.725 | 3.8182 | 7.7083 | 1.65 | forest/1/主池; forest/2/主池 |
| 11 | 鐵甲蛹 | bug | 205 | 1 | 23.275 | 3.5455 | 7.2917 | 1.6833 | forest/2/主池; forest/3/主池 |
| 12 | 巴大蝶 | bug,flying | 395 | 2 | 33.725 | 4.2727 | 11.5625 | 2.3167 | forest/3/主池 |
| 13 | 獨角蟲 | bug,poison | 195 | 0 | 22.725 | 3.9091 | 8.0208 | 1.65 | forest/1/主池; forest/1/後段; forest/2/主池; forest/2/後段 |
| 14 | 鐵殼蛹 | bug,poison | 205 | 1 | 23.275 | 3.6364 | 7.6042 | 1.6833 | forest/2/主池; forest/2/後段; forest/3/主池; forest/3/後段 |
| 15 | 大針蜂 | bug,poison | 395 | 2 | 33.725 | 4.3636 | 12.5 | 2.3167 | forest/3/主池; forest/3/後段 |
| 16 | 波波 | normal,flying | 251 | 0 | 25.805 | 4.0182 | 9.2708 | 1.8367 | forest/1/主池; forest/2/主池 |
| 17 | 比比鳥 | normal,flying | 349 | 1 | 31.195 | 4.2909 | 10.8333 | 2.1633 | forest/2/主池; forest/3/主池 |
| 18 | 大比鳥 | normal,flying | 479 | 2 | 38.345 | 4.8364 | 12.9167 | 2.5967 | forest/3/主池 |
| 19 | 小拉達 | normal | 253 | 0 | 25.915 | 4.3091 | 9.5417 | 1.8433 | forest/1/主池; forest/2/主池; desert/1/居民; desert/2/居民 |
| 20 | 拉達 | normal | 413 | 1 | 34.715 | 4.7636 | 12.1458 | 2.3767 | forest/2/主池; forest/3/主池; desert/2/居民; desert/3/居民 |
| 21 | 烈雀 | normal,flying | 262 | 0 | 26.41 | 4.2727 | 10.0417 | 1.8733 | forest/1/主池; forest/2/主池; desert/1/居民; desert/2/居民 |
| 22 | 大嘴雀 | normal,flying | 442 | 1 | 36.31 | 4.8182 | 13.1667 | 2.4733 | forest/2/主池; forest/3/主池; desert/2/居民; desert/3/居民 |
| 23 | 阿柏蛇 | poison | 288 | 0 | 27.84 | 4 | 10.4167 | 1.96 | forest/1/後段; forest/2/後段; desert/1/居民; desert/2/居民 |
| 24 | 阿柏怪 | poison | 448 | 1 | 36.64 | 4.4545 | 13.6458 | 2.4933 | forest/2/後段; forest/3/後段; desert/2/居民; desert/3/居民 |
| 27 | 穿山鼠 | ground | 300 | 0 | 28.5 | 3.7273 | 10.5208 | 2 | forest/1/居民; forest/2/居民; desert/1/主池; desert/2/主池 |
| 28 | 穿山王 | ground | 450 | 1 | 36.75 | 4.1818 | 13.125 | 2.5 | forest/2/居民; forest/3/居民; desert/2/主池; desert/3/主池 |
| 29 | 尼多蘭 | poison | 275 | 0 | 27.125 | 3.7455 | 9.6042 | 1.9167 | forest/1/後段; forest/2/後段; desert/1/居民; desert/2/居民 |
| 30 | 尼多娜 | poison | 365 | 1 | 32.075 | 4.0182 | 11.1667 | 2.2167 | forest/2/後段; forest/3/後段; desert/2/居民; desert/3/居民 |
| 31 | 尼多后 | poison,ground | 505 | 2 | 39.775 | 4.3818 | 13.875 | 2.6833 | forest/3/後段; desert/3/主池; desert/3/居民 |
| 32 | 尼多朗 | poison | 273 | 0 | 27.015 | 3.9091 | 10.2292 | 1.91 | forest/1/後段; forest/2/後段; desert/1/居民; desert/2/居民 |
| 33 | 尼多力諾 | poison | 365 | 1 | 32.075 | 4.1818 | 11.7917 | 2.2167 | forest/2/後段; forest/3/後段; desert/2/居民; desert/3/居民 |
| 34 | 尼多王 | poison,ground | 505 | 2 | 39.775 | 4.5455 | 14.9167 | 2.6833 | forest/3/後段; desert/3/主池; desert/3/居民 |
| 35 | 皮皮 | fairy | 323 | 1 | 29.765 | 3.6364 | 10.3125 | 2.0767 | forest/2/後段; forest/3/後段 |
| 36 | 皮可西 | fairy | 483 | 2 | 38.565 | 4.0909 | 13.3333 | 2.61 | forest/3/後段 |
| 37 | 六尾 | fire | 299 | 0 | 28.445 | 4.1818 | 9.6458 | 1.9967 | forest/1/居民; forest/2/居民; desert/1/居民; desert/1/後段; desert/2/居民; desert/2/後段 |
| 38 | 九尾 | fire | 505 | 1 | 39.775 | 4.8182 | 13.125 | 2.6833 | forest/2/居民; forest/3/居民; desert/2/居民; desert/2/後段; desert/3/居民; desert/3/後段 |
| 39 | 胖丁 | normal,fairy | 270 | 1 | 26.85 | 3.3636 | 9.6875 | 1.9 | forest/2/主池; forest/2/後段; forest/3/主池; forest/3/後段 |
| 40 | 胖可丁 | normal,fairy | 435 | 2 | 35.925 | 3.8182 | 12.9167 | 2.45 | forest/3/主池; forest/3/後段 |
| 41 | 超音蝠 | poison,flying | 245 | 0 | 25.475 | 4 | 9.0625 | 1.8167 | forest/1/主池; forest/1/後段; forest/2/主池; forest/2/後段; desert/1/居民; desert/2/居民 |
| 42 | 大嘴蝠 | poison,flying | 455 | 1 | 37.025 | 4.6364 | 12.7083 | 2.5167 | forest/2/主池; forest/2/後段; forest/3/主池; forest/3/後段; desert/2/居民; desert/3/居民 |
| 43 | 走路草 | grass,poison | 320 | 0 | 29.6 | 3.5455 | 11.25 | 2.0667 | forest/1/主池; forest/1/後段; forest/2/主池; forest/2/後段 |
| 44 | 臭臭花 | grass,poison | 395 | 1 | 33.725 | 3.7273 | 12.6042 | 2.3167 | forest/2/主池; forest/2/後段; forest/3/主池; forest/3/後段 |
| 45 | 霸王花 | grass,poison | 490 | 2 | 38.95 | 3.9091 | 14.5833 | 2.6333 | forest/3/主池; forest/3/後段 |
| 46 | 派拉斯 | bug,grass | 285 | 0 | 27.675 | 3.4545 | 11.25 | 1.95 | forest/1/主池; forest/2/主池 |
| 47 | 派拉斯特 | bug,grass | 405 | 1 | 34.275 | 3.5455 | 13.4375 | 2.35 | forest/2/主池; forest/3/主池 |
| 48 | 毛球 | bug,poison | 305 | 0 | 28.775 | 3.8182 | 10.1042 | 2.0167 | forest/1/主池; forest/1/後段; forest/2/主池; forest/2/後段 |
| 49 | 摩魯蛾 | bug,poison | 450 | 1 | 36.75 | 4.6364 | 12.8125 | 2.5 | forest/2/主池; forest/2/後段; forest/3/主池; forest/3/後段 |
| 50 | 地鼠 | ground | 265 | 0 | 26.575 | 4.7273 | 9.8958 | 1.8833 | forest/1/居民; forest/2/居民; desert/1/主池; desert/2/主池 |
| 51 | 三地鼠 | ground | 425 | 1 | 35.375 | 5.1818 | 13.3333 | 2.4167 | forest/2/居民; forest/3/居民; desert/2/主池; desert/3/主池 |
| 52 | 喵喵 | normal | 290 | 0 | 27.95 | 4.6364 | 9.4792 | 1.9667 | forest/1/主池; forest/2/主池; desert/1/居民; desert/2/居民 |
| 53 | 貓老大 | normal | 440 | 1 | 36.2 | 5.0909 | 12.0833 | 2.4667 | forest/2/主池; forest/3/主池; desert/2/居民; desert/3/居民 |
| 54 | 可達鴨 | water | 320 | 0 | 29.6 | 4 | 10.9583 | 2.0667 | forest/1/居民; forest/2/居民; desert/1/居民; desert/2/居民 |
| 55 | 哥達鴨 | water | 500 | 1 | 39.5 | 4.5455 | 14.0833 | 2.6667 | forest/2/居民; forest/3/居民; desert/2/居民; desert/3/居民 |
| 56 | 猴怪 | fighting | 305 | 0 | 28.775 | 4.2727 | 11.4583 | 2.0167 | forest/1/居民; forest/2/居民; desert/1/主池; desert/2/主池 |
| 57 | 火爆猴 | fighting | 455 | 1 | 37.025 | 4.7273 | 14.0625 | 2.5167 | forest/2/居民; forest/3/居民; desert/2/主池; desert/3/主池 |
| 58 | 卡蒂狗 | fire | 350 | 0 | 31.25 | 4.0909 | 12.2917 | 2.1667 | forest/1/居民; forest/2/居民; desert/1/居民; desert/1/後段; desert/2/居民; desert/2/後段 |
| 59 | 風速狗 | fire | 555 | 1 | 42.525 | 4.7273 | 16.0417 | 2.85 | forest/2/居民; forest/3/居民; desert/2/居民; desert/2/後段; desert/3/居民; desert/3/後段 |
| 60 | 蚊香蝌蚪 | water | 300 | 0 | 28.5 | 4.6364 | 9.7917 | 2 | forest/1/居民; forest/2/居民 |
| 61 | 蚊香君 | water | 385 | 1 | 33.175 | 4.6364 | 11.1458 | 2.2833 | forest/2/居民; forest/3/居民 |
| 62 | 蚊香泳士 | water,fighting | 510 | 2 | 40.05 | 4.2727 | 13.8542 | 2.7 | forest/3/居民; desert/3/主池 |
| 63 | 凱西 | psychic | 310 | 0 | 29.05 | 4.6364 | 10.625 | 2.0333 | forest/1/居民; forest/2/居民 |
| 64 | 勇基拉 | psychic | 400 | 1 | 34 | 4.9091 | 12.1875 | 2.3333 | forest/2/居民; forest/3/居民 |
| 65 | 胡地 | psychic | 500 | 2 | 39.5 | 5.1818 | 13.75 | 2.6667 | forest/3/居民 |
| 66 | 腕力 | fighting | 305 | 0 | 28.775 | 3.6364 | 11.4583 | 2.0167 | desert/1/主池; desert/2/主池 |
| 67 | 豪力 | fighting | 405 | 1 | 34.275 | 3.8182 | 13.3333 | 2.35 | desert/2/主池; desert/3/主池 |
| 68 | 怪力 | fighting | 505 | 2 | 39.775 | 4 | 15.8333 | 2.6833 | desert/3/主池 |
| 69 | 喇叭芽 | grass,poison | 300 | 0 | 28.5 | 3.7273 | 12.6042 | 2 | forest/1/主池; forest/1/後段; forest/2/主池; forest/2/後段 |
| 70 | 口呆花 | grass,poison | 390 | 1 | 33.45 | 4 | 14.1667 | 2.3 | forest/2/主池; forest/2/後段; forest/3/主池; forest/3/後段 |
| 71 | 大食花 | grass,poison | 490 | 2 | 38.95 | 4.2727 | 15.7292 | 2.6333 | forest/3/主池; forest/3/後段 |
| 72 | 瑪瑙水母 | water,poison | 335 | 0 | 30.425 | 4.2727 | 9.5833 | 2.1167 | forest/1/後段; forest/2/後段 |
| 73 | 毒刺水母 | water,poison | 515 | 1 | 40.325 | 4.8182 | 12.7083 | 2.7167 | forest/2/後段; forest/3/後段 |
| 74 | 小拳石 | rock,ground | 300 | 0 | 28.5 | 3.3636 | 11.25 | 2 | forest/1/居民; forest/2/居民; desert/1/主池; desert/2/主池 |
| 75 | 隆隆石 | rock,ground | 390 | 1 | 33.45 | 3.6364 | 12.8125 | 2.3 | forest/2/居民; forest/3/居民; desert/2/主池; desert/3/主池 |
| 76 | 隆隆岩 | rock,ground | 495 | 2 | 39.225 | 3.0545 | 14.7917 | 2.65 | forest/3/居民; desert/3/主池 |
| 77 | 小火馬 | fire | 410 | 0 | 34.55 | 4.6364 | 13.0208 | 2.3667 | forest/1/居民; forest/2/居民; desert/1/居民; desert/1/後段; desert/2/居民; desert/2/後段 |
| 78 | 烈焰馬 | fire | 500 | 1 | 39.5 | 4.9091 | 14.5833 | 2.6667 | forest/2/居民; forest/3/居民; desert/2/居民; desert/2/後段; desert/3/居民; desert/3/後段 |
| 79 | 呆呆獸 | water,psychic | 315 | 0 | 29.325 | 3.2727 | 10.7292 | 2.05 | forest/1/居民; forest/2/居民 |
| 80 | 呆殼獸 | water,psychic | 490 | 1 | 38.95 | 3.5455 | 13.8542 | 2.6333 | forest/2/居民; forest/3/居民 |
| 81 | 小磁怪 | electric,steel | 325 | 0 | 29.875 | 3.8182 | 11.1458 | 2.0833 | forest/1/居民; forest/2/居民; desert/1/後段; desert/2/後段 |
| 82 | 三合一磁怪 | electric,steel | 465 | 1 | 37.575 | 4.2727 | 13.75 | 2.55 | forest/2/居民; forest/3/居民; desert/2/後段; desert/3/後段 |
| 83 | 大蔥鴨 | normal,flying | 377 | 0 | 32.735 | 4.0909 | 13.0417 | 2.2567 | forest/1/主池; forest/2/主池 |
| 84 | 嘟嘟 | normal,flying | 310 | 0 | 29.05 | 4.3636 | 11.7708 | 2.0333 | forest/1/主池; forest/2/主池; desert/1/居民; desert/2/居民 |
| 85 | 嘟嘟利 | normal,flying | 470 | 1 | 37.85 | 5 | 14.375 | 2.5667 | forest/2/主池; forest/3/主池; desert/2/居民; desert/3/居民 |
| 88 | 臭泥 | poison | 325 | 0 | 29.875 | 3.4545 | 11.6667 | 2.0833 | forest/1/後段; forest/2/後段 |
| 89 | 臭臭泥 | poison | 500 | 1 | 39.5 | 3.9091 | 14.2708 | 2.6667 | forest/2/後段; forest/3/後段 |
| 92 | 鬼斯 | ghost,poison | 310 | 0 | 29.05 | 4.4545 | 11.3542 | 2.0333 | forest/1/居民; forest/1/後段; forest/2/居民; forest/2/後段 |
| 93 | 鬼斯通 | ghost,poison | 405 | 1 | 34.275 | 4.7273 | 12.9167 | 2.35 | forest/2/居民; forest/2/後段; forest/3/居民; forest/3/後段 |
| 94 | 耿鬼 | ghost,poison | 500 | 2 | 39.5 | 5 | 14.4792 | 2.6667 | forest/3/居民; forest/3/後段 |
| 95 | 大岩蛇 | rock,ground | 385 | 0 | 33.175 | 4.2727 | 9.0625 | 2.2833 | desert/1/主池; desert/2/主池 |
| 96 | 催眠貘 | psychic | 328 | 0 | 30.04 | 3.7636 | 9.7917 | 2.0933 | forest/1/居民; forest/2/居民 |
| 97 | 引夢貘人 | psychic | 483 | 1 | 38.565 | 4.2182 | 12.6042 | 2.61 | forest/2/居民; forest/3/居民 |
| 100 | 霹靂電球 | electric | 330 | 0 | 30.15 | 4.8182 | 9.1667 | 2.1 | forest/1/居民; forest/2/居民 |
| 101 | 頑皮雷彈 | electric | 490 | 1 | 38.95 | 5.7273 | 11.4583 | 2.6333 | forest/2/居民; forest/3/居民 |
| 102 | 蛋蛋 | grass,psychic | 325 | 0 | 29.875 | 3.7273 | 10 | 2.0833 | forest/1/主池; forest/2/主池; desert/1/居民; desert/2/居民 |
| 103 | 椰蛋樹 | grass,psychic | 530 | 1 | 41.15 | 4 | 16.1458 | 2.7667 | forest/2/主池; forest/3/主池; desert/2/居民; desert/3/居民 |
| 104 | 卡拉卡拉 | ground | 320 | 0 | 29.6 | 3.6364 | 9.7917 | 2.0667 | desert/1/主池; desert/2/主池 |
| 105 | 嘎啦嘎啦 | ground | 425 | 1 | 35.375 | 3.8182 | 12.0833 | 2.4167 | desert/2/主池; desert/3/主池 |
| 106 | 飛腿郎 | fighting | 455 | 1 | 37.025 | 4.5818 | 13.9583 | 2.5167 | desert/2/主池; desert/3/主池 |
| 107 | 快拳郎 | fighting | 455 | 1 | 37.025 | 4.3818 | 13.0208 | 2.5167 | desert/2/主池; desert/3/主池 |
| 108 | 大舌頭 | normal | 385 | 0 | 33.175 | 3.5455 | 10.9375 | 2.2833 | forest/1/主池; forest/2/主池 |
| 109 | 瓦斯彈 | poison | 340 | 0 | 30.7 | 3.6364 | 11.5625 | 2.1333 | forest/1/後段; forest/2/後段 |
| 110 | 雙彈瓦斯 | poison | 490 | 1 | 38.95 | 4.0909 | 14.1667 | 2.6333 | forest/2/後段; forest/3/後段 |
| 111 | 獨角犀牛 | ground,rock | 345 | 0 | 30.975 | 3.4545 | 11.5625 | 2.15 | desert/1/主池; desert/2/主池 |
| 112 | 鑽角犀獸 | ground,rock | 485 | 1 | 38.675 | 3.7273 | 15 | 2.6167 | desert/2/主池; desert/3/主池 |
| 113 | 吉利蛋 | normal | 450 | 1 | 36.75 | 3.9091 | 6.7708 | 2.5 | forest/2/主池; forest/3/主池 |
| 114 | 蔓藤怪 | grass | 435 | 0 | 35.925 | 4.0909 | 12.6042 | 2.45 | forest/1/主池; forest/2/主池; forest/3/主池 |
| 115 | 袋獸 | normal | 490 | 0 | 38.95 | 4.6364 | 12.6042 | 2.6333 | forest/1/主池; forest/2/主池; forest/3/主池; desert/1/居民; desert/2/居民 |
| 118 | 角金魚 | water | 320 | 0 | 29.6 | 4.1455 | 10.6458 | 2.0667 | forest/1/居民; forest/2/居民 |
| 119 | 金魚王 | water | 450 | 1 | 36.75 | 4.2364 | 13.4583 | 2.5 | forest/2/居民; forest/3/居民 |
| 122 | 魔牆人偶 | psychic,fairy | 460 | 1 | 37.3 | 4.6364 | 11.9792 | 2.5333 | forest/2/後段; forest/3/後段 |
| 123 | 飛天螳螂 | bug,flying | 500 | 0 | 39.5 | 4.9091 | 14.1667 | 2.6667 | forest/1/主池; forest/2/主池; forest/3/主池 |
| 126 | 鴨嘴火獸 | fire | 495 | 1 | 39.225 | 4.6909 | 15.1042 | 2.65 | desert/2/後段; desert/3/後段 |
| 127 | 凱羅斯 | bug | 500 | 0 | 39.5 | 4.5455 | 15.1042 | 2.6667 | forest/1/主池; forest/2/主池; forest/3/主池 |
| 128 | 肯泰羅 | normal | 490 | 0 | 38.95 | 5 | 12.9167 | 2.6333 | forest/1/主池; forest/2/主池; forest/3/主池; desert/1/居民; desert/2/居民 |
| 130 | 暴鯉龍 | water,flying | 540 | 1 | 41.7 | 4.4727 | 15.3125 | 2.8 | forest/2/主池; forest/3/主池 |
| 132 | 百變怪 | normal | 288 | 0 | 27.84 | 3.8727 | 10 | 1.96 | forest/1/主池; forest/2/主池 |
| 133 | 伊布 | normal | 325 | 0 | 29.875 | 4 | 10.3125 | 2.0833 | forest/1/主池; forest/2/主池 |
| 136 | 火伊布 | fire | 525 | 1 | 40.875 | 4.1818 | 17.0833 | 2.75 | desert/2/後段; desert/3/後段 |
| 137 | 多邊獸 | normal | 395 | 0 | 33.725 | 3.7273 | 12.2917 | 2.3167 | forest/1/主池; forest/2/主池 |
| 138 | 菊石獸 | rock,water | 355 | 0 | 31.525 | 3.6364 | 11.25 | 2.1833 | desert/1/主池; desert/2/主池 |
| 139 | 多刺菊石獸 | rock,water | 495 | 1 | 39.225 | 4 | 13.5417 | 2.65 | desert/2/主池; desert/3/主池 |
| 140 | 化石盔 | rock,water | 355 | 0 | 31.525 | 4 | 12.2917 | 2.1833 | desert/1/主池; desert/2/主池 |
| 141 | 鐮刀盔 | rock,water | 495 | 1 | 39.225 | 4.4545 | 14.8958 | 2.65 | desert/2/主池; desert/3/主池 |
| 142 | 化石翼龍 | rock,flying | 515 | 0 | 40.325 | 5.3636 | 14.0625 | 2.7167 | forest/1/主池; forest/2/主池; forest/3/主池; desert/1/主池; desert/2/主池; desert/3/主池 |
| 143 | 卡比獸 | normal | 540 | 1 | 41.7 | 2.8364 | 14.5833 | 2.8 | forest/2/主池; forest/3/主池 |
| 149 | 快龍 | dragon,flying | 600 | 2 | 45 | 4.4545 | 17.5417 | 3 | forest/3/主池 |

## 生成公式

| 項目 | bundle 規則 | 來源 |
| --- | --- | --- |
| 預算／秒 | p(t)=0.7+0.014t+0.5(t/60)^1.75；再乘 1+.35(stage−1)、difficulty、enemyAmount、diff.enemyAmount；finalSwarm ×6 | `news-DDcWCXrq-mvekcp7c.js:1769` |
| 卡片成本 | 1+BST/220；每次按 weight 抽，預算不夠則等下次；最初3卡 | `main-DSroRSEE-mvekcp7c.js:40684` |
| 一般敵上限 | min(enemyCap, round((10+.65t+4.5(t/60)^2)×(1+.6(stage−1))×tier.cap)) | `main-DSroRSEE-mvekcp7c.js:40813` |
| effective t | stageTime+[0,75,150][stage−1]×min(1,stageTime/20)；上述曲線 t 是秒 | `main-DSroRSEE-mvekcp7c.js:40701` |
| HP曲線 | m=t/60；[1,5.5,13,20][stage−1]×(1+.3m+r×max(0,m−offset)^2)；r=[.15,.07,.05,.05]，offset stage1=1.5 其餘0 | `main-DSroRSEE-mvekcp7c.js:40708` |
| toughness | 一般非特殊敵 HP 額外×(1.35+1.05max(0,1−t/480))；XP×(1+(toughness−1)×.35) | `main-DSroRSEE-mvekcp7c.js:40728` |
| 傷害曲線 | (1+.13m)×[1,2,3.1,3.4][stage−1]；stage≥2 再乘 tier.late | `main-DSroRSEE-mvekcp7c.js:40754` |
| 速度曲線 | min(1.3,1+.02m+.06(stage−1)) | `main-DSroRSEE-mvekcp7c.js:40731` |
| Elite機率 | stage1前90秒禁用；其他 .012+.004×stageTime/60+.03(stage−1)，另加 tier.elite、difficulty 與事件 | `main-DSroRSEE-mvekcp7c.js:40785` |
| 出現距離 | 距玩家24–36，最多16次找點；邊界修正後不得小於14 | `main-DSroRSEE-mvekcp7c.js:40763` |
| Elite/Alpha/Boss | HP ×4.5/22/70，scale×1.35/2/2.6，XP×6/25/60；Boss尚有額外配血機制 | `main-DSroRSEE-mvekcp7c.js:11830` |
| Totem/Summoner | HP ×30/14，scale×2.2/1.9，XP×35/20 | `main-DSroRSEE-mvekcp7c.js:11830` |
| 資料容量 | enemy n<2200；每秒生成保護1800（非正常生成速率）；品質500/900/1400另限 | `main-DSroRSEE-mvekcp7c.js:11833` |
| 遠離玩家 | 距離>75的一般敵重放至32距離；特殊旗標不套用 | `main-DSroRSEE-mvekcp7c.js:54521` |

## 難度倍率

| 難度 | HP | 傷害 | 速度 | 數量 | 上限倍率 | Elite額外率 | XP倍率 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 普通 | 1 | 1 | 1 | 1 | 1 | 0 | 1 |
| 困難 | 1.4 | 1.42 | 1.08 | 1.3 | 1.15 | 0.04 | 1.15 |
| 夢魘 | 1.9 | 1.96 | 1.16 | 1.6 | 1.3 | 0.08 | 1.3 |

來源 `news-DDcWCXrq-mvekcp7c.js:1749`、`main-DSroRSEE-mvekcp7c.js:52728`。

## 排程與 Boss

標準局：card 約每48–72秒加一張至9.6分鐘；Alpha 150/330/480秒；stage1 horde 235秒、其餘200秒，另390/520秒；Elitewave stage1 330、其餘270，另450秒；Totem stage1 290、其餘255，另420秒；Summoner360秒。tier early 為0/15/30秒提前（card/event除外）。來源 `main-DSroRSEE-mvekcp7c.js:40589`。守護者由地圖 boss/shrine 互動啟動，`main-DSroRSEE-mvekcp7c.js:48797`。森林三區 guardian候選為 [123,26,55]／[127,62,53]／[34,76,59]；第四區聖域151。沙漠候選請見環境表。Boss HP 不只套固定倍率，會用近期輸出 meter 配血，`main-DSroRSEE-mvekcp7c.js:45339`。

生存：card60秒起每48–72秒；Alpha150每150；horde235每140–160；totem290每200–220；elite330每180；summoner380每340–380。里程碑每300秒；phase在720/1440；night在2700秒開始。`main-DSroRSEE-mvekcp7c.js:40593`、`news-DDcWCXrq-mvekcp7c.js:1770`。這些不是一局固定結束時間。

## 生存模式曲線

這些是 bundle 公式，仍須乘當局 curse/pact 與玩家 difficulty；不是獨立線上設定。令 t=整局秒數、m=t/60、H(t)=t（t<600）或600+.55(t−600)。

| 項目 | 公式 | 來源 |
| --- | --- | --- |
| 預算／秒 | p(H(t))×(1+min(.6,t/3600))×difficulty×enemyAmount×curse.amount；night再×2 | `news-DDcWCXrq-mvekcp7c.js:1776`；`main-DSroRSEE-mvekcp7c.js:40853` |
| HP倍率 | (1+.3m+.12max(0,m−1.5)^2+.0025m^3)×1.06^max(0,m−20)×1.15^max(0,m−45)；再乘curse.hp×difficulty | `news-DDcWCXrq-mvekcp7c.js:1778` |
| 傷害倍率 | (1+.13m)(1+.02m)×1.03^max(0,m−20)×1.1^max(0,m−45)；再乘curse.dmg | `news-DDcWCXrq-mvekcp7c.js:1785` |
| 速度倍率 | min(1.45,1+.01m)×min(1.3,1+.02max(0,m−45))×curse.speed | `news-DDcWCXrq-mvekcp7c.js:1787` |
| 敵數上限 | min(enemyCap,round((10+.65H(t)+4.5(H(t)/60)^2)×(1+.012m))) | `main-DSroRSEE-mvekcp7c.js:40860` |
| XP需求附加倍率 | 1.008^max(0,level−60)，乘round(8+5.5L+L^1.8)後再round | `news-DDcWCXrq-mvekcp7c.js:1786`；`main-DSroRSEE-mvekcp7c.js:39665` |

Boss輸出配血下限：每秒取單一敵人最高累積傷害，最近最多120個樣本取第85百分位，乘目標秒數與(1+.15×tier)×difficulty；只提高到超過原maxHp的結果。守護者目標40/50/60秒，傳說60；超過目標2.5倍後每20秒exhaust翻倍。`main-DSroRSEE-mvekcp7c.js:35601`、`:45272`、`:45339`。
