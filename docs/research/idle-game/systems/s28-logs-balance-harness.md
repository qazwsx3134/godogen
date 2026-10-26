# S28 戰鬥紀錄、收益統計與平衡工具

狀態：研究完成／製作規格草案；本新案尚未審核或整合實作，repo既有基礎另計。優先級：Vertical Slice；主要里程碑：M3。

既有module／prototype、差距與程式位置見[30系統重用盤點](../reuse-audit.md)。

## 1. 原作證據與未知

O：截圖戰鬥帶下有日誌／統計按鈕；沒有展開內容。P：本案加入可重播trace與批次測量。 證據ID對照[素材分析](../00-reference-analysis.md)；未標O的實作與規則均為P提案。

## 2. 用途與玩家價值

玩家知道瓶頸是輸出、續航還是滿包；設計師能用相同條件比較build與關卡。

## 3. 要做的內容與規則

M1就保留核心事件trace；M2可查最近獎勵／錯誤；M3完整DPS／HPS、來源、金與EXP每分、死因及headless batch runner。

P：玩家摘要與開發完整trace分層；每份結果標build／content版本、seed、tick範圍與實際模擬時長。有效治療與raw治療分開，收益不以顯示幀數作分母。

## 4. 資料、數值與持久化

CombatSummary、RewardSummary、RingBuffer、BenchmarkScenario；統計欄位含damage_by_source、overheal、deaths、blocked_drops、time_alive。預設只存有界摘要，不無限保存所有事件。

數值與單位以本系統正式F／D文件為準；共通候選計算見[數值模型](../balance-model.md)。持久狀態經S23的快照介面保存，定義資源不承載玩家狀態；顯示用暫態不自動列入存檔。S23是儲存適配器，這項整合不是領域系統反向依賴它。

## 5. Godot分工與介面

StatisticsProjector只讀已提交事件；logs_panel.tscn、stats_panel.tscn、tools/simulate_batch.gd。與純核心同seed可重播，工具不直接修改正式profile。

強制領域前置：**S02, S08, S18**。直接使用本契約的下游：**S30**。此處列的是實作契約依賴；玩家循環中的獎勵回饋不形成程式循環引用。畫面檔名為預定交付，尚未建立。

## 6. 例外與失敗行為

除以0回明確無樣本；切build時分段；debug trace有容量／導出上限；缺事件造成統計不完整要標示，不能拿錯誤摘要調平衡。

## 7. 調參與文件交付

初始trace環形上限2,000事件，批次100seed×10分鐘作P；最終看機器成本。任何改公式的實驗固定seed集合及內容版本。

**正式文件需求**：G／F／U／T／D／Q；統計定義、事件schema、平衡實驗矩陣與可重播fixture。 代號內容見[文件製作計畫](../documentation-plan.md)。本檔提供研究／規格草案，不代表這些正式文件已完成。

## 8. 驗收條件草案

- **AC-S28-01**：同一事件流的傷害、治療、擊殺與獎勵加總可與核心／帳本對上。
- **AC-S28-02**：固定scenario能導出可重現JSON／CSV；切換UI或背景FPS不改測量結果，buffer到上限仍不增記憶體。

關聯：[系統總表](../systems-index.md) · [Godot架構](../godot-architecture.md) · [roadmap](../roadmap.md)。實際驗收需保留建置版本、環境、指令與結果；目前均未執行遊戲功能驗收。
