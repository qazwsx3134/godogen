# 軌道連珠 Pachinko — TODO

可執行清單。策略視角與出場條件見 [ROADMAP.md](ROADMAP.md)，規格數字一律以
[README.md](README.md) 為準（`scripts/spec.gd` 是它的可執行副本）。

## 現在的狀態

**整台機器會動**：盤面物理已校準、狀態機與終局結算完成、`sim.gd` 全綠、Web 匯出跑在
iPhone 上、效能確定不是問題。**缺的是演出**——SP 的接管中段被推翻，要重做運動模型。

| 檔案 | 做什麼 |
| --- | --- |
| `scripts/spec.gd` | 規格常數與導出量（互斥路徑權重、SP 出現率由大當率導出） |
| `scripts/machine.gd` | 狀態機。沒有畫面也沒有物理 |
| `scripts/playfield.gd` | 盤面物理。只負責始動口入賞率一個數字 |
| `scripts/sequence.gd` | 路徑 → 拍點的純函式。只有時序沒有畫面 |
| `scripts/presentation.gd` | 軌道連珠的畫面。位置都是時間的純函式 |
| `scripts/blackhole_shader.gd` | 黑洞的兩種畫法（讀螢幕／純程序生成） |
| `scripts/game.gd` | 把盤面＋狀態機＋演出＋HUD 組起來 |
| `scripts/show.gd` | 四條路徑的可重播序列測試台 |
| `scripts/probe.gd` | 裝置探測：音訊 gesture 解鎖、斜坡時序、觸控 A/B |
| `scripts/stress.gd` | 效能壓力測試：冷啟動 vs 穩態，三個成本類別 |
| `scripts/tones.gd` | 程序合成音（帶斜坡，才測得到 Web 的 Sample 限制） |
| `sim.gd` | 模擬安全網：純 RNG 類＋場次類 |
| `tools/measure_start_rate.gd` | 物理類量測：真的射球量入賞率 |
| `tools/measure_nail_spread.gd` | 釘調整的 20 台分布量測 |
| `tools/test_sequence.gd` | 演出時序的 38 條斷言 |
| `tools/serve.sh` / `capture.sh` / `Caddyfile` | 匯出＋LAN HTTPS server／影格擷取 |

---

## 下一步（建議順序）

1. **重做接管中段的運動模型**（M1 留下的債，M3 的第一件事）。
2. **回報實機的音訊與觸控判讀**——M1 僅剩的三個未結出場條件，只有人能判。
3. 確變的專屬視覺與連莊累積回饋。

---

## 已完成

### 專案骨架

- [x] `project.godot`：Compatibility renderer、1080×1920 直式、2D 重力 1400、物理 120 Hz
- [x] 極小的 `main.tscn`（單一 root＋script），其餘場景樹在執行期用 GDScript 組
      → 完全繞過 `.tscn` 序列化陷阱（owner chain、靜默掉節點）
- [x] 選單（手機上沒有命令列）＋每個模式的 BACK
- [x] `--mode=` / `--path=` / `--auto` / `--design` 命令列參數
- [x] 建置關卡：`--headless --import` 與 `--headless --quit` 都乾淨
- [x] Web 匯出模板（`web_nothreads_*.zip`，4.7.stable）已安裝

### 裝置往返與效能

- [x] `probe.gd`：音訊時間軸（機械聲 → 2.0 秒上升斜坡 → 0.5 秒靜默 → 爆），
      畫面上顯示排定時間與實際漂移
- [x] `tones.gd`：程序合成音。**帶 pitch／音量斜坡**——Web 的 Sample 播放模式限制的是
      執行期參數控制，單發短音會通過，斜坡才會暴露問題
- [x] 發射 A/B：按住連發 vs 點一下開始／再點停止
- [x] Web 匯出（Compatibility／thread support off／無 VRAM 壓縮）＋防長按的 CSS
- [x] `tools/serve.sh`：Caddy 的 `tls internal` 簽帶 IP SAN 的憑證，不裝進系統鑰匙圈
- [x] `stress.gd`：三個**成本類別**（讀 backbuffer／全螢幕程序生成／局部程序生成），
      分 COLD 與 STEADY 兩個窗量

**實機結果（iPhone Safari）**：穩態下三個變體都 **60/60/60**，80 顆球也一樣。
效能不是問題，[ADR 0010](docs/adr/0010-reconsidering-ios-native.md) 因此裁定留在 Web。

### 數字與狀態機

- [x] `machine.gd`：通常／確變／大當中／結束、保留上限 4、持ち玉 收支、確變ループ、
      振り分け、**終局結算**（[ADR 0007](docs/adr/0007-zero-balls-settles-the-queue.md)）
- [x] `playfield.gd`：左打／右打兩條路線、始動口、電チュー、大入賞口、卡球回收
- [x] `game.gd`：HUD（持ち玉／狀態／轉數／保留＋滿的警示／連莊與累計出玉／回轉率按鈕／
      右打提示）
- [x] `sim.gd` 純 RNG 類（10⁶）十項全過
- [x] `sim.gd` 場次類（600 場）全過：期望 472 轉、中位數 369、保留溢出 4.5%、
      結束原因全數為持ち玉歸零、P(≥3 SP) = 0.83
- [x] **釘子校準**：左打 12.31 発/轉（CI [11.66, 13.04]，目標 12）、右打 3.58（目標 4）
- [x] **釘調整**（[ADR 0006](docs/adr/0006-nails-are-reset-each-session.md)）：一場一台，
      抽常態分布的誘導釘開口；`--design` 驗收組態鎖定固定標準台
- [x] `tools/measure_nail_spread.gd`：20 台 × 5000 顆實跑。最甘 9.80、中位 12.14、
      平均 12.04、最辛 14.04 → SP 3.4 次。全部落在 9.5–16.5、無離群

### 演出（非 SP 的部分）

- [x] `sequence.gd`：四條通常路徑＋兩條確變路徑展開成拍點
- [x] SP 的 18.0 拆成 變動 3.0 ＋ リーチ 2.0 ＋ 接管 11.0 ＋ 靜默 0.5 ＋ **決著 1.5**
- [x] 升級窗口 1.5 秒，三條路徑同時開（否則玩家能從開窗時間預判結果）
- [x] `tools/test_sequence.gd`：**38 條斷言全過**
- [x] 鎖定態、目標位幽靈標記、吸附引力線、擦過後崩解、三星連珠
- [x] 接管越界：整個軌道系統跟著放大 2.1 倍衝出液晶框
- [x] `show.gd`：四條路徑可重播＋開場 2.5 秒暖機

---

## 未完成

### 演出重做（M3 的第一件事）

- [ ] **接管中段的運動模型**。現在是 `sin()` 疊 drift 的動畫曲線；要改成有速度的積分，
      讓吸附是真的減速、遠離是真的加速。這是被推翻的那一段
- [ ] 載入時預熱 SP 的 shader（實機編譯 68 ms 是會被感覺到的一次性 stall）
- [ ] 確變高速變動的畫面（現在只有時序，沒有專屬視覺）
- [ ] 連莊累積回饋：每多一次連莊，軌道多一圈環、BGM 多一層泛音
- [ ] 完整混音：通常時只有機械聲，リーチ 進來聲音才長出來
- [ ] 依秒節奏表調校，驗通常與確變的保留溢出率都 < 3%
- [ ] 真正的接管做完之後重跑壓力測試（現在量的只有黑洞，還沒有三天體、粒子與音訊）

### 待人判讀（模擬腳本判不了）

- [ ] 音訊 gesture 解鎖：點畫面前不該有聲音
- [ ] Sample 播放模式時序：第 2 步要**連續**爬升不是跳階，第 3 步要真的安靜
- [ ] 發射操作 A/B 定案，寫回 README
- [ ] 機台手感：發射節奏、保留、右打切換、連莊 HUD

### 交付（M4）

- [ ] 評估開 thread support（要 COOP/COEP header）
- [ ] itch.io 上架

---

## 實機那一趟的補救清單

只跑一趟手機的話，帶著這些去才不會空手回來。

| 症狀 | 動哪裡 |
| --- | --- |
| 斜坡變成跳階或一路平 | `project.godot` 加 `audio/general/default_playback_type.web=0`（Stream，預設 1＝Sample）。犧牲延遲換回執行期參數控制 |
| 按住連發跳出選取泡泡／手感黏滯 | 不是 GDScript 的問題。`export_presets.cfg` 的 `html/head_include`（`touch-action:none` 已經塞了） |
| 橫著拿時嚴重 letterbox | 不是版面壞掉。`progressive_web_app/enabled=false`，web 上沒有橫向鎖定 |

---

## 踩過的坑

留著是因為它們都不是「調參數」能發現的，而且大多只有真的跑一次才會出現。

### 環境與工具鏈

- **匯出失敗但只說 "configuration errors"**：preset 開著
  `vram_texture_compression/for_mobile=true`，那要求專案啟用 ETC2/ASTC 匯入。
  零貼圖根本不需要，關掉即可。
- **`secure context` 載入失敗**：Godot Web 需要 secure context，而那**不是** COOP/COEP
  的問題——關掉 thread support 免掉的是後者，前者照樣要。`https://` 或 `localhost`
  才算，手機走 LAN IP 兩者皆非。
- **`--headless` 加 `--write-movie` 在 macOS 會 crash**（MoltenVK 的 SPIRV 轉換炸掉）。
  擷取一定要有視窗，會搶 focus 幾秒。
- **畫面文字一律 ASCII**：Godot Web 拿不到系統字型，內嵌一套 CJK 要好幾 MB，
  而效能預算是設計約束（[ADR 0004](docs/adr/0004-web-only-delivery.md)）。
  M3 的 HUD 若需要中文，要用子集化字型，不是整套內嵌。
- **選單被切掉**：`CanvasLayer` 裡的 `Control` 在 stretch 之後量到的是視窗像素，
  而 `_draw()` 量到的是 viewport。混用兩套座標空間，桌機看不出來，手機上差很多。

### 量測方法

- **第一輪效能數字是冷啟動不是穩態**。球數翻倍反而全部變成滿幀，因為 shader 程式快取、
  Safari 的 WASM tier-up、iPhone 的時脈爬升都要數秒，而暖機只給了 0.8 秒。
  現在分 COLD／STEADY 兩個窗——**兩個都有意義，玩家拿到的是冷的那條路徑**。
- **capture 畫面上的 FPS 讀數是垃圾**：`--write-movie` 每格要編碼 PNG（約 10 ms），
  那是 wall-clock 幀率，和 `--fixed-fps` 的邏輯時間無關。已在畫面上標示。

### 盤面物理

- **打出軌道在左下角**。第一版放右下角，球落在 x 693–816 而始動口在 540，
  **1500 顆零入賞**。真機的拓樸是左側打上去、繞過頂部再落下：左打落中央、
  右打才到右側路線。
- **入賞率的旋鈕是誘導釘 V 底的開口，不是釘子密度**。靠釘子自然收束量到 30–55 発/轉
  而且抖得厲害；真機也是用導引結構，不是靠運氣。
- **誘導牆的寬度是懸崖不是旋鈕**（260 給 17.4 発/轉，275 給 5.8）。它只負責
  「確實接得到球」，校準交給平滑的那個參數。整個範圍只要 ±6% 的開口變動。
- **左右臂要不對稱**：右臂得夾在右側路線分界內，否則會把右打的球一起接走；
  對稱地一起夾會把左臂也砍半，入賞率從 12 掉到 44。
- **卡在角落的球要回收**，否則終局結算永遠等不到盤面清空，校準量測也會卡住。

### 球數經濟（兩個 bug 都不是機率算錯，是順序錯）

- **大當中還在給始動口賞球**，但那時候球打的是大入賞口，出玉由腳本化的 payout 給
  ——重複計算。
- **`rate` 在 `advance()` 之前算、賞球在之後給**，狀態會在半路翻掉（大當結束、
  確變→通常），變成用右打的 4 顆球換到一次通常抽選。該花 12 顆的只花 4 顆，
  單場轉數從 480 暴增到 1238。
- **最後幾顆球不能保證換到入賞**。原本 `maxi(bank, 1)` 讓 1 顆球也能換到 3 顆賞球，
  bank 越打越多，場次永遠打不完。改成幾何分布抽樣：打不滿就什麼都沒買到。

### 演出

- **崩解和最後的逼近同時發生**，變成先崩再擦。README 要的是擦過之後才崩，
  否則玩家看不到「差了多少」——而那是落空唯一要傳達的東西。
- **`MISS_MARGIN` 0.46 rad 讀起來是「差很多」**。調到 0.22（外圈上約一個天體的寬度）
  才有「只差那麼一點」的懊惱。
- **接管第一版只有背景擴張**，軌道留在原地被吞進事件視界，完全看不到「扭曲軌道」。
  越界的必須是**演出本身**。
- **`z_index` 沒設對**，接管被載具那張不透明的液晶底色整個蓋掉。
- **`sin()` 疊 drift 不是軌道運動**。天體沒有速度這個量，所以沒有近日點加速、
  沒有遠日點拖慢，看起來就是被瞬移——這就是接管中段被推翻的原因。
