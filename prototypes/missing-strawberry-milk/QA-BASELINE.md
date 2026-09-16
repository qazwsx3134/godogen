# QA Baseline — 消失的草莓牛奶

Date: 2026-09-16

Scope: `src/dev-walkthrough.ts` scene-graph and state walkthrough only. No
production files, package files, or lockfiles were changed. The dependency
installation was handled by the commander.

## Commands and results

The original four-case script was saved before modification at
`/tmp/missing-strawberry-milk-dev-walkthrough-baseline.ts`. Because its imports
are relative, it was run from a temporary `/tmp` source layout containing the
unchanged core, types, and scene data:

```text
/mnt/d/repo/godot/godogen/prototypes/missing-strawberry-milk/node_modules/.bin/tsx \
  /tmp/missing-strawberry-milk-baseline-run.zlBx4a/src/dev-walkthrough.ts
exit: 0
OK: ask_shinpachi -> meta => ending_success
OK: ask_kagura -> scared => ending_fail
OK: ask_landlady -> deflect => ending_fail
OK: ask_shinpachi -> __timeout__ => ending_fail
All paths reached a valid end beat.
```

Updated commands, run in `prototypes/missing-strawberry-milk/`:

```text
npm run walkthrough
exit: 0

npm run build
exit: 0
vite v8.3.0 building client environment for production...
✓ 9 modules transformed.
✓ built in 288ms
```

The first pre-install attempt was not a code result: walkthrough exited 127
because `tsx` was absent and build exited 2 because `vite/client` was absent.
After dependency installation, the first sandboxed `tsx` attempt hit
`listen EPERM ... /tmp/tsx-1000/14.pipe`; the same command was rerun with the
required tool permission and passed.

## Twelve story combinations

Expected mapping is based on the current scene data: `meta` is correct and
ends at `ending_success`; `scared` and `deflect` are wrong and end at
`ending_fail`; timeout ends at `ending_fail` with its timeout Flag.

| Case | Expected ending | Expected choice Flag | Expected tsukkomi Flag | Actual |
| --- | --- | --- | --- | --- |
| 新八 + meta | `ending_success` | `asked:shinpachi` | `tsukkomi:tsukkomi_reveal:correct` | PASS — `ending_success`, both Flags present |
| 新八 + scared | `ending_fail` | `asked:shinpachi` | `tsukkomi:tsukkomi_reveal:wrong` | PASS — `ending_fail`, both Flags present |
| 新八 + deflect | `ending_fail` | `asked:shinpachi` | `tsukkomi:tsukkomi_reveal:wrong` | PASS — `ending_fail`, both Flags present |
| 新八 + timeout | `ending_fail` | `asked:shinpachi` | `tsukkomi:tsukkomi_reveal:timeout` | PASS — `ending_fail`, both Flags present |
| 神樂 + meta | `ending_success` | `asked:kagura` | `tsukkomi:tsukkomi_reveal:correct` | PASS — `ending_success`, both Flags present |
| 神樂 + scared | `ending_fail` | `asked:kagura` | `tsukkomi:tsukkomi_reveal:wrong` | PASS — `ending_fail`, both Flags present |
| 神樂 + deflect | `ending_fail` | `asked:kagura` | `tsukkomi:tsukkomi_reveal:wrong` | PASS — `ending_fail`, both Flags present |
| 神樂 + timeout | `ending_fail` | `asked:kagura` | `tsukkomi:tsukkomi_reveal:timeout` | PASS — `ending_fail`, both Flags present |
| 房東 + meta | `ending_success` | `asked:landlady` | `tsukkomi:tsukkomi_reveal:correct` | PASS — `ending_success`, both Flags present |
| 房東 + scared | `ending_fail` | `asked:landlady` | `tsukkomi:tsukkomi_reveal:wrong` | PASS — `ending_fail`, both Flags present |
| 房東 + deflect | `ending_fail` | `asked:landlady` | `tsukkomi:tsukkomi_reveal:wrong` | PASS — `ending_fail`, both Flags present |
| 房東 + timeout | `ending_fail` | `asked:landlady` | `tsukkomi:tsukkomi_reveal:timeout` | PASS — `ending_fail`, both Flags present |

## Additional guard coverage

- `reset()` returns to `intro` and clears the selected choice Flag plus an
  additional Flag.
- An unknown beat ID throws and leaves the current beat unchanged.
- Unknown suspect input, missing tsukkomi input (early termination), and
  unknown tsukkomi input all throw explicit failures.
- A synthetic dialogue self-loop is detected and throws instead of hanging or
  being silently skipped.

## Explicit non-coverage

This script does not verify browser DOM rendering, real wall-clock timing or
button races, portrait/background/image loading, sound playback, whether the
text is funny, first-person immersion, or a friend's authoring workflow. Those
remain outside this baseline and are not evidence that the whole product
passes.
