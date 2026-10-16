# 本地套件相容性補丁

## Dialogue Manager 4.1.0：Godot 4.7 編輯器字級（2026-10-16）

固定上游版本與 MIT 授權保留。`addons/dialogue_manager/utilities/theme_values.gd`
先讀 Godot 4.7 的 `interface/editor/fonts/code_font_size`，再退回舊 key；兩者皆無有效值時採用 16。

起因：乾淨的 Godot 4.7 EditorSettings 不含舊 key，導致初始化四個編輯器面板時將 Nil 指派給 int。
此補丁以 headless editor 的重新匯入驗證；不變更遊戲 runtime 或編寫格式。

來源：[Godot EditorSettings 官方參考](https://docs.godotengine.org/en/latest/classes/class_editorsettings.html#class-editorsettings-property-interface-editor-fonts-code-font-size)。
更新 Dialogue Manager 前先確認上游是否已採用新 key，再決定是否保留本地差異。
