# Kit 第二批實作研究：抽樣、養成與場景（2026-11-06）

本批全文讀取 10 支先前只有清單盤點的腳本，語義限制回填 `catalog/specs.json`，由既有 build 再生 `capabilities.json` 與 REFERENCE。未改 runtime、未同步原型、未執行延期測試。

## 實作結論

| 能力／來源 | 原始碼確認 | 抽象與維護決策 |
|---|---|---|
| [gacha](../addons/proto_kit/gacha.gd) | 整數抽 tier；保底不耗 RNG；featured 可在 pool 外直接返回；pick 的 featured 分支發生在空 choices 檢查前 | 保留獨立抽樣順序。先補 weights／pool／share 邊界；勿直接改成浮點 weighted_choice 破壞 RNG 相容性。檔頭 pure functions 用語不足，目錄明訂會消耗呼叫端 RNG |
| [card_draft](../addons/proto_kit/card_draft.gd) | 深複製卡片；抽選無放回；reroll 候選不足會回用舊卡；restore 回寫 RNG；pick 只看公開 current | 是完整選卡狀態機，不只 weighted sample。保持 core，先封裝 current 或明訂外部不可改，補 restore 的全域限制。與新 weighted_choice 的 <= / < 邊界差異需遷移策略 |
| [pet_care](../addons/proto_kit/pet_care.gd) | egg groups／XP 表是固定玩法；每次 tick 至多一次飢餓；feed 不扣物品；evolve recipe 只比 membership；失敗可清 XP | 定位 Seal 風格 companion policy。交易由遊戲管理，材料數量須另驗；未來若第二個養成模型需要，只抽共同需求衰減／事件邊界，不先參數化所有規則 |
| [march_strip](../addons/proto_kit/march_strip.gd) | visible 時 _process 自動 step；沒有 auto_step flag；傷害／popup 共用元件 RNG；popups 為固定子節點輪用 | 保留展示 scene，權威結算留 domain。手動 step 時需停用 process。增加 popup 會改變展示 RNG 序列，故不能由此事件決定經濟結果 |
| [hd2d_look](../addons/proto_kit/hd2d_look.gd) | Resource factory；未知 override 只記錯繼續；回傳可能已有其他設定 | 定位製作配方，產出 .tres 後讓編輯器維護。設定檢查應可回 diagnostics，不把 push_error 當拒絕整筆設定 |
| [hd2d_stage](../addons/proto_kit/hd2d_stage.gd) | ready 收集靜態 light 清單；sprite_light 接世界點；flicker 每步覆寫 energy | stage scene＋少量行為是合適抽象。明訂光源生命週期與唯一 energy owner；群體乘光源的掃描成本待測，不預先另建空間索引 |
| [sprite3d_actor](../addons/proto_kit/sprite3d_actor.gd) | ready 複製材質；step 秒轉 60 Hz ticks；finished 是查詢；size_from_sheet 會覆寫 scale | 延續 scene＋sheet 分層；與 MultiMesh 共用 sheet math、不強迫共用 Node。單一 clock owner，設定／動畫 fallback 需驗證 |
| [pixel_card3d](../addons/proto_kit/pixel_card3d.gd) | setter 與 ready 重建 mesh/material，覆寫 tilt/shadow；texture=null 清 mesh | 明訂參數化卡片與 baked prop 兩種維護方式。後者才允許直接編輯獨立材質；不能宣稱手改生成資源會保留 |
| [camera_shot](../addons/proto_kit/camera_shot.gd) | 23 行資料 Resource；負 hold 為等待 release；無 runtime 方法 | 保留資料資產；運算與座標修正在 ShotCamera，避免每個 preset 各自執行 |
| [nine_slice](../addons/proto_kit/nine_slice.gd) | 修改 Theme 五種狀態；normal 缺失不改，其他狀態退回 normal；pad/sink 與 slice 分開 | 製作工具，保留既有 Theme 其餘項目；不新增 UI runtime，也不重畫既有美術。入口需驗 pattern／margin |

## 儲存規格需要分別描述

```text
Gacha       → 宿主保存 pity + RNG + pool/version
CardDraft   → 本身保存 levels/offers + RNG.state；restore 會改外部 RNG
PetCare     → 保存 pet 狀態；RNG/options 另由宿主保存
MarchStrip  → 展示狀態；不作離線收益權威
```

四者都涉及隨機與時間，持久化邊界卻不同。禁止用一個通用「to_dict 可存檔」標籤取代細節。

## 下一步

先修正式契約的輸入驗證與所有權，再評估遷移；本次已將現有行為與缺口寫入 AI 查詢的 constraints。尚未實作的改進沒有被包裝成保證。累計研究覆蓋為 36 項實作研究（含前批選讀）、8 項前階段、26 項清單盤點，詳見 [覆蓋表](RESEARCH-COVERAGE.md)。剩餘項目包含 inspection／authoring／gallery／VFX，仍須逐類研究，不以數量宣稱全部完成。

## CodeGraph 接入與實際證據

本機 `codegraph` 為 v0.9.9，路徑 `/Users/peter/.local/bin/codegraph`。使用者已初始化此 repo；`codegraph status .` 回 260 files、5,742 nodes、15,104 edges，語言統計為 Python／JavaScript／YAML／TypeScript／TSX／C#。`codegraph files --pattern '*.gd' --json` 無結果；這只證明目前索引未涵蓋 GDScript，不推論所有版本永遠不支援。

`codegraph install --target codex --location local --yes` 回報 Codex 不支援 local；取得沙箱外寫入授權後，以 `--location global` 成功更新 `~/.codex/config.toml`。安裝器要求重啟 agent；本 session 未出現 CodeGraph MCP 工具，因此本輪採 CLI 查詢，而非宣稱已經呼叫新 MCP。

已執行 `codegraph query api --kind function --limit 3 --json`，定位到 `tools/capabilities.py:31`；`files --filter prototypes/godot-kit/tools` 列出 16 個工具來源。GDScript 仍優先用既有 codebase-memory MCP（本 repo 已索引），按需要讀來源。未另裝功能重複的 skill，也未建立本 repo 禁止維護的 `.agents/skills/`。

驗證為文件／目錄層：build 已成功生成 70 項；不等於 GDScript、手機／GPU 或新重構測試通過。`.codegraph/` 為本機索引，保留使用者已有狀態，未納入提交。
