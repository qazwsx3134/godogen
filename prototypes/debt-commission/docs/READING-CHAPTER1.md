# C–E 交付紀錄（2026-10-06）

作者已確認銀魂和紙透明 PNG 版本可採用，並指定後續對話框與按鈕沿用。新安裝預設該風格，既有偏好繼續保留。

## 可玩的內容

- 第一章：`?sample=chapter1`（新啟動的預設），來源 `story_src/chapter1.dialogue`＋`chapter1.blocks.json`，建置輸出 `data/chapter1_story.json`；保留「上機試讀版」。採用草稿 v0.2 已核准 P1–P8，220 句及四級結算評語可由 [追溯表](chapter1-source-map.json) 對照句號。
- 文字演出：`?sample=text_effects`。四款對話框皆支援重點色、放大、抖動、句中停頓、慢速、標點停頓與角色打字音；正文／補完／AUTO／SKIP／紀錄／QA 使用可讀字元。背景交叉淡化、黑幕淡入淡出與立繪動畫會在換章／讀檔／重開／略讀取消。
- 目錄：上一句、快速存檔、快速讀檔。回滾限同一閱讀段落，還原旗標／素材／舞台／音樂／紀錄；不能跨互動邊界。快速格與自動檔、18 格手動檔各自獨立，毀損檔回退有效備份。
- 設定：小／標準／大字級、65%／82%／100% 紙底透明度，立即套用並記住；文字／名字／按鈕維持不透明。窄手機可捲動設定與選單。

```
開冰箱 → 客廳調查（四線索；可選話題／廚房）
         ↓
銀時證言 → 神樂證言（牌子／條件隱藏線）
         ↓
兩人連擊（C1–C4 或龜派氣功）→ C5 QTE
         ↓
薪水袋與定春反轉 → S／A／B／C 結算

眼鏡歸零 → Game Over → G05 備用眼鏡 → 該回合檢查點
```

## 可編輯 scene

`dialogue_log.tscn`＋`log_entry.tscn`、`save_slots_panel.tscn`＋`save_slot_card.tscn`＋`save_overwrite_confirmation.tscn`、`end_controls.tscn` 已保存完整場景樹，主要留白與排列由 anchor／Container 決定。Godot 保存時驗證 owner 與 node 數，測試再 pack／載入確認 8／3／74／8／10／4 nodes，六個存檔卡保留 item scene 參照；改文字／間距後執行仍保留，正常執行不重建來源。

## 驗證

- `test_chapter1.gd`：九條完整路線（完美、隱藏、超必殺、弱吐槽／未聆聽、逾時、重試及 1／2／4 次失敗），四線索、三個話題、廚房往返、聆聽素材、牌子、條件隱藏、C1–C4／C5、薪水袋、S／A／B／C；每個關鍵位置 snapshot／restore 不增素材或計分。
- `test_dialogue_text.gd`／`test_text_presentation.gd`：ICU grapheme、格式、停頓、四款 RichText、紀錄一致、打字音政策與取消舊動畫。
- `test_reading_convenience.gd`／`test_reading_scenes.gd`：回滾狀態與互動邊界、快速格備份／隔離、字級與紙底 alpha、scene 序列化與編輯器保留。
- 29 組引擎測試全數通過，見 [測試報告](reading-chapter1-tests.json)。原有全部測試一併回歸。舊測試明確指定 cinema，避免把「新安裝預設」當成固定 cinema；手勢測試先捲動讓選單列進入視窗再點按，保留真實輸入斷言。首次 headless 回合 UI 測試曾遇 Godot 4.7 原生 signal 11，單獨重跑通過。
- `check_gintama_reference.mjs`：720×1280、390×844、320×568 的參考台詞及 LOG／AUTO／SKIP／MENU 實點。
- `check_reading_chapter1.mjs`：390×844／320×568 真實觸控新閱讀入口，已通過調查、牌子、超必殺及 C5 文字完成後才進 QTE；最後的自動精準點按未能建立 perfect 時序，Web 到結算需再覆驗，見 [實點報告](reading-chapter1-web.json)。QA 只讀狀態，不注入遊戲流程。熱區驗證修正了廚房返回後角色熱區未重建、沙發線索被底列遮住。

實際畫面：[390 設定](chapter1-390-settings.png)、[320 存檔欄位](chapter1-320-save.png)、[320 牌子](chapter1-320-placard.png)。

## 尚待真人與資產

作者試讀修訂、真人遊玩時間量測、Android Chrome／iOS Safari 實機驗收，以及正式語音／音效。PERFECT 可放入 `assets/audio/voice/shinpachi_tsukkomi_01.ogg` 至 `_08.ogg`；缺少錄音時正常運作，合成音效保留。Chromium 手機尺寸模擬不代替手機真人驗收。
