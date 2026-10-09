# 美術進度（2026-10-09 10:10，暫停待續）

## 已定案（選中的圖一律是 `selected.png` 或 `master/`）
| 素材 | 檔案 | 備註 |
|---|---|---|
| 男主角 | `heroes/man/master-green/master.json`（來源 `man/edit-02.png`） | 綠幕 key（紅領帶偏洋紅） |
| 女主角 | `heroes/woman/master-green/master.json`（來源 `woman/edit-01.png`） | 綠幕 key；眼睛仍有虹膜，使用者選定照用 |
| 臭臭胖子 | `enemies/fatty/master/master.json`（來源 candidate-03） | 叼菸保留 |
| 機車 5 方向 | se：`vehicles/motorcycle/master/`（＝`selected-se.png`）；s／e／ne／n：`vehicles/motorcycle/dir-<方向>/selected.png` | s 01、e 02、ne 01、n 01；n／s 車身看起來比 se 小，接入時統一尺寸 |
| 汽車 5 方向 | se：`vehicles/car/master/`（＝`selected-se.png`）；s／e／ne／n：`vehicles/car/dir-<方向>/selected.png` | s 02、e 02（fix-e-02 的 take 2，看得到車頂）、ne 01、n 01 |
| 夜市風格基準 | `background/street_block/selected.png`（candidate-01，斜菱形鋪磚） | 只當風格參考；地圖用拼接素材 |
| 圖示 ×11 | `icons/<名稱>/selected.png` | 愛的小手 01、便當寶箱 02、金幣 01、鞭炮 01、寶石 02、香 01、天燈 02、珍珠 02、滷肉飯 01、藍白拖 01、吸塵器 edit-01（加粗版） |
| 地圖道具 ×8 | `map/props/<id>.png`（遊戲尺寸見 `ASSETS-REPORT-3.md`） | 攤位 ×2、燈籠柱、花台、三角錐、護柱、停放機車、水果箱；攤位比主角偏小，接入時可放大 |
| 地圖 Godot 匯出 | `map/godot/`（TileSet＋示範場景，Godot 4.7 匯入通過） | 地面重做後要重新匯出 |

`heroes/man/master/` 是沒用到的洋紅版，可刪。

## 下一步（使用者已同意，回家後再派 Codex）
1. **地面重做**（只做地面，道具保留）。問題：地磚只有 128×128、橘色反光條紋鋪滿、對比太高（敵人與煙霧會看不清）、重複一眼可見、斜菱形鋪磚看不出來、斑馬線糊。要求：
   - 無縫地磚 512 px 以上（遊戲尺寸），低對比、中性暖灰褐，斜菱形鋪磚在遊戲尺寸清楚可辨。
   - 反光從地磚拆出來，做成燈籠附近才放的疊加層（暖色光暈、濕地反光各一）。
   - 斑馬線重做成清楚的疊加層。
   - 重新匯出 Godot、出 3×3 與「地面＋道具＋主角」預覽；`--route codex-cli`。
2. **抽菸者改成台灣流氓**：虛構的成年男性，手臂刺青、抽菸，髮型照 `docs/reference/阿志.png`：兩側與後腦剃到見頭皮的高漸層（high skin fade），頭頂留短、剪成平頂的黑髮。**參考圖是真人照片：只借髮型，臉與身分要虛構，不畫成照片裡的人。** 其餘規格同其他敵人（mob、朝右下、50 度俯視、透明、pixel、`--style-ref` 男主角）。3 張候選。

## 玩法待辦（美術告一段落後改程式）
- 香的攻擊改成「戳人」（近身突刺），不再是原本的攻擊形態。
- 機車敵人的攻擊路線改成 S 型前進。
- 地圖改用拼接：地面 TileSet 無限重複＋道具散放；無限捲動或大型有限地圖待定，兩種都用同一套素材。

## 暫停中
- 動畫／影片：等靜態圖都定案再做（`heroes/MANUAL-VIDEO.md`、`heroes/man/set/` 保留可續用）。

## 紀錄
- 派工單與報告：第四輪 `BRIEF-assets.md` → `ASSETS-REPORT-1.md`、`-2.md`（圖示總覽 `icons/all-contact.png`）；第五輪 `BRIEF-assets-2.md` → `ASSETS-REPORT-3.md`。
- 第五輪汽車 e 方向第一次重做卡了 3 小時（codex exec 無回應），停掉後重跑一次成功；之後派工單可要求每筆生成設時限。
- 生圖一律 `--route codex-cli`：config 裡的 API key（Gemini、OpenAI 無效；xAI 沒額度；BytePlus、fal 無效）會讓預設路由失敗。BytePlus 有兩筆「送出結果不明」（clientRequestId `6f5394908dc249518ad1f0a9d1aae991` 等），可到後台確認有無扣款。
- Codex 在 Herdr pane `wT:pE`；多數指令要人工核准（建議在 Codex 用 `/approvals` 放寬）。
- 流程說明：skill `character-sprite-forge`（`prototypes/godot-kit/skills/character-sprite-forge/`）。
