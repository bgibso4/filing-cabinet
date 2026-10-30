# Filing Cabinet · design handoff

Design is finished (2026-10-29). This folder is everything the build needs from it.

**What to build** is defined by `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html`, especially section 06 · Design changes. Where a screen and the requirements disagree, the requirements win. Where the 2026-07-12 design spec disagrees with either, it loses.

## What's here

| Path | What it is |
| --- | --- |
| `screens/` | All 95 chosen screens as PNGs (light and dark), grouped by flow. Start with `screens/README.md`. |
| `prototype/index.html` | Clickable prototype of the main flows (scan, review, save, view, Trash, Settings, first launch). Open it in a browser; it needs the `scans/` folder beside it. It shows motion and behaviour, not final visuals. |
| `components/` | The source of every screen: HTML templates with exact sizes, spacing, colours and copy. Each `renderVals()` holds the sample data and the per-state logic. `screens/index.json` says which component and props draw each PNG. |
| `tokens.json` | Design tokens: colours (light and dark), type styles, spacing, radii, collection symbols. Updated for contrast, so it supersedes the design system artifact where they differ. |
| `app-icon/` | Final app icon: layers for Icon Composer plus previews. See `app-icon/README.md`. |

## Rules that shape every screen

- Black, white and grey interface; colour only identifies a collection or marks expiry (plus destructive red).
- New York (serif) for titles only; SF Pro for everything else; Dynamic Type everywhere; tabular numerals.
- Three radii: 14 (surfaces), 6 (nested, thumbnails), pill (Scan, chips, search). No shadows; floating controls use Liquid Glass.
- Copy uses middots, never em dashes. The Scan button always says "Scan".
- Collections are data (name, colour, symbol, lifespan), not a fixed list of five: custom collections come later.

## Not designed (left to the system)

The document camera (VisionKit), share sheet, system alerts and permission prompts, Control Center, Lock Screen, Spotlight and Shortcuts surfaces. Ours are the words, the Scan symbol and what happens next.

## Online versions

- Design canvas (Final page first, Exploration second): https://claude.ai/artifact/HwW3TFkm4d9wBBUj7smpUF
- Prototype: https://claude.ai/artifact/TyQLh5ooNgP7smnuw3oAfm
- Design system (tokens before the contrast fixes): https://claude.ai/artifact/Hsi7TGewT9m81Yj5z9eDCh

These are private to Ben's claude.ai account; the files in this folder are the copies to build from.
