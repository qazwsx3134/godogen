# seal-meadow 交接進度

最後更新：2026-11-05。每次 commit、使用者出門或下班時更新這份檔案。只保留最近 3 次 commit 期間的工作與尚未 commit 的工作（新的在上）；更早的紀錄移到 [MILESTONE.md](MILESTONE.md)。

## 2026-11-06｜kit 存檔 adapter 遷移（未提交）

- 分支 master；跨原型能力庫重構的一部分。SaveStore 委派 SaveSlots 並注入 Validation.valid，Main 改經 adapter 保存、映射拒寫原因；保留 bytes 恢復比對與異常主檔保護。
- 只從 kit 來源同步 save_slots.gd；atomic_file 來源／副本一致，其他 kit 副本保持原狀。v4 遷移使用固定位置 UID，v5/v6 與新掉落 UID 不變；future 備份現在啟動即拒絕。
- 驗證：來源／副本 cmp、能力目錄 build/check PASS 70、git diff --check；未執行 Godot／讀寫真實存檔。使用者優先重構、測試延期；此前存檔與城鎮 PASS 不涵蓋本次修改。
- 下一步：恢復測試時以隔離 save_path 跑 save_protection/m3_hardening/world_lifecycle，補雙檔 future 與 v4 UID 冪等性；其他原型 adapter 未遷移。
- 重要入口：scripts/save_store.gd、main.gd、docs/save-protection.md；未改 scene／素材／匯出，未 commit/push，保留其他 session 工作。

## 2026-11-05｜暖陶瓦城鎮薄切片與製作規格

- 分支 `master`、基準 `2237f384`（最新以 `git log -1` 為準）。使用者要求詳細規劃並執行，授權直接生成兩張城鎮方向圖並選定 A 暖陶瓦；接著另授權直接生成商店三視圖與陶瓦／木材／灰泥材質參考。四張圖、實際 prompt、選擇及限制見[風格參考](design/art-prompts/town-style-references-2026-11-05.md)。
- 已接入可編輯[城鎮薄切片](design/quick-specs/town-slice-2026-11-05.md)：商店外觀在廣場北側、南側為入口路與 Kenney 路牌；原村長提供交易及任務，原傳送、存檔、重生與紙娃娃測試人保留。商店不能進入，圓形障礙保守包住目前外觀。正式角色優先直接做 2D Sprite；尚未產生正式角色圖，身體／髮型／武器同步與方向遮擋需再實作素材並驗證。
- 以 Kenney Castle Kit CC0 屋頂加自行建模的倒角牆面、門窗、木樑及台階做出商店樣板：完整 1,296 tris，路牌 168 tris；其原始色票在 Godot 以 shader 示意暖陶色。`.blend`、GLB、原始色票、scene、Kenney 授權副本與[網格報告](production/qa/town-shop-draft-2026-11-05.json)已保存。商店 0 非流形邊、退化面、完全重複三角面與 BVH 相交候選；這些不能保證不存在所有閃爍或共面問題。參考材質圖尚未轉成正式無縫貼圖或法線圖。[正式製作規格](design/pipeline/town-shop-production-spec.md)列出尺寸起點、3,650 tris 預算、材質與驗收。
- 本輪 L2 `env XDG_DATA_HOME=/tmp/seal-town-slice-test-data XDG_CONFIG_HOME=/tmp/seal-town-slice-test-config TEST_TIMEOUT=120 bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow town_slice m2 world_lifecycle town_signpost_sample`：四組 PASS（`/tmp/godot-tests.JzWBIn`）。headless 匯入成功，仍有既知沙箱 TCP 監聽錯誤；無 scene／腳本解析錯誤。桌面 Compatibility 1280×720、844×390 的[商店](art_src/town-slice/shop-1280x720.png)與[入口](art_src/town-slice/entrance-844x390.png)靜態截圖已檢查；尚未完成人工移動時閃爍／觸控、手機 Web／iPhone 效能、L3、正式燈光與材質驗收。
- 下一步：按正式規格統一三視圖、精修商店及真正 UV／底色／必要法線；先以一名原創 2D 角色試方向與裝備層，再擴建廣場街景。後續生成其他圖片前須依專案規則描述批次並讓使用者選擇直接生成或 opt image。多人、戰鬥寵 AI 與手機真人驗收仍依既有延期狀態。本輪城鎮及素材索引納入本次提交；其他專案未提交修改保留，未 push／上傳。測試結果沿用本輪實作證據，交接時沒有重跑。

## 2026-11-05｜先前盤點：城鎮現況與 2D 紙娃娃方向

- 使用者詢問城鎮還缺什麼，並偏好角色直接使用 Sprite 紙娃娃，因正式 3D 角色製作流程尚未跑通。先以直接製作 2D 圖層為優先方向，3D 離線渲染保留為備案；角色來源風格、第一批素材與 AI 生圖方式仍待選定。
- 核對現況：玩家執行時已是 3D 世界中的 2D 分層 Sprite，已有測試身體、頭髮、武器及衣服／鐵劍換裝；現有圖層同步但順序固定，正式 2D 素材的多方向對齊與遮擋尚未驗證。原測試角色來自 Blender，渲染／打包已有證據，不代表正式角色的建模／綁骨／動畫已完成。
- 城鎮已有廣場、草地、樹石、村長、商店、三段任務及草原傳送；缺房屋、道路街景與完整城鎮構圖，既有路牌技術樣板未放入村莊。玩家目前以圓形障礙推開，建築遮擋、動線與相應碰撞仍需實作／驗證。多人、戰鬥寵 AI、iPhone／真人驗收仍維持既有延期或待驗狀態。
- 更新 README、[角色素材規劃](design/art-prompts/README.md)、[3D 備案](design/pipeline/3d-to-sprite.md)及 S22 planning dossier，避免把舊 3D 建模方案與未實作的依方向分層寫成現況。這次只有查閱與文件更新；未改程式、scene、圖或模型，也未重跑測試。工作區有本輪及既有未提交修改，未 commit／push。

## 2026-11-04｜本機 3D 素材索引

- 使用者提供 `D:\repo\godot\model-assets`，希望先分類建立索引，再優先從現有模型改造。素材庫保持原樣；共掃描 17 包，其中 11 包有 890 筆 3D 模型，同名 GLB／FBX／OBJ 合併。各包本機授權檔均標示 CC0。
- 已建立[圖像索引](../../docs/model-assets/index.html)、[TSV 清單](../../docs/model-assets/models.tsv)、[使用說明與城鎮候選](../../docs/model-assets/README.md)，可依名稱、分類、套件、城鎮候選、原始面數與異常篩選。`scripts/index_model_assets.py` 可重掃；分類依檔名初篩，模型原始 GLB 的 890 筆解析與相依檔檢查均為 0 個異常。這批 GLB 引用外部貼圖，使用時需一併複製並維持相對路徑。
- 代表候選：Mini Forest 木架 144／屋頂 324／柵欄 330 tris；Survival 路牌 28、木箱 124、木桶 412 tris；Retro Fantasy 門牆 36／屋頂 88 tris。Godot 4.7 `GLTFDocument` 另核對路牌 44、Mini Forest 屋頂 324、Retro Fantasy 門牆 36 tris，一致。這些均為未修改前的數字，不代表已通過倒角、碰撞、重面或手機畫面驗收。
- Windows Blender 5.1.2 可執行；已複製並修改 Survival Kit `signpost-single`：合併原本交疊的牌面與柱子、加倒角、內嵌原色票，得到 168 tris 的[獨立路牌技術樣板](design/pipeline/town-signpost-sample.md)。來源 `.blend`、GLB、可編輯 scene 與 Blender 預覽已保存，沒有修改素材庫或現有村莊。自動檢查與適用範圍見該文件；尚未在遊戲鏡頭或手機驗證閃爍、阻擋及風格。
- 索引生成器測試 `python3 -m unittest discover -s tests -p test_model_asset_index.py -v` 3/3 PASS；真瀏覽器開啟索引、中文搜尋／城鎮與面數篩選／縮圖及 390px 版面 PASS。Godot L1 `town_signpost_sample` PASS（`/tmp/godot-tests.LyPFWL`）；headless 匯入有既知沙箱 TCP 監聽錯誤，未見腳本解析錯誤。風格參考圖的生成方式仍待明確選擇；手機真人驗收、戰鬥寵 AI 與多人延期待辦不變。未 commit／push。

## 2026-11-04｜城鎮模型流程與免費素材調查

- 使用者希望繼續城鎮建模，提出先選風格參考圖、拆元素、建模、貼圖與搭景；指定複雜模型最多 8,000、普通 4,000、簡單 500，要求倒角，以及 AI 依需求做貼圖與自查穿模、重合面、閃爍。暫以渲染三角面統一計數，詳見[城鎮模型與場景製作流程](design/pipeline/town-modeling.md)。
- 已檢查現有村莊、42 度固定俯角、角色與圓形障礙機制；規劃先做一間普通小屋與一個簡單道具的遊戲內樣板，再擴建。撰寫兩套未定案的概念圖提示詞，已詢問使用者要直接生成兩張參考圖或取得 opt image 提示詞；尚未收到選擇，未生成圖片或模型。
- 查證 Kenney Fantasy Town、Nature、Retro Fantasy 的官方頁面為 3D／CC0；Fantasy Town ZIP 直接下載回傳 HTTP 403，未取得或檢查模型。Hunyuan3D 2.1 的硬體建議與涵蓋產出物的地域授權限制已附來源；未安裝或測試。WSL 的 GPU 查詢被系統阻擋，Windows 有 Blender 5.1 資料夾，本次未執行 Blender。
- 本輪只有規劃文件和 README／交接更新，未改遊戲程式、scene、正式素材或匯出；規劃層不跑遊戲測試。此前的 iPhone／瀏覽器驗收及戰鬥寵 AI／多人延期狀態不變。後續依使用者選擇準備風格圖，選定後才做代表性模型並實測；未 commit／push。

## 一句話現況

M0～M3 有桌面可玩的核心循環；城鎮已加入暖陶瓦商店、入口路與路牌樣板，正式 2D 紙娃娃角色及美術貼圖待製作。iPhone 17 實機驗收和真人平衡尚未完成。

## 怎麼驗證

```bash
env XDG_DATA_HOME=/tmp/seal-tests XDG_CONFIG_HOME=/tmp/seal-tests-config bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow
env XDG_DATA_HOME=/tmp/seal-bot godot --headless --path prototypes/seal-meadow --fixed-fps 60 -s res://tests/bot_m1.gd -- clear 5
env XDG_DATA_HOME=/tmp/seal-m3-hardening-test XDG_CONFIG_HOME=/tmp/seal-m3-hardening-config timeout 60 godot --headless --path prototypes/seal-meadow --script res://tests/test_m3_hardening.gd
env XDG_DATA_HOME=/tmp/seal-collection-tests XDG_CONFIG_HOME=/tmp/seal-collection-config timeout 50 godot --headless --path prototypes/seal-meadow --script res://tests/test_collection.gd
env XDG_DATA_HOME=/tmp/seal-fishing-tests XDG_CONFIG_HOME=/tmp/seal-fishing-config timeout 50 godot --headless --path prototypes/seal-meadow --script res://tests/test_fishing.gd
```

上一輪 7 組 suite 通過（2026-10-27，`/tmp/godot-tests.P3vyHO`）；m1 與 m1_loot 離開時各有 ObjectDB 清理警告。測試包含長按後走去撿物與傳送、重疊點選、反擊／移動、世界地圖、1,000 筆訊息上限及場景編輯後保留。五怪清群短測：普攻 18.0 秒、揮砍 11.1 秒，快 1.62 倍；20 秒 bot 的完成揮砍 2 次／嘗試 2 次。短測不是長時間穩定或平衡驗收。當時 Godot Web 橫向 Chromium 844×390 觸控開關地圖、0 console error／請求失敗；截圖 `/tmp/seal-web-map.png`、`/tmp/seal-web-closed.png`。當時匯出的 `build/web/` 與 `build/seal-meadow-web.zip` 沒有上傳；PCK 64.19 MB、WASM 39.5 MB、zip 約 16 MB，這是舊版。本機伺服器 `http://127.0.0.1:8794/` 是否仍存活需另外確認。

`godot-kit/sync.sh --check seal-meadow` 目前回報 drift；上游有較新的額外模組及 `scene_builder.gd`，本輪沒有同步或修改 kit 副本。第一次沙箱內網頁匯出及測試匯入曾有 Godot socket／editor settings 權限錯誤；之後用隔離設定目錄與授權的環境重新匯出及重跑測試，沒有上述錯誤。

## 還沒做

1. **真機（M0-05、M3-05）**：iPhone 17 Safari 的載入時間、FPS、10～30 分鐘發熱、切背景後回來。需要 HTTPS 網址：用 itch 草稿頁上傳前要先問使用者。模擬器的數字在 `production/qa/m0-baseline.md`。
2. **長時間穩定性**：修好訊息紀錄的洩漏之後，還沒重跑長時間測試。使用者要求不要再讓機器人跑 25 分鐘；如果要測，改用短的定點測試。
3. **平衡**：
   - 機器人從不撤退，6 分鐘死 4～5 次，Lv1 遇到 5 隻一群可能太危險，要靠真人試玩判斷。
   - 收入約 280～600 金／6 分鐘；全部買齊加精煉到 +6 約需 2400 金，大約 4～8 次 session。
   - 寵物進化大約要餵 25～40 次。
4. **M2-06 多人試驗**：依 D08 延後。多人相關系統保留為之後可加入的項目；S19、S33 已優先製作單機薄切片。
5. **紙娃娃量產**：每個裝備層在 256 px 下一張 2560×1280，約 4.2 MB（壓縮後）。如果要大量換裝，再考慮裁切每層的空白（D05）。
6. **其他原型的 godot-kit 副本是舊版**：這次只用 `sync.sh` 同步了 seal-meadow，其他原型要等使用者同意再同步。
7. 已修正 bot 的 `sweeps` 統計；若要重新做長期平衡比較，仍需固定 seed、場景與玩法政策，不能把本輪 20 秒短測當成完整證據。

8. 舊版通用 `Web` 匯出的 PCK 同時包含 S3TC／ETC2 貼圖；2026-10-31 的 `Mobile Web` 候選僅用 ETC2 且已建立 ZIP，但不包含本次城鎮樣板。載入與真機記憶體仍需實測，不得把舊版壓縮 zip 的 16 MB 誤認為實際 PCK 的下載大小。

## 注意事項

- **改 scene 的方式**：用 Godot 存檔（headless 腳本搭配 `PackedScene.pack`，或 kit 的 `SceneBuilder`）；只有單純的數值或節點列才直接改文字。
- **Blender 位置**：Windows 版 `"/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"`，路徑要先用 `wslpath -w` 轉換。
- **測試依賴的固定前提**：村莊與草原在同一個 scene，相距 300 m（`TerrainHeight.TOWN_CENTER`），Town 底下的節點要用 `global_position`。
- **生圖要先問**：AI 生圖前要先問使用者，是直接生成還是只給 prompt；程序化的 Blender 建模不需要問。
