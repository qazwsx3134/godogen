# Taskbar Hero Prototype Scene Contract

- Keep authored presentation in `.tscn` scenes. UI scripts may update text, values, visibility, and combat feedback, but must not create or replace screen trees.
- The seven user references in `docs/taskbar-hero-mobile-spec/images/` define the current UI. See `docs/taskbar-hero-mobile-spec/docs/17_reference_ui_contract.md` for precedence and flow.
- `main.tscn` owns a persistent header, six-button navigation, seven page instances, and one live battlefield. Initial view is `idel.png`; Monster navigation opens `monster.png`. The header portrait returns to overview.
- Keep all seven pages as separate editable scenes. Expanded pages share the SAME panel top/bottom and navigation position; overflowing content scrolls inside the panel. Repeated cards/rows/buttons are reusable scene instances.
- Playable actors remain authored scene instances, with actual health, damage, movement and death reflected by their visible presentation. Do not hide a simulator behind a static battle screenshot.
- Put static unit tuning in `data/units/*.tres`. Runtime HP, targets, cooldowns, and respawn timers belong to the unit node.
- UI layout uses anchors and Containers. Runtime `position` changes are reserved for Node2D actors in the battlefield.
- `tools/build_scenes.gd` is a one-shot authoring utility. Run it only to intentionally regenerate scene files; regular startup and tests load checked-in scenes.
- Current scope is docs/18_progression_wave_contract.md: immediate paid hero training, dense inventories, multiple deployed monsters, real equipment and save v2 migration; monster growth comes only from EXP and equipment. Combat uses enemy waves and parallax marching transitions. Purchases and ad rewards remain local demonstrations without external SDKs.
- User PNGs may be referenced as AtlasTexture art regions. Text, quantities, progress bars and clickable controls must be independent editable nodes. A screenshot with invisible hotspots is not an implementation of this contract.
- Reference capture data must be explicit and isolated from player saves. Do not overwrite restored gold with reference numbers simply to match a screenshot.
- Keep it simple (KISS) and test by tier per the root `AGENTS.md` ("KISS 與分層測試驗收"): planning runs no tests; L1 (new isolated feature) runs only the matching `tests/test_*.gd`; L2 (feature touching other systems, or a bug fix) adds `test_playable.gd` and `test_scene_persistence.gd` as the quick regression; L3 (large task) runs every test listed in README「驗證」plus `tools/capture_review.gd` only after the user has accepted it by hand. Each test uses its own `XDG_DATA_HOME`.
