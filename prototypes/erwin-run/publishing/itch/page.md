# itch.io 上架資料：艾爾文衝鋒（erwin-smith-run）

頁面：https://natsu-madao.itch.io/erwin-smith-run

## 基本欄位

| 欄位 | 填什麼 |
|---|---|
| Title | 艾爾文衝鋒 Erwin's Charge |
| Short description | 10/14 艾爾文團長生日快樂！騎馬衝出城牆，斬巨人、彈巨石，最後和兵長一起討伐獸之巨人。 |
| Classification | Games |
| Kind of project | HTML |
| Release status | Released |
| Pricing | No payments（粉絲作品，免費） |
| Genre | Action |
| Tags | endless-runner, pixel-art, fan-game, attack-on-titan, birthday, one-button, short, mobile |
| Cover image | `publishing/itch/cover-630x500.png` |
| Screenshots | `publishing/screenshots/01-title.png` 到 `08-birthday-ending.png`，照編號順序上傳 |

## Uploads

- 檔案：`build/erwin-run-web.zip`（13 MB），勾選 **This file will be played in the browser**。
- Embed options：
  - Viewport dimensions：1280 × 720
  - 勾 **Mobile friendly**，Orientation 選 **Landscape**
  - 勾 **Fullscreen button**
  - 不用勾 SharedArrayBuffer（匯出時沒開多執行緒）
  - Frame options：不要勾 Automatically start on page load（讓玩家先點一下，聲音才能播）

## 介紹內容（貼到 Description）

**10 月 14 日，艾爾文團長生日快樂！**

「ススメ——！！」

艾爾文團長一聲令下，調查兵團衝出城牆。騎著白馬穿過廢墟與平原，斬倒擋路的巨人、把飛來的巨石彈回去。約兩分半之後，獸之巨人會在遠方現身。斬斷他伸來的手臂，或把巨石彈回他臉上，兵長就會趕到。

**玩法**

- 只有兩個動作：**跳躍**、**斬擊**。斬擊同時也是彈反。
- 巨人靠近時出刀，貼得越近越好，算「完美討伐」，分數加倍。
- 右側出現「!」代表巨石要飛來了，看準時機斬擊把它彈回去；低飛的也可以跳過。
- 揮刀太早會落空，之後有一小段時間不能再砍。
- 三格血，撐到獸之巨人出現。死在 Boss 戰可以直接從獸之巨人重來。

**操作**

| | 鍵盤 | 手機 | 手把 |
|---|---|---|---|
| 跳躍 | 空白鍵、↑、W | 點左半邊 | A |
| 斬擊・彈反 | J、X、K、→ | 點右半邊 | X |
| 暫停 | Esc、P | 右上角 II | Back |

手機請**橫著拿**，直拿時遊戲會暫停。

**製作**

- 引擎：Godot 4.7
- 角色與背景的像素圖由 AI 生成，再手工裁切、限色。
- 音樂：「Stroke of Destiny」by RockCapers
- 字型：俐方體 11 號 Cubic 11（SIL OFL）

本作是非官方的粉絲作品，免費遊玩。《進擊的巨人》及其角色版權屬於諫山創、講談社。

---

**Happy birthday, Commander Erwin! (Oct 14)**

A short one-button runner fan game. Charge out of the walls on horseback, cut down titans, parry the boulders thrown at you, and survive until the Beast Titan shows up. Cut off its reaching arm or knock a boulder back into its face, and Captain Levi will finish the job.

Jump: Space / ↑ / tap left half. Slash & parry: J / → / tap right half. Play in landscape on phones.

Unofficial fan work, free to play. Attack on Titan and its characters belong to Hajime Isayama and Kodansha.

## 上架前要確認

- 「Stroke of Destiny」與其他使用者提供的音效（馬蹄、馬嘶、士兵吶喊、跳躍、碎石），授權是否允許放在公開網頁上、要怎麼標示出處。上面的製作名單只寫了曲名和作者。
- 開場喊聲 `susume` 取自動畫原音，本身有版權；粉絲作品慣例上會用，但要不要放由你決定。
