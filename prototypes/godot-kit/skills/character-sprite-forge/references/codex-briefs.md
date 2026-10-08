# 派給 Codex 的派工單範本

Codex 的 context 是空的：路徑一律寫絕對路徑，提示詞指到檔案的哪一段。派工時 `herdr agent prompt <名稱> "請完整讀 <BRIEF 路徑> 並照做，最後只回一行 DONE 或 BLOCKED＋原因"`。

## 第一輪：生原畫候選（BRIEF.md）

```markdown
# 派工：<角色們> 原畫（master still）

目標：用 agent-sprite-forge 的 `$generate2dsprite`（`master_still.py generate`）為每位角色各生成 3 張原畫候選，給 Claude 挑選。只做原畫，不做動畫、不 approve、不做其他素材。

## 輸入
- 參考圖（每張都附上）：<美術方向參考圖絕對路徑>
- 提示詞：<prompt 文件絕對路徑> 的「## 1. …」「## 2. …」text 區塊，照用；可依 master_still 的格式調整措辭，但不改外觀描述。
- spec 參數：`--facing right`、`--view "<斜俯視角度與朝向>"`、`--class hero`、`--finish pixel`、`--key <magenta 或 green>`、`--recap "<一句完整外觀摘要>"`。
- 共同風格：<像素風、頭身比、視角、朝向、無陰影…>

## 輸出位置
- <角色 A>：<絕對路徑>/
- 每位 3 張候選＋並排比較圖 `candidates-contact.png`。

## 驗收條件
- 每位 3 張 PNG，透明背景、單一角色、手腳未裁切、朝向正確（朝向相反就水平鏡像交付，保留原始 generated.png）。
- 外觀逐條：<角色 A 的關鍵特徵>；<角色 B 的關鍵特徵>。
- 做不到（沒有可用的生圖路徑、參考圖附不上）就直說並停下，不要改用 codeart 程式繪圖替代。

## 回報
寫到 <REPORT.md 絕對路徑>，≤20 行：route_media 回報的 provider/model、每張候選路徑、比較圖路徑、與外觀條件不符之處、遇到的問題。
```

## 第二輪：修改選定的圖（EDIT.md）

```markdown
# 派工：修改選定的原畫

使用者選了 <角色/candidate-NN>。用 `master_still.py edit`（「THE ONLY CHANGE: ...」格式）各修一次，每位 2 張候選；不要 approve。

## 修改
- <角色>/candidate-NN.png：THE ONLY CHANGE: <一件事，英文描述>；<列出必須不變的部位：臉、表情、服裝、姿勢、像素風、視角、朝向>。

## 輸出
- <角色>/edit-01.png、edit-02.png
- 每位一張比較圖：原圖＋兩張 edit（edits-contact.png）

## 驗收
- 只有指定處改變；朝向正確；透明背景、無裁切、無陰影。
- 做不到就直說並停下。

## 回報
寫到 <EDIT-REPORT.md 絕對路徑>，≤12 行：路徑、生成路徑、偏差（哪些非指定部位也被重畫了）。
```

一次改兩件事（例如站姿＋眼睛）可以，但要編號列出；實測線條眼這類細節常改不到，兩張候選裡通常只有一張達標。
