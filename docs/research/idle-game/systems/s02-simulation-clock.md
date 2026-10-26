# S02 模擬時鐘與事件排程

狀態：研究完成／製作規格草案；本新案尚未審核或整合實作，repo既有基礎另計。優先級：MVP；主要里程碑：M1。

既有module／prototype、差距與程式位置見[30系統重用盤點](../reuse-audit.md)。

## 1. 原作證據與未知

I：錄影有週期性作戰；E06～E09開管理頁時戰鬥帶仍可見。無法得知原作tick。 證據ID對照[素材分析](../00-reference-analysis.md)；未標O的實作與規則均為P提案。

## 2. 用途與玩家價值

掛機收益要由遊戲時間決定；低FPS與管理面板開關都不能改變戰鬥結果。

## 3. 要做的內容與規則

M1做固定tick、事件順序與RNG分流；M2支援明確暫停及背景；M3接休眠補算政策。

P：先以20Hz測試；累積單調時間由唯一driver推進。UI、動畫不推進模擬。同tick以phase／source_id／sequence穩定排序，亂數以用途分流。大delta交給catch-up，不能無上限補tick。

## 4. 資料、數值與持久化

SimulationState：tick、accumulator、combat_rng_state、loot_rng_state、pending_commands、build_revision；所有冷卻用tick或明確秒轉換。

數值與單位以本系統正式F／D文件為準；共通候選計算見[數值模型](../balance-model.md)。持久狀態經S23的快照介面保存，定義資源不承載玩家狀態；顯示用暫態不自動列入存檔。S23是儲存適配器，這項整合不是領域系統反向依賴它。

## 5. Godot分工與介面

RefCounted模擬＋SimulationDriver Node；advance_ticks(count)、enqueue_command；輸出不可變CombatEvent。driver保存於main.tscn，不在每個Window各建一份。

強制領域前置：**S01**。直接使用本契約的下游：**S07, S08, S09, S10, S24, S28, S30**。此處列的是實作契約依賴；玩家循環中的獎勵回饋不形成程式循環引用。畫面檔名為預定交付，尚未建立。

## 6. 例外與失敗行為

OS休眠／視窗隱藏與手動暫停要分開；無負delta；過期command依tick及版本拒絕；關窗與重新開窗不能複製driver。

## 7. 調參與文件交付

20Hz／30FPS只是初始P；catch-up逐幀上限、每幀運算預算、允許延遲須量測。不得用改時間倍率補救效能。

**正式文件需求**：G／F／T／D／Q；時序圖、暫停矩陣、RNG契約；ADR A02。 代號內容見[文件製作計畫](../documentation-plan.md)。本檔提供研究／規格草案，不代表這些正式文件已完成。

## 8. 驗收條件草案

- **AC-S02-01**：固定seed與command序列，在15／30／60FPS顯示下跑相同tick，核心state完全一致。
- **AC-S02-02**：開關管理面板10次後只有一個driver，無重複獎勵；休眠區間不與在線區間重疊結算。

關聯：[系統總表](../systems-index.md) · [Godot架構](../godot-architecture.md) · [roadmap](../roadmap.md)。實際驗收需保留建置版本、環境、指令與結果；目前均未執行遊戲功能驗收。
