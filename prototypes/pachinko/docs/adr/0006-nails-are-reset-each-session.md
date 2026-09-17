---
status: accepted
---

# Nails are nudged at the start of every session

Real parlours adjust their machines' nails daily, and picking a generous machine is one of the things the hobby is actually about. So every session nudges the nail positions slightly: this run's machine is a little kinder or a little meaner than the last one's.

What this does **not** touch is the draw. Per ADR 0002 the outcome is fixed the moment a ball reaches the start pocket, so nails cannot change the jackpot rate — they change only how many draws a given number of balls buys. The observable range runs roughly from one spin per 10 balls to one per 16, which over a 3000-ball session is 428 spins down to 230, and therefore 5.4 SP sightings down to 2.9 before any payout comes back. The mean case is one spin per 12 balls. The meanest roll still expects roughly three sightings, and acceptance runs on a fixed standard machine anyway (below), so the range does not reach ADR 0005's sample argument — but a wider one would put the meanest roll below three, and at that point the nails would be deciding whether a session is judgeable.

Two consequences:

- **Acceptance runs on a fixed standard machine** (one spin per 12 balls), not a rolled one. The Lean-in Test has to be repeatable — with a rolled machine, a presentation change that feels worse is indistinguishable from an unlucky roll.
- **The simulation safety net checks a distribution, not a value.** Start rate now has to land within range at both extremes and on average, and the check reruns whenever the nail randomisation range is touched.

A real player cannot see a nail adjustment; they infer it by counting spins. We keep that — the spin rate is hidden behind a button rather than sitting on the HUD, so checking whether this machine is any good stays something the player chooses to do. On a 9:16 phone it also keeps the panel clear.
