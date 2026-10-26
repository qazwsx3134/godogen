# S30 背景效能、長時間運作與品質預算

狀態：研究完成／製作規格草案；本新案尚未審核或整合實作，repo既有基礎另計。優先級：Alpha；主要里程碑：M5。

既有module／prototype、差距與程式位置見[30系統重用盤點](../reuse-audit.md)。

## 1. 原作證據與未知

I：桌面常駐的使用方式需要低耗能與長時間穩定；素材不提供CPU、GPU、電力或記憶體測量。 證據ID對照[素材分析](../00-reference-analysis.md)；未標O的實作與規則均為P提案。

## 2. 用途與玩家價值

遊戲陪伴工作而不拖慢工作機；八小時後仍能正常作戰、整理與存讀。

## 3. 要做的內容與規則

M1開始量基準與上限；M2限制actor／浮字；M5完成管理面板反覆開關、隱藏、睡眠、8小時soak與匯出版效能驗收。

P：降低的是渲染、特效、UI刷新與音訊負擔，核心經過時間按S02政策處理。可見30FPS、隱藏低頻或停render作候選；背景補算不能改獎勵效率。所有事件buffer與池有上限。

## 4. 資料、數值與持久化

PerformanceProfile、RuntimeCounters、SoakSummary；actors、fx、voices、event_queue、memory、tick_ms、frame_ms、catchup_latency。記錄硬體／OS／renderer／build與是否匯出版。

數值與單位以本系統正式F／D文件為準；共通候選計算見[數值模型](../balance-model.md)。持久狀態經S23的快照介面保存，定義資源不承載玩家狀態；顯示用暫態不自動列入存檔。S23是儲存適配器，這項整合不是領域系統反向依賴它。

## 5. Godot分工與介面

PerformanceController只協調adapter預算；profiler與S28導出結果；performance_debug_panel.tscn只給開發模式。UI重算用dirty標記，避免每幀整頁重建。

強制領域前置：**S02, S04, S28**。直接使用本契約的下游：**無強制下游；由Application／UI整合**。此處列的是實作契約依賴；玩家循環中的獎勵回饋不形成程式循環引用。畫面檔名為預定交付，尚未建立。

## 6. 例外與失敗行為

過量spawn／反應事件觸頂要可診斷；切關釋放舊actor／signal；多次開關管理面板不累積view；睡眠喚醒不凍結數分鐘；無渲染時仍能安全存檔。

## 7. 調參與文件交付

暫定M5目標：參考機匯出版可見30FPS；tick p95<5ms；暖機後8小時記憶體增幅<10%且無單調無界成長；實際硬體與CPU／GPU／電力門檻M1量後釘選，不宣稱已達成。

**正式文件需求**：G／F／T／D／Q；效能預算、參考機、profile紀錄、8小時soak protocol與證據。 代號內容見[文件製作計畫](../documentation-plan.md)。本檔提供研究／規格草案，不代表這些正式文件已完成。

## 8. 驗收條件草案

- **AC-S30-01**：8小時腳本含開關窗、切關、滿包、存檔與睡眠喚醒，無錯誤、獎勵重算或無界資源成長。
- **AC-S30-02**：15／30／60FPS與隱藏模式同tick測試核心一致；效能報告含p95、記憶體趨勢及未達標項。

關聯：[系統總表](../systems-index.md) · [Godot架構](../godot-architecture.md) · [roadmap](../roadmap.md)。實際驗收需保留建置版本、環境、指令與結果；目前均未執行遊戲功能驗收。
