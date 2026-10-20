# 第三輪窄範圍審查

結論：未發現 P0／P1；有 **2 項 P2**。四組既有測試全部通過。範圍僅限預熱、appear 淡入、拳影與大招橫幅呼叫，以及核對它們必需的相連實作；未修改程式、shader、scene 或測試。

以下路徑相對於 `prototypes/luffy-marineford/`。

## P0／P1

無。

## P2

### 1. 預熱的 pooled FX 要到遊戲恢復後才首次提交，樣本也沒有清掉

- **位置**：`scripts/main.gd:193`–207、`:593`–597、`:603`–609。
- **情境**：`_begin_warm_up` 的 spark／ring／flash／flame／dust 只加入 Fx 的存活陣列；必須由 `fx.step()` 填進 GlowPool，commit 才會提交實例。但預熱期間不呼叫 `_simulate`，因此也不呼叫該 step。退出時只還原 `_warm_shown`，沒有回收這五個 pooled 樣本。結果它們第一次出現是在正常模擬已恢復之後，而不是受保護的預熱階段。
- **實測**：在實際 main，以 1/60 s 手動逐幀執行；GPU 版每步另等真正的 frame_post_draw，結果一致：

  | 處理步 | 剩餘 warm frames | elapsed | Glow／Dust 提交數 | Fx.live |
  |---|---:|---:|---:|---:|
  | 1 | 2 | 0 | 0／0 | 5 |
  | 2 | 1 | 0 | 0／0 | 5 |
  | 3 | 0 | 0.016667 | 4／1 | 5 |

  當時 kills=0，也沒有正常攻擊，第三步的五個樣本全部來自預熱。第三次 `_process` 已先 `_end_warm_up`、開始解除壓暗，再跑模擬；並不是 README 所述完整三幀都不推進遊戲。這不會抹掉已測得的開局預熱效益，但不能據此宣稱 pooled FX 已在預熱遮罩內全部實際畫過。
- **建議**：保留「預熱不跑玩法」的條件；另外在預熱階段獨立填入／提交預熱 FX，讓樣本真正畫過，再回收這些樣本、還原幾何與解除遮罩，最後才恢復模擬。不要為了預熱而重新啟用整段 `_simulate`。

```text
現在：加入樣本 → 預熱期間沒有 FX 實例 → 解除遮罩＋恢復模擬
                                      └→ 首次畫出預熱樣本
建議：加入樣本 → 預熱階段實際提交／畫出 → 回收樣本 → 恢復遊戲
```

### 2. 預設拳影的拳端圓形與外框超過 quad，末端被截平

- **位置**：`shaders/fist_streak.gdshader:21`–24；尺寸來源 `scripts/fist_streak.gd:38`–40，呼叫 `scripts/main.gd:412`–413。
- **情境**：拳端中心固定在 UV.x=0.92；圓形半徑依世界寬高比換算。預設寬 0.42 m、目前第一級拳長 2.3 m 時，拳頭主體最右端為 `0.92 + 0.48×0.42/2.3 = 1.00765`，外框最右端為 `0.92 + 0.62×0.42/2.3 = 1.03322`，都超過 quad 的 UV.x=1。越短的拳影截得越多；main 的最短長度 1.5 m 時更明顯。
- **證據**：透過實際 `_on_struck(TAIJUTSU,...)` 呼叫，probe 確認 quad 沿攻擊方向從肩膀延伸到 2.3 m，沒有額外尾端 padding；上述超出範圍無幾何可承接。這是 shader 形狀與 quad 尺寸的確定裁切，不是透明排序問題。
- **建議**：依 `texels.y / texels.x` 計算拳端中心，讓外框與至少一個 texel 邊距完整落在格內；或將效果 quad 的視覺 padding 與實際攻擊 reach 分開。調整後保留肩膀起點及實際打擊端點的一致性。

## 四處核對結果

1. **預熱與模擬條件**：預熱尚未結束時確實不跑 `_simulate`，因此不會把期間新觸發的拳影／大招幾何在結尾吞掉。`_warm_shown`／`_warm_from` 有清空；原本隱藏的幾何會隱藏並還原 transform。待修的是上述 pooled 樣本與階段邊界，並非要求移除模擬保護。
2. **appear 淡入**：陣列有 resize、spawn 初始化、路線回收重設及 `_remove` 搬移。實際 custom data Z 依序驗到 `2.0`（appear=1）、`-1.5`（appear=0.5，鏡像）、搬移後 `-1.25`（appear=0.25）、回收後 `-2.0`，完成後回到 ±1。符號與 dissolve 共用方式符合 kit 解碼，沒有把鏡像翻錯，也未漏搬狀態。使用遊戲 dt，會跟 hit stop 一起慢下來，與現有模擬時鐘一致。
3. **拳影場景／池／呼叫**：保存 scene 含三個實際 MeshInstance3D；工具用 SceneBuilder 存檔且既有 scene 不覆蓋，未執行重建。每個 arm 有自己的材質副本；環狀索引與壽命收尾正常。實際 `_on_struck` 得到 2.3 m 的正確肩膀起點／攻擊方向，超過 life 後隱藏；即使 hits=0 仍顯示揮空拳影，符合該呼叫位置。透明材質不寫深度，priority=1，晚於深度描邊 -100；本輪桌面 Compatibility 沒有 shader 編譯錯誤。待修僅上述拳端裁切。
4. **大招橫幅**：`scripts/main.gd:467` 的參數與 HUD API 相符；呼叫仍位於正常大招路徑，沒有預熱時誤觸發。實際 `_fire_ultimate` 顯示「霸王色霸氣」，之後停止 main 模擬並設 Engine.time_scale=0，約 1.25 s 的真實時間動畫仍能完成／隱藏，沒有卡在 hit stop。此處未發現新增問題。

## 驗證與量測邊界

- 執行前確認沒有其他 Godot 程序；測試與 probe 均循序執行。
- 既有回歸：

  ```bash
  GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash prototypes/godot-kit/tools/run_tests.sh prototypes/luffy-marineford route banner sprites core:60
  ```

  **PASS route／PASS banner／PASS sprites／PASS core**。記錄：`/var/folders/y8/00ksqf0156n9lqddlq79vnlc0000gn/T/godot-tests.zSrkB3/`。

- 窄範圍探針：`/tmp/luffy-review-r3-probe.gd`，載入實際 main，測上列預熱提交、appear 搬移／回收、拳影及橫幅。headless 記錄 `/tmp/luffy-review-r3-probe.log`；另以真正 GPU 逐幀核對：

  ```bash
  /Applications/Godot.app/Contents/MacOS/Godot --path prototypes/luffy-marineford --rendering-method gl_compatibility --resolution 1280x720 --always-on-top --log-file /tmp/luffy-review-r3-gpu.log --script /tmp/luffy-review-r3-probe.gd -- --seed=3
  ```

  Apple M1 Pro／OpenGL 4.1 Metal；最終 GPU 探針正常退出，無 shader／GDScript 錯誤。初版 headless 探針立即 free 活動中的 main 時有兩個 ObjectDB 清理警告；改成 queue_free 並等待幀後，最終 GPU 驗證未再出現，未將暫存探針的收尾警告列為產品問題。

- 已讀 README「量測」：10 秒暖機、10 秒牆上時間採樣；群體受擊使用 `autoplay&ult-at=11&learn=chibaku`，要求出現 `ULT fired`，且 macOS 視窗置頂。這能避免只設滿 dominance 卻沒有實際施放的假測量。未在本輪重跑冷啟動 WebGL 的四次 A/B benchmark，因此不另背書其 p95／最慢幀數字，也不否定已有實測；手機仍未驗收。
- 本輪對列入審查的程式、shader、工具、拳影 scene 與 README 做前後 SHA-256 比對，全部一致（快照 `/tmp/luffy-review-r3-before.json`）。只新增本報告。
