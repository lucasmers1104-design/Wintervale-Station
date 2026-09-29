# Menu gallery visual pages

`GameGUI.zip` supplies seven approved 1672 × 941 PNGs. Each is preserved without edits under `assets/ui/menu_screens/` and shown at native aspect ratio inside the menu's existing reference canvas.

| Page | Project asset | Entry |
|---|---|---|
| Load Save | `load_save.png` | Main menu → Load Save |
| Achievements | `achievements.png` | Main menu → Achievements |
| Settings: Graphics | `settings_graphics.png` | Main menu → Settings; Settings sidebar |
| Settings: Audio | `settings_audio.png` | Settings sidebar |
| Settings: Controls | `settings_controls.png` | Settings sidebar |
| Settings: Gameplay | `settings_gameplay.png` | Settings sidebar |
| Credits | `credits.png` | Main menu → Credits |

The page images provide the approved visuals. `menu_gallery.gd` provides a separate button layer, with each navigation button displaying an exact crop of its corresponding artwork. Back, Escape, Settings tabs, and the links from Achievements to Load Save, Settings, and Credits navigate between pages. Settings sliders, toggles, Apply, Reset, save records, achievement progress, and credit names remain visual sample content with no data or settings behavior. This follows the current visual-only request and prevents those depicted values from being mistaken for actual saved state in implementation code.

## Missing reference

The ZIP has no **New Game** setup page. Continue and Quit are actions in the main menu, with no separate page pictured. It also has no Delete confirmation, New Save follow-up, or individual achievement-detail slides, if those are intended to exist.

## Verification

Actual Godot captures are saved as `docs/menu_gallery_<page>.png`. All seven were inspected against the supplied images at 1672 × 941. A sampled comparison across every fourth pixel found a mean per-channel difference of 2.36–3.27 on a 0–255 scale, consistent with texture import and rendering. The menu flow probe confirmed all pages load and Settings tab and Back navigation work.
