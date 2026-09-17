---
status: accepted
---

# SP reliability is 25%, set by the Lean-in Test rather than by genre convention

Anyone who knows real machines will read a 25% SP reliability as too low — real SPリーチ sits around 30–50%. The number is deliberate. Appearance rate and reliability are not independent: they multiply into the jackpot rate, so raising one lowers the other. At 1/319 over the 333-spin baseline session, that trade decides how often the acceptance run is even judgeable:

| SP reliability | SP appears | Sightings per session | P(≥ 3 sightings) |
| --- | --- | --- | --- |
| 25% | every 79.8 spins | 4.2 | **79%** |
| 40% | every 127.6 spins | 2.6 | 48% |
| 50% | every 159.5 spins | 2.1 | 35% |

The Lean-in Test (see `CONTEXT.md`) judges a repeated reaction, so a session with two sightings tells us nothing — and at genre-normal reliability that is most sessions. 25% is the setting where the test usually works, and it is still high enough to be worth wanting and low enough to still hurt.

Even at 25%, roughly one session in five falls short; those sessions are rerun rather than judged, which is why `sim.gd` checks P(≥3) as an explicit acceptance-condition health metric rather than as a machine-quality one.

## Presentation paths are mutually exclusive terminals

Reliability only adds up if each spin belongs to exactly one path, chosen at the moment of the draw alongside the outcome itself (ADR 0002). There are four:

| Terminal path | Rate at 1/319 | Rate at 1/99 | Reliability |
| --- | --- | --- | --- |
| Straight miss | 0.875000 | 0.875000 | 0 |
| Normal-stop | 0.112461 | 0.084596 | **0** |
| SP miss | 0.009404 | 0.030303 | — |
| SP jackpot | 0.003135 | 0.010101 | — |

Each column sums to 1. SP takes 4/319 of which 1/319 is a jackpot, so reliability is exactly 25% — the rate is derived from the jackpot rate rather than chosen independently. Normal-stop reliability is a clean **zero**: every win is on an SP path by construction, so a reach that stops without escalating was never a candidate.

The distinction that keeps this consistent is between two quantities that are easy to conflate. **Reach-passed = 1/8** is what the player perceives as reach frequency, and it includes the SP paths, because an SP path is still *rendered* as a reach that then escalates. **Normal-stop = 1/8 − SP rate** is the terminal one, and it is the only one that carries a reliability. Counting escalation as a separate event on top of the reach would double-count it; the path is picked once, at the draw.

The design rule that falls out — **a normal reach that stays put is already dead** — is worth keeping deliberately: it makes the appearance of the black hole the only signal that means anything. What it costs is that normal reach has to carry its suspense somewhere else, which is why the escalation window is a specified, bounded thing in `README.md` rather than an implementation detail.

## What the development knob can and cannot validate

At the 1/99 development value SP appears every 24.75 spins, three times in a ten-minute session. What that buys is iteration speed on the sequence itself.

What it does not buy is pacing. Holding reach-passed at 1/8 while SP appears 3.2× more often means escalation runs at 32% during development and 10% at acceptance; pinning escalation at 10% instead would mean a reach every 2.5 spins, which is noise. There is no setting where both match, and the gap is not removable.

So the knob has a stated scope: **the development value validates the legibility and quality of a single SP sequence; it cannot validate the reach economy or whether the wait is worth it.** Those are only observable at design values, which is exactly the split ADR 0009 makes into two separate tests. If the test is ever replaced by something that does not need repeated observation, the 25% should go back up toward the genre norm.
