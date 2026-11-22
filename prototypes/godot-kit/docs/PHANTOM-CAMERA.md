# Phantom Camera

新場景需要 2D／3D 跟隨、死區、平滑移動、群組取景或分鏡切換時，優先評估 Phantom Camera。虛擬鏡頭保存取景設定，Host 將當前鏡頭套到 Godot 的實體 Camera。〔[官方節點與運作方式](https://phantom-camera.dev/overview/what-is-this)〕

## 安裝到原型

從 `prototypes/godot-kit/` 執行以下命令。

```bash
./sync.sh --addon phantom-camera <原型名稱>
./sync.sh --check --addon phantom-camera <原型名稱>
```

等 Godot 完成資源匯入，再在目標專案的 Project Settings → Plugins 啟用 **Phantom Camera**。啟用後在 Globals → Autoload 確認 `PhantomCameraManager`。第一次接入可開啟 `res://addons/phantom_camera/examples/example_scenes/` 中的 2D 或 3D 範例。〔[官方安裝與範例](https://phantom-camera.dev/overview/installation)〕

## 接到場景

1. 在現有 `Camera2D` 或 `Camera3D` 下加入 `PhantomCameraHost`。
2. 依場景維度新增一個以上的 `PhantomCamera2D` 或 `PhantomCamera3D`。玩家跟隨可以從 Simple Follow 開始，指定場景中的 Follow Target。需要死區時改用 Framed Follow。
3. 設玩家鏡頭優先級為 10。劇情鏡頭平時可設 0，進場時設 20，退出時還原。用虛擬鏡頭的 Tween Resource 決定轉場時間與曲線。〔[官方優先級](https://phantom-camera.dev/priority)〕

移植既有場景時，讓 Host 成為實體 Camera 基礎位置與旋轉的寫入者。把跟隨與取景參數搬到虛擬鏡頭，並在 2D／3D 場景實際確認邊界、切換時機與轉場。由 v0.11 升至 v0.12 時，檢查舊場景的死區寬高，因新版型別改為 `Vector2`。〔[v0.12 變更紀錄](https://github.com/ramokz/phantom-camera/releases/tag/v0.12)〕

## 上游版本

Godot Asset Store 官方 **v0.12** ZIP，最低 Godot 4.4。原始檔和範例存於 `third_party/phantom-camera/`，附 [MIT 授權](../third_party/phantom-camera/LICENSE)。〔[Asset Store](https://store.godotengine.org/asset/ramokz/phantom-camera/)〕
