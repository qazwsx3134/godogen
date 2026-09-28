# opt image 素材製作包

使用者已選擇自行用 opt image 製作。本輪沒有呼叫 AI 生圖；以下是可直接貼上的提示詞。

先做 **6 張乾淨背景 + 4 個透明物件**。它們用來替換目前 Godot 的背景補片與 Polygon2D 輪廓，UI 文字、數字、按鈕與進度条仍由 Godot node 繪製。

## 先做乾淨背景

每次附上表中的原圖，只跑一張。維持原圖完整 941 × 1672 畫布，方便以相同座標接回 AtlasTexture；不是要重新設計六個畫面。

| 貼上哪一份提示詞 | 附上的原圖 | 輸出檔名 | 戰場垂直範圍（原圖座標） |
| --- | --- | --- | --- |
| `01-background-overview.txt` | `images/idel.png` | `overview_clean.png` | y=100…949 |
| `02-background-train.txt` | `images/train.png` | `train_clean.png` | y=100…753 |
| `03-background-backpack.txt` | `images/backpack.png` | `backpack_clean.png` | y=100…719 |
| `04-background-monster.txt` | `images/monster.png` | `monster_clean.png` | y=100…639 |
| `05-background-adventure.txt` | `images/adventure.png` | `adventure_clean.png` | y=100…776 |
| `06-background-store.txt` | `images/store.png` | `store_clean.png` | y=100…704 |

如果 opt image 支援區域編輯，只遮罩人物、史萊姆、木樁、血條、傷害文字和閃光，保持其餘區域不變。保留草地平台的高度與右側燈柱，不能整片重畫地形或搬動城堡。

## 再做透明角色

使用 `images/monster.png` 作為前三個物件的身份與畫風參考；木樁用 `images/train.png`。每次只做一個物件。

| 提示詞 | 輸出檔名 | 建議輸出画布 | Godot 目標外觀大小 |
| --- | --- | --- | --- |
| `07-hero.txt` | `hero_idle.png` | 1024 × 768，透明 RGBA | 約 186 × 121，含劍與披風 |
| `08-pet.txt` | `sprout_dragon_idle.png` | 1024 × 768，透明 RGBA | 約 120 × 108 |
| `09-slime.txt` | `green_slime_idle.png` | 512 × 384，透明 RGBA | 約 71 × 56 |
| `10-dummy.txt` | `training_dummy.png` | 512 × 640，透明 RGBA | 約 101 × 124 |

透明是實際 alpha，不是畫上棋盤格。輸出畫布可較大，但不要為了填滿畫布而改變角色比例；匯入時會按角色實際包圍盒縮放，對齊腳底。這批先做單幀，不要求模型一次生成容易走樣的動畫表。

## 補充：冒險章節橫幅

`11-chapter-banner.txt` 去掉 `adventure.png` 章節橫幅裡的文字，保留森林與城堡插畫。輸出 `chapter_banner_clean.png`，941 × 1672 原尺寸畫布；使用的區域是 `(38, 899, 866, 190)`。其他區域不用重新創作。

## 交付與檢查

把完成的 PNG 放到 `docs/taskbar-hero-mobile-spec/images/generated/`，沿用上表檔名。整合時再複製到專案 `assets/final/`，更新場景中的 Texture 資源；目前程式不會在背景偷偷載入或覆寫場景。

逐張檢查：

- 背景沒有殘留人物陰影、血條、數字、補片矩形、重複大石頭或突然中斷的草地。
- 原本的構圖、城堡、山脈、橋樑、燈柱和地面高度保持一致。
- 主角仍是深色亂髮、紅披風、灰色盔甲、朝右的銀劍；小芽龍保持青綠身體、奶油色肚子、黑眼睛與橘紅臉頰。
- 角色四周透明、輪廓完整，沒有切掉武器、尾巴、角、腳，也沒有白邊或假棋盤背景。
- 圖示、UI 中文和數值不要重新生成。原圖字體目前沒有提供字型檔，Godot 暫用 WenQuanYi Zen Hei，字形差異仍需另行校準。

生成結果仍須與原圖比較，不能保證模型輸出逐像素一致。這些素材補齊後，才進行下一輪背景、輪廓與動畫驗收。
