# sprite3d 程式審查：意見清單

2026-10-20，wJ:p13 Codex → wJ:pZ Claude。以本輪最新檔案為準，包含正俯視 fallback、2048 cells 限制及更新後 skill。以下依嚴重度排列；**尚不 ACK**。所有路徑相對 godogen 根目錄。未改 repo 檔案、未重跑會覆寫 scene 的產生器；驗證暫存資料與 gallery 僅在 /tmp，本報告為唯一交付修改。

## 1. [P1] horde-25d 場景產生器有語法錯誤，無法重建

位置：`prototypes/horde-25d/tools/build_scenes.gd:26`（相同錯誤另在28、30行）。

第三個參數前保留了多餘的 `{`，裡面再呼叫 `_with(...)`，但沒有對應的字典關閉；Godot 實際解析失敗。重現：

```text
env XDG_DATA_HOME=/tmp/sprite3d-review-data godot --headless \
  --path prototypes/horde-25d --check-only \
  --script res://tools/build_scenes.gd
→ Parse Error: Closing ")" doesn't match the opening "(".
→ res://tools/build_scenes.gd:27
→ exit 1
```

建議移除這三處多餘的字典起始符號，直接傳 `_with(...)` 的 Dictionary 結果；先做 check-only，再由擁有者在可控副本／製作流程重建並審 diff。兩個現存 scene 的 core 測試通過不會發現工具腳本語法錯誤，不能因此宣稱產生器也驗過。

## 2. [P1] @tool 預覽修改共享材質，可讓不同 actor 串用錯誤圖集，並將預覽參數寫進存檔

位置：`prototypes/godot-kit/addons/proto_kit/sprite3d_actor.gd:49`、`:97`、`:105`、`:109`。

只有非 editor 的 `_ready()` 才 duplicate 材質；editor 中 `_apply_sheet()` 仍直接對原始 `material_override` 設 atlas／frames／foot_gutter，`_draw_frame()` 也直接寫 frame／facing。把同一 actor scene 放兩份、共享同一 ShaderMaterial、兩份指定不同 sheet 時，後套 sheet 的實例會修改前一份看到的 atlas/grid；材質與 child.scale 都是可序列化屬性，使用者儲存 scene／resource 時會保存這些預覽改值。這違反「scene 的材質留作共享來源」的註解，也不能滿足 editor 調整不被執行或預覽污染的規則。另 @tool 只有 sheet setter 更新，編輯器改 anim 不會重算預覽，因 `_process()` 在 editor 直接 return。

建議 editor 與 runtime 都有明確的每實例材質隔離，預覽狀態與可儲存來源分開；不要在 editor 直接改外部共享 ShaderMaterial。尺寸若由sheet派生，應明訂由誰保存／何時更新，保留 size_from_sheet=false 的手動調整。驗證兩份不同 sheet 的實例同時顯示正確、切換／重開 scene 不串圖，且存檔 diff 沒有不相干 frame／材質／scale 變更；補 anim 或 Resource changed 的預覽更新。此項是由程式路徑可確定的共享資源修改；本輪未操作互動式 editor，沒有宣稱已測到每次開檔 UI 都顯示 dirty。

## 3. [P1] actor 動畫使用引擎 delta，無法跟隨本專案的遊戲層 hit-stop／選卡暫停

位置：`prototypes/godot-kit/addons/proto_kit/sprite3d_actor.gd:58`；對照 `prototypes/madara-survivor/scripts/main.gd:161`、`:204` 與 skill `sprite-actors-3d/SKILL.md:170`。

actor 自己在 `_process(delta)` 增加 `ticks += delta*60`，只跟隨 Engine.time_scale 與 SceneTree 暫停，沒有手動 game-dt 入口。兩個原型／新案採的是主邏輯自己的 dt：選卡使 dt=0、hit-stop 使 dt變小，Engine.time_scale 不動。因此把新 actor 接進這條更新鏈後，世界停止時角色動畫仍繼續，攻擊／受擊／死亡格和傷害時序分離；目前兩個原型沿用舊 player 腳本，core PASS 尚未涵蓋這個新 actor 的整合情境。

建議新增明確的 `step(game_dt)` 與 automatic/manual 更新模式，手動模式停用自身 `_process`；本案由主模擬傳 dt。驗證 game_dt=0 時 ticks／finished 不變、hit-stop按比例推進、恢復後不補跑牆上時間；保留其他遊戲採 Engine 時鐘的選項。不能只修改註解稱它是遊戲時間。

## 4. [P1] 高度場影子的建議接法在 shader 中仍被強制壓到同一個 ground_y

位置：`prototypes/godot-kit/addons/proto_kit/sprite3d_shadow.gdshader:22`、`:23`；對照最新 skill `sprite-actors-3d/SKILL.md:121`。

skill 建議高度場用獨立 shadow MultiMesh，每個 instance 放到自己的地面高度。但 shader 隨即用**全批共用** uniform `ground_y` 覆寫 `MODEL_MATRIX[3].y`，而且先將原 instance.y−ground_y 當飛行高度。例：地面高10m的shadow instance、ground_y預設0，實際影子被畫到0.03m，shrink又變1/(1+10*.35)=0.222；它不會留在10m台地。獨立批次因此仍無法解決，除非每個高度分一批／另傳逐實例ground_y。對少量actor也有隔離問題：`sprite3d_actor.gd:116` 的 `_parts()` 不含 Shadow，runtime duplicate不會複製影子材質；兩個高度不同的actor若共用shadow material，各設ground_y會互相改到。

建議讓「獨立地面批次」模式直接保留instance地面y、以額外資料傳air_height或不縮小；「本體共用buffer的平地」模式保留目前uniform。少量actor有地面高度時也要隔離影子材質。新增同批兩個不同地面高度、其中一個飛起的測試；不能僅在原有y=0灰盒中驗證。

## 5. [P2] 抽取改變了既有 madara 翻滾時的受擊變形次序

位置：`prototypes/godot-kit/addons/proto_kit/sprite3d.gdshader:95`、`:98`；`sprite3d.gdshaderinc:31`。原始對照：`git show HEAD:prototypes/madara-survivor/shaders/sprite_billboard.gdshader` 的55–66行。

舊 shader 先腳底／鏡像、再bob/squash、最後繞身體中點spin；新shader在 `sprite3d_local()` 已spin完，才在主shader做bob/squash。旋轉與非均勻縮放不交換，故被打飛且flash／bob仍有效的敵人形狀和位置會改變。用同一vertex(.5,1)、foot_gutter=.047、spin90°、flash1、hit_squash.6、bob0演算：舊local=(-.28146,1.105)，新local=(-.54813,.82)，差異遠超浮點誤差。選定第10／39影格相同不足以排除此狀態。

建議將spin抽成單獨helper，在主shader保留原次序，xray／ghost再按各自需求呼叫；或將此改變明確列作有意的外觀調整並提供受擊翻滾對照驗收，不能稱完整保留原效果。補測非零spin×flash／bob組合；xray新增spin也要用自身未遮擋的負例檢查，現gallery沒有xray節點。

## 6. [P2] atlas strip 尺寸不能整除 frame 時會默默丟棄不透明像素

位置：`prototypes/godot-kit/tools/sprite_atlas.py:79`、`:80`、`:81`。

以整除取得橫縱格數後只crop完整格，沒有驗 `strip.width % fw`／`strip.height % fh`。本輪用記憶體fixture、不寫輸入檔，傳65×32全不透明strip、fw=fh=32、d=[1,1]，`load_frames(...,rows=1)` 正常回兩格，第65欄不透明像素直接消失且無AtlasError；縱向餘數同樣會掉。這繞過目前「超出格子報錯、不要偷偷切掉素材」的保證，使用者填錯切格尺寸時會得到貌似成功但缺像素的圖集。

建議先驗fw/fh為正整數、strip寬高能整除，再crop；若打算容忍外圍padding，需明確欄位並驗餘區確實透明。新增橫／縱各多一欄不透明pixel必須失敗的self-test，保留合法canvas透明邊可超出cell而不被誤殺的行為。

## 7. [P2] one-shot 的 finished() 提早一個 tick，且與缺動畫 fallback 的實際播放不一致

位置：`prototypes/godot-kit/addons/proto_kit/sprite3d_actor.gd:74`、`:78`；`sprite3d_sheet.gd:83`、`:129`。

non-loop d=[3,3] 的總長6 ticks，`finished()` 在ticks=5已回true；若呼叫端以finished切回idle，最後一格僅完成2/3停留時間。只有一格d=[1]更在ticks=0就finished，尚未經過它的一個tick。另外cell()會把不存在的anim退回walk／第一動作，但finished()直接對原anim `_anim()`，找不到就回true，與畫面仍在fallback播放不同；d為空時frame_index支援n作fallback，length_ticks卻回0，也會立即結束。

建議統一「解析實際動作」入口，finished代表完整duration走完時用 `ticks >= total_ticks`；若需求其實是「已進最後一格」則另命名API，不能拿來作播放完成。length_ticks與frame_index對缺d的政策一致；補ticks=0／N−1／N、長尾格與缺動作fallback測試。

## 驗證與未列作缺陷的事項

- `env XDG_DATA_HOME=/tmp/sprite3d-review-data godot --headless --path prototypes/godot-kit --script res://tests/test_proto_kit.gd` → **PROTO KIT TESTS PASSED**。測試內故意產生的壞scene／missing resource錯誤符合既有負例，不列新回歸。
- 同樣隔離user-data、`--fixed-fps 60` 分別執行 madara-survivor／horde-25d `tests/test_core.gd` → **CORE TESTS PASSED**；madara另外印12個ObjectDB leak警告，本輪沒有證據可歸因此diff，不列新缺陷。
- 用既有uv快取中的Python3.13／Pillow載入最新sprite_atlas.py執行self_test → **sprite_atlas self-test OK**；另外以in-memory strip重現第6項。沒有下載依賴。
- `sync.sh --check madara-survivor horde-25d`、限定三個專案的 `git diff --check` → exit0。同步符合kit副本流程；未重建可維護scene以免覆寫人工修改。
- Compatibility gallery在Xvfb實際渲染成功，檢視 `/tmp/sprite3d-code-review-gallery.png` 可見三角度8方向／鏡像、各身分輪廓、閃白、溶解與翻滾。環境為桌機OpenGL4.5、Mesa llvmpipe，**不是手機WebGL／GLSL ES3.0驗收**；本輪沒有Mobile相等或手機效能的新證據。sampler作函式參數、三元與int陣列在這次GL渲染沒有編譯失敗，故不憑猜測另報相容性bug。
- 最新 `view_angle()` 的正俯視camera-up fallback已存在，且kit測試通過；正常無roll的相機方向、4／8方向鏡像、環形遲滯沒有發現需要另報的錯誤。1方向mirror實作有雙向遲滯，較skill「1方向不用」不同但不構成轉向崩壞，應由擁有者統一規格。
- `MAX_CELLS=2048` 及build時的總grid cells檢查已存在，並限制在索引0–2047，這輪不再報缺上限。COLOR身分以1−role/8編碼、round解碼，0–7留有足夠間距；即使8bit alpha量化，最大誤差乘8也遠小於半級，不會單因量化變成別的身分。實際gallery亦畫出各色。custom.z=0時sign=0、dissolve=0，而local只在face<0翻轉，因此是正向未溶解，不會把角色壓成零寬。
