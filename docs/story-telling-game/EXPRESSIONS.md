# 角色表情清單（美術製作）

更新：2026-09-28。劇本用表情 id 標出角色當下的臉（`char("kagura", "angry", "right")` 或台詞後面加 `[#angry]`），遊戲依 id 換成那張圖；還沒有圖的表情就先顯示角色原本那張。這份清單列出有哪些表情、每個角色要畫哪些。

## 表情 id

表情 id 在 `prototypes/debt-commission/scripts/story_runner.gd` 的 `VALID_EXPRESSIONS`，劇本只能用這些。要新增表情，先在這裡加一列並說明用途，再加進 `VALID_EXPRESSIONS`。

| id | 中文 | 什麼時候用 | 畫法 |
|---|---|---|---|
| `neutral` | 平常 | 一般說話、旁觀 | 角色的定稿圖（目前每個角色那一張） |
| `smile` | 笑 | 開心、客套、裝沒事 | 眼睛彎、嘴角上揚 |
| `annoyed` | 不耐煩 | 嫌麻煩、被念、敷衍 | 半閉眼、嘴撇、可加青筋小記號 |
| `angry` | 生氣 | 真的動怒、拍桌、反擊 | 眉頭壓低、咬牙或張嘴、青筋 |
| `shout` | 大吼（吐槽） | 吐槽那一句、大聲反駁 | 嘴張很大、手指對方、線條誇張 |
| `surprised` | 驚訝 | 看到證據、意外發展 | 眼睛睜大、瞳孔縮小、嘴張開 |
| `panic` | 慌張 | 手忙腳亂、事情失控、被逼到絕境 | 眼睛打轉或睜大、冒汗、手亂揮 |
| `nervous` | 緊張 | 事情發生前的不安、被盯著看 | 僵硬、嘴抿緊、一滴汗 |
| `sweat` | 心虛冒汗 | 說謊被戳破、找藉口 | 眼神飄走、大量汗滴 |
| `smug` | 得意 | 炫耀、自以為贏了、嫁禍成功 | 斜眼、嘴角單邊上揚 |
| `thinking` | 思考 | 推理、內心話、調查 | 手托下巴、眼睛看旁邊 |
| `serious` | 認真 | 喜劇中突然認真的那一段 | 眼神銳利、表情收起、畫面線條變少 |
| `cry` | 哭／委屈 | 真的難過、假哭、被冤枉 | 眼淚、眉毛下垂 |
| `broken` | 崩潰 | 被打擊到石化、靈魂出竅 | 白眼或空洞眼、全身發白、可加裂痕 |
| `nosepick` | 挖鼻孔 | 裝傻、不當一回事、聽人說教時 | 手指挖鼻孔、死魚眼 |
| `mock` | 嘲笑 | 指著人大笑、看別人出糗 | 指著對方、張嘴大笑、眯眼 |

## 各角色要畫的表情

「第一批」是第一章（[草稿 v0.2](stories/003-strawberry-milk-ch1-draft-v0.2.md)）會用到、要先畫的；「第二批」之後章節可能用到。每個角色原本那張圖當作 `neutral`。✓ 表示已經放進遊戲（2026-09-28）。

| 角色 | 在第一章的功能 | 第一批（先畫） | 第二批 |
|---|---|---|---|
| 新八 `shinpachi` | 主角、吐槽役 | ✓`shout`、✓`angry`、✓`panic`、✓`thinking`、**還缺 `broken`**（薪水與定春的反轉、Game Over） | ✓`nervous`、`surprised`、`smile`、`cry`、`serious` |
| 銀時 `gintoki` | 裝傻、事件製造者 | ✓`smug`、✓`sweat`、✓`annoyed`（挖鼻孔那張，回合中程式固定用它）、✓`panic`（和 `nervous` 同一張）、✓`serious`（拿木刀那張） | ✓`angry`、✓`nosepick`、✓`nervous`、`smile`、`surprised`、`shout` |
| 神樂 `kagura` | 嫁禍給定春、提示員 | ✓`smile`、✓`smug`、✓`sweat`（和 `nervous` 同一張）、✓`angry` | ✓`annoyed`（鄙視）、✓`mock`（嘲笑）、✓`nosepick`、`cry`（假哭）、`surprised`、`panic` |
| 登勢 `otose` | 家庭會議的裁判 | ✓`annoyed`（抽菸不耐煩）、✓`angry`、✓`serious` | `smile` |
| 定春 `sadaharu` | 被冤枉的證人、真兇 | **還缺** `smile`（汪）、`cry`（被冤枉）、`smug`（舔嘴，真兇） | `angry`（咬人） |
| 伊莉莎白 `elisabeth` | 第四面牆 | 不用（一直是 `neutral`，舉空白牌；牌上的字由遊戲疊上去） | `surprised` |

第一批還缺 4 張：新八 `broken`，定春 `smile`、`cry`、`smug`。

## 生成的 prompt

**這系列的圖都是用下面這段 prompt 生成的**：附上一張原圖，讓 AI 用 MS 小畫家、滑鼠亂畫的方式重畫。新的表情、角色、背景、素材圖都照抄這段，才會和現有的圖同一個風格。附的參考圖要是那個角色、做出那個表情（或那個場景）的圖。用付費工具（例如 Scenario）生成前先跟作者確認。

```text
Please redraw the attached image in the most clumsy, messy, and hopelessly pathetic way possible. Use a white background and make it look like it was drawn in MS Paint with a mouse. It should vaguely resemble the original, but not really — like it's kind of correct in some places yet strangely off and awkward overall. Emphasize a low-quality, pixelated look, and make it appear ridiculously badly drawn. …Actually, never mind — just draw it however you want in a sloppy way.
```

## 放進遊戲

生成的圖是白底，大小、位置也和角色原本那張不一樣，交給 `tools/fit_expressions.gd` 處理。以下路徑都在 `prototypes/debt-commission/`：

1. 把生成的原圖放進 `art_src/expressions/`。這個資料夾有 `.gdignore`，Godot 不會匯入，也不會打包進遊戲。
2. 在 `art_src/expressions/fit.json` 那個角色底下，把表情 id 對到檔名。兩個表情可以用同一張圖。
3. 執行 `godot --headless --path . --script res://tools/fit_expressions.gd`，它會：
   - 去掉從邊緣連進來的白色（衣服裡的白色不動）；
   - 把角色縮放到和原本那張同樣大小（預設用身高比，原圖有道具或特殊姿勢時在 `fit.json` 寫 `scale`，例如神樂原圖有傘又在跳，用頭的大小對齊，`scale` 1.0）；
   - 腳底對齊原圖的腳底、身體中線對齊；
   - 輸出到 `assets/image/expressions/<角色id>_<表情id>.png`，姿勢比原圖寬或高時畫布會往兩邊、往上加大。
4. 把它最後印出的 `CATALOG` 那行貼進 `data/asset_catalog.json` 那個角色的 `expressions`。

遊戲依圖的大小自己擺位置，`scenes/characters/<角色>.tscn` 調好的大小位置不用重調。

## 查哪些表情還沒有圖

在 `prototypes/debt-commission` 執行：

```bash
godot --headless --path . --script res://tools/list_expressions.gd
```

它列出已建置的劇本（`data/*_story.json`）實際用到的每個表情，以及有沒有圖。新劇本寫好、建置後跑一次，把還沒有的加進上面的表格。
