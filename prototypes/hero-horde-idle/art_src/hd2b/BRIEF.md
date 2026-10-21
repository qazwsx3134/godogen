# 派工：6 職業英雄動作格（hd2b）

## 背景
- hd2 的 6 個職業站姿已選定（見下表的 FIRST 圖）。遊戲裡每個職業要 5 個動作格，和站姿拼成跑步、攻擊、倒下、大招的動畫。
- 遊戲裡英雄只有約 40 px 高，動作要**大、剪影清楚**，細節次要。

## 做法
- 每個動作用 `master_still.py edit`，FIRST 圖（`--still`）用該職業選定的站姿。
- 都加 `--route codex-cli --finish pixel --class hero --facing right`，key 與 hd2 該職業相同。
- keep：同一個角色（臉、髮型、服裝、淺色布料、武器、配色）、同樣比例與畫風、約 45° 俯視、朝右。
- **對齊**：交付前把每張放到和 FIRST 圖同樣大小的畫布上，人物比例不變，腳底（倒地則是身體最低點）和 FIRST 圖的腳底同一個高度；做法同 hd1b 的 `prepare_delivery.py`。
- 每個動作 1 張，不多骰；每筆時限 6 分鐘、超時重跑一次、再卡就跳過並寫進回報。
- 只有 edit 失敗時才改用 generate＋`--identity-ref` 站姿，並在回報寫明。
- Codex 額度不夠就先停在已完成的職業，依表格順序做。

| 職業 | FIRST 圖 |
|---|---|
| shield | `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/hd2/shield/<選定>.png` |
| sword | `…/hd2/sword/<選定>.png` |
| spear | `…/hd2/spear/<選定>.png` |
| bow | `…/hd2/bow/<選定>.png` |
| mage | `…/hd2/mage/<選定>.png` |
| healer | `…/hd2/healer/<選定>.png` |

（`<選定>`：6 個職業都用 `candidate-01.png`。）

## 動作（edit 的 THE ONLY CHANGE，英文）

| 資料夾 | 所有職業共用 |
|---|---|
| `run_a/` | running to the right, leaning forward, left leg forward and right leg pushing back, weapon carried |
| `run_b/` | running to the right, mid-stride with the legs swapped: right knee raised high, left leg back (clearly different legs from run_a) |
| `strike/` | the attack at full extension (see the class line below) |
| `down/` | fallen: lying on the back on the ground, eyes closed, weapon dropped beside the body, body horizontal |
| `volley/` | all-out charge cry: weapon raised high overhead with both arms, chest out, mouth open shouting |

`strike/` 依職業：
- shield：bashing forward with the tower shield, sword raised behind it
- sword：a wide horizontal slash, longsword swept forward to the right
- spear：a full lunge, spear thrust straight forward to the right
- bow：bow fully drawn and aimed to the right, arrow nocked
- mage：staff thrust forward to the right, the crystal flaring bright
- healer：sun-ring staff raised forward, a soft golden glow around the ring

## 輸出
- `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/hd2b/<職業>/<動作>/candidate-01.png`
- 每個職業一張 `hd2b/<職業>/poses-contact.png`：站姿＋5 個動作並排。

## 驗收
- 透明背景、全身與武器不裁切、朝右（倒地除外）、同一職業 6 張是同一個角色、腳底對齊。

## 回報
寫 `hd2b/REPORT.md`，最多 12 行：route、偏差、額度、跳過的項目。完成後建立 `hd2b/DONE`。
