---
status: accepted
---

# The draw resolves the instant the ball enters the start pocket

A reader looking at a pachinko playfield full of simulated nails will reasonably assume the physics decides whether you win — that is how the Shōwa-era mechanical machines worked, and it is what the visuals suggest. It is not how this machine works. The ball's only job is to reach the start pocket; the moment it does, the outcome is drawn and fixed. Everything after that — which way the ball bounces out, how long the orbital alignment takes, whether the black hole shows up — is presentation over a settled result.

We chose this because we are reproducing a **modern digital** machine, where the drama lives in the presentation and the payout state machine, not in the ball path. The consequence worth naming: the physics is load-bearing for exactly one number, the start rate (see `CONTEXT.md`), and for nothing else. Do not add physics fidelity hoping it will make the game fairer or more interesting — it cannot reach the outcome.

## Probability and ball count are development knobs, not design values

The design values are **1/319** and a **3000-ball** session; those are what the Lean-in Test runs on. During development the constants sit at **1/99** and **1000 balls** so a presentation change can be seen within ten minutes instead of half an hour. Anyone reading 1/99 in the source is looking at a knob, not at the design.
