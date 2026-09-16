---
status: accepted
---

# SP reliability is 25%, set by the Lean-in Test rather than by genre convention

Anyone who knows real machines will read a 25% SP reliability as too low — real SPリーチ sits around 30–50%. The number is deliberate. A layer's appearance rate and its reliability are not independent: they multiply into the jackpot rate, so at 1/319 a 40% SP can only appear about once every 160 spins, which is 1.5 sightings in a 240-spin session. The Lean-in Test (see `CONTEXT.md`) judges a repeated reaction, and it cannot judge anything from 1.5 samples.

So the split is one SP every 80 spins at 25% reliability — three sightings per acceptance session. 25% is still high enough to be worth wanting and low enough to still hurt.

That split consumes almost the whole probability budget on its own: `(1/80) × 25% = 0.003125`, against 1/319 = 0.003135. Normal reach is left with roughly 0.008% reliability, which is a derived consequence, not a choice. The design rule that falls out of it — **every win escalates to SP**, so a normal reach that stays put is already dead — is worth keeping deliberately: it makes the appearance of the black hole the only signal that means anything.

The same ratio holds when the probability knob moves to the development value of 1/99: SP then appears roughly every 25 spins, three times in a ten-minute session, so what is tuned during development is what is judged at acceptance. If the test is ever replaced by something that does not need repeated observation, this number should go back up toward the genre norm.
