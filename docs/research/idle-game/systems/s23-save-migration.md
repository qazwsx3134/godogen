# S23 存檔、版本遷移與復原

狀態：研究完成／製作規格草案；本新案尚未審核或整合實作，repo既有基礎另計。優先級：MVP；主要里程碑：M2。

既有module／prototype、差距與程式位置見[30系統重用盤點](../reuse-audit.md)。

## 1. 原作證據與未知

I：長期養成與收藏需要持久保存；素材沒有展示存檔、雲端或帳號服務，不能宣稱原作有特定同步方式。 證據ID對照[素材分析](../00-reference-analysis.md)；未標O的實作與規則均為P提案。

## 2. 用途與玩家價值

掛幾小時的成果不會因關閉或更新遺失；製作與進化中斷後仍可恢復合法狀態。

## 3. 要做的內容與規則

M2做單一本地profile、版本化原子快照、備份與load驗證；M3補收益watermark／receipt；雲端非本次範圍。

P：Application收集同一state_revision的各owner快照，驗證後原子寫入。先寫tmp再替換，保留上一份合法bak。schema_version按步遷移，較新未知版本拒絕覆寫；只在成功讀取後才啟動模擬。

## 4. 資料、數值與持久化

SaveEnvelope：schema_version、content_version、state_revision、saved_utc、owners、reward_watermark、receipts；使用UID引用，不序列化NodePath／Tween／視窗物件。

數值與單位以本系統正式F／D文件為準；共通候選計算見[數值模型](../balance-model.md)。持久狀態經S23的快照介面保存，定義資源不承載玩家狀態；顯示用暫態不自動列入存檔。S23是儲存適配器，這項整合不是領域系統反向依賴它。

## 5. Godot分工與介面

SaveRepository＋MigrationPipeline；候選kit atomic_file負責底層，業務一致性由本作負責。save_recovery_panel.tscn提示讀備份／匯出診斷；S23不要求其他domain直接呼叫檔案API。

強制領域前置：**S01**。直接使用本契約的下游：**S24, S25, S27**。此處列的是實作契約依賴；玩家循環中的獎勵回饋不形成程式循環引用。畫面檔名為預定交付，尚未建立。

## 6. 例外與失敗行為

正式壞檔退到通過驗證的備份；兩者都壞則保留原檔並顯示恢復選項，不直接覆寫新遊戲；磁碟滿保持舊檔；未知ID依遷移政策隔離。

## 7. 調參與文件交付

原型自動存檔間隔先30秒、重要不可逆養成交易後立即保存；可接受遺失時間與檔案上限需量測核定。不是雲端anti-cheat方案。

**正式文件需求**：G／U／T／D／Q；完整schema、遷移／回復矩陣、故障注入證據；ADR A04。 代號內容見[文件製作計畫](../documentation-plan.md)。本檔提供研究／規格草案，不代表這些正式文件已完成。

## 8. 驗收條件草案

- **AC-S23-01**：在tmp寫入、替換前／後等注入中斷點，重啟都得到前或後的完整合法快照。
- **AC-S23-02**：舊版fixture遷移一次後資料正確且重跑不重複加成；新版本未知schema不被舊程式覆寫。

關聯：[系統總表](../systems-index.md) · [Godot架構](../godot-architecture.md) · [roadmap](../roadmap.md)。實際驗收需保留建置版本、環境、指令與結果；目前均未執行遊戲功能驗收。
