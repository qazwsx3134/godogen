# Madara's Skill Progression: Growth and Satisfying Power at the Same Time

> The user's direction (2026-10-19): start with taijutsu, and learn new jutsu as you level up: fan, fire release (small fireball growing large), Sharingan, Susanoo, Chibaku Tensei, Wood Release.
> Design principles from doc1 to doc3: battlefield dominance, not survival; "strong → more absurd," not "weak → strong."

## The core contradiction and how to resolve it

```
Growth needs a "weaker at first" feeling   ←→   Madara's fantasy is "strong from the start"
```

**Resolution: Madara is strong from the very first second. What grows is the "number of moves" and the "scale."**
Basic attacks are never "unusable at first, fixed later."

| Axis of growth | What the player feels | Example |
|---|---|---|
| ① New moves (verbs) | "I learned something new" | Taijutsu → fan → fireball → Wood Release → Susanoo |
| ② Scale (size and count) | "My moves are getting bigger" | Fireball from a fist-sized ball to one bigger than a person; camera pulls back |
| ③ Mechanic change | "This move behaves differently now" | Fireball leaves burning ground → burning spreads → explosion chains |
| ④ Enemy scale | "The battlefield can't hold me anymore" | 20 people → 300 people → a sea of ninja |

The four axes take turns. **Every 60–90 seconds there must be one noticeable power spike.** If the run stays in the same state for 2 minutes, it gets boring.

## Power curve over one run (10 minutes)

```
Power ▲                                              ┌ Chibaku Tensei (ultimate)
      │                                     ┌────────┘ Perfect Susanoo
      │                           ┌─────────┘ Fusion: Great Fire Annihilation
      │                 ┌─────────┘ Susanoo (ribcage → half-body)
      │        ┌────────┘ Sharingan / Wood Release
      │  ┌─────┘ Fan / Great Fireball
      │──┘ Taijutsu (one-shots a genin from the start)
      └──────────────────────────────────────────────► Time
        0:00  1:00   2:30    4:00    6:00    8:00  10:00
```

## The jutsu

Each jutsu has 5 levels. **Every level must be visible on screen.** "+10% damage" never appears on its own; numbers only come bundled with a visual change.

### 1. Taijutsu (starting move)
- **Role**: close-range three-hit combo. The third kick sends a target flying into the crowd (a human cannonball).
- **Level-up path**: Lv2 faster combo → Lv3 longer reach → Lv4 the third hit releases a shockwave ring → Lv5 the third hit sends the target flying farther and harder.
- **Satisfaction**: at Lv1 every hit kills a genin. Bodies send the people behind them flying.

### 2. Fan (Gunbai)
- **Role**: medium-range 120° cone with big knockback; clears the front.
- **Level-up path**: fan grows → Uchiha Counter (deflects projectiles back) → each swing raises a gust of wind (the dust visibly gets bigger).

### 3. Fire Release: Great Fireball → Great Fire Annihilation (**the "small ball growing large" core**)

| Lv | Fireball | New mechanic |
|---|---|---|
| 1 | Fist-sized, small explosion | — |
| 2 | Human-sized | Explosion radius increases |
| 3 | Bigger than a person | **Leaves burning ground** behind |
| 4 | Two fireballs | Burning ground lasts longer |
| 5 | A giant fireball as tall as two people | Enemies that die burning **explode** |
| Fusion | **Great Fire Annihilation** (needs Fan Lv3+ and Fire Release Lv5) | A sea of fire pushing forward in a wave; burning **spreads between enemies** (the more enemies, the faster it spreads) |

### 4. Sharingan (rewards skillful play)
- **Perfect dodge**: dash within 0.2 s before an enemy hits you → 0.15 s slow motion → afterimage counterattack.
- Each level: crit rate up, longer dodge window, the counterattack hits more targets.
- Mangekyō (Lv5): you are briefly invincible after a perfect dodge.

### 5. Wood Release (control)
- **Deep Forest Emergence**: roots grow from the ground and bind every enemy in a ring (they can't move) → perfect timing for the fan or fire.
- **Wood Dragon**: a dragon pushes forward in a line, sweeping up everyone in its path.
- **Synergy with fire**: wood burns. Burning roots turn the fire damage into area damage.

### 6. Susanoo (visual progression is itself the reward)
- Learned stages: ribcage (blocks damage) → arm (swings sweep a wide area) → half-body (sword) → armored → **Perfect Susanoo**.
- Each stage makes Madara visibly larger and pulls the camera back. The battlefield shrinks; enemies turn into a sea.
- Mobile controls: Susanoo is an **active skill** (one button), running on a chakra gauge for a limited time.

### 7. Rinnegan: Chibaku Tensei (ultimate)
- **Charges from the Dominance bar** (kills, multi-kills, perfect dodges, killing elites). Fire it when full.
- Flow: music cuts out → a black core appears overhead → **every enemy on screen is pulled up into the sphere** → the sphere compresses → white flash → kill counter +N.
- This is the "moment worth recording" from doc2. It is also the performance stress test: the whole screen of enemies flying at once.
- Tengai Shinsei: Rinnegan + Susanoo fusion (Susanoo・Tengai). At the end of the run, during the Reward Phase, it's a meteor shower.

## Level-up cards

Three cards, drawn from the pool in a fixed order of priority:

```
Has an empty jutsu slot and is not among the guaranteed jutsu? → 1 of the cards must be a "new jutsu"
Fusion conditions met?                                         → a gold "???" card appears (you only see what it is after picking it)
Remaining cards                                                → upgrade owned jutsu (shows the visual change of the next level) / passive (chakra, movement speed...)
```

- **Guaranteed pacing**: Lv2 must offer a new jutsu, Lv4 must offer a new jutsu, Lv7 must offer Susanoo. This ensures the first 3 minutes contain at least two "learned something new" moments.
- Jutsu slots: 4 (taijutsu counts as one). Susanoo and the ultimate get their own buttons and don't take a slot.
- Card text **describes the change**: "The fireball grows bigger than a person, and leaves burning ground."
  Don't only write "+20%."

## Satisfying feedback grows along with your power

| Power stage | Kill counter | Camera | Music (Dominance) |
|---|---|---|---|
| Taijutsu / fan | 5–30 KILLS | Normal distance | Drums |
| Fire / Wood Release | 30–100 | Slightly pulled back | + strings |
| Susanoo | 100–300 | Pulled back | + taiko |
| Chibaku Tensei | 300+ in one hit | Wide shot + white flash | Full theme |

## Mobile controls (doc2: no more than 3 buttons)

```
Left side: joystick          Lower right: 瞬身 (dash)
                             Right: Susanoo (once learned)
                             Upper right: ultimate (lights up when Dominance is full)
```

Everything else (taijutsu, fan, fire, Wood Release) **casts automatically**. The player decides positioning, dashing, and the timing of the two big moves.

## Implementation order

1. ✅ Basics: movement, dash, enemy horde, knockback and human cannonball, hit stop, kill streaks (Milestones 1+2 are done).
2. **Next**:
   - Starting taijutsu
   - Jutsu slots and "learn new jutsu / upgrade" cards
   - Fan and Great Fireball (Lv1→5, growing)
3. Sharingan perfect dodge, Wood Release.
4. Dominance bar; Susanoo (stages and active button); Chibaku Tensei.
5. Fusion: Great Fire Annihilation, Susanoo・Tengai; burning spread.
6. Boss, Reward Phase, music layers.
