# 派工：madara-survivor 第一輪原畫（master still）

目標：用 agent-sprite-forge 的 `master_still.py generate` 為 8 個角色各生成 3 張原畫候選，給 Claude 挑選。
只做原畫，不做動畫、不 approve、不做其他素材。

## 環境
- forge：`/Users/peter/repo/agent-sprite-forge`；Python 用 `/Users/peter/repo/agent-sprite-forge/.venv/bin/python`。
- **一定要加 `--route codex-cli`**（用已登入的 Codex CLI；config 裡的 API key 無效）。

## 輸入
- 提示詞與規格：`/Users/peter/repo/godot/godogen/prototypes/madara-survivor/docs/art-spec.md`
  - 「共同風格」區塊接在每個角色描述後面。
  - 角色描述照 1～8 節的 text 區塊，外觀描述不要改。
- spec 參數：
  - `--finish hd --facing right --takes 3`
  - `--view "elevated three-quarter overhead view about 42 degrees, body turned diagonally toward the lower-right"`
  - `--class`：斑用 `hero`，其餘用 `mob`。
  - `--key`：每節標題寫的顏色。
  - `--recap`：斑用 1 節給的那句；其他角色用一句英文外觀摘要。

## 輸出位置
- 根目錄：`/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round1/`
- 每個角色一個子資料夾（`--output-dir` 必須是不存在的新資料夾）：`madara/`、`genin/`、`masked/`、`heavy/`、`caster-fire/`、`caster-water/`、`caster-earth/`、`elite/`
- 每個資料夾放 3 張候選＋`candidates-contact.png`。

## 驗收條件
- 每張候選：透明背景、單一角色、全身、手腳沒被裁切、朝右下（方向反了就水平鏡像交付，並保留原圖）。
- 斑：紅色分段甲、及腰黑色長刺髮遮住右眼、白紅團扇、小腿白繃帶。
- 一般忍者：護額**沒有任何村子標誌**。
- 三種施術忍者：身形一樣，靠配色和手上的光區分元素。
- 做不到（沒有可用的生圖路徑）就直說並停下，**不要改用程式繪圖代替**。

## 回報
寫到 `/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round1/REPORT.md`，最多 20 行：
- route_media 回報的 provider／model
- 每個角色的資料夾與 contact sheet 路徑
- 和外觀條件不符的地方、遇到的問題

完成後建立 `/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round1/DONE`。
