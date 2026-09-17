---
status: accepted
---

# Running out of balls settles the pending draws instead of ending the session

The obvious reading of "持ち玉 hits zero, the session is over" leaves three things undefined, and every one of them is load-bearing: balls still in flight on the playfield, draws already accepted into the 保留 queue, and a jackpot that has been drawn but not yet paid out. Under ADR 0002 the outcome is fixed the moment a ball reaches the start pocket, so a queued draw is a result the player has already bought. Throwing it away because the bank happened to reach zero half a second later would make the single most consequential moment in the game depend on timing the player cannot control.

So zero balls starts a **settlement**, not an ending. Firing is disabled; balls in flight finish their run and still pay their 3-ball 賞球 and still produce a draw if the queue has room; queued draws play out in order; any jackpot among them pays out in full. Settlement ends when the queue is empty and the playfield is clear — and only then does the bank decide: still zero means the session is over, above zero means play resumes in whatever state it was in.

That last clause is what makes this one rule instead of several. A 3-ball 賞球 trickle and a 387-ball jackpot payout both simply leave the bank above zero, and both resume the same way. A trickle bounded by three more shots terminates on its own within seconds; no special case needed.

Two consequences:

- **The session-end ball count is always zero**, so it cannot be a simulation metric. What `sim.gd` measures instead is total spins, total payout, peak bank, chain length, and the end reason (`持ち玉歸零` or `主動結束`).
- **A session can end mid-chain.** If the bank empties during 確變, settlement runs, and if no jackpot comes out of the queue the chain dies there. That is the correct behaviour — a ループ 確變 is only worth what you can afford to keep playing.
