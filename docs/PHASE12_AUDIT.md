# Phase 12 audit and implementation checklist

Audited before implementation on branch `feat/premium-main-menu`. Phase work is isolated on `feat/phase12-menu-functionality`; unrelated pre-existing working-tree changes are preserved.

## Existing and functional

- Main menu's seven visible buttons, keyboard focus, Escape from gallery, seven supplied gallery images, and navigation between the four Settings tabs.
- Saveable world components use stable `get_save_id`/`save_state`/`load_state` contracts. Quick save/load work in game. Fullscreen and HUD legend preferences persist globally.
- Gameplay signals exist for railway segments, village construction and population, freight service, weather, day/night, and train movement.

## Incomplete or broken

- Continue checks only `quicksave.json`, does not validate it before instantiating a world, and can load into an initialized world after a failure.
- New Game bypasses setup. Load Save shows fictional records and has no slot operations. Settings images depict controls with no behavior. Achievement page depicts fictional progress. Credits image includes unverified names.
- Save files have no display metadata, list API, safe slot validation, or atomic replacement. Save file parse checks only top-level type.
- Gallery changes pages instantly. Focus styling is absent on art-cropped navigation buttons.

## Missing

- Save setup and slot selection, settings implementation and persistence, achievement backend/UI, notification queue, transitions, reduced motion, and automated menu tests.
- The supplied ZIP lacks an approved New Game reference, achievement detail reference, and delete confirmation reference.

## Integration conflicts and decisions

- The seven approved screenshots include baked fictional text. Data-driven UI must cover those text regions with matching parchment so only true save/settings/achievement values are visible.
- `project.godot`, `systems/events.gd`, `systems/input_config.gd`, and gameplay scripts already have unrelated local edits. Changes to these files require careful staging of only Phase 12 hunks.
- Achievement progress will be **per save** because railway and village state are per world. Existing saves lacking achievement state start with zero recorded progress; no retroactive unlock is inferred from starter content.
- `quicksave` remains a compatible legacy slot. Named journeys use separate slot IDs and must never overwrite another journey.

## Implementation checklist

- [x] Validate/list saves, metadata, safe writes, create/load/delete flow.
- [x] New Game setup and Continue from latest valid slot.
- [x] Replace fictional Load Save/Settings/Achievement/Credits content with live content.
- [x] Apply/persist supported settings, key rebinding conflict checks, restore defaults.
- [x] Per-save achievement state and event wiring for supported goals. All fifteen goals have corresponding gameplay events.
- [x] Achievement cards/details and queued notifications.
- [x] Reusable interrupt-safe forward/reverse transitions and reduced motion.
- [x] Godot parse, automated integration tests, screenshots, visual review, regression pass. See `PHASE12_QA.md` for evidence and limits.
