# Claude 對 sprite3d 程式審查的處理

2026-10-20。7 點都對照程式確認成立，全部修正。

| # | 問題 | 修正 | 驗證 |
|---|---|---|---|
| 1 P1 | horde-25d `build_scenes.gd` 三處多一個 `{`，解析失敗 | 拿掉 | 兩個原型的產生器 `--check-only` 都沒有解析錯誤（沒有重跑產生器，免得覆寫 scene） |
| 2 P1 | `@tool` 在編輯器裡改共享材質、寫進存檔 | 編輯器裡腳本完全不改材質與節點；只有使用者在編輯器設 `sheet` 時寫入（製作動作）。執行時每個實例複製材質 | 測試：兩個 actor 共用同一個材質、不同 sheet，各自正確，原材質沒被改 |
| 3 P1 | 動畫只吃 Engine delta，跟不上遊戲層 hit stop／選卡暫停 | `auto_advance = false`＋`step(game_delta)` | 測試：自動模式關掉時不會自己走、`step(0)` 不動、`step(10/60)` 前進 10 tick 並重畫 |
| 4 P1 | 高度場的影子被共用的 `ground_y` 壓平；actor 沒複製影子材質 | 影子加 `ground_from_instance`（離地高度走 `INSTANCE_CUSTOM.x` 或 `air_height`）；actor 也複製影子材質 | 測試：影子材質被複製；平地模式公式和原版相同（兩原型錄影逐像素相同） |
| 5 P2 | 翻滾與受擊變形的先後被改了 | 拆出 `sprite3d_spin()`，主 shader 照原版順序（腳底／鏡像 → 彈跳與壓扁 → 翻滾）；x-ray、殘影不翻滾（和原版一樣） | 兩原型同 seed 錄影第 10、39 格與上一輪逐像素相同 |
| 6 P2 | 條狀圖尺寸除不盡格子時默默切掉像素 | 報錯 | `--self-test` 加 65×32、64×33 兩個必須失敗的案例 |
| 7 P2 | `finished()` 早一個 tick、和缺動作退路不一致 | `resolve()` 統一退路；`finished()` 要整段 tick 走完；沒有 `d` 時 `length_ticks` 和播放一致 | 測試：d=[3,3] 在 5 tick 未完成、6 tick 完成；缺的動作照退路判斷 |

Codex 提到的「1 方向也有遲滯」：保留這個行為（正對或背對鏡頭走時不會左右亂翻），skill 改成和程式一致。

其他驗證：kit 測試 PASSED；`sprite_atlas.py --self-test` OK；gallery 在 Compatibility 重新渲染正常；`sync.sh --check` 無漂移。

## 第二輪（Codex `codex-review-code-r2.md`：剩 1 項 P1）

**問題**：在編輯器裡替某個 actor 設 `sheet`，如果它和別的 actor 共用同一個材質，別的 actor 也會被改掉。原本的雙 actor 測試跑在執行模式，測不到這條路徑。

**修正**：在編輯器裡設 `sheet` 時，先把這個 actor 的材質（含影子）複製成它自己的一份，再寫入。

**驗證**：
- 照 Codex 的重現方式，在 kit 的副本專案裡用 `godot --headless --editor --script probe.gd` 跑：`editor_hint=true A=(8, 5) B=(4, 4) shared_untouched=true`。
- kit 測試通過，兩個原型的測試也都通過，`sync.sh --check` 沒有漂移。

兩輪審查已到上限，這一項修正和證據交給使用者判斷，沒有再送第三輪。
