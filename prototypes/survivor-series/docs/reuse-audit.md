# 模組重用盤點

來源檢查：2026-10-07，`/mnt/d/repo/godot/sugarcane-tanks` 與 `prototypes/godot-kit`。本次未修改兩個來源專案，也未引入外部套件或美術。

## 已同步的共用能力

godot-kit 已包含 sugarcane-tanks 抽出的 `sfx_bank.gd`、`haptics.gd`、`time_control.gd`、`music.gd`、`camera_shake.gd`、`floating_stick.gd`、`scene_loader.gd`，以及 `atomic_file.gd`、`synth.gd`、`scene_builder.gd`、`test_kit.gd`、`font_check.gd`。

現在實際使用 SceneBuilder（製作）、TestKit／FontCheck（驗證）、FloatingStick（輸入）、TimeControl／CameraShake（回饋）、SfxBank／Synth（音效）；Music 留在場景中但未指定音樂。使用 kit 的 Web 建置／IDBFS 補丁與字型子集工具，已完成無 threads 的 Web 匯出設定。震動與載入 UI 尚未接入，沒有將未使用的模組宣稱為已實作。

## sugarcane-tanks 候選

| 來源 | 可保留概念 | 已見耦合／接入前須處理 |
|---|---|---|
| `domain/hero_stats.gd` | 一局數值與升級堆疊的純邏輯分離 | 甘蔗多發／穿透／反彈、固定能力 ID 與固定經驗曲線；不能等同通用武器系統 |
| `data/ability_def.gd` | Resource 編輯升級卡資訊 | 效果靠 hero_stats 的 ID 分派；多武器／進化若採用需重新定義效果邊界 |
| `ui/ability_card.tscn`、`choice_panel.tscn` | 可編輯卡片與選擇面板 | 文案、樣式、腳本依賴與暫停行為需對照第一款需求 |
| `player/hero.gd` | CharacterBody2D 移動與受傷回饋 | 明確禁止移動攻擊，呼叫 game 的瞄準、juice 與甘蔗攻擊；需拆出攻擊策略才能支援邊走邊打 |
| `enemies/` | 預警、衝刺、遠程敵人的模式 | 依 game 服務、角色素材與房間縮放；先選出第一款需要的敵人再抽取 |
| `pickups/`、`effects/` | 拾取、傷害數字、升級表現 | 需逐項查 scene 素材與 game 呼叫；未宣稱可直接搬入 |
| `game/settings.gd` | 設定存檔模式 | 系列各作品／角色是否共享存檔尚未確定 |
| `main.gd`、`rooms/` | 清房、Boss、結算的流程參考 | 是房間制，非持續時間刷怪；不作系列核心直接複製 |

優先使用 kit 的既有實作；專屬戰鬥模組經需求確認後抽取。新抽取物先在本專案驗證，是否回收進 kit 依實際第二個使用者判斷。美術與音樂若要搬入，再依來源的授權／製作名單逐項記錄。
