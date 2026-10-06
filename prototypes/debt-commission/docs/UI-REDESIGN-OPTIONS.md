# 四款可切換介面風格

更新：2026-10-06。前三款以 [UI options](ui-options/index.html) 為視覺基準，第四款「銀魂和紙」依 [v2 Option A](../../../docs/story-telling-game/v2/story-telling-ui2.jpeg) 製作。標題與遊戲目錄均可切換；偏好儲存於獨立的 `user://ui_preferences.cfg`，不改變劇情存檔或閱讀位置。

| 風格 | 畫面與元件 |
| --- | --- |
| A 月下映畫 | 彩色立繪、低彩度夜景；漸層墨藍對話區、青色細線、菱形說話者記號、分隔線推進鈕。 |
| B 萬事屋委託簿 | 暖色場景；紙張雙框、朱紅側線、說話者印記與圓形「續」印章。 |
| C 吐槽分鏡 | 黑白場景與立繪；黑色框線、偏移陰影、對話框尖角、紅色斜切推進鈕。 |

| D 銀魂和紙 | 米色紙面、深藍圓角雙框與姓名牌；左下淡藍青海波、右下粉櫻花，紙框下方是深藍閱讀按鈕。 |

## 遊戲中的操作

對話區依完整台詞的內容配置高度，打字途中保持位置穩定。閱讀工具列提供 **目錄／回顧／自動**，右側推進鈕補完當句或前進。分支回應集中於底部選項面板，限時吐槽顯示真實計時。

目錄集中儲存、讀取、略讀及其他閱讀功能。目錄標題與關閉鈕保持固定，閱讀動作與兩欄風格選擇器可以捲動。標題採底部卡片，保留故事選擇、四款風格與新遊戲／續讀操作。

銀時使用與預覽相同的既有彩色立繪；分鏡風格轉為黑白。尚無立繪的角色透過姓名與台詞登場。

## 比對方式

- [HTML 對話比較](ui-options/comparison-dialogue.png)、[HTML 四選一比較](ui-options/comparison-choices.png)是設計基準。
- 遊戲截圖使用真正的討債劇本：選擇先聽銀時說明，走到「這次的理由比較長。先從我小時候說起——」，與 HTML 預覽比對相同台詞。
- 分別檢查 390×844 與 320×568，包含四款對話、長篇旁白、選項、目錄與標題。觸控按鈕以實際畫布縮放後的尺寸檢查。
- 功能驗證與視覺驗收分開：偏好記憶、切換保留位置及存讀檔檢查，不能代替實際畫面比對。

## 實作

各款的對話框、標題、目錄與選項位於 `scenes/ui/*_<style>.tscn`；`main.gd` 在切換風格時掛載對應場景。`scripts/ui_ornament.gd` 繪製框形與推進鈕，`scripts/ui_styles.gd` 管理配色與互動狀態，`scripts/ui_stage_style.gd` 管理場景色調。

Godot MCP Toolkit 用於啟動原生遊戲、取得實際執行截圖與檢查錯誤；Web 版另外以真實 Canvas 觸控檢查不同手機比例。

## 設計依據

[TODO](../TODO.md) 的參考圖、[早期試作](UI-TRIAL.md)及 `game-ui-design` 的 patterns、sharp_edges、validations。HTML 中的靜態計時與示意功能不作為遊戲資料。Android／iOS 真人實機閱讀與手勢仍需實際試玩。

## 第四款驗證（2026-10-05）

- UI styles、選項、漫畫演出與 EP00（895 checks）headless 測試通過；編輯器副本的靜態文字與間距在執行後保留，執行狀態不改写原始場景。
- [390×844 實際對話](preview-gintama-390.png)、[320×568 實際對話](preview-gintama-320.png)。Web 驗收包含標題切換、長旁白、分支選項、銀時台詞，以及開關目錄保持閱讀位置。

## 第四款還原修正（2026-10-06）

以原圖下方對話框為直接對照：720×1280 下紙框約 x=10、y=1005、寬 700、高 193；名字牌跨在紙框上緣。雲形深藍金邊、喇叭、淡紙紋、左下青海波、右下櫻花與框內下一句三角改用原圖經 imagegen 去背／清字的透明 PNG；明體正文、名字與按鈕標籤保存在可編輯的 scene。底列依原圖順序為 LOG、AUTO、SKIP、MENU，圖示與文字各是子 node；可見按鈕高度約 41 px，透明觸控範圍至少 48 CSS px。

- [原圖與 Godot 並排](gintama-reference-comparison.png)：左右皆為同一句「今天也完全沒有工作啊。」，以 UI 區域原尺寸裁切；背景與立繪仍使用遊戲既有素材。透明素材為模型輔助去背／補圖，尚未獲作者確認逐像素相同；[素材與提示詞](../assets/ui/GINTAMA-EXTRACTION.md)保留來源。
- 同一句的完整實際畫面：[720×1280](preview-gintama-reference-720.png)、[390×844](preview-gintama-reference-390.png)、[320×568](preview-gintama-reference-320.png)。[瀏覽器報告](gintama-reference-report.json)保留每個閱讀按鈕的矩形與檢查結果。
- 三種尺寸均以真實 canvas 觸控驗證 LOG／MENU 返回同一句台詞，以及 AUTO／SKIP 開關；兩種手機尺寸另檢查長旁白、分支、選單和每個操作目標至少 48 CSS px、不出界、不互相重疊；沒有頁面或 Godot 腳本錯誤。
- `test_ui_styles.gd`、`test_investigation.gd`、`test_phase4_rounds_ui.gd` 通過。場景存檔驗證 68 個 node 與四個閱讀按鈕子 scene 參照；修改場景副本的正文左間距後 instantiate，`_ready` 保留修改，執行文字和名字狀態未改寫來源 scene。
- Web 匯出成功；編輯器外掛在退出時仍有既有資源洩漏訊息，實際 Web 操作無此錯誤。Android／iOS 真人視覺與觸控驗收仍待完成。

同一句截圖與四按鈕驗證可重跑：

```sh
node tools/check_gintama_reference.mjs --url http://127.0.0.1:5194/ --playwright /path/to/playwright --out test-results/gintama-reference
```

2026-10-06 波紋溢出修正：紙框、波紋與櫻花合成單一透明底圖，`PaperCutout` 用 NinePatch 保留四角，`Frame.clip_contents` 限制繪製範圍。UI styles 回歸額外驗證紙框四角為透明、啟用裁切，且沒有獨立的波紋／櫻花 node 可再溢出。

作者已確認透明 PNG 紙框版本可採用（2026-10-06），並指定後續對話框與按鈕延續此樣式。新安裝的預設風格為銀魂和紙；文字演出與新閱讀面板驗證見 [C–E 交付紀錄](READING-CHAPTER1.md)。
