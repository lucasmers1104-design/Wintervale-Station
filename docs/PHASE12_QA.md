# Phase 12 validation and handoff

## Menu button inventory

| Surface | Controls | Result |
| --- | --- | --- |
| Main menu | Continue, New Game, Load Save, Settings, Achievements, Credits, Quit | Wired to valid-save loading, setup, live pages, or Godot shutdown. Continue is disabled with an explanation when no valid save exists. |
| New Game | Journey name, starting season, Start Your Journey, Back | Creates a unique named slot, configures the starter world and season, saves the initial world, and returns through Back. Only the available Wintervale Valley scenario is offered. |
| Load Save | Load, Delete, Keep Save, Delete Save, New Journey, Back | Real file metadata and screenshots are shown. Damaged files are marked unavailable. Deletion requires a separate confirmation. |
| Settings | Graphics, Audio, Controls, Gameplay, Back, Reset to Default, Apply | All displayed controls change engine, audio, input, or gameplay settings. Back discards uncommitted changes. Display changes have a ten-second keep/revert dialog. |
| Achievements | Save selector, fifteen cards, Continue, New Game, Load Save, Settings, Credits, Quit, Back | Displays progress stored in the selected save. Cards open detail views. Continue is disabled when no valid save exists. |
| Credits | Back | Shows verified project and engine credits. |

The gallery's logo also returns to the main menu. Escape closes the active modal before leaving a page. Keyboard focus receives a visible outline; mouse hover and navigation have restrained paper audio. Switching pages is immediate; closing a page retains a decorative transition with a reduced-motion path.

## Save and settings changes

- Named saves have unique safe slot IDs, readable world metadata, optional in-game thumbnails, and atomic replacement with a recoverable backup. Legacy quicksave remains supported.
- Continue selects the newest restorable save, using a stored timestamp or file modification time for older saves. Corrupt saves cannot start an empty world.
- Global preferences and keybindings are stored separately from per-journey progress. Audio buses cover master, music, ambient, train, weather, and UI sound. Resolution, fullscreen, VSync, FPS limit, camera controls, daily autosave, day speed, achievement notifications, and reduced motion are wired to real behavior.
- Resolution and fullscreen previews are not written to disk until confirmed. If the player rejects them, the previously confirmed display state returns while other applied preferences remain.

## Achievement architecture

Achievement state belongs to each save. `Achievements` observes real railway, train, freight, village, weather, and clock events after the world is initialized. It records IDs already counted, progress values, and unlock times in the world's save data. A short delayed save persists a new unlock even when daily autosave is disabled. The toast queues unlocks one at a time; notification settings affect presentation only.

| Category | Working achievements and event source |
| --- | --- |
| Railway | First Tracks, Getting Connected, Railway Engineer (new rail segments); All Aboard, Full Schedule (arrivals); Freight Master (freight service deliveries). |
| Village | Home Sweet Home, Village Architect (finished paid houses); Little Village, Growing Community (population); Bright Nights (paid decorative lanterns). |
| Cozy | Winter Wonderland (snow weather); Night Owl (complete night transition); Let There Be Light (paid string lights); Cozy Evening (winter evening arrival). |

## Automated evidence

- `tests/phase12_menu_test.gd`: 29 checks, zero failures. Covers eight live pages, Continue state, save names and metadata, invalid and corrupt paths, confirmation/cancellation of deletion, settings persistence, unconfirmed display preview, key conflict/rebinding persistence, immediate tab switches, and animated closing.
- `tests/phase12_journey_test.gd`: 23 checks, zero failures. Creates a real world from New Game through the illustrated loading screen, saves and restores it, checks latest-save selection, verifies a real rail event unlocks First Tracks, prevents duplicate progress from restoring the same track, and checks achievement persistence. It also follows Continue from a saved journey through the illustrated loading screen and verifies the restored world and achievement.
- `tests/smoke_test.tscn`: existing world/railway regression suite, zero failures.
- Eight runtime captures at 1672 × 941 are stored as `docs/phase12_*.png`. These were inspected for layout, clipping, and consistency against the supplied visual pages.

## Visual and manual limits

- The supplied visual package has no approved New Game, delete confirmation, or achievement detail image. Those screens use the existing wooden frame and parchment artwork with live content. Exact pixel matching for them cannot be verified without references.
- Live text and controls cover sample values baked into the supplied screenshots. The new parchment regions are intentionally visible, so the runtime result is visually consistent with the reference family but is not an exact pixel match.
- The supplied art depicts renderer effects and other settings this project has not implemented. They are covered by live parchment and are not offered as nonfunctional controls.
- The fifteen badge SVGs are original, consistent engraved motifs, but several goals share a motif family. A dedicated illustrated badge per goal could be refined with an approved art reference.
- Automated tests verify scene logic and state. Physical audio levels, operating-system display confirmation, performance on other GPUs, and the feel of each transition still merit a human playthrough on target hardware.
