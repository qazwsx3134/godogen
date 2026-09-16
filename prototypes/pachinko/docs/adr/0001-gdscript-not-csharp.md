---
status: accepted
---

# This prototype is written in GDScript, not C#

`engines/godot.md` specifies Godot 4 .NET/Mono with C# for every Godot project, but that guide governs the runtime repos `publish.sh` renders — and ADR 0001 (`prototypes/docs/adr/`) puts everything under `prototypes/` permanently outside that pipeline. The machine here has Godot 4.7.stable **standard build** (no `GodotSharp`, no .NET SDK installed), so C# would mean installing a second Godot build and a .NET toolchain before the first ball is fired.

We write this prototype in GDScript. The trade-off we accept: none of its code can be lifted into a `publish.sh`-rendered C# repo later without a rewrite. That is acceptable because the prototype validates a feel question, not a codebase.
