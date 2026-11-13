# 寫手派工單：魔都傭兵（mortal-city）劇情委託

你要替一款 cyberpunk 文字冒險 roguelike 寫**一件劇情委託**草稿。專案根目錄：`/Users/peter/repo/godot/godogen/prototypes/mortal-city`（下文路徑都相對它）。派工時會另外給你：**草稿 id、街區、中間人、題材方向**；沒給的你自己決定，並寫進設計說明。

## 1. 目標與動機

作者想用 AI 擴充劇情。你的草稿會先過機器檢查，再交給一個沒看過你寫作過程的審查員，最後作者在遊戲裡讀全文判斷合不合理。所以：**每一句選項文字承諾的事，都要有對應的欄位**；邏輯要經得起逐條檢查。

## 2. 先讀這些（讀完再動筆）

| 檔案 | 為什麼 |
|---|---|
| `CONTEXT.md` | 世界觀名詞與**不要用的詞**（每個詞底下的 `_Avoid_`） |
| `docs/adr/0001-single-player-roguelike.md` | 遊戲是什麼 |
| `docs/DICE-POOL-SPEC.md` 第 1、3、5 節 | 場面怎麼擲骰、危險節點的致命判定、追擊戰 |
| `src/content/cases.ts`（`StoryCase`、`Approach`、`CaseOption` 型別，以及 01「終電包裹」、02「診所不收現金」） | 資料格式與既有語氣 |
| `src/content/cases_wangan.ts`（03、06） | 灣岸的語氣與人物 |
| `docs/story-pipeline/example-P01-01.json` | 01 匯出的 JSON，**你的檔案就是這個形狀** |
| `src/content/beats.ts` | 場面（`Beat`）格式與委託的通用場面 |
| `src/content/data.ts` 的 `FIXERS`、`src/content/districts.ts` | 人物 id、每個街區有哪些中間人與神機醫 |
| `src/content/items.ts` 的 `ITEMS` | `loot` 只能用這裡的 key |
| `src/content/glossary.ts` | 玩家看得到的名詞解釋 |

## 3. 交付物

1. `story-drafts/<id>.json`：一個符合 `StoryCase` 的 JSON 物件，`kind` 是 `"draft"`，`id` 用派工給的（沒給就 `D-英文短名`）。不要接進地圖，不要改任何其他檔案。
2. `story-drafts/<id>.writer.md`：10 行內的設計說明——題材一句話、在哪個街區、跟哪個人物有關、每種做法的差異、機器檢查剩下的警告為什麼不修。**這個檔最後才寫，它出現就代表你做完了。**

## 4. 機制限制（機器檢查會擋的寫在 `src/content/storyCheck.ts`）

- **做法 `approaches`**：3～4 種，涵蓋武力 `force`、駭入 `hack`、潛行 `stealth`；可以多一種屬性做法（`needs: { attr, min: 6～8 }`）。每種做法：
  - `summary` 一句話講怎麼做、代價在哪；`autoLog` 2～4 行（每行 ≤70 字）；`injury` 路上傷勢 0～30；`lethalMod` −0.06～0.06（正數＝這條路最後比較險）。
  - 可以要先打一場（`fight`，數值照既有案子：HP 50～120、攻擊 8～14、命中 0.5～0.6、`ice`／`sense` 3～8），打贏後的文字放 `afterFight`。
  - **一定要寫 `beats`：剛好兩個場面**，用下面的模板，而且要符合這件案子的地點與這條路線。
- **場面模板（`Beat`）**：
  - `title` 2～5 字；`attr` 擲哪個屬性（`body` 體能、`reflex` 反應、`tech` 技術、`int` 智力、`cool` 沉著）。
  - `setup` 一段 ≤80 字的情境：眼前發生什麼、要做到什麼。
  - `out` 四種結果各一句（≤50 字）：`crit` 大成功（比預期更好）、`clean` 乾淨成功、`cost` 成功但出了狀況、`fail` 失敗（狀況惡化）。
  - `costs` 兩個代價選項，種類不同：`injury` 受傷、`heat` 通緝、`stress` 神經壓力、`pay` 少拿報酬；文字寫具體的動作（「被攝影機拍到半張臉」），≤24 字。
  - `fail` 失敗時吃的代價：`injury`／`heat`／`stress`（不能是 `pay`）。
- **危險節點 `danger`**：`title`、`body`（≤260 字，寫清楚**現場有誰**）、`options`：
  - **一個撤離選項**：`lethal: false`，沒有 `needs`、沒有 `approach`、沒有 `fight`，每種做法都看得到。可以給部分報酬（`reward`）。
  - **1～2 個冒險選項**（`lethal: true`，`lethalBase` 0.15～0.35：≥0.28 少一顆骰、≤0.1 多一顆骰）。
  - **限定做法的選項**（`approach: "<做法 id>"`）：只有走那條路才看得到，文字要接得上那條路。
  - **器材選項**（`needs: { slot: "deck"|"implant"|"weapon", direction, label }`）與**屬性選項**（`needs: { attr, min }`）：一樣是 `lethal: true`，遊戲會給 +2 顆骰、報酬七五折、名聲減半。
  - 可以有一個「打」的選項（`fight`，`lethal: true`）：打贏＝撐過去，打輸才擲致命判定。
  - **追兵**：致命判定失敗時，現場的敵人會逼近、要打一場。沒寫 `danger.threat` 就用「打」選項的對手；兩個都沒有＝失敗直接致命（只有現場真的沒人時才這樣，例如只有防火牆）。`threat` 要和 `body` 寫的是同一批人。
  - 每個選項的 `text` 是結案文字，寫**撐過去時**發生的事。選項欄位：`reward`（0～4000，參考 01 撤離 0、冒險 600；02 900～1500）、`heat` 通緝、`heal: true`（神機醫縫好傷口）、`lifeline: 1`（拿到一張救命保單）。**文字寫了拿到保單就要有 `lifeline`，寫了縫傷口就要有 `heal`，寫了被拍到或警察記住就要有 `heat`**。
- **其他欄位**：`fixerId` 與 `replies[].who` 只能用 `FIXERS` 的 id，而且中間人要屬於那個街區（新宿：`k` 老K、`rin` 阿凜、`snake` 白蛇；灣岸：`tide` 潮伯、`mist` 霧、`gull` 海鷗；任何地方：`crow` 夜鴉、`mpd` MPD 巡警、`medic` 武裝醫療隊）。`replies` 3～5 則，時間照順序（`"01:30"`），`posted` 像 `"2077.11.04 01:12"`。`xp` 30（中段案）。`lossText` 被武裝醫療隊救出時補的一句。`broadcast.survived`／`broadcast.other` 結案後夜鴉的插播。`loot` 可選，`kind` 只能用 `ITEMS` 的 key。`requires`／`variants`／`approachReplies` 只有接在某件案子之後才寫（variants 的 key 只能是 `won`／`lost`）。

## 5. 文字

- 繁體中文、台灣用語、短句、冷硬，跟 01～06 同一個語氣。人物說話方式照既有案子（老K 精簡、霧冷淡、夜鴉像 DJ）。
- **用標準用語**：「防火牆」不叫黑冰／ICE／冰；攻擊不寫「咬」；不用遊戲英文黑話（build、debuff、merc）；神經錯亂不叫賽博精神病。
- 玩家看到的文字**不寫百分比、不寫 HP 數值**——機率交給骰子，數值交給畫面。
- 不引入遊戲裡沒有的新系統（新貨幣、新道具類型、新屬性）。可以引入新的配角、企業部門、地點，但要跟 `CONTEXT.md` 與既有案子一致（神坂バイオテック、MPD、港務部、武裝醫療隊、救命保單）。

## 6. 自我檢查（做完才交）

```bash
cd /Users/peter/repo/godot/godogen/prototypes/mortal-city
pnpm story:check story-drafts/<id>.json
```

- **錯誤必須是 0**。警告逐條決定：修，或在 `<id>.writer.md` 寫為什麼不修。
- 自己逐一核對：每個選項的文字 vs 欄位；`danger.body` 裡的人 vs `threat`／「打」的對手；每個做法的兩個場面放在這件案子的地點合不合理。

## 7. 回報

- 做不到或前提有誤（例如派工指定的中間人不在那個街區），直說並停止，不要交看起來像完成的半成品。
- 最後寫 `story-drafts/<id>.writer.md`；在對話裡只回：檔案路徑＋3 行摘要＋`pnpm story:check` 的最後一行。
