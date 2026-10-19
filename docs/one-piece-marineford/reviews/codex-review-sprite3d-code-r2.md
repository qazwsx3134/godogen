# 程式審查第二輪：剩餘意見

2026-10-20。已讀實際 diff、最新檔案與 `docs/one-piece-marineford/reviews/claude-response-sprite3d-code.md`。剩餘 1 項，尚不 ACK。

## [P1] editor 設定 sheet 仍會修改共享材質，另一個 actor 的圖集隨之被改

位置：`prototypes/godot-kit/addons/proto_kit/sprite3d_actor.gd:28`、`:58`、`:119`。

`_ready()` 在 editor 直接 return，確實修掉「開啟 scene 自動改寫」的路徑；但 editor 中替某個 actor 指定 sheet，setter 仍直接呼叫 `_apply_sheet()`，它在沒有隔離材質的情況下執行 `sheet.apply(node.material_override)`。兩個實例共用材質時，設定 B 的 sheet 會連 A 的 atlas／frames／foot_gutter 一起改掉；這不是單純允許製作動作保存參數，而是一次編輯污染另一個實例的外觀。若共享的是外部 `.tres`，其他引用者也會受到影響。新增的雙 actor 測試跑在 runtime，不能證明 editor 路徑已修正。

已在 /tmp 的隔離 project 複製最新模組，以 `godot --headless --editor --script res://probe.gd` 重現；未修改來源 repo。測試建立兩個 actor，Sprite 指向同一個 ShaderMaterial，進樹後依序設定 A 的 sheet=8×5、B 的 sheet=4×4。關鍵輸出：

```text
editor_hint=true
after_A=(8.0, 5.0)
after_B_A=(4.0, 4.0)
after_B_B=(4.0, 4.0)
shared_preserved=false
```

預期 B 改完後 A 仍為8×5、B為4×4，原始共享材質未被改寫。建議在 editor 的「設定 sheet」製作動作套參數前，將需寫入的材質變成本實例獨有、可保存的子資源；或讓 setter 完全不修改材質，改用明確的製作工具／按鈕完成獨立材質與套表。補 editor-hint 情境的共享資源負例，並確認保存／重開後兩份外觀仍正確。單靠將這條路徑稱為製作動作，無法隔離共享資源。

## 本輪重跑

- 兩個原型的 `tools/build_scenes.gd`：Godot `--headless --check-only` 均 exit0；未執行產生器覆寫 scene。
- kit `tests/test_proto_kit.gd`：`PROTO KIT TESTS PASSED`；包含手動時鐘、完整 one-shot duration／fallback、runtime 材質與影子隔離測試。
- madara-survivor、horde-25d 的 `tests/test_core.gd`（fixed-fps60）：均 `CORE TESTS PASSED`。madara另有ObjectDB退出警告，未據此認定本輪新缺陷。
- 最新 `sprite_atlas.py --self-test`：OK，包含65×32及64×33 strip的拒絕案例。
- `sync.sh --check madara-survivor horde-25d`、限定三專案的 `git diff --check`：exit0。
- 最新 Compatibility gallery在Xvfb／Mesa llvmpipe成功渲染並檢視，方向／鏡像、身分描邊、閃白、溶解與翻滾正常；圖片在 `/tmp/sprite3d-code-review-r2-gallery.png`。這是桌機GL驗證，未外推手機WebGL。

其餘原審查第1、3–7項的修正與程式一致；本輪沒有新增其他剩餘意見。高度場shadow已分離instance地面高度與air_height；主shader已恢復先bob/squash後spin；strip整除驗證與動畫duration/fallback亦已補齊。
