# 派工：修改選定的原畫（第二輪）

使用者選了 男 candidate-01、女 candidate-01。用 `master_still.py edit`（「THE ONLY CHANGE: ...」格式）各修一次，修完不要 approve，等使用者看過。

## 修改
- 男 `man/candidate-01.png`：THE ONLY CHANGE: 頭髮改成往後梳、貼頭的黑色油頭（slicked straight back, glossy, neat），額頭露出；臉、表情、西裝、紅領帶、駝背姿勢、像素風、視角、朝向全部不變。
- 女 `woman/candidate-01.png`：THE ONLY CHANGES: (1) 站姿改成直立、雙腳併攏或略開、身體挺直，一手自然垂下、一手微微前伸張掌；(2) 眼睛改成細長銳利的線條眼（narrow angular line eyes, no visible large iris, cold expression）。髮型髮色、服裝、白靴、像素風、視角、朝向右下全部不變。

每位可生成 2 張 edit 候選；去背、補邊方式同第一輪。

## 輸出
- `man/edit-01.png`、`man/edit-02.png`、`woman/edit-01.png`、`woman/edit-02.png`
- 每位一張並排比較圖：原 candidate-01 ＋ 兩張 edit（`man/edits-contact.png`、`woman/edits-contact.png`）

## 驗收
- 只有指定處改變；朝向右下；透明背景、無裁切、無陰影。
- 做不到就直說並停下。

## 回報
寫到 `/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/EDIT-REPORT.md`，≤12 行：路徑、生成路徑、偏差。
