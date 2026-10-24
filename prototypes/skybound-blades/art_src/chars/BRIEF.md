# 派工：浮空劍域 6 位角色原畫（master still）候選

目標：用 agent-sprite-forge 的 `master_still.py generate` 為 6 個角色各生成 3 張原畫候選，給 Claude 挑選。只做原畫，不 approve、不做姿勢或動畫、不做其他素材。這是本作原創角色，不要參考或複製 hero-horde-idle 的任何圖。

## 輸入
- 提示詞與參數：/Users/peter/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/PROMPTS.md（共同 spec＋每角色的 subject／identity／pose／recap／class／pronoun；照用，不改外觀描述）。
- 工具：PY=/Users/peter/repo/agent-sprite-forge/.venv/bin/python，腳本 /Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts/master_still.py。
- 一定加 `--route codex-cli --takes 3 --finish hd`。每筆設時限（`--timeout` 或外部 timeout，6 分鐘）；超時停掉、記錄、重跑一次，再卡就跳過並在報告寫明。
- 先只做 captain 一個角色，確認流程能出圖後再做其他 5 個。

## 輸出位置
- /Users/peter/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/<角色 id>/r1/（generate 的 --output-dir；角色 id：captain、guardian、medic、meadow_slime、briar_boar、ruin_hound）
- 每角色一張並排比較圖：/Users/peter/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/<角色 id>/candidates-contact.png

## 驗收條件
- 每角色 3 張 PNG、單一角色、手腳與武器未裁切、朝右下（朝向相反就水平鏡像交付，保留原始檔）。
- HD 插畫風，不是像素風；角色身上沒有洋紅／粉紅（會被去背吃掉）。
- 做不到（沒有生圖路徑、codex-cli 不能用）就直說並停下，不要用程式繪圖替代。

## 檔案邊界
只寫 /Users/peter/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/ 底下。不改 game/、scenes/、tools/、design/、assets/。

## 回報
寫到 /Users/peter/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/REPORT.md，≤20 行：route_media 回報的 provider/model、每角色候選路徑與比較圖、與 PROMPTS 外觀不符之處、遇到的問題。完成後在 pane 只回一行 DONE 或 BLOCKED＋原因。
