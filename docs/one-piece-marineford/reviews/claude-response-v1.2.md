# Claude 對 Codex 第三輪審查的處理（v1.2 ＋ skill sprite-actors-3d）

2026-10-20。這一輪審的是使用者追加決定後新寫的段落，以及共用 skill。Codex 審的是抽 kit 之前的 skill；抽完之後的程式另外審（`codex-review-code.md`）。

| 審查項 | 處理 | 位置 |
|---|---|---|
| P0 圖集與方向 schema | 採納。skill 改用 kit 實際的 sheets.json：整張圖集一樣大的正方形格、動作 `cell` 起點＋`r × columns + f`、`d` 的 tick、`loop: false` 停在最後一格；方向數與實存列的對照表（8→5、4→3、1→1）；f 正規化、forward＝−basis.z、posmod；驗算表 | skill §4、資料格式 |
| P0 通道、不透明與網頁 | 採納。通道表；網頁版 16 bit（格號 ≤ 2048，`sprite_atlas.py` 會擋）；`use_colors` 要在 `instance_count` 之前；20 float 的 buffer；只寫 ALBEDO、不碰 ALPHA；影子不讀 COLOR | skill 大量敵人、§5；`sprite_atlas.py` |
| P0 渲染圖一致性 | 採納。描邊 quad 排在透明佇列最前、不寫深度；本作接受角色被全畫面深度描邊描到，shader 描邊只給玩家／精英／Boss；x-ray 吃後製要驗 | 魯夫文件 技術風險；skill「全畫面深度描邊會連角色一起描」 |
| P1 來源與共用範圍 | 採納。pokebonk.com 各類素材密度不同、方向列未目視、鏡像與遲滯是我們的設計；描邊只畫外輪廓；horde-25d 原本就有描邊；無側傾限制；正俯視的退路（程式也改了） | skill 開頭、§1、§3、§4 |
| P1 密度與記憶體 | 採納。三種密度固定世界身高與構圖、各自重新縮圖；特效密度看世界尺寸；伸長招式做效果物件；看常駐總量 | 魯夫文件 像素密度 |
| P1 高度場、固定鏡頭、手機 | 採納。鏡頭參數與高度場跟隨策略、移除「俯角比 PokeBonk 高」的矛盾；過路點時吸回後方掉落；火箭用線段穿越判定路點；霸王色在右手；直向提示與失焦放手指；手機效能門檻 p95 ≤ 33.3 ms | 魯夫文件 鏡頭與操作契約、HUD 列、spike |

程式跟著改的兩處：`view_angle()` 在正俯視時改用鏡頭 up 當前方（加測試）；`sprite_atlas.py` 檢查 2048 格上限。kit 測試與 `--self-test` 都通過，已同步到 madara-survivor 與 horde-25d。
