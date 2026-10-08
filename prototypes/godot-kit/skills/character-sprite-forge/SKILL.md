---
name: character-sprite-forge
description: 用 agent-sprite-forge 把遊戲角色從文字描述做到動畫 sprite 的分工流程：Claude 寫派工單、挑圖、核准原畫、改動作描述、驗收；Herdr 裡的 Codex 用已登入的 Codex CLI 文字生原畫（generate2dsprite master_still generate／edit，不需要 API key）；圖生影片沒有 API 時改成使用者手動生成、放回指定資料夾，再由 video2dsprite sprite_set 去背、QC、像素化、打包。要做角色原畫、角色動畫（idle／walk／attack…）、或 video2dsprite 卡在 no-route 時用。
---

# 角色 sprite：Claude × Codex × 手動影片

agent-sprite-forge 在 `~/repo/agent-sprite-forge`（以下 `$FORGE`）。產出放在原型的 `art_src/<群組>/<角色>/`，不放 `assets/`。來源：survivor-series 男女主角，2026-10-07～08。

```
 文字描述 ──→ ① Codex 生原畫 3 張 ──→ ② Claude 挑圖 ──┬─ 差一點 → ③ Codex edit（只改一處）─┐
                                                       │                                   │
                                                       └─────────── ④ Claude 核准 ←────────┘
                                                                        │ master.json
 ⑤ Claude plan＋改 motion ──→ ⑥ run ──┬─ 有影片 API → 自動生成
                                       └─ no-route → 給使用者 input.png＋prompt → 手動生影片 → 放進 media/
                                                                        │
 ⑦ 再 run（去背→QC→對位→像素化→打包）──→ ⑧ Claude 看 sheet → accept／retake
```

## 分工

| 誰 | 做什麼 |
|---|---|
| Claude（主對話） | 寫派工單、看 contact sheet 挑圖、`approve`、`plan` 與改 `motion`、跑 `run`／`review`、看圖決定 accept 或 retake |
| Codex（Herdr pane） | 只做文字生圖：`master_still.py generate` 與 `edit`，走 `route_media` 的 `local:codex-cli`（使用者已登入的 Codex CLI）。不 approve、不做動畫 |
| 使用者 | 選圖、確認修改；沒有影片 API 時手動用圖生影片工具做每支動作 |

生圖交給 Codex（使用者定的分工；Claude 這邊直接跑 `generate` 讓 `route_media` 呼叫本機 `codex` CLI 沒試過）。approve 以後全是本機確定性工具，Claude 自己跑，不派工。

## 0. 環境（每台機器一次）

```bash
cd $FORGE && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt   # 系統 numpy/Pillow 常太舊
.venv/bin/python skills/video2dsprite/scripts/video2dsprite.py doctor              # ffmpeg 5.1+、vp9_alpha、libx264
.venv/bin/python skills/generate2dmedia/scripts/route_media.py resolve --kind video # 看有沒有影片 API
```

以下 `PY=$FORGE/.venv/bin/python`。

## 1–3. 原畫（派給 Codex）

1. 先準備：角色外觀的英文 prompt（寫在原型的 docs，例如 `opt-image-prompts.md`）、一張美術方向參考圖。
2. 派工單寫成檔案放在 `art_src/<群組>/BRIEF.md`，報告寫到同資料夾 `REPORT.md`；範本見 `references/codex-briefs.md`。Codex 用 Herdr 開（`herdr agent start <名稱> --kind codex`，模型依 AGENTS.md：`gpt-6-luna`、max effort）。完成訊號是報告檔出現。
3. 挑圖：Read 每張 `candidates-contact.png`，對照外觀條件逐條看。差一點就派 edit（`EDIT.md`，一次只改一件事，用「THE ONLY CHANGE」句型），不要重骰。

**派工單一定要寫 `--route codex-cli`**：預設路由順序是 API key 優先，config 裡只要有一把 key（就算無效、沒額度）就會先試它而失敗，不會走 Codex 登入額度。2026-10-08 實測整批 0 張就是這個原因。

**generate 時就要定好**（approve 會繼承 spec，事後改很麻煩）：
- `--facing right`（斜俯視朝右下也用 right，再用 `--view` 描述角度）。不給會是 `none`。
- `--key`：角色有紅、粉、紫（例如紅領帶）就用 `green`，不然洋紅去背會吃掉。approve 有警告「colours lean to the key」就是這個。
- `--recap`：一句完整外觀摘要，之後每支影片 prompt 都以「The same <recap>」開頭。edit 產生的 spec 會把 recap 變成「character shown in the FIRST reference image」，影片 AI 看不懂。

## 4. 核准（Claude）

```bash
$PY $FORGE/skills/generate2dsprite/scripts/master_still.py approve \
  --still <選定.png> --spec <該輪>/spec.json --route codex-cli --prompt-file <該輪>/prompt.txt \
  --subject "..." --identity "..." --recap "..." \
  --facing right --view "elevated three-quarter overhead view about 50 degrees..., body turned diagonally toward the lower-right" \
  --class hero --finish pixel --pronoun he --key green --output-dir <角色>/master
```

`--output-dir` 必須不存在；要重做就換新名字（`rm -rf` 會被 auto mode 擋）。

## 5–6. 動作計畫與執行（Claude）

```bash
$PY $FORGE/skills/video2dsprite/scripts/sprite_set.py plan --master <角色>/master/master.json \
  --output-dir <角色>/set --actions idle,walk,attack --finish pixel --target-height 90
```

改 `set/set_plan.json` 裡每個動作的 `motion`、`negatives`（規則與這個角色的寫法見 `references/manual-video.md`），然後：

```bash
$PY $FORGE/skills/video2dsprite/scripts/sprite_set.py run --plan <角色>/set/set_plan.json
```

- 有影片 API：自動生成，`--max-takes` 預設 3，會花錢（`route_media` 會印 `estimateUsd`）。
- `no-route`（exit 3、`waiting-for-clips`）：正常狀態。`mkdir -p` 每個 `actions/<id>/takes/t01/media/`，把交接表給使用者，並寫成 `art_src/<群組>/MANUAL-VIDEO.md`（範本見 `references/manual-video.md`）。

## 7–8. 收影片與驗收

使用者放好影片後再跑一次 `run`，它會接手已放進 `media/` 的檔案，不重新生成。接著：

```bash
$PY $FORGE/skills/video2dsprite/scripts/sprite_set.py review --plan <set>/set_plan.json
```

Read 每張 `-sheet.png`、`-final.png` 與 lineup：數字看不出臉、朝向、多出來的東西。
- 通過：`accept --plan ... --action <id> --take <n>`。
- 不通過：`retake --plan ... --action <id> --fix <never-turn|face-visible|keep-colours|…>`，再 `run`；沒 API 時會在 `t02/` 出新 prompt，再交給使用者手動做。
- 最後 `report --plan ...`，回報時寫明每支影片是誰用什麼工具做的。

> 第 7–8 步截至 2026-10-08 還沒有用手動影片實際跑過；第一次跑完把結果補進這裡。

## 坑

- Codex 的 sandbox 第一次會擋 Codex CLI 初始化，要使用者核准外部執行。
- 生出來的原畫可能朝左下：Codex 會水平鏡像交付，原始 `generated.png` 保留，核准前確認朝向。
- 同一個 repo 在 WSL（`/mnt/d/...`）與 Mac（`~/repo/...`）路徑不同，舊報告裡的路徑要換算。
- `prepare_i2v_input.py lint` 對 sprite set prompt 會報 `missing-work-region`、`missing-timeline`，可以不理（sprite set 刻意不放數字範圍）；要注意的是 `weak-amplitude`。
- 先做一個角色跑完整條，確認畫面與費用，再做其他角色。
- `route_media.py resolve` 只看 key 有沒有設，不驗 key 對不對、帳號有沒有錢。2026-10-08 實測：xAI 新 team 沒儲值回 403 `quota`；BytePlus、fal 的 key 錯回 401；一個 provider 失敗會自動往下一個試。第一次跑先 `run --max-takes 1`，失敗看 `actions/<id>/takes/tNN/media.failed-api-<provider>/job.json` 的 `error`。config 是 `~/.config/agent-sprite-forge/config.json`，provider 名稱用 `xai`（寫 `grok` 會被忽略）。
