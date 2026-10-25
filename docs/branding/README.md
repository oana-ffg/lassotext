# LassoText branding

| File | Purpose |
| --- | --- |
| `social-preview.png` | 1280 × 640 GitHub social preview, also suitable for X/Twitter large cards. |
| `social-preview.html` | Editable HTML/CSS source for the preview. |
| `render.sh` | Renders the HTML to `social-preview.png`. |

## Provenance

- **Icon:** the preview places `Resources/LassoText.png` unmodified. Its origin,
  prompt and license are documented in [Resources/README.md](../../Resources/README.md).
- **Palette:** petrol `#036169`, mint `#9eeaca`, ivory `#f8efe0` and copper
  `#ecaa6f` are sampled from the icon. The background deepens the petrol to
  `#03181e` so the tile stands out.
- **Type:** New York (wordmark and tagline) and SF Pro (everything else), both
  macOS system fonts, loaded as `ui-serif` and `system-ui`. No font files are
  bundled.
- **Illustration:** the dashed rectangle and crosshair around "Text" depict the
  select-to-copy gesture. They are drawn in CSS and SVG and are not a screenshot;
  the real selection overlay uses a white outline over a dimmed screen.
- **Copy:** every claim matches the main README: offline Apple Vision OCR,
  Command + Shift + 2, no accounts or analytics, MIT.

## Rendering

Requires macOS and Google Chrome (set `CHROME` to another Chromium binary if
needed):

```sh
./docs/branding/render.sh
```

The script screenshots the page in headless Chrome at 1280 × 640, 1× scale,
then writes a 506 × 253 thumbnail to a temporary directory so you can check
legibility at card size. It prints the dimensions and byte size of both images.
GitHub limits social previews to 1 MB; the current PNG is about 490 KB.

Upload `social-preview.png` in the repository's **Settings → General → Social
preview**.

## Suggested share copy

> LassoText: offline screen-to-text for macOS. Press ⌘⇧2, drag around text on
> screen, and it's on your clipboard. Apple Vision OCR, no accounts or
> analytics. MIT, build it from source.
> https://github.com/oana-ffg/lassotext

Shorter:

> Grab text. Get on with it. ⌘⇧2, select, paste: a tiny open-source macOS menu
> bar app with offline OCR. https://github.com/oana-ffg/lassotext
