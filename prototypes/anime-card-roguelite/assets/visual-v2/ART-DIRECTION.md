# Visual v2 — 木葉與角色動作

2026-09-08。依使用者要求，火影角色改為 Naruto Shippuden 的金髮、橘黑服、木葉護額、面頰鬚紋；使用內建 imagegen 重製角色與木葉村／火影岩背景。遊戲內角色 ID 與數值不變。

## 交付

- bg-ninja.png：角色選單使用的 1672×941 原構圖。
- bg-ninja-wide.png：戰鬥全景 2048×683，避免寬螢幕裁掉火影岩。
- hero-{shadow_ninja,ki_fighter,silver_ronin}-{idle,attack,hurt}.png：九張 512×512 透明圖集，每格 256×256，2×2 閱讀順序，共36格。
- 火影：準備 → 轉肩 → 出拳 → 收勢；空悟：聚勢 → 轉身 → 推掌 → 收勢；銀桑：舉刀 → 轉肩 → 木刀斬 → 收勢。
- 受擊：防備 → 後仰／縮身 → 疼痛姿勢 → 恢復。沒有將待機平移冒充新動作。
- 空悟／銀桑待機沿用 visual-v1 原畫；其餘由內建 imagegen 生成，來源與 prompt 在 generation.json、panorama-generation.json。

## 處理與驗證

raw/ 保留原始生成圖，processed/ 含逐格 PNG、GIF、pipeline-meta.json。scripts/prepare-actions.py 使用 generate2dsprite 處理器，需具備 Pillow / NumPy 的 Python。每名角色由待機建立 scale-profile，攻擊和受擊沿用相同縮放、腳底對齊規則。因蹲姿／後仰造成輪廓面積變化，動作的 profile body-scale 指標容許22%變化（實測最高18.54%）；未放寬來源／輸出邊界、裁切或空白格檢查。九組均通過 strict QC，見 qc.json。

## 遊戲介面與播放

深色 HUD 統一生命、能量、共鳴與回合操作；宇宙配色只作點綴，戰場背景隨接力切換。手牌有費用徽章、插圖、效果與流派標籤，角色選單使用大立繪選卡。主體維持2D橫向；手機手牌與多敵人各自橫向捲動，不讓整頁溢出。

battle-art.js 將動作圖集套到場上主角，約0.6秒結束恢復待機；出牌、重繪與離開戰場清理計時器。敵方攻擊時播放主角受擊，全格擋也保留受擊姿勢；毒死亡而未出手的敵人不觸發。reduced-motion 停用逐格與位移動畫。新八客串與氣功光束保留。

普通敵人與首領目前仍使用原有待機、位移和受擊閃光；本批新動作範圍為三名可選角色。逐招專用施法姿勢和每張卡專屬插圖尚未製作，現有卡面使用可重用角色與場景素材。
