# 存檔版本與 JSON 保護

2026-10-30；目前存檔 schema v2，保留 v1 遷移。

## 行為

- 檔案不存在：正常建立新進度。
- 空檔、無法解析的 JSON、非 Dictionary 根資料或缺少有效整數版本：回傳預設進度供畫面顯示，停止該進度物件寫入，原檔保留。
- 較新版本或不支援的舊版本：停止寫入，不降版。
- 保存前再次讀取目標檔的 JSON／版本；即使遊戲載入後才被其他版本換檔，也拒絕覆寫不相容檔。
- 主畫面提示「存檔受保護」，說明本次遊玩不保存；一般寫入失敗也會在戰報顯示。解除問題需先由玩家備份／檢查原檔，再重新載入。

不新增備份還原或 UI 重設功能。載入、目標檔寫入前檢查，以及準備寫入的新資料都會經過欄位驗證。未知欄位會阻止寫入，避免 normalization 或 resize 丟掉未識別內容。

## 內部欄位檢查

- 英雄等級／經驗／突破陣列必須各有 100 筆，數值為有限整數且落在對應可儲存範圍；行軍與隊長索引有效且不重複。
- 天賦、遺物及藥水陣列不可超過現行數量。舊 v2 的較短天賦／遺物陣列與單一數量藥水仍接受，沿用既有補預設值遷移。
- 武庫／飾品欄位長度與裝備類型吻合；物品 ID 必須存在，uid 跨穿戴與背包唯一，next_uid 必須大於已使用 uid。
- 詞綴是兩元素 pair，key 已定義且不重複，value 為有限數值；未知物品欄位不默默捨棄。
- v2 背包上限 60 件；v1 件數背包遷移後超過 60 件時停止寫入並保留原檔，不截斷。
- root 數值與亂數狀態型別、字串集合及可選欄位均先檢查；正常 v1 武庫與件數背包可遷移。

這是目前格式及安全轉換邊界，不是存檔簽章、反作弊或所有跨欄位經濟規則的證明；例如不驗證每筆貨幣的取得來源。

## 證據

舊版直接載入後保存，會覆蓋較新版、破損 JSON 與空檔；先以回歸測試重現三項 FAIL（`/tmp/hero-save-before.log`）。

修正後 L2 `save_protection progression home main` 全 PASS（`/tmp/godot-tests.zMQXlQ`）。涵蓋原始 bytes 不變、執行中換成未來版本、主畫面提示與保存、缺檔正常保存、v1 遷移及原有養成／主流程。新增提示字在目前 Bold／Medium 字型可用（`/tmp/hero-guard-font.log`）。

重現：repo 根目錄使用隔離 XDG，執行 `bash prototypes/godot-kit/tools/run_tests.sh prototypes/hero-horde-idle save_protection progression home main`。這不是實際舊版／新版雙程序同時操作，也沒有驗證真人手機、磁碟滿或斷電恢復。

## 2026-10-30 schema 回歸結果

先以 15 種有效 JSON 的損壞 payload 重現舊寫入檢查不足（`/tmp/hero-schema-before.log`），再加入 20 種異常的載入／寫入保護、舊格式相容與 v1 裝備遷移測試。亦先重現非法記憶體狀態能建立壞檔的失敗，再加入寫入資料驗證（`/tmp/hero-schema-outgoing-before.log`）。

首次整合測試發現 JSON 的 float 版本值被整數集合比對拒絕；改為數值比較後，最終 L2 `save_protection progression home main recruit` 全部 PASS（`/tmp/godot-tests.vW1ukD`；命令輸出 `/tmp/hero-schema-final2.log`）。未見 SCRIPT ERROR／Parse Error。沒有改 schema 版本或建立手機安裝包。
