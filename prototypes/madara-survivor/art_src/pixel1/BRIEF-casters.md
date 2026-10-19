# 派工：P1 收尾＋三種施術忍者改造型（P1b）

## 背景
- 使用者對火、水、土遁忍者有新的設計：三種各自一套服裝，參考 `docs/naruto/doc/` 的三張圖。
- 你在 P1 已經生成的 `caster-fire/`、`caster-water/`、`caster-earth/` 是舊設計（同身形換色），作廢。
- 你上次停在額度用完：elite、chakra、props 有 takes 但還沒處理完。

## 規則（同 P1）
- 一定要加 `--route codex-cli --finish pixel`。
- 共同風格、視角、比例照 `BRIEF.md`：HD-2D 像素、約 4 頭身、約 20° 俯視、朝右下。
- 不多骰。額度不夠就停在已完成的項目，在回報裡寫明。

## 順序
1. **先把 P1 收尾**：
   - 處理 elite、chakra、props 已有的 takes，做出 candidate 與 contact sheet。
   - 不重新生成。只有 take 真的不能用時才補生，並在回報裡寫明。
2. **把舊的施術忍者移走**：
   - 移到 `art_src/pixel1/rejected/caster-<元素>-v1/`。
   - 這個資料夾已被 gitignore。
3. **重新生成三種施術忍者**：
   - 每種 2 張，輸出到原本的 `caster-fire/`、`caster-water/`、`caster-earth/`。

## 三種施術忍者

共同點：
- 雙手在胸前結印，手邊有一小團該屬性的查克拉光。
- 都用 `--class mob --takes 2`。

各自的參考圖用 `--identity-ref` 附上，並設定：
- `--identity-copy "costume cut, colours, gear and silhouette only"`
- extra 寫明：不要照抄參考圖的臉、髮型以外的人物身分；臉畫成一般忍者雜兵。
- 參考圖是動畫原圖，畫風一律照像素規則，不要抄動畫線稿。

| 資料夾 | 參考圖 | key | 服裝（寫進 identity，英文） | 查克拉 |
|---|---|---|---|---|
| `caster-fire/` | `/Users/peter/repo/godot/godogen/docs/naruto/doc/konoha.png` | magenta | 木葉制服：橄欖綠防彈背心（立領、胸前兩排卷軸口袋、肩扣）、深藍黑長袖緊身上衣與長褲、左上臂紅色漩渦臂章、黑布護額 | orange fire |
| `caster-water/` | `/Users/peter/repo/godot/godogen/docs/naruto/doc/water.png` | green | 灰色連帽寬袖上衣，下擺斜裹；白色單肩胸甲（三道刻線）；深灰燈籠褲，膝蓋白布交叉綁帶；暗紅護臂與綁腿；深紫灰忍者涼鞋；背上斜背一把紅白纏柄刀；白色刺髮、護額 | blue water |
| `caster-earth/` | `/Users/peter/repo/godot/godogen/docs/naruto/doc/sand.png` | magenta | 砂隱風格：卡其橄欖背心（高領、大肩甲、腰間一排口袋）、深褐長袖與長褲、白頭巾從護額後面垂到背、大腿綁白繃帶 | brown earth and stone |

- 護額的金屬牌一律素面，不放村子標誌。
- 火遁的紅色漩渦臂章可以保留。
- key 已經依衣服配好：綠背心不能用 green key。

## 驗收
- 透明背景、單一主體、不裁切、朝右下。
- 三種一眼就分得出來：剪影和主色都不同。
- 刀、頭巾這類突出物不要被裁掉。
- 做不到就直說並停下，不要用程式繪圖代替。

## 回報
1. 更新 `art_src/pixel1/REPORT.md`，最多 20 行，寫明：
   - route
   - 各資料夾路徑
   - 偏差
   - 額度
2. 全部完成後建立 `art_src/pixel1/DONE`。

以上路徑都在 `/Users/peter/repo/godot/godogen/prototypes/madara-survivor/` 底下。
