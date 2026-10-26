# S08 傷害、治療、生命與戰敗

狀態：研究完成／製作規格草案；本新案尚未審核或整合實作，repo既有基礎另計。優先級：MVP；主要里程碑：M1。

既有module／prototype、差距與程式位置見[30系統重用盤點](../reuse-audit.md)。

## 1. 原作證據與未知

O：V中可見血條下降、數字、治療與敵人減少；E03有HP／攻擊。U：護甲、暴擊、全滅、復活規則。 證據ID對照[素材分析](../00-reference-analysis.md)；未標O的實作與規則均為P提案。

## 2. 用途與玩家價值

玩家能理解隊伍如何存活或失敗；所有傷害、治療與死亡都有單一權威。

## 3. 要做的內容與規則

MVP做普攻、治療、敵方死亡、我方全滅與安全重試；護甲／元素／暴擊先以簡化可配置值處理。

P：EffectResolver統一套傷害與治療，產生raw／mitigated／applied值；HP限制0～max。HP歸零立即標不可選，死亡只發一次。全滅回該關起點，先不扣永久資產，需在正式GDD核定。

## 4. 資料、數值與持久化

DamageRequest／HealRequest：source、target、coefficient、type、tags、cause_id；CombatEvent包含tick、amount_raw、amount_applied、hp_after；EncounterResult帶唯一ID。

數值與單位以本系統正式F／D文件為準；共通候選計算見[數值模型](../balance-model.md)。持久狀態經S23的快照介面保存，定義資源不承載玩家狀態；顯示用暫態不自動列入存檔。S23是儲存適配器，這項整合不是領域系統反向依賴它。

## 5. Godot分工與介面

CombatResolver、HealthState、EncounterState為domain；health_bar.tscn／damage_number.tscn只表演。死亡不能同時由動畫與模擬各發一次RewardGrant。

強制領域前置：**S02, S06, S07**。直接使用本契約的下游：**S09, S10, S18, S19, S24, S28**。此處列的是實作契約依賴；玩家循環中的獎勵回饋不形成程式循環引用。畫面檔名為預定交付，尚未建立。

## 6. 例外與失敗行為

同tick死亡與治療按排程處理；已死亡目標不吃一般治療；過量治療保留raw但applied封頂；無敵／免疫與最低1傷害規則互斥優先級需明列。

## 7. 調參與文件交付

傷害／抗性／間隔候選公式見balance-model；死亡重試延遲、消耗品政策與復活HP尚待核定；原型用1秒重試僅測閉環。

**正式文件需求**：G／F／U／T／D／Q；傷害結算表、生命週期、同tick優先序、戰敗政策。 代號內容見[文件製作計畫](../documentation-plan.md)。本檔提供研究／規格草案，不代表這些正式文件已完成。

## 8. 驗收條件草案

- **AC-S08-01**：同一死亡事件重送兩次只產生一次掉落；HP永不小於0或超上限。
- **AC-S08-02**：全隊死亡能完成失敗→重置→重新遭遇；關管理頁不取消或重複失敗結果。

關聯：[系統總表](../systems-index.md) · [Godot架構](../godot-architecture.md) · [roadmap](../roadmap.md)。實際驗收需保留建置版本、環境、指令與結果；目前均未執行遊戲功能驗收。
