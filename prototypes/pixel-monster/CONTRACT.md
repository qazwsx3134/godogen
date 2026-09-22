# 口袋怪獸日記 — implementation contract

Godot **4.7.stable.official.5b4e0cb0f**. Stage A gameplay with an iOS build pipeline. GDScript typed methods and dictionary domain state. Design source: `../../docs/pixel-monster/pixel-monster-godot-prompt.md`. Traditional Chinese player copy. All domain timestamps are integer UTC seconds supplied by the caller.

## Components

- Coordination and presentation: `scripts/game_session.gd`, `scenes/`, `ui/`, assets/audio, integration tests.
- Care and growth: `domain/pet_model.gd`, `domain/care_service.gd`, `domain/time_service.gd`, `domain/evolution_service.gd`, `data/balance.json`.
- Steps and storage: `domain/step_provider.gd`, `domain/mock_step_provider.gd`, `domain/step_service.gd`, `domain/hatch_service.gd`, `domain/save_service.gd`.
- Battle: `domain/battle_service.gd`, `data/opponents.json`.
- Distribution: `tools/ios/`, `export_presets.cfg`, `.github/workflows/pixel-monster-ios.yml` at repository root.

No global autoload is required. Each domain script `extends RefCounted` with a unique class_name and static methods except providers. Dependencies use explicit preloads. Tests extend SceneTree and return a nonzero exit for failures.

## Shared state

`PetModel.create_state(now: int) -> Dictionary` initializes:

```text
schema_version: 1
saved_at: now
last_tick: now
pet: {} (no pet before hatch)
egg: {} (HatchService starts it)
collection: []
pending_battle: {}
battle_history: []
step_ledger: {} (step service owns structure)
step_debug: {} (mock owns structure)
settings: {sound: true, music: true, vibration: true, auto_lights: true,
           sleep_hour: 22, wake_hour: 7, timezone_offset_minutes: 480,
           debug_time_offset: 0}
```

`PetModel.create_pet(now) -> Dictionary` fields minimum:
`id`, `name` (芽芽), `species` (sprout / bloom / ember / moss / breeze), `stage` (baby / growing / mature), `born_at`, `stage_started_at`, `fullness`, `mood`, `energy`, `health`, `cleanliness` (0..100 float), `weight` (float), `training` dictionary with `power/guard/swift` ints, `training_count`, `wins`, `losses`, `draws`, `battles`, `care_mistakes`, `sleep_seconds`, `behavior` (idle/sleeping), `conditions` dictionary (`injured`, `sick`, `hibernating` bools), `lights_on`, `poop` (Array timestamps), `poop_queue` (Array timestamps), `cooldowns` dictionary, `history` Array, `evolutions` Array. Additional fields allowed; keep listed names stable.

`PetModel.stats(pet) -> Dictionary` returns `attack`, `defense`, `agility`, `max_hp` (ints). `PetModel.ideal_weight(pet) -> Vector2`. `PetModel.stage_name(pet) -> String`. Balance is an explicit JSON schema accessed through `CareService.balance()`.

## Care / time / evolution APIs

- `CareService.can_act(state, action: String, now: int) -> String`: empty if allowed; Traditional Chinese denial otherwise. action: meal/snack/clean/lights/heal_injury/heal_sickness/train/battle/wake.
- `CareService.perform(state, action, now) -> Dictionary`: `{ok: bool, message: String, animation: String}`; animation eat/happy/sleep/idle/heal. No-op on denied. Wake exits protective hibernation.
- `CareService.train(state, kind: String, quality: int, now) -> Dictionary`: kind power/guard/swift, quality 1..3; clamp to per-stage cap, record history, energy cost/cooldown; result same shape plus optional gain.
- `TimeService.advance(state, now) -> Dictionary`: ordered offline needs max 12 hours, protective hibernation thereafter; UTC high-water handling, no negative elapsed or rollback exploits; two-hour per-need grace with sleep pause and one mistake per unresolved event. Age/evolution real elapsed separate. Settings timezone offset and sleep interval respected. Return elapsed/protected/message.
- `EvolutionService.check(state, now) -> Array`: stage transitions recorded once, results array of readable messages. baby 2h -> growing; growing 24h and 3 trainings -> mature. Branch max training; ties power > guard > swift. stats finite modifiers from care/sleep/battle history. Check can advance multiple eligible stages with deterministic timestamps.
- `EvolutionService.archive(state, now) -> Dictionary`: only mature with no unsettled battle; deep-copy full individual/history to collection, clear pet and egg. GameSession starts the next egg in the same save transaction. Return ok/message.

## Steps / hatch / save APIs

- `StepProvider` instance: `capabilities() -> Dictionary`, `permission() -> String`, `query(state: Dictionary, from_utc: int, to_utc: int) -> Dictionary`. This is our interface, not an OS API. Result includes source/status/coverage/buckets; see `docs/STEPS.md`.
- `MockStepProvider.add_steps(state, count: int, now: int) -> void`; `set_mode(state, mode: String, now: int) -> void`; modes normal/denied/unavailable/delayed/duplicate/reboot. Persist mock events so repeat calls/relaunch produce stable totals. Explicit source mock. GameSession and UI expose these controls only in OS.is_debug_build(). Production/native unavailable fallback MUST NOT fabricate step source.
- `StepService.synchronize(state, provider: StepProvider, now: int) -> Dictionary` returns ok/message/status, `today_steps` nullable if unavailable; persists source/coverage/last_sync in egg or root. Durable time bucket replacement + delta, refuse overlapping sources, new eggs exclude prior steps, no carry remainder. Requery accommodates late data and idempotence.
- `HatchService.start_egg(state, now: int, kind: String = "starter") -> Dictionary` target 500/2000/5000. Starter only UI initially. Egg fields: id/kind/started_at/target_steps/credited_steps/mode (steps/time)/hatched/hatched_at; persist hatch once via PetModel.create_pet. Never replace active egg/pet silently.
- `HatchService.check(state, now: int) -> Dictionary` includes ok/hatched/message; only true hatched on new transition. `HatchService.use_time_mode(state, now: int) -> Dictionary`, 24h from egg start (document rule), idempotent.
- `SaveService.save(state, path: String = "user://pocket_diary.json") -> Error` atomically writes temp and backup with all state; schema validation. `SaveService.load_state(path: String = "user://pocket_diary.json") -> Dictionary`, returns {} when no usable save. Preserve valid backup across corrupt primary recovery.

## Battle APIs

- `BattleService.opponents() -> Array` three NPC dictionaries: id/name/attack/defense/agility/max_hp/species/description.
- `BattleService.begin(state, npc_id: String, stance: String, now: int) -> Dictionary`: stance balanced/assault/defend. Validate pet/energy/injury/sleep/no pending, consume 12 energy; freeze stats, generate random seed once, calculate full bounded deterministic timeline at start into pending_battle. Battle IDs include per-state monotonic sequence. Caller saves immediately. Returns ok/message/battle. All failures no mutation.
- `BattleService.finish(state, now: int) -> Dictionary`: applies existing pending result once, stores history, marks settled, returns ok/message/outcome. Repeated no rewards. Keep completed pending data until next begin to support replay (pending `settled: true`). Do not mutate lifelong base stats without cap. Loss does not kill pet.
- pending_battle minimum `id`, `seed`, `npc_id`, `npc_name`, `stance`, `player` snapshot, `enemy` snapshot, `rounds` array, `outcome` win/loss/draw, `settled` bool, `started_at`. Each rounds entry contains `round`, `actor` player/enemy, `damage`, `skill` bool, `miss` bool, `player_hp`, `enemy_hp`, `text` Chinese.
- UI animates timeline or skips and calls finish. On load the same pending battle resumes. `resolve_battle(player, enemy, stance, seed) -> Dictionary` provides a pure seeded resolver for tests.

## Integration rules

GameSession settles elapsed care time before actions, saves state and receipts together, then emits presentation signals. Tests use isolated `/tmp/pixel-monster-test-*.json` saves. `tools/verify.sh` imports resources before running all suites and checks script diagnostics as well as process status. Native step integration and physical-device evidence belong to Stage B; iOS build evidence is tracked separately in `docs/VALIDATION.md`.
