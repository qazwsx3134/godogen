---
status: accepted
---

# Session length is tuned with the fire interval, never with the ball bank

A 3000-ball session on a standard machine is 333 spins before any payout comes back, and at a real machine's legal firing rate of 100 balls per minute that is about 40 minutes of firing. The Lean-in Test asks a person to sit through it attentively, so the length matters — and there are exactly two ways to shorten it.

Cutting the ball bank is the wrong one. ADR 0005 sets SP reliability at 25% specifically so that a session produces three SP sightings, because a test that judges a repeated reaction cannot judge anything from one. The bank is what buys those spins. Halving it halves the sample and quietly invalidates the acceptance condition that the number was derived from in the first place.

So the fire interval is the knob: **0.4 seconds per ball**, 150 per minute, which brings the no-payout baseline to 27 minutes with the SP count untouched at 4.2. Real machines cap at 100 per minute because of Japanese gaming regulation, not because of feel, and ADR 0005 already accepts departing from real-machine convention when the test requires it. The same reason applies here.

The acceptance run also does not need the whole bank. The judgement point is the **third SP sighting** — median around spin 240, roughly 19 minutes in — and the session can end there.

The consequence to keep in mind: at 0.4s the playfield sees 50% more simultaneous balls than a real machine, which lands on the `RigidBody2D` count and therefore on the mobile Safari frame budget (ADR 0004). If the fire interval ever has to go back up for performance reasons, session length goes up with it — the bank still does not move.
