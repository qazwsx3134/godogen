# 派工：浮空劍域 6 角色動作姿勢（edit）

Claude 已核准 6 張 master：/Users/peter/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/<角色>/master/（captain、guardian、medic、meadow_slime、briar_boar、ruin_hound）。用 `master_still.py edit` 從各自 master 改出動作姿勢。不要 approve、不要做動畫。

## 輸入
- 姿勢清單與英文 change 文字、共同 keep：/Users/peter/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/POSES.md（照用）。
- 工具同上輪：PY=/Users/peter/repo/agent-sprite-forge/.venv/bin/python，/Users/peter/repo/agent-sprite-forge/skills/generate2dsprite/scripts/master_still.py。
- 每筆 `--takes 2 --route codex-cli`，時限 6 分鐘；超時重跑一次，再卡就跳過並記錄。
- 可以平行跑多筆，但同時不超過 6 筆。

## 輸出
- /Users/peter/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/<角色>/poses/<pose>/（edit 的 --output-dir）
- 每角色一張總覽：/Users/peter/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/<角色>/poses-contact.png（第一格 master，接著每個 pose 的 take 1、take 2，標上 pose 名稱）

## 驗收
- 每個 pose 2 張；身分、服裝、配色、畫風與 master 一致；朝右下；完整不裁切；洋紅底。
- 做不到就直說並停下。

## 檔案邊界
只寫 /Users/peter/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/ 底下。

## 回報
寫到 /Users/peter/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/POSES-REPORT.md，≤20 行：每角色總覽圖路徑、明顯偏差（哪張身分或朝向跑掉）、失敗或跳過的筆數。完成後在 pane 只回一行 DONE 或 BLOCKED＋原因。
