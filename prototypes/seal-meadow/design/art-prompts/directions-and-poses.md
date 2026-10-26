# 方向與動作填空字串

把下面的英文整句貼進 prompt 的 `{DIRECTION}`、`{POSE}`、`{MONSTER}`。

## 方向 `{DIRECTION}`

「右」都是畫面的右邊。左側三向由程式鏡像，不畫。

| 資料夾 | 玩家 | 怪物 | 英文 |
|---|---|---|---|
| front | ✔ | ✔ | facing the viewer, body and face turned straight toward the camera |
| front_right | ✔ | — | turned diagonally toward the lower-right of the screen, face and chest visible in three-quarter view |
| right | ✔ | ✔ | in side profile facing screen right |
| back_right | ✔ | — | turned diagonally toward the upper-right of the screen, mostly seen from behind, only the cheek edge visible |
| back | ✔ | ✔ | facing away from the viewer, seen fully from behind, face not visible |

## 玩家動作 `{POSE}`

武器拿在**角色自己的右手**（解剖學右手），方向改變時也不換手。

| 檔名 | 英文 |
|---|---|
| idle_1 | relaxed standing pose, arms loose at the sides, weight even on both feet |
| idle_2 | same relaxed standing pose with a slight breathing rise: shoulders and head 2 percent higher, arms a touch further from the body |
| walk_1 | walking, contact pose: left foot forward touching the ground heel first, right foot back, right arm swinging forward, left arm back |
| walk_2 | walking, passing pose: right leg lifted and passing under the body, left foot planted, body at its highest point, arms near the sides |
| walk_3 | walking, contact pose mirrored in the legs: right foot forward touching the ground, left foot back, left arm forward, right arm back |
| walk_4 | walking, passing pose: left leg lifted and passing under the body, right foot planted, body at its highest point |
| attack_1 | attack wind-up: right arm raised high behind the head as if holding a sword overhead, torso twisted back, front knee bent |
| attack_2 | attack swing: right arm sweeping forward and down in a strong diagonal strike, body leaning into the move, back heel lifted |
| attack_3 | attack follow-through: right arm low and across the body after the strike, torso turned forward, recovering balance |
| hurt_1 | hit reaction: head and torso snapped backward, eyes squeezed shut, arms flung slightly out, one foot sliding back |
| down_1 | knocked down: lying on the back on the ground, eyes shown as two small spiral swirls, limbs loose; still drawn inside the same canvas with the body on the baseline |

## 怪物動作 `{POSE}`

| 檔名 | 英文 |
|---|---|
| idle_1 | resting pose, relaxed, body slightly squashed |
| idle_2 | same resting pose with a gentle breathing stretch: body 3 percent taller and slightly narrower |
| walk_1 | moving, first step or hop start: body squashed low, ready to push off |
| walk_2 | moving, mid-step or mid-hop: body stretched and lifted, feet off or nearly off the ground |
| walk_3 | moving, second step: landing, body squashed wide |
| walk_4 | moving, recovering: body back to normal shape, feet planted |
| attack_1 | attack wind-up: body pulled back and compressed, angry eyebrows, about to lunge |
| attack_2 | attack strike: lunging forward toward the facing direction with the main weapon part (teeth, tusks, head or fists) leading |
| hurt_1 | hit reaction: body knocked back and squashed, eyes shut tight, small sweat drop |
| down_1 | defeated: flopped flat on the ground, eyes shown as two small spiral swirls |

## 怪物 `{MONSTER}`

照抄 [20-monster-master.txt](20-monster-master.txt) 裡該怪物的 IDENTITY 段落與 SIZE 句。
