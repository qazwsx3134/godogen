可以。這種遊戲最怕一開始就「把完整遊戲一起做」，最後會同時卡在劇本、事件系統、小遊戲、戰鬥、存檔、時間線分支、像素美術。

比較好的做法是把它拆成可獨立驗證的模組，先證明每個模組本身成立，再整合成 vertical slice。

Roadmap 核心原則

不要用「第一章、第二章」切。

先用「系統能力」切：

文字敘事系統
    │
    ├── 對話
    ├── 選項
    ├── 條件分支
    ├── 吐槽
    └── Flag / State
         │
         ▼
時間線系統
    │
    ├── 世界狀態
    ├── Loop Reset
    ├── 記憶保留
    └── 事件變化
         │
         ▼
Mini-game Framework
    │
    ├── 共通介面
    ├── 成功 / 失敗
    ├── 分數
    └── 回傳故事結果
         │
         ▼
探索 / Hub
    │
    ├── 移動
    ├── NPC
    ├── 場景
    └── 互動
         │
         ▼
Vertical Slice

也就是：

先證明積木能用，再把積木拼成遊戲。

Phase 0：先定義 MVP 要驗證什麼

你的 MVP 不應該驗證「能不能做 RPG」。

你真正需要驗證的是這三件事：

1. 對話 + 吐槽有沒有真的好笑

玩家願不願意看。

2. 一個事件突然切換成 Mini-game，會不會有驚喜

而不是覺得突兀。

3. 時間線變化有沒有讓玩家產生

「等等，我剛才做的事情居然影響這裡？」

只要這三件事情成立，這款遊戲的核心就成立。

Phase 1：文字遊戲 Prototype

這個甚至可以完全沒有地圖。

先做一個：

10～15 分鐘純文字版本。

功能只需要：

Dialogue
Choice
Flag
Conditional Branch
Character Portrait
Screen Effect
Sound

例如：

阿銀：
我只是來找一隻狗。

新八：
對，就是這麼簡單。

[選項]

A. 去公園
B. 去商店街
C. 不找了，回家

選 C：

銀時：
我們回去吧。

新八：
委託開始 30 秒就放棄了啊！！

然後 Flag：

gaveUpEarly = true;

後面 NPC 可以因此吐槽。

第一個 Prototype 劇情

我甚至會故意做超簡單：

《消失的草莓牛奶》

任務：

找出誰偷喝了冰箱裡最後一盒草莓牛奶。

嫌疑人：

新八
神樂
房東
神秘黑影

調查到最後發現神秘黑影：

██████████

穿著非常可疑的斗篷。

銀時：

「等等，這個剪影是不是某個動漫的人？」

新八：

「不要講名字！！」

然後第一次出現：

[吐槽！]

玩家要選正確吐槽。

這 15 分鐘就可以驗證：

文本節奏到底成不成立。

Phase 1 驗證標準

不要用「完成了」當成功標準。

要觀察：

玩家有沒有真的笑
玩家有沒有主動看完對話
玩家有沒有亂選選項
玩家會不會想試另一個選項
玩家有沒有理解角色關係

最好找 5～10 個不知道你劇情的人測試。

Phase 2：吐槽系統

接下來把「吐槽」正式做成 mechanic。

不是普通 dialogue choice。

例如：

NPC：
「只要相信友情，一定可以——」

             吐槽！

           3
           2
           1

玩家只有 2 秒。

A. 這裡不是少年漫畫！
B. 好熱血！
C. 我相信你！

正確：

TSUKKOMI PERFECT
吐槽其實可以分三種
普通吐槽

純文本效果。

戰鬥吐槽

削弱敵人。

Narrative Break

直接打破遊戲規則。

例如 Boss 說：

「等我先解釋我的能力。」

玩家成功吐槽：

「不用解釋！」

結果：

Boss Tutorial
SKIPPED

這會成為你的 signature mechanic。

Phase 3：Mini-game Framework

這階段不要做 20 個。

做：

3 個。

而且三個要完全不同。

例如：

A. Reflex

看到東西立刻按。

把草莓牛奶搶回來！
B. Timing

節奏型。

在正確時間吐槽。
C. Drag / Avoid

把某個危險物拖走或閃避。

這樣才能驗證：

「遊戲突然切玩法」是不是好玩。

Mini-game 最重要的不是內容

而是：

Framework

所有 Mini-game 都應該有相同 interface。

概念上：

interface MiniGame {
  start(): void;

  result: {
    success: boolean;
    score?: number;
    grade?: "S" | "A" | "B" | "C";
  };
}

劇情系統只需要知道：

startMiniGame("strawberry_milk_chase")
            ↓
        回傳結果
            ↓
success
   │
   ├─ true → 劇情 A
   │
   └─ false → 劇情 B

這很重要。

否則以後每新增一個小遊戲，都要重新修改整個故事系統。

Phase 4：時間線 Prototype

這時候再碰最危險的系統。

先不要做整天。

只做：

一個房間 + 三次 Loop。

例如同一間便利商店。

第一次：

14:00
NPC A 買飲料
NPC B 吵架
貨架倒下

第二輪玩家知道貨架會倒：

14:00
阻止貨架

結果：

NPC B 沒有被砸
 ↓
提早離開
 ↓
遇到另一個 NPC

第三輪：

玩家利用已知資訊解決事件。

這一階段你要驗證的不是時間系統

而是：

玩家有沒有因為知道未來，而覺得自己變聰明。

這是 time-loop 最重要的 reward。

Phase 5：探索 Hub

這時候才開始做像素 RPG 的部分。

第一個 Hub 不需要大。

我會限制成：

萬事屋
  │
  ├── 商店街
  │
  ├── 公園
  │
  └── 便利商店

大概：

4 個場景
6～8 個 NPC

就夠。

不要先做城市。

因為城市本身不是你的核心。

你的核心是：

事件密度。

Phase 6：第一個 Vertical Slice

到這時才把全部東西串起來。

我會做：

《消失的 Jump 篇》

大概 30～45 分鐘。

流程：

萬事屋
 ↓
接委託
 ↓
自由探索
 ↓
NPC 對話
 ↓
發現異常
 ↓
動漫污染
 ↓
吐槽
 ↓
Mini-game
 ↓
時間線重置
 ↓
第二次調查
 ↓
Mini-game
 ↓
Boss / Narrative Break
 ↓
故事結尾

這就是第一個真正能給別人玩的 build。

第一個 Vertical Slice 甚至可以完整演示你的概念

例如：

阿銀發現：

自己的 Jump 不見了。

開始調查。

發現所有漫畫內容開始混在一起。

商店街出現：

忍者
海賊
死神
籃球員
卡牌決鬥者

但是全部：

馬賽克
剪影
嗶聲

接著世界被：

少年漫畫污染

阿銀外觀開始變化。

第一次：

頭髮變尖

新八：

「怎麼突然變得這麼王道！」

第二次：

背後出現巨大武器

第三次：

整張臉：

████████████

新八：

「已經完全不能播了啊！！！」

最後玩家靠「吐槽」把敘事規則破壞掉。

Phase 7：Content Pipeline

如果 Vertical Slice 成立，這才是正式 Production。

這時你才開始做：

Chapter 1
Chapter 2
Chapter 3
...

但所有章節都共用：

Dialogue Engine
Event Engine
Timeline Engine
Mini-game Framework
Save System
NPC System
Quest System

所以每新增一章，主要成本變成：

劇本 + 美術 + 特殊小遊戲

而不是一直重新寫系統。

我會把 Roadmap 寫成這樣
Phase	內容	產物	驗證問題
0	Core Design	1頁設計文件	遊戲到底在賣什麼
1	Text Prototype	10–15 分鐘	對話好不好笑
2	吐槽系統	可玩 Prototype	吐槽能不能當玩法
3	Mini-game Framework	3 個 mini-game	Genre shift 好不好玩
4	Timeline Prototype	3-loop Demo	時間線推理成立嗎
5	Exploration Hub	4 場景	世界有沒有生命
6	Vertical Slice	30–45 分鐘	完整體驗成立嗎
7	Production Pipeline	Chapter Template	能不能大量生產內容
8	Full Production	8～15 小時	正式遊戲
專案程式架構也可以直接照這個切

如果是 Godot，我會很刻意把它分成：

/game
│
├── core
│   ├── GameState
│   ├── SaveManager
│   └── EventBus
│
├── narrative
│   ├── DialogueManager
│   ├── ChoiceSystem
│   ├── TsukkomiSystem
│   └── FlagManager
│
├── timeline
│   ├── TimelineManager
│   ├── WorldState
│   └── LoopManager
│
├── minigames
│   ├── MiniGameBase
│   ├── Rhythm
│   ├── Reflex
│   └── Chase
│
├── world
│   ├── Player
│   ├── NPC
│   ├── Interaction
│   └── SceneManager
│
└── content
    ├── chapter_01
    ├── chapter_02
    └── shared

這樣你不會把：

劇情程式

跟：

小遊戲程式

全部黏在一起。

對你這個案子，我認為真正的 MVP 應該只有 20～30 分鐘

不要做 2 小時。

MVP：

1 個 Hub
3 個場景
4～6 NPC

1 個主線事件

1 次動漫污染

2 種阿銀異常外觀

1 次時間線 Reset

3 個吐槽事件

2 個 Mini-game

1 個短 Boss

1 個真正有情緒重量的結尾

已經足夠。

因為你要證明的是：

日常
 ↓
奇怪
 ↓
跨動漫 Parody
 ↓
玩法改變
 ↓
吐槽
 ↓
時間線謎題
 ↓
突然認真
 ↓
再用智障笑點收尾

這個 25 分鐘如果很好玩，你就有遊戲了。

後面基本上都是內容擴張。