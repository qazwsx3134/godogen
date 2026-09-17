---
status: accepted
---

# Reconsidering iOS native now that development is on macOS

> **Resolved by measurement, and by more margin than expected.** On the target iPhone in mobile Safari, every variant tested — including full-screen and including the screen-reading one — holds **60 fps in steady state at double the physics load**. Web stays, comfortably.
>
> The first run read much worse (37 fps full-screen, 27 screen-reading) because it measured a cold machine: shader caching, WASM tier-up and clock ramp had not settled. That is worth keeping as the finding rather than the footnote — the cost here is front-loaded, not sustained, and the two need different remedies. Numbers and consequences in `TODO.md`.

ADR 0004 rules out an iOS native build with one sentence: *"Building for iOS needs macOS, Xcode and a paid Apple developer account; development happens on Linux under WSL."* Development is on macOS. The premise is false, so the conclusion has to be re-earned rather than inherited.

## What actually changed

Only one clause of ADR 0004 died. The rest still stands on its own:

- **Still true:** putting the machine in front of someone who has not seen it, with nothing but a link, is something only a web build does. TestFlight needs the paid Apple Developer Program and a review round; a free Apple ID sideloads to a device the developer physically holds, and the provisioning profile expires in seven days.
- **Now false:** that a native build is impossible here. With Xcode installed it is a Godot iOS export plus an Xcode build step.

So this is not a rendering decision. It is a decision about **M4's exit condition** — *"把連結傳給一個沒看過這台機器的人，他用手機打開就能玩完一場"*. Web is the only thing that satisfies that sentence. Going native means rewriting it.

## The argument that actually matters: a false negative

The prototype exists to answer one question, and ADR 0009 is already careful that a failure condemns only this revision of the presentation rather than the abstract vocabulary. There is a confound that neither ADR has named yet.

ADR 0003 puts the entire presentation in shaders and particles. ADR 0004 pins the renderer to Compatibility on mobile Safari — the cheapest, most constrained combination available. If the black hole takeover has to be thinned out until it holds framerate there, and the thinned version then fails the Lean-in Test, **the test has measured the performance floor, not the hypothesis.** That failure would look exactly like "abstract geometry cannot carry anticipation" while actually meaning "abstract geometry cannot carry anticipation *at this frame budget*".

That is a worse outcome than a slow toolchain, because it is invisible. It retires a concept that was never given a fair run.

## What native buys, concretely

- Forward+ or Mobile renderer instead of Compatibility; the shader and particle budget stops being the binding constraint on the one thing being tested.
- The Web audio risks vanish outright — no Sample playback mode limits on runtime parameter control, no browser gesture-unlock rules. The mixing design is pinned on a rising ramp and a half-second of silence (`README.md`), so this removes a named M1 risk rather than mitigating it.
- No thread-support / COOP-COEP question, no `touch-action` fights with Safari's long-press.
- Xcode Instruments instead of inferring frame cost from a counter drawn on the screen.

## What native costs

- **The share path.** M4's exit condition has to become something weaker — "the developer hands their unlocked phone to someone" — which also shrinks who can ever take the Lean-in Test.
- **Seven-day re-signing** on a free Apple ID, for a prototype likely to run longer than that. The paid programme removes it at US$99/year.
- **The discipline.** ADR 0004's real product was *"效能預算是設計約束不是優化議題"* — effects built cheap from the first line. Native headroom removes the forcing function, and an effect built against native headroom can never go back to web. This direction is one-way.
- A second toolchain (Xcode project export, signing, device deployment) during the phase where iteration speed is the whole point (ADR 0003).

## Proposal: keep Web, but demote the no-fallback clause to a measured question

Deciding this before measuring anything would be premature in both directions. Nothing has run on the device yet; mobile Safari may well hold the takeover fine, in which case native buys a toolchain and costs the share path for nothing.

So:

1. **Web stays the delivery target.** M1 runs its device test exactly as planned.
2. **ADR 0004's "no native fallback" stops being an axiom and becomes a threshold.** If the black hole takeover holds **≥ 30 fps** on the target iPhone in mobile Safari, ADR 0004 stands with a corrected premise and nothing else changes.
3. **If it does not hold**, the answer is no longer automatically "make the effect cheaper". Cheapening it risks the false negative above. The choice at that point is explicit: cheapen the effect, or take the native build and rewrite M4's exit condition. That decision gets made with a measurement in hand.
4. **One thing adopted immediately, regardless:** Mac + iPhone over USB gives Safari Web Inspector — real console and timeline from iOS, which is strictly better than `--remote-debug` and costs nothing.

The reason to prefer this over switching now is that it keeps the cheap, wide-reaching delivery path until there is evidence it cannot carry the work, while naming in advance the specific failure that would justify switching — so the switch, if it comes, is a decision rather than a drift.

If the Lean-in Test is only ever going to be run by people in the room, that assumption should be stated now instead, and native becomes the better choice immediately — the share path was the only thing web was protecting.
