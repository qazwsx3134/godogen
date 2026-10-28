# 人格與記憶：人類確認後才能用於共同編劇

這是製作階段 CPC v0.1 的最小檔案流程；供外部 agent 重複讀取，編輯器可查看與匯出；人格修改及確認登記仍依檔案／CLI 流程進行。

目前銀時、新八、神樂三份人格為已確認 revision 2，三條基礎背景記憶維持已確認 revision 1。作者在審閱補充後回覆「可以 採用」，已依完整內容雜湊記錄於 confirmations.json；完整現行資料見 [REVIEW.md](REVIEW.md)。例句是新擬的語氣測試句，不是原作引文。後續新增或修改仍須人類確認。

[第二版補充審閱稿](proposals/character-depth-v2/REVIEW.md)已採用，包含情境反應、語氣正反例、行為界線與關係差異；[第一版歷史快照](archive/character-depth-v1/README.md)保留舊內容及確認證據。本次沒有新增記憶。角色 JSON 中 proposal_meta 保留提案建立時的來源追蹤資料，現行採用狀態以 confirmations.json 的內容雜湊與人類證據為準。

## 必須遵守的人類確認規則

1. agent 新增、修改人格或記憶時，先展示完整內容、來源與雜湊，請協作人類確認。使用者同意「建立系統」不等於同意具體角色設定。
2. 未確認內容只能拿來討論／修訂草稿，不能當成本篇已成立設定或已發生事件。人類可以逐筆確認、要求修改或拒絕。
3. 只有取得明確的人類確認後，agent 才能替相應 id／內容雜湊登記確認；記錄實際確認語句或可追溯位置。禁止自行填入、猜測或偽造人類證據。
4. 確認綁定整筆資料的 SHA-256；內容或 revision 改變後即失效，必須重審。不要只把 `status` 改成 confirmed。
5. 新劇情不自動變成人物記憶。先提出記憶草案，確認 owner、知情角色、來源與可否改寫，再請人類確認。

```text
人格／記憶草稿 → 人類檢閱 → 明確確認指定內容
                    │             ↓
                    └─ 修改 ← 確認紀錄綁定雜湊
                                  ↓
                         產生 agent 寫作上下文
```

## 資料與最小格式

- `characters/*.json`：schema_version=1、kind=character、id、正整數 revision、來源 sources、name，以及 core／behavior／voice／relationships／boundaries。voice 至少有 examples 和 avoid；描述行為依據，不只形容詞。這是最小結構驗證，不會自動判定人物是否還原原作。
- `memories/*.json`：schema_version=1、kind=memory、id、revision、sources、owner、category（canon／story／relationship／conversation）、summary、known_to、mutable。owner 必須是已登記角色，且位於 known_to；事實與人物錯誤信念如需分離，要寫清楚再送審。
- `confirmations.json`：獨立的確認紀錄。初始為空，草案不能自行宣告通過。此檔是本機合作紀錄，不是身份驗證或數位簽章；無法防止有寫入權的人偽造證據，必須搭配上述協作規則。

新增角色時建立 character 檔，新增本篇事件時另建 memory 檔。未選取的記憶不會自動載入；不替任何角色假定他知道全部人的秘密。

## 操作（在遊戲目錄）

```bash
python3 tools/persona_context.py validate
python3 tools/persona_context.py review
python3 tools/persona_context.py context --characters shinpachi --memories shinpachi_yorozuya_baseline
```

`validate` 只檢查結構與引用，不代表人類確認；`review` 顯示完整內容、當前雜湊及待審狀態。`context` 遇到任一未確認、被改過或未知的指定記錄就失敗，不輸出部分上下文。沒有 `--memories` 時不載入記憶；輸出按 known_to 分配給各角色，附 revision 與雜湊供交接查核。

取得人類明確確認後，才執行以下命令；將每個參數換成實際 id、檢閱時的雜湊、確認人與確認證據：

```text
python3 tools/persona_context.py confirm --id <id> --sha256 <已檢閱雜湊> --reviewer <確認人> --evidence <實際人類確認語句或位置>
```

命令只會接受與目前內容相符的雜湊。人格和每條記憶分別確認，不能用「確認角色」推定所有記憶也確認。工具不會代替你判斷對話中的人類是否真的授權，agent 必須先核對確認語句的範圍。

## agent 每次開工

先讀本文件，再用 `context` 明確選角色與記憶。若被擋住，讀 review 內容請人類確認，不能繞過去拿原始草案寫正式劇本。產生上下文後，才寫本篇節拍與台詞候選；新設定、額外記憶或角色知情變動另外列成待確認提案。作者採納劇本後再放進故事編輯器試玩。

本機編輯器的「編劇參考」可查看這份正式人格庫，手動選角色與記憶，產生／下載和 CLI 相同的 agent 上下文。記憶預設不選，需先選擁有者；未確認或內容變更時不能匯出，開面板後版本更新則要求重開檢閱。面板不改寫人格、記憶、確認紀錄或故事，不提供一鍵自我核准。獨立作品不會自動套用萬事屋角色；資料來源固定為本作 authoring 正式庫，排除 archive／proposals。

尚未提供完整 CRE、內建 AI Writer、向量檢索、OOC 自動評分或自由聊天。這一輪完成的是外部 agent 與故事編輯器之間的人格參考流程。

測試：`python3 tools/test_persona_context.py`；測試的確認資料只在暫存目錄，不能作為實際作者確認。
