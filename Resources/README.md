# LassoText artwork

`LassoText.png` is the original 1254 × 1254 master with an alpha channel. The mint
lasso surrounds three ivory text strokes; a copper tail sits against the deep
petrol-teal tile. It is used by the app bundle and the share artwork.

Created with OpenAI's built-in image generator, in generation mode with a
transparent background. The artwork is included under this repository's MIT
license. No competitor artwork was used.

Prompt:

> Create one original, polished macOS application icon for LassoText, a small
> native offline screen-to-text capture app. An elegant luminous mint lasso
> ribbon forms a rounded rectangular selection loop, enclosing three short
> warm-ivory horizontal text strokes, with a compact flowing tail at the lower
> right. Deep petrol-teal squircle, restrained dimensional satin material, crisp
> beveled edges, subtle depth and soft studio lighting. A tiny warm copper accent
> on the ribbon tail. Strong silhouette, readable at 32px. Square centered
> composition, transparent outside the tile. No letters, words, numbers, UI
> screenshot, mockup, multiple icons, watermarks or competitor imagery.

`./scripts/build.sh` uses `scripts/make-icon.swift` to derive all macOS icon
sizes from this master, preserving transparency and writing exact pixel sizes
at both standard and Retina resolutions. There is no separate hand-edited icon
source to keep in sync.
