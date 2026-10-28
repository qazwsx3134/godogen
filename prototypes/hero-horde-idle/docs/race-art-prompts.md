# 精靈與獸人英雄圖：opt image 提示詞

英雄改成三個人型種族（人類、精靈、獸人；`domain/heroes.gd`）。現在精靈與獸人暫時用人類的圖（`scripts/portraits.gd row_of`、`scripts/army.gd sheet_of`），舊的野豬／魔狼／史萊姆列不再當英雄用。生好的圖放 `art_src/races/<race>_<class>/`（Godot 不匯入），Claude 再切成 48 px 格、統一像素密度與描邊，接進 `assets/heroes/heroes.png`／`heroes.json` 的 `beast_*`、`elf_*` 列，並換掉暫代。

## 要生的圖（共 24 張）

每個種族 × 6 職業（盾 shield、劍 sword、槍 spear、弓 bow、法 mage、補 healer），各兩張：

| 檔名 | 內容 | 尺寸建議 |
|---|---|---|
| `<race>_<class>_sheet.png` | 一列 9 個姿勢，全部面向右：跑步 4 格、攻擊 3 格（舉起、出手、收招）、倒地 1 格、施放大招 1 格（雙手高舉） | 1728×192（每格 192×192），透明底 |
| `<race>_<class>_portrait.png` | 全身站姿立繪（英雄頁大圖） | 512×768，透明底 |

`<race>` 用 `elf` 或 `beast`。

## 共用描述（每張提示詞前面都加）

> 16-bit JRPG pixel art character, side view facing right, crisp hard-edged pixels, no anti-aliasing, limited palette, 1-pixel dark outline, soft light from the upper left, transparent background, no text, no UI, original high-fantasy design, same proportions as a classic SNES-era sprite (about 3 heads tall)

同一族的 6 張要像同一族：相同的髮色範圍、耳朵與服裝風格；同一職業的人類、精靈、獸人要拿同一類武器，在戰場上一眼分得出職業。

## 種族描述

- **精靈 elf**：long pointed ears, slender build, flowing hair in pale blond / silver / soft green, leaf-and-vine motifs, light leather or cloth in forest green and cream with gold trim
- **獸人 beast**：humanoid beastfolk with animal ears and a tail (wolf, fox, cat, bear mixed across the six), sturdy build, fur-trimmed leather, earthy browns and reds with bone or wood accessories; fully human-shaped body, not an animal

## 職業描述（接在種族描述後）

| 職業 | 武器與輪廓 |
|---|---|
| 盾 shield | large round or kite shield and a short sword, heavy stance |
| 劍 sword | one-handed longsword, agile stance |
| 槍 spear | long spear held in both hands |
| 弓 bow | longbow, quiver on the back |
| 法 mage | staff with a glowing orb, robe |
| 補 healer | holy staff with a small flower or star tip, light robe |

## 姿勢提示（sheet 那張再加）

> nine poses in one horizontal row, evenly spaced, same character in every frame: running cycle frames 1-4, attack wind-up, attack strike, attack follow-through, knocked down lying on the ground, casting with both arms raised

## 驗收

- 透明底，邊緣沒有白邊；9 個姿勢大小一致、腳底在同一條線上。
- 縮到 48 px 一格時，耳朵（精靈）與耳朵加尾巴（獸人）還看得出來。
- 先生一張（例如 `elf_sword`）確認風格再生其餘 23 張。
