# Design Iteration Findings

## Preserved success patterns

- Three materially different compositions create useful batch variety without changing only color.
- `editorial` is the most robust default for mixed source photography and variable headline length.
- `bold_photo` creates the strongest feed stop when the source image supports a safe overlay.
- `recipe_card` adds scan value when time, ingredients, yield, or another compact fact is verified.

## Corrected failure patterns

- A legacy right-aligned metadata card used a left inset but no right inset.
- The shared renderer now uses at least 28 px horizontal padding on both sides of pills and cards.
- Headlines now fit down to a template-specific minimum instead of silently clipping.

## Unresolved risks

- Semantic focal-point coverage still needs human full-size inspection.
- Non-macOS rendering still depends on the documented HTML/CSS fallback.
