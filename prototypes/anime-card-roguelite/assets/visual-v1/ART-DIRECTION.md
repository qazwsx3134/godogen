# Visual v1 — 橫向跨宇宙戰鬥

2026-09-07。第一批可玩的像素素材：角色在左、敵人在右、手牌在戰場下方。背景依出牌宇宙切換：忍村月夜、武鬥岩原、江戶燈街；角色本身保留身分。UI 字型、色盤與框線延用既有宇宙主題。

## 資產契約

- 3 張背景：1672×941 PNG，橫向滿版裁切。
- 8 張透明圖集：512×512，每張 2×2、每格 256×256，共 32 格。順序左上、右上、左下、右下。
- 角色：shadow_ninja、ki_fighter、silver_ronin，朝右；普通敵人 raider、首領 boss 朝左。
- cameo-shinpachi：吐槽四格；fx-energy：命中／格擋；fx-beam：橫向氣功。
- 人物共用縮放比例與腳底對齊，CSS 保持正方形格子，不拉長身體。特效獨立於角色，支援跨宇宙借招。
- 待機四格循環；出牌觸發短暫演出後清除。系統偏好減少動態時停播動畫。

## 生成與重建

使用內建 imagegen 生成原畫，完整 prompt 與來源路徑見 generation.json。raw/ 保留原始八張圖集；背景保留在此目錄。使用者提供的 D:\repo\image-work-flow 經檢查，其 sprite workflow 是 TODO scaffold，本批直接生成並落地於遊戲。

使用 generate2dsprite 技能的處理器去背、切格與對齊，沒有以程式繪製素材。重建需要 Pillow、NumPy 與本機 generate2dsprite 技能：

```bash
python prototypes/anime-card-roguelite/scripts/prepare-visuals.py
```

可用 --tool 指定另一個處理器位置，--python 指定具備依賴的 Python。processed/ 留存分格、GIF 與 pipeline-meta.json；qc.json 彙整八張的嚴格檢查結果。通過後處理器會複製透明圖集到本目錄，供 battle-art.js 載入。

目前三名角色共享待機搭配位移演出；專用施法姿勢、敵人差異造型、手部聚氣定位與逐角色攻擊動作屬下一批素材。吐槽反擊沿用格擋／荊棘卡牌規則，客串不佔場上位置。
