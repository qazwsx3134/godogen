---
status: accepted
---

# Web is the only delivery target, so the performance budget is a design constraint

The machine is played portrait on a phone, and the phone is an iPhone. A native iOS build is possible — development is on macOS — but it costs the one thing nothing else provides: handing someone who has never seen the machine a link and having them play. Sideloading needs a device in hand and re-signing every seven days; TestFlight needs the paid Apple Developer Program and a review round. There is exactly one route that reaches a stranger's phone: a Godot web export opened in mobile Safari.

ADR 0010 turned the performance question from an assumption into a measurement, and the answer was not the one this ADR originally assumed. In steady state the target device holds 60 fps on every variant tested — full-screen, screen-reading, and at double the physics load. Sustained GPU cost is not the binding constraint, and "make the effect cheaper" is not the lever it was expected to be.

What the measurement did find is that the cost is **front-loaded**. A first run showed the full-screen takeover dipping to 37 fps and the screen-reading one to 27; a second run, warm, showed 60 everywhere. Shader program caching, Safari's WASM tier-up and the phone's clock ramp all take seconds to settle, so an early measurement reads a machine that is still waking up. Shader compilation in particular is a one-time stall — 68 ms for the takeover shader — that lands wherever the shader first draws.

So the real constraint is the first minute, not the sustained frame, and it needs different handling: warm the takeover shader at load rather than on first use. The presentation's own pacing helps here by accident — SP appears about once in 80 spins, so a player meets their first black hole minutes in, long after everything has settled. The exception is the forced sequence test of ADR 0009, which plays SP immediately and would otherwise measure a cold machine and blame the presentation for it.

Three mechanics of the web export shape the setup, and the first two are routinely confused with each other:

- **Threads need COOP/COEP.** Godot 4's default threaded web build needs `SharedArrayBuffer`, which requires the host to send COOP and COEP headers. Disabling thread support in the export preset removes that requirement at a performance cost, which is the choice made here.
- **Godot Web needs a secure context regardless.** Turning threads off does *not* remove this. A secure context means `https://` or `localhost`; a phone reaching the dev machine over a LAN IP is neither, so plain HTTP fails at load with *"missing: secure context - check web server config (use HTTPS)"*. Local testing therefore needs a TLS server (Caddy with `tls internal` and an IP SAN, tapping through the certificate warning on the device), not `python3 -m http.server`.
- **Audio will not start until the user touches the screen.** The reach cue must not be the first sound the game tries to play.
