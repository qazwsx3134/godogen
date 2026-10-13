# 派工：erwin-run 第一輪生圖（18 張）

目標：替橫向卷軸跑酷遊戲 erwin-run 生成 sprite 條與背景圖層的原始圖。**只生成**，不去背、不切格、不縮圖、不改任何遊戲檔案——後製由 Claude 做。

`ER/` = `/mnt/d/repo/godot/godogen/prototypes/erwin-run/`；工具 `ASF/` = `/mnt/d/repo/agent-sprite-forge/`。
Python 不建 venv，一律用 uv。

## 指令（每張一次）

```bash
cd /mnt/d/repo/godot/godogen/prototypes/erwin-run
uv run --no-project --with-requirements /mnt/d/repo/agent-sprite-forge/requirements.txt \
  python /mnt/d/repo/agent-sprite-forge/skills/generate2dmedia/scripts/cli_media.py image \
  --route codex-cli --prompt-file art_src/prompts/<ID>.txt --output-dir art_src/gen/<ID> \
  --project-dir . --execute --timeout 360
```

- 提示詞已寫好，照用，不要改寫。
- 一律 `--route codex-cli`，不碰任何 API key。
- 每張限時 360 秒；逾時或失敗記在報告，最多重跑一次（換新的 output-dir：`art_src/gen/<ID>-r2`），再失敗就跳過。
- `--output-dir` 已存在會被拒：不要刪，換新名字。
- 整條生圖路徑不能用（例如 codex-cli 回 IMAGE_UNAVAILABLE、登入失效）就停下回報，**不要改用程式畫圖（SVG／PIL／canvas）替代**。

## 順序（重要的先做）

erwin_gallop、erwin_actions、titan_tall、rocks、beast_body、beast_arm、levi、emblem、ground、bg_sky、bg_far、bg_mid、wall_gate、bg_ruins、titan_fat、titan_runner、title_art、ending_art

## 回報

寫到 `ER/art_src/GEN-REPORT-1.md`，**每完成一張就追加一行**（Claude 會邊收邊用）：
`<ID> | ok/failed | <generated 檔案路徑> | <秒數> | <備註：例如被拒、明顯不符提示詞>`

18 張都處理完後，在報告最後加一行 `ALL DONE`，對話最後只回一行：`DONE` 或 `BLOCKED：原因`。
