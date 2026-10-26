# S20 天賦星圖與永久能力解鎖

狀態：研究完成／製作規格草案；本新案尚未審核或整合實作，repo既有基礎另計。優先級：Vertical Slice；主要里程碑：M3。

既有module／prototype、差距與程式位置見[30系統重用盤點](../reuse-audit.md)。

## 1. 原作證據與未知

O：E06／E07節點圖、前置、0/1、金幣、上陣格+1、回到中心、已購加成。U：各節點成本／重置與Lv.20含義。 證據ID對照[素材分析](../00-reference-analysis.md)；未標O的實作與規則均為P提案。

## 2. 用途與玩家價值

把收益轉成有方向的長期成長，逐步開放隊伍空間與管理能力。

## 3. 要做的內容與規則

M3先做6～8節點、2條選擇路、1個上陣格解鎖；M4擴經營／修習線，數量為P。

P：節點有前置、最高級、價格與效果；價格和資格都由服務驗證。數值加成送Modifier，格數加成送SlotPolicy。原型不開重置；正式是否退款須明定，不能直接套kit預設免費退款。

## 4. 資料、數值與持久化

TalentDefinition：id、position、prerequisites、max_rank、cost_curve、effects、unlock_requirement；TalentState：ranks、purchase_receipts。節點位置留在scene或編輯器資源可調。

數值與單位以本系統正式F／D文件為準；共通候選計算見[數值模型](../balance-model.md)。持久狀態經S23的快照介面保存，定義資源不承載玩家狀態；顯示用暫態不自動列入存檔。S23是儲存適配器，這項整合不是領域系統反向依賴它。

## 5. Godot分工與介面

TalentService評估前置並用S18支付；talent_graph.tscn、talent_node.tscn、purchase_preview.tscn。kit upgrade_tree先驗證前置與語意再適配，不直接修改同步副本。

強制領域前置：**S06, S18**。直接使用本契約的下游：**S26**。此處列的是實作契約依賴；玩家循環中的獎勵回饋不形成程式循環引用。畫面檔名為預定交付，尚未建立。

## 6. 例外與失敗行為

前置循環由S01拒絕；餘額剛好可買；快速連點不能超rank；解鎖slot後既有編成不重設；灰節點顯示具體缺條件。

## 7. 調參與文件交付

成本曲線、加成量、首個上陣格所需時間與兩路取捨做F表；UI同時顯示目前／下級／花費／餘額。

**正式文件需求**：G／F／U／T／D／Q／C；節點圖、價格／效果／前置表、重置決策與slot整合。 代號內容見[文件製作計畫](../documentation-plan.md)。本檔提供研究／規格草案，不代表這些正式文件已完成。

## 8. 驗收條件草案

- **AC-S20-01**：前置未滿時直接送購買command也被拒絕；快速重送不多扣金幣或超級數。
- **AC-S20-02**：買上陣格後SlotPolicy恰+1，存讀仍成立；取消預覽不改金幣或能力。

關聯：[系統總表](../systems-index.md) · [Godot架構](../godot-architecture.md) · [roadmap](../roadmap.md)。實際驗收需保留建置版本、環境、指令與結果；目前均未執行遊戲功能驗收。
