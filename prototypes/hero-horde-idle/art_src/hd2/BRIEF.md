# 派工：全員推王 6 職業英雄原畫（hd2）

## 背景
- hd1／hd1b 的舞台與巨魔已接進遊戲（HD-2D 像素風、黃昏）。現在英雄還是暫用小人，要換成同一個世界的角色。
- 遊戲裡 100 名英雄共用 6 個職業身體，每名英雄的衣服在遊戲裡換色，所以**衣服要畫成淺色、低彩度**（接近白、淺灰、米色），金屬與皮革照常上色。
- 這一批只做每個職業的站姿原畫；挑好之後下一批再用 edit 做跑步、攻擊等動作格。

## 規則
- 同 hd1：`master_still.py generate`，**一定要加 `--route codex-cli`**，`--finish pixel --class hero --facing right`，每筆時限 6 分鐘、超時重跑一次、再卡就跳過並寫進回報。
- 每個職業 2 張（`--takes 2`），不要多骰；額度不夠就停在已完成的項目並寫明。
- 參考畫風：`/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/hd1/boss/candidate-01.png`（同一個遊戲世界、同樣的像素質感與光向），用 `--identity-ref` 只借畫風，不借外型。
- 做不到就直說並停下，不要用程式繪圖代替。

## 共同風格（每個 prompt 都套用，英文）
```text
detailed HD-2D pixel art game sprite in the style of Octopath Traveler and Triangle Strategy: rich hand-placed shading,
crisp 1-pixel dark outline, limited palette, compact heroic proportions about 3.5 heads tall, lit by a warm low sun from
the upper-left with cool shadows, seen from an elevated three-quarter view about 45 degrees above, body and face turned
toward the right, standing in a ready combat stance, full body with feet visible on an invisible ground line, no
background, no cast shadow, no text. The cloth parts of the outfit are very light and low-saturation (off-white, pale
grey, cream) so the game can recolour them; metal, leather, hair and skin keep natural colours.
```

## 項目

| 資料夾 | key | 描述（英文接在共同風格前） |
|---|---|---|
| `shield/` | magenta | a stout shield knight with a large rectangular tower shield held in front and a short sword, steel half-plate over a light tabard, open-faced helmet |
| `sword/` | green | a swordsman with a longsword held in both hands, light gambeson coat with a short cape, leather boots, no helmet, short hair |
| `spear/` | magenta | a lancer with a long spear angled forward, light padded coat, round bracers, a simple bandana |
| `bow/` | magenta | an archer with a longbow and a quiver on the back, light hooded short cloak, leather bracer |
| `mage/` | green | a mage with a wooden staff topped by a softly glowing crystal, light long robe with a hood down, a small spellbook on the belt |
| `healer/` | magenta | a cleric healer with a short staff ending in a golden sun ring, light flowing robe with a stole, a small satchel |

- `--recap` 依上表的描述寫一句完整外觀。
- 6 個職業的身高、頭身比、視角要一致，並排時要看得出是同一套美術。

## 輸出位置
`/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/hd2/<職業>/`：`candidate-01.png`、`candidate-02.png`、`candidates-contact.png`。
另外做一張 `hd2/lineup.png`：6 個職業各取 candidate-01 並排，腳底對齊。

## 驗收
- 透明背景、全身與武器不裁切、朝右。
- 衣服是淺色、低彩度；去背沒有吃掉主體顏色。

## 回報
寫 `hd2/REPORT.md`，最多 12 行：route、各資料夾、偏差、額度。完成後建立 `hd2/DONE`。
