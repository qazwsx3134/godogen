---
name: vat-crowd
description: 在 Godot 4 將同型 3D 群眾的待機、移動動畫烘焙為 VAT，以 MultiMesh 播放並保留各實例的位置、動畫相位與受擊閃光。
---

# VAT 群眾動畫

1. 用相同鏡頭、角色數、材質與陰影量測骨架版的 CPU／GPU 幀時間。先選一個有代表性的單表面機型，確認它的動作能用循環片段表達。
2. 在有 renderer 的獨立製作場景實例化原始骨架與 AnimationPlayer。呼叫 `await preload("res://addons/proto_kit/vat_crowd.gd").bake(player, mesh, [&"idle", &"run"], 24)`。函式會移動播放頭；空 Dictionary 表示輸入或取樣失敗。輸出兩張半精度浮點貼圖、各片段的起始列與幀數、涵蓋全部姿勢的局部 bounds。用 ResourceSaver 將貼圖存成 .res，另存片段資料與原動畫秒數。使用原地移動動畫，由遊戲推進世界位置。
3. 建立場景中的 MultiMeshInstance3D。MultiMesh 先設 TRANSFORM_3D、use_custom_data，再指定原網格與 instance_count。每個批次使用同一機型與動畫資料，跨區域時按區拆批。將網格 custom_aabb 設成烘焙 bounds；若另設整批 custom_aabb，要涵蓋所有實例位置。遊戲端保存位置、生命與碰撞，用 set_actor(batch, index, transform, clips[clip], phase, flash) 更新個體。每個實例只需要一筆資料。
4. 可直接使用 `res://addons/proto_kit/vat_crowd.gdshader` 並綁定裝甲與發光貼圖；有自訂效果時，在原材質的 spatial shader 引入下列片段，綁定 positions、normals。範例按待機、跑步各自的秒數設定速度；不同長度的片段可依起始列選擇對應週期。轉換 StandardMaterial3D 時保留其貼圖、UV、粗糙度與發光遮罩。

```glsl
#include "res://addons/proto_kit/vat_crowd.gdshaderinc"
uniform float idle_seconds = 1.0;
uniform float run_seconds = 1.0;
void vertex() {
    float duration = INSTANCE_CUSTOM.y == 0.0 ? idle_seconds : run_seconds;
    vat_pose(VERTEX_ID, INSTANCE_CUSTOM, TIME / max(duration, 0.001), VERTEX, NORMAL);
    vat_hit = INSTANCE_CUSTOM.w;
}
```

在原 fragment 的 EMISSION 上加上受擊色乘 vat_hit。沿用原網格頂點順序，停用會改變頂點對應的 LOD 或逐 LOD 烘焙。具切線空間 normal map 的模型需另烘焙切線與 handedness；本模組提供位置及法線。陰影 pass 必須執行同樣的 vertex 變形。

5. 對齊原骨架和 VAT 的相同時刻，檢查腳掌、循環接點、裝甲反光、發光標誌、落影與裁切。用兩隻錯開相位的角色，只對其中一隻施加閃光。最後以相同條件重測幀時間、draw calls 與貼圖記憶體，記錄硬體與敵人數。
