# Screenshot Studio

A browser-based editor for App Store screenshot sets. Everything renders and
exports client-side, so it deploys anywhere static-ish and never uploads your
artwork.

```bash
pnpm install
pnpm dev      # http://localhost:3000
```

## What it does

- **Board view** — every screen side by side, all of them editable in place.
- **iPhone + iPad Pro** — switch between current iPhone formats and the 13-inch
  iPad Pro canvas. Device captures and frame positions stay separate while
  copy, layers and themes remain shared across the set.
- **Layers** — text, shapes and images, each with its own position, rotation,
  opacity and colour. Drag on the canvas, nudge with arrows, ⌫ to delete.
- **One theme for the set** — pick a palette and every screen repaints. Custom
  palettes get five colour pickers; `Alternate` runs two palettes in turn.
- **Bleed** — tick "Bleed across screens" on a layer and it is positioned in
  set coordinates, so a circle on a boundary is cut in half and continues on
  the next screenshot.
- **Uploads** — pick several files or drop a folder anywhere on the page.
  Images live in IndexedDB (localStorage's ~5MB quota can't hold PNGs) and are
  referenced as `asset:<id>`.
- **Autosave** — every change is written to localStorage, debounced. The header
  shows the last save time. `Save file` downloads the project as JSON.
- **App Store-ready export** — choose an accepted portrait resolution, then
  render one screen or the full set as lossless RGB PNGs with no alpha channel.
  The recommended defaults are 1320 × 2868 for iPhone and 2064 × 2752 for the
  13-inch iPad Pro.
- **Project files** — save a portable JSON project and open it again from the
  Export panel.

## Deploying to Vercel

Import the repo and deploy; no environment variables, no configuration.

Two things behave differently once deployed:

- `POST /api/save` (writing PNGs into `exports/`) is **local only** — it
  returns 403 outside development, because a serverless filesystem is
  read-only. Use the zip download instead.
- `GET /api/screenshots`, which lists `public/screenshots`, is built as static
  JSON at build time. Files added to that folder need a redeploy to appear;
  anything uploaded through the UI is unaffected.

Uploads and projects live in the browser, so they are per-device. `Save file`
plus the project JSON is the way to move a set between machines.

## Bundled artwork

The shapes (circle, ring, blob, star, sparkle, arrow, squiggle…) are drawn as
SVG paths in `src/components/Shape.tsx`. They are original to this project, so
there is no licence attached to anything you export.

For richer illustrations, upload them and place them as image layers. Sources
that are safe for commercial use:

| Source | Licence | Notes |
| --- | --- | --- |
| [unDraw](https://undraw.co) | Free, no attribution | Recolourable SVGs, huge library |
| [Open Peeps](https://openpeeps.com) | CC0 | Hand-drawn people, mix and match |
| [Humaaans](https://humaaans.com) | CC BY 4.0 | Attribution required |
| [DrawKit](https://drawkit.com) | Mixed | Check per pack |
| [Storyset](https://storyset.com) | Free with attribution | Animated options |
| [Phosphor Icons](https://phosphoricons.com) | MIT | Icon set |

Check the licence at the source before shipping — the terms above are a
starting point, not legal advice.
