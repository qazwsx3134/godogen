# S18 掉落、金幣與獎勵交易

狀態：研究完成／製作規格草案；本新案尚未審核或整合實作，repo既有基礎另計。優先級：MVP；主要里程碑：M2。

既有module／prototype、差距與程式位置見[30系統重用盤點](../reuse-audit.md)。

## 1. 原作證據與未知

O：V有金幣+6／+8／+7；各截圖金幣增加，地圖有鑰匙；角色與裝備存在。U：完整掉落表與貨幣用途。 證據ID對照[素材分析](../00-reference-analysis.md)；未標O的實作與規則均為P提案。

## 2. 用途與玩家價值

掛機產出能被看懂且可預測投入；一個擊殺或獎勵不會重領，也不因介面關閉而遺失。

## 3. 要做的內容與規則

MVP做金幣、EXP與固定獎勵；M3加入多池與關卡收益統計；M4接進化與製作資源sink。

P：獎勵由唯一encounter_id／kill_id產生grant_id，生成結果後去重提交。金幣以整數保存；支出先驗證資源與目的容量。Application協調EXP／角色等owner，不建立第二套資料副本。

## 4. 資料、數值與持久化

LootTable、RewardBundle、RewardReceipt、WalletLedger；來源、金額、池版號、seed／結果、command_id、state_revision；貨幣單位與上限明確。

數值與單位以本系統正式F／D文件為準；共通候選計算見[數值模型](../balance-model.md)。持久狀態經S23的快照介面保存，定義資源不承載玩家狀態；顯示用暫態不自動列入存檔。S23是儲存適配器，這項整合不是領域系統反向依賴它。

## 5. Godot分工與介面

RewardService、Wallet與InventoryTransaction；reward_summary.tscn、currency_row.tscn。CombatEvent由應用轉成GrantReward，不讓戰鬥scene直接改背包Label或wallet。

強制領域前置：**S01, S08, S17**。直接使用本契約的下游：**S14, S15, S19, S20, S21, S24, S28**。此處列的是實作契約依賴；玩家循環中的獎勵回饋不形成程式循環引用。畫面檔名為預定交付，尚未建立。

## 6. 例外與失敗行為

同一grant重送回既有receipt；負金幣支出或溢位拒絕；實物滿包依S17；若多種獎勵需一次領取，不能只加部分後拋例外。

## 7. 調參與文件交付

掉率、金幣範圍、資源流與成本回收期見balance-model。記錄各來源／消耗類別，分清一次性首通與可循環農場收益。

**正式文件需求**：G／F／U／T／D／Q／C；資源流圖、獎勵交易／去重、掉落與成本表；ADR A04。 代號內容見[文件製作計畫](../documentation-plan.md)。本檔提供研究／規格草案，不代表這些正式文件已完成。

## 8. 驗收條件草案

- **AC-S18-01**：把同kill事件提交100次，只得到一次獎勵；重開視窗及讀檔後仍無重領。
- **AC-S18-02**：製作或天賦支出不足時不扣任何資產；固定seed的掉落分布與預期表一致於統計容許區間。

關聯：[系統總表](../systems-index.md) · [Godot架構](../godot-architecture.md) · [roadmap](../roadmap.md)。實際驗收需保留建置版本、環境、指令與結果；目前均未執行遊戲功能驗收。
