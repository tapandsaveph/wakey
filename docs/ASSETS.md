# Artwork

## Existing creature

The awake and sleeping marks are the existing Wakey identity. `docs/brand/awake.svg` and `sleep.svg` retain their geometry and approved outline weight. These are intentionally stroke-based SVGs with rounded joins and ends. The sleeping static variant shows one Z; native playback uses a staggered stream.

- `Resources/Creature/`: actual app artwork, 56px Retina frames on a 28pt canvas; four 30fps sequences; 432 frames total.
- `docs/brand/app-icon.png`: approved textured green creature, gently tilted and cropped at the right and bottom, on a pink/lavender background. Generated from the approved cover artwork; `Resources/Wakey.icns` contains native-size derivatives. Menu-bar animation artwork is independent and unchanged.
- `docs/media/states.png`: the approved vector state artwork in a presentation layout. Editable source: `states.html`.
- `docs/media/menu-bar-screenshot.png`: an unaltered user-supplied macOS development screenshot. It predates the final outline-weight refinements.

## Cover

`docs/media/hero.png` is illustrated brand artwork generated with the built-in image-generation tool, using the project’s awake/sleep marks as identity references. It is not a screen capture, App Store listing, or claim of a ranking. The selected Pinterest references guided the broad rounded typography, large/small character contrast, pastel palette and tactile finish; their characters and interfaces were not reused.

The exact generation brief is retained in `image-prompt.txt`. The creature silhouettes and simple facial marks remain the project’s identity. The cover uses one dominant name, a much smaller purpose line, and unequal character sizes. The README then steps down to state artwork, a genuine menu-bar capture, and ordinary Markdown instructions.

The app is native AppKit. No React site, browser runtime, or generated artwork is required at runtime beyond the packaged image assets.

## Rights

Original project source and creature artwork use the repository’s MIT license. Apple/macOS names identify compatibility, not endorsement. Neighboring system/app icons appear only within the real development screenshot.
