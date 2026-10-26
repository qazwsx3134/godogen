# 蓬蓬草原 session checkpoint

## 2026-10-26｜系統文件與 roadmap 規劃

- 使用者要求：以 Lead Game Designer、Godot Specialist、Lead Programmer、Lead Systems Designer 職責，根據手機製作基準詳細列出各系統文件與 roadmap。
- 已確認：手機執行、固定鏡頭方向／俯角、無旋轉操作、不做短連招；現行製作基準不安排其他鍵序／節奏連招。鏡頭可跟隨平移。
- 此次完成：40 系統 planning dossiers、系統索引、文件契約、Godot 架構草案、M0～M6 roadmap、16 項決策清單、驗證計畫、game brief 與 README 入口。
- 入口：`design/planning/README.md`；結構化登錄：`design/planning/system-register.json`；順序與出口：`production/roadmap.md`。
- 狀態：Planning Draft；不是 40 份詳細 GDD 定案，不是功能實作完成。現有 prototype 含部分行為，但新手機範圍未驗收。
- Studio：從遊戲 root 明確跑 resolve_config，得到 minimal／solo／collaborative；依使用者本次詳細文件要求增加深度，未改全域設定。授權內可逆文件編輯直接完成，未開代理。
- 文件驗證：40 unique systems、120 unique AC、前置圖無循環、反向依賴一致、首版階段先後一致、49 Markdown／615 本地連結／8 圖通過。證據：`production/planning-validation-2026-10-26.json`。
- 沒有修改遊戲腳本、scene、素材、匯出或部署；Godot／真機／多人壓測未執行。
- 下一步建議：依 M0 工作包補可實作的 GDD／契約／TDD，收斂 D01～D03（方向、平台、目標機），再做固定鏡頭／觸控／導航／最小物品與保存的手機薄切片。使用者尚未在本次要求實作。
- 更新規劃時同步維護 Markdown／JSON 與雙向依賴；本次 `/tmp/seal_planning_build.py` 僅製作工具，正常執行不可用它覆寫人工文件。
