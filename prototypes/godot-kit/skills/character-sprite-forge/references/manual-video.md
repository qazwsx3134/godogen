# 動作描述與手動影片交接

## 改 `set_plan.json` 的 motion

prompt 由 `sprite_set.py` 組成，只有 `motion`（動作）與 `negatives`（排除條件）該改，其餘是模板：

```
The same <recap>, facing RIGHT the entire time and never turning around,   ← 模板（facing 寫死）
<motion>                                                                    ← 改這裡
The clip starts AND ends in exactly the same pose as the still.             ← 模板
<negatives>                                                                 ← 視需要改
camera locked ... <key> background ... keep the exact <style> look          ← 模板
```

規則（出自 `$FORGE/skills/video2dsprite/references/motion-prompts.md`，121 支 Grok 影片的經驗）：
- 一支影片一個動作；開頭結尾都是原畫姿勢。
- 不用 tiny、barely、very slow 這類弱化字，動作在遊戲尺寸會看不見。
- 不要特效（塵土、火花、拖影），那是遊戲 FX 層的事。
- walk／run 寫「腳落在同一條地平線」，不要寫「腳固定不動」（會失去步伐）。
- 改完用 `prepare_i2v_input.py lint --prompt-file <takes/t01/prompt.txt> --key <key>` 檢查；只理 `weak-amplitude` 這類，`missing-work-region`、`missing-timeline` 可忽略。

這個專案額外加的：
- **斜俯視角色**：模板假設側視，`facing RIGHT` 可能讓 AI 轉成側面。每個 motion 結尾加：`Keep the still's elevated three-quarter overhead camera (about 50 degrees) and the body turned diagonally toward the lower-right; never switch to a flat side profile.`（尚未驗證是否足夠；轉側面時下一個 take 加 `never-turn`。）
- **徒手角色的 attack**：模板寫「weapon or fists」，要改成 `Bare fists only, no weapon.`，negatives 的武器句換成 `No weapon appears.`
- **個性要寫進動作**：例如厭世上班族的 idle 是「tired breathing, drooping shoulders rising and sinking, a slight listless sway」，walk 是「slow, tired, shuffling walk, feet dragging low」。原模板的「hair stirring in a soft wind」對油頭不適用，要拿掉。

## 交接給使用者（MANUAL-VIDEO.md 範本）

`run` 回 `waiting-for-clips` 後，給使用者每個動作四樣東西：起始圖、prompt、影片放哪、比例。

```markdown
# <角色> 動作影片：手動生成交接

根目錄：`<角色>/set/actions/`

| 動作 | 起始圖（上傳這張） | prompt（整段貼上） | 影片放這裡 | 比例 | 尾幀 |
|---|---|---|---|---|---|
| idle（循環） | `idle/job/input.png` | `idle/takes/t01/prompt.txt` | `idle/takes/t01/media/clip.mp4` | 1:1 | 有欄位就也放 input.png |
| walk（循環） | `walk/job/input.png` | `walk/takes/t01/prompt.txt` | `walk/takes/t01/media/clip.mp4` | 1:1 | 不用 |
| attack（單次） | `attack/job/input.png` | `attack/takes/t01/prompt.txt` | `attack/takes/t01/media/clip.mp4` | 16:9 | 有欄位就也放 input.png |

生成設定：5–6 秒、720p、鏡頭固定、關掉工具自帶的運鏡／增強。`.mp4`、`.webm`、`.mov` 都收，檔名不限。

收之前自己看：背景整段純色（無地板、陰影、漸層）；角色沒轉側面、沒走出畫面、沒縮放；attack 只出手一次並回到起始姿勢。
```

比例跟著 `input.png`：plan 給 idle／walk／hurt 方形、attack／cast 16:9、jump 3:4。尾幀只對 idle 與 attack 有意義（plan 的 `pinLastFrame`）。

在對話裡也要把三段 prompt 全文貼出來，使用者直接複製用。
