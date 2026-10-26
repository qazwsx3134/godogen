# S16 裝備、穿戴與比較

狀態：研究完成／製作規格草案；本新案尚未審核或整合實作，repo既有基礎另計。優先級：MVP；主要里程碑：M2。

既有module／prototype、差距與程式位置見[30系統重用盤點](../reuse-audit.md)。

## 1. 原作證據與未知

O：E01六部位武／副／頭／身／手／鞋；E05武器上身且攻擊傷害顯示18。U：裝備職業限制、詞綴、品質與強化規則。 證據ID對照[素材分析](../00-reference-analysis.md)；未標O的實作與規則均為P提案。

## 2. 用途與玩家價值

玩家回來一次就有容易理解的改善；能比較新裝與目前裝備的實際作用。

## 3. 要做的內容與規則

MVP先啟用主武器與一件防具，其餘槽可顯示未啟用；Alpha擴完整六槽與裝備類別。

P：裝備物件有獨立item_uid；穿戴是從容器轉到角色slot的引用交易。限制按slot／job／level驗證；比較顯示受影響屬性來源與預覽，不用單一虛構戰力隱藏差異。

## 4. 資料、數值與持久化

EquipmentDefinition：slot、requirements、modifiers、appearance_id；ItemInstance：uid、definition_id、rolled_affixes、locked；EquipmentState：unit_uid→slots。

數值與單位以本系統正式F／D文件為準；共通候選計算見[數值模型](../balance-model.md)。持久狀態經S23的快照介面保存，定義資源不承載玩家狀態；顯示用暫態不自動列入存檔。S23是儲存適配器，這項整合不是領域系統反向依賴它。

## 5. Godot分工與介面

EquipmentService＋StatCalculator；equipment_panel.tscn、equipment_slot.tscn、compare_tooltip.tscn。換裝只在下一build邊界影響戰鬥；外觀與數值可獨立投影。

強制領域前置：**S05, S06, S17**。直接使用本契約的下游：**S22**。此處列的是實作契約依賴；玩家循環中的獎勵回饋不形成程式循環引用。畫面檔名為預定交付，尚未建立。

## 6. 例外與失敗行為

卸裝目的容器滿時拒絕，交換穿戴時可用換出的空位；鎖定只阻止消耗不一定阻止穿戴，正式規則要明示；不相容部位／等級拒絕並顯示理由。

## 7. 調參與文件交付

屬性幅度、掉落頻率、職業限制與比較排序資料化；原型只用固定詞綴，隨機roll範圍待M4內容驗證。精煉／強化未由素材確認，不加為必做。

**正式文件需求**：G／F／U／T／D／Q／C；裝備槽／職業限制、比較規則與裝備內容表。 代號內容見[文件製作計畫](../documentation-plan.md)。本檔提供研究／規格草案，不代表這些正式文件已完成。

## 8. 驗收條件草案

- **AC-S16-01**：裝備從背包到角色槽再返回，全程只有一個UID且modifier沒有重複。
- **AC-S16-02**：比較預覽與提交後屬性相同；不合法裝備與滿包卸裝不改任何容器。

關聯：[系統總表](../systems-index.md) · [Godot架構](../godot-architecture.md) · [roadmap](../roadmap.md)。實際驗收需保留建置版本、環境、指令與結果；目前均未執行遊戲功能驗收。
