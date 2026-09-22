# Prototypes

此目錄收錄獨立的設計驗證原型。各原型維護自己的工具鏈、README 與驗證資料，repo 邊界見 [ADR 0001](docs/adr/0001-prototypes-live-in-godogen.md)。

## 第一人稱互動小說規劃

[Prototype Roadmap](../docs/interactive-fiction/ROADMAP.md)：以現有《消失的草莓牛奶》與銀魂概念為起點，先測試文字雛形，再做 2D 主觀視角改編。和朋友完成短篇後，再根據反覆需要的功能整理製作工具。

## 既有原型

- [口袋怪獸日記](pixel-monster/README.md)：iOS 優先的直式像素養成遊戲，包含照顧、模擬步行孵化、訓練、NPC 對戰、分歧進化與本機收藏；[iOS CI/CD](pixel-monster/docs/IOS-CICD.md)。
- [消失的草莓牛奶](missing-strawberry-milk/README.md)：本輪互動小說原型；[功能基線](missing-strawberry-milk/QA-BASELINE.md)與[真人試玩計畫](missing-strawberry-milk/PLAYTEST.md)。相關題材詞彙見 [CONTEXT.md](CONTEXT.md)。
- [Anime Card Roguelite](anime-card-roguelite/README.md)：卡牌戰鬥原型，範圍與執行方式見該目錄文件。
- [軌道連珠 Pachinko](pachinko/README.md)：Godot 直式柏青哥機台，驗證「純抽象的幾何演出能不能撐起期待感」；階段見 [ROADMAP.md](pachinko/ROADMAP.md)，詞彙見 [CONTEXT.md](pachinko/CONTEXT.md)。獨立於互動小說路線。
