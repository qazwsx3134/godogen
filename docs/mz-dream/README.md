# 《夢靨植人》畫面研究與 Godot 對照

[研究進度與下一步](PROGRESS.md)

2026-11-26 研究原作公開 WebGL 客戶端。下列原作數值使用遊戲自己的世界單位。[原作](https://mz-dream.pages.dev/) · [對戰地圖入口](https://mz-dream.pages.dev/?lv=104&bmap=0)

## 鏡頭與人物

原作的 cameraMatrices 使用透視投影。預設垂直視野 24°、距離 11、俯角 28°，沿 Z 軸朝場景內看。窄視野讓近遠人物的尺寸差較小，地面仍有透視。updateCamera 讓目標點隨橫向速度預看 0.35 秒、縱向預看 0.25 秒，以 1 − exp(−3.5 × dt) 靠近目標。後處理把景深和多尺度泛光疊回畫面。可先關閉後處理校準構圖，再讓燈火發光，保留人物腳邊草葉的清晰度。

Godot 先建 Node3D 跟隨點，Camera3D 放在其局部 (0, 5.16, 9.71)，rotation_degrees.x 設為 −28，保持垂直 FOV 24°。距離 11 時，焦平面的可見高度約 4.68 個世界單位。若人物改成公尺比例，鏡頭距離也要等比例調整。角色用 CharacterBody3D 在 XZ 地面走，子節點 Sprite3D 對齊腳底，用 Nearest 取樣。各幀按自己的 pivot 切換，避免攻擊時因圖框變寬而位移。

## 樹、草和躲藏

| 畫面元素 | 原作做法 | Godot 場景做法 |
|---|---|---|
| 近景老樹 | giantTree 用逐漸變細的立體管段做彎幹、根和枝，枝端掛多張葉簇。葉簇先畫暗底再加左上亮面，樹根下補接觸陰影 | Tree.tscn 放樹幹 MeshInstance3D、數張交疊的葉簇 QuadMesh 和根部陰影。樹幹有碰撞，樹冠下留通道 |
| 針葉與遠樹 | conifer 用分層錐體，樹尖偏彎。drawTree 另有三種尺寸的整樹像素圖 | 近景保留針葉樹剪影和厚度；遠景可用整樹 Sprite3D |
| 草地 | buildGrass 在抖動格點放草簇，依邊界距離壓低草高，用連續雜訊決定高矮與偏色，另混入花穗 | 每塊草地一個 MultiMeshInstance3D，用世界座標雜訊控制整片密度與顏色。Shader 固定草根，只讓草尖隨風及角色接近而偏折 |
| 對戰讀圖 | 超高草可藏人；距離約 0.38 或剛攻擊的約 1 秒內會破壞這層掩護。另有樹冠覆蓋、高度、照明及視線判定 | 草地場景另放 Area3D，讓敵方索敵與角色顯示共用可見性判定。砍倒樹時同步撤掉樹冠遮蔽 |

## 下載的研究圖集

reference/ 內同時保存 PNG 和原作切框資料。CHAR_PACK、DRAGON_PACK 原是首頁內嵌 PNG，其餘圖片來自站上的 chars/、npc/、mobs/。此處作研究參考，未確認再發行授權。

| PNG | JSON 切框資料 |
|---|---|
| CHAR_PACK、DRAGON_PACK | 各自同名 |
| mz_newch、mz_folk | MZ_NEWCH_META、MZ_FOLK_META |
| mz_props | MZ_PROP_META |
| mz_mobs、mz_mobs2 | MZ_MOB_META、MZ_MOB_META2 |
| mz_giant、mz_critters | MZ_GIANT_META、MZ_CRIT_META |

例如夢燈有熄滅、點亮兩幀。MZ_PROP_META 的 mzp_dream_off 取矩形 (892, 0, 39, 110)，錨點 (19.5, 110)，每像素 0.002273 世界單位。Godot 用 AtlasTexture.region 裁切、Sprite3D.pixel_size 設比例；以 centered=false、offset 為負錨點擺放。點亮時換幀，另外只讓火焰部分發光。

先用一棵樹、一塊高草、一盞燈和兩名角色驗證。沿 Z 軸走過樹前與樹後，觀察腳底遮擋；再讓一人藏草、另一人從遠處走近，檢查玩家何時看得見對方，AI 是否同時能發現他。本文是實作設計，尚未建立 Godot 試作場景。
