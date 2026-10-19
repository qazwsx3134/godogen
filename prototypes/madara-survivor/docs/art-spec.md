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

## 5～7. 施術忍者（mob；火 key green、水 key magenta、土 key green）

同一個身形，配色和結印特效不同：

```text
a generic ninja jutsu caster: forehead protector (no symbol), dark clothes with a sleeveless short coat, both hands
forming a hand seal in front of the chest, a small glow of <ELEMENT> chakra around the hands.
```

| 元素 | 外套顏色 | 手邊光的顏色 | `<ELEMENT>` 填入 |
|---|---|---|---|
| 火 | 暗紅 | 橘紅 | `orange fire` |
| 水 | 藍 | 水藍 | `blue water` |
| 土 | 褐 | 黃褐 | `brown earth and stone` |

## 8. 精英（mob，key magenta）

```text
an elite jonin commander (generic): white long hooded cloak with a red trim over dark armour, metal-plate headband,
confident stance, one hand raised ready to cast.
```
