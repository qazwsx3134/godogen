---
status: accepted
---

# Nails are nudged at the start of every session

Real parlours adjust their machines' nails daily, and picking a generous machine is one of the things the hobby is actually about. So every session nudges the nail positions slightly: this run's machine is a little kinder or a little meaner than the last one's.

What this does **not** touch is the draw. Per ADR 0002 the outcome is fixed the moment a ball reaches the start pocket, so nails cannot change the jackpot rate — they change only how many draws a given number of balls buys. The mean case is one spin per 12 balls. The harsh end of the range is not a taste call — it is derived, and an earlier draft of this ADR got it wrong.

ADR 0005 needs three SP sightings. On the no-jackpot baseline that is `3 ÷ (4/319) = 239` spins, and 3000 balls buys that many only while `3000 ÷ (rate − 3) ≥ 239`, i.e. **one spin per 15.5 balls or better**. This ADR previously named 16 as the harsh end and claimed it kept the floor intact; 16 yields 2.90 sightings, so it did not. The range is one spin per 10 balls to one per 15.5.

The roll is a normal distribution about the standard machine, clamped to that derived cap — not a uniform spread, because a parlour keeps most of its machines near standard and the generous and mean ones are the exceptions. Measured over 20 rolled machines by actually firing balls (`tools/measure_nail_spread.gd`, 5000 balls each), the realised spread runs 9.8 to 14.0 with the mean on 12.0 — the meanest of them still expecting 3.4 sightings.

Two consequences:

- **Acceptance runs on a fixed standard machine** (one spin per 12 balls), not a rolled one. The Lean-in Test has to be repeatable — with a rolled machine, a presentation change that feels worse is indistinguishable from an unlucky roll.
- **The simulation safety net checks a distribution, not a value.** Start rate now has to land within range at both extremes and on average, and the check reruns whenever the nail randomisation range is touched.

A real player cannot see a nail adjustment; they infer it by counting spins. We keep that — the spin rate is hidden behind a button rather than sitting on the HUD, so checking whether this machine is any good stays something the player chooses to do. On a 9:16 phone it also keeps the panel clear.
