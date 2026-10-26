# S10 關鍵詞、狀態與事件連鎖

狀態：研究完成／製作規格草案；本新案尚未審核或整合實作，repo既有基礎另計。優先級：Vertical Slice；主要里程碑：M3。

既有module／prototype、差距與程式位置見[30系統重用盤點](../reuse-audit.md)。

## 1. 原作證據與未知

O：E08祝福／靈息描述治療觸發傷害；V約3.5s可見+48與祝福-22。U：是否用治療基值、過量量、觸發CD等。 證據ID對照[素材分析](../00-reference-analysis.md)；未標O的實作與規則均為P提案。

## 2. 用途與玩家價值

創造補師也能成為輸出引擎等build差異，讓隊伍選擇超過單純比較攻擊力。

## 3. 要做的內容與規則

M3只做2～3個可組合關鍵詞、限時buff／stack與治療反應；不先做通用任意腳本效果語言。

P：每個Rule指定listen_event、條件、產生效果、stack_policy、ICD與scope。反應透過有界佇列處理，不在signal callback遞迴扣血。事件帶cause_id、parent_id與tags；同源重入禁止。

## 4. 資料、數值與持久化

ReactionRule、StatusDefinition、StatusInstance、ReactionTrace；治療事件同時保留raw/applied，原型按實際治療算，原作規則未確認。

數值與單位以本系統正式F／D文件為準；共通候選計算見[數值模型](../balance-model.md)。持久狀態經S23的快照介面保存，定義資源不承載玩家狀態；顯示用暫態不自動列入存檔。S23是儲存適配器，這項整合不是領域系統反向依賴它。

## 5. Godot分工與介面

ReactionResolver讀S08標準事件並產生下一批EffectRequest；status_icon.tscn與keyword_tooltip.tscn顯示來源及堆疊。RNG與tick由S02注入。

強制領域前置：**S02, S08**。直接使用本契約的下游：**無強制下游；由Application／UI整合**。此處列的是實作契約依賴；玩家循環中的獎勵回饋不形成程式循環引用。畫面檔名為預定交付，尚未建立。

## 6. 例外與失敗行為

兩個反應互相觸發時限制深度與同源重入；死亡來源是否仍生效由規則定義；狀態刷新是延長或覆蓋不能混淆；過量0治療原型不觸發。

## 7. 調參與文件交付

初始上限每根事件深度8／子事件64，觸頂留trace並報錯；調stack上限、持續時間、係數與ICD，正常build不可依賴上限截斷才穩定。

**正式文件需求**：G／F／U／T／D／Q／C；觸發矩陣、反應trace、過量治療決策；ADR A05。 代號內容見[文件製作計畫](../documentation-plan.md)。本檔提供研究／規格草案，不代表這些正式文件已完成。

## 8. 驗收條件草案

- **AC-S10-01**：建立治療→祝福傷害→吸血的循環fixture，事件有界且trace能指出阻斷原因。
- **AC-S10-02**：相同輸入重播得相同stack／HP；移除關鍵詞後下一遭遇不留下隱藏反應。

關聯：[系統總表](../systems-index.md) · [Godot架構](../godot-architecture.md) · [roadmap](../roadmap.md)。實際驗收需保留建置版本、環境、指令與結果；目前均未執行遊戲功能驗收。
