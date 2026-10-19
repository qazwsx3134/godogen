# 美術規格與生圖提示詞

## 遊戲裡怎麼用

- 角色是 3D 場景裡的公告板圖：腳底是錨點，鏡頭從約 42° 斜俯視。
- 手機上角色顯示約 80～140 px 高。原圖畫到約 512 px 高，遊戲縮進 256 px 的圖集格子。
- 動畫用**關鍵姿勢靜態圖**：每個動作 1～2 張，程式補彈跳、擠壓、殘影。
- 每個角色只畫朝右下一個方向，朝左時用程式水平翻轉。

| 角色 | 姿勢 | 張數 |
|---|---|---|
| 斑 | idle、跑 A／B、直拳、飛踢（收尾）、團扇揮擊、結印 | 7 |
| 一般忍者 | 跑 A（原畫本身）＋跑 B | 2 |
| 施術忍者 | 跑、結印施術 | 2 |

## 共同風格（每個 prompt 都套用）

```text
Japanese TV-anime cel shading: clean dark ink outlines (thick enough to read at 100 px tall),
flat base colours with one shadow tone, no gradients, no painterly texture, no background,
single full-body character standing on an invisible ground line, feet fully visible,
elevated three-quarter overhead view about 42 degrees, body turned diagonally toward the lower-right,
heroic proportions about 6 heads tall, readable silhouette, no cast shadow, no text, no logo.
```

## 1. Madara（主角，hero，key green）

```text
Uchiha Madara from Naruto Shippuden in his Fourth Great Ninja War appearance: very long, wild, spiky black hair
falling past his waist with a long fringe covering his right eye, pale skin, sharp face, red Sharingan eye visible,
dark navy high-collared long-sleeved shirt, segmented crimson-red samurai-style armour (chest plate with horizontal
plates, large red shoulder guards, red armoured skirt panels to the knees), dark navy trousers, white bandages
wrapped around the shins, black ninja sandals, holding a large round war fan (gunbai: cream-white face with a red
circle, wooden handle) in his right hand at his side. Calm, arrogant expression.
```

recap：`Uchiha Madara in crimson segmented armour with long spiky black hair and a white-and-red war fan`

## 2. 下忍（mob，key magenta）

```text
a generic young male leaf-village ninja soldier (not any named character): short black hair, forehead protector
headband with a plain metal plate (no symbol), olive-green padded flak vest with scroll pockets over a dark navy
long-sleeved shirt, dark navy trousers, shin bandages, holding a kunai, running stance leaning forward.
```

## 3. 蒙面忍者（mob，key magenta）

```text
a generic masked ninja soldier: dark grey flak vest, black cloth mask covering the lower face, metal-plate
headband (no symbol), dark grey clothes, a kunai in each hand, fast low sprinting pose.
```

## 4. 重裝忍者（mob，key magenta）

```text
a big, broad heavy ninja soldier: brown armoured flak vest, thick arm guards, metal-plate headband (no symbol),
dark brown clothes, carrying a large wooden war hammer, heavy marching stance.
```

## 5～7. 施術忍者（mob；火 key magenta、水 key green、土 key magenta）

三種各自一套服裝，參考使用者給的 `docs/naruto/doc/` 三張圖（只抄服裝，不抄臉；參考圖不進版控）。共同點：雙手在胸前結印，手邊一小團該屬性的查克拉光。

```text
a ninja jutsu caster, both hands forming a hand seal in front of the chest, a small glow of <ELEMENT> chakra around
the hands. <OUTFIT>
```

| 元素 | 參考圖 | 服裝重點 | `<ELEMENT>` |
|---|---|---|---|
| 火 | `konoha.png` | 木葉制服：橄欖綠防彈背心（立領、胸前卷軸口袋、肩扣）、深藍長袖與長褲、左肩紅色漩渦臂章、護額 | `orange fire` |
| 水 | `water.png` | 灰色連帽寬袖上衣、下擺斜裹；白色單肩胸甲（三道刻線）；深灰燈籠褲、膝上白布交叉綁帶；暗紅護臂與綁腿；深紫灰忍者涼鞋；背一把紅白纏柄刀；白色刺髮、護額 | `blue water` |
| 土 | `sand.png` | 砂隱風：卡其橄欖背心（高領、大肩甲、腰間一排口袋）、深褐長袖與長褲、白頭巾從護額後垂到背、大腿白繃帶 | `brown earth and stone` |

key 顏色跟著衣服改：火和土的背心是綠色系，用 magenta；水有暗紅，用 green。

## 8. 精英（mob，key magenta）

```text
an elite jonin commander (generic): white long hooded cloak with a red trim over dark armour, metal-plate headband,
confident stance, one hand raised ready to cast.
```
