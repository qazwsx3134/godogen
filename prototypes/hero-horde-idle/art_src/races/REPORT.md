# 精靈與獸人英雄圖回報（2026-10-29）

依 `docs/race-art-prompts.md` 生成，用人類英雄（hd2 站姿 → hd2b 動作）同一條流程做。產生器 `run_generation.py`，選圖紀錄 `selected.json`，遊戲尺寸對照 `lineup.py` → `lineup-40px.png`。

- 工具：本機 Codex CLI 登入額度（`master_still.py --route codex-cli`），沒有 API key、沒有費用。共 72 次生成、84 張，全部一次成功，沒有重試、逾時或額度問題。最慢的一張 122 秒，合計約 99 分鐘。
- 每個種族×職業 6 張：站姿 `ready/`（generate 2 張，以同職業的人類站姿當參考圖，由 Claude 挑一張）＋`run_a`、`run_b`、`strike`、`down`、`volley`（從選定的站姿 edit，動作描述照 hd2b 原文）。全部在 1024 畫布上，腳底對齊 y=926（與 hd2 相同），去背完成。
- 跟提示詞文件不同的地方：
  - 沒有生 9 格一列的 sheet 與 512×768 立繪。`tools/pack_stage_art.py` 的 `heroes()` 會用這 6 張組出 9 格，`portraits()` 用站姿做立繪，和人類一樣。
  - 鏡頭、比例照人類：約 45° 俯視、3.5 頭身。文件寫的是側視、3 頭身，照文件做會和人類站在同一群裡對不起來。
  - 布料維持淡色，沒用森林綠或土褐色。`army.gd tint()` 會把職業色疊在淡色衣服上，深色布會讓職業染色變濁。種族改靠耳朵、尾巴、髮色、葉紋與毛邊表現。
- 獸人的動物：盾＝熊、劍＝狼、槍＝狐、弓＝貓、法＝白狐、補＝貓。精靈的髮色：盾與法銀色，劍與弓淡金色，槍與補淡綠色。
- 去背：精靈用洋紅底，獸人用綠底。模型在精靈的倒地格與髮梢畫了不透明的洋紅「陰影」，一般去背清不掉，所以在去背、縮放之後各跑一次 `despill_magenta()`：連到外面的洋紅像素挖空，人物內部的轉成灰階。用色相差遮罩重掃（精靈 `r−g>50 且 b−g>50`，獸人 `g−r>50 且 g−b>50`），72 張合計剩 3 px（獸人 3 個單點，像素化後看不到）；沒有任何一張碰到畫布邊（`inputs/*-delivery-qc.json`）。
- 40 px 辨識度（`lineup-40px.png`，照 `pack_stage_art.heroes()` 縮到 40 px、32 色，再乘上 `army.gd` 的職業染色）：
  - 獸人**通過**：6 個職業的尾巴都看得出來，熊盾的圓尾最小。
  - 精靈**未通過**文件的驗收條件「縮到 48 px 時耳朵還看得出來」：染色把髮色差異壓平，尖耳只剩一兩個像素，看起來就是顏色比較淡的人類。修法：只重生 6 個精靈站姿，耳朵畫得更長更寬（橫向超出頭寬），再從新站姿重跑 30 張動作。約 36 次生成、1 小時左右，用的是 Codex 登入額度，不花錢。等作者決定。

| 種族_職業 | 選用站姿 |
|---|---|
| elf_shield / sword / spear | take 1 / 1 / 1 |
| elf_bow / mage / healer | take 2 / 1 / 2 |
| beast_shield / sword / spear / bow | take 1 / 1 / 1 / 1 |
| beast_mage / healer | take 2 / 1 |

下一步（Claude，要改遊戲程式）：`selected.json` 加入 `beast_*`、`elf_*`，`pack_stage_art.py` 多打包 12 列，`portraits.gd row_of`、`army.gd sheet_of` 改用種族列，`test_main` 的圖集列數檢查一起更新。
