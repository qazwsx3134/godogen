---
status: accepted
---

# House game prototypes inside the godogen repo, under `prototypes/`

godogen's own CLAUDE.md states it is "not a published game repo" and it carries no JS/TS tooling — it's a Python-based generator that renders runtime game repos via `publish.sh`. Validating the Gintama-like game's dialogue/tsukkomi pacing (see `docs/gintama-like/`) needs a throwaway Vite + TypeScript build that can be shared with testers.

We put it in `prototypes/<name>/` inside this repo rather than a separate repo, so disposable design-validation builds live next to the brainstorm docs (`docs/gintama-like/`) that motivated them, instead of scattering across many small repos that are hard to find and correlate later.

Consequence: godogen now carries an npm/Vite toolchain alongside its Python tooling. Everything under `prototypes/` is disposable by design and must never be wired into `publish.sh`'s rendering pipeline — it is not one of the engine templates the generator produces.
