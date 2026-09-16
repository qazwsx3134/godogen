---
status: accepted
---

# Web is the only delivery target, so the performance budget is a design constraint

The machine is played portrait on a phone, and the phone is an iPhone. Building for iOS needs macOS, Xcode and a paid Apple developer account; development happens on Linux under WSL. An Android APK — the usual escape hatch when a web build runs badly — is therefore not an escape hatch here. There is exactly one route to the target device: a Godot web export opened in mobile Safari.

That makes the performance budget a design constraint rather than an optimisation concern, which matters because ADR 0003 puts the entire presentation in shaders and particles. If the black hole takeover cannot hold framerate in mobile Safari, the answer is a cheaper effect, not a native build.

Two mechanics of the web export that shape the setup: Godot 4's default threaded web build needs `SharedArrayBuffer`, which requires the host to send COOP and COEP headers (a plain `python3 -m http.server` does not, and the game shows a blank page); itch.io has a setting for this, and the export preset can alternatively disable thread support at a performance cost. Mobile browsers also refuse to start audio until the user touches the screen — the reach cue must not be the first sound the game tries to play.
