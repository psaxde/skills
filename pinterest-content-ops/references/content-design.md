# Content And Design

## Source integrity

- Use the actual page title, destination, product or article image, and visible attributes.
- Treat generated images as framing, mood, background, or illustration only.
- Do not alter names shown on a product, food appearance, ingredients, materials, quantities, or included components.
- Keep unsupported prices, discounts, shipping promises, health claims, and urgency out of copy and graphics.

## Copy contract

| Field | Rule |
|---|---|
| Title | main search intent first; 1-100 characters; unique within batch |
| Description | natural language; normally 150-500 characters; include destination benefit and verified context |
| Alt text | describe what is visibly shown; no keyword stuffing |
| CTA | match destination: shop, recipe, guide, collection, or marketplace |
| Hashtags | default to none; follow a verified account rule when present |
| Year | use only when seasonally useful and current for the scheduled period |

Create distinct variants by changing at least two of: search intent, headline, crop, layout, supporting benefit, season, or recipient. A color-only change is not a meaningful new pin.

## Visual contract

- Canvas: 1000 x 1500 px, 2:3, JPG.
- Keep the headline readable at mobile width and usually within the upper third.
- Let the authentic source image occupy the visual focus.
- Use strong contrast and quiet areas behind text.
- Limit one pin to one primary message and one CTA.
- Keep small footer proof optional and legible; remove it if it competes with the subject.
- Keep at least 70 px outer safe area and at least 28 px horizontal padding inside pills, buttons, and metadata cards.
- Never place right-aligned text directly against a component edge.
- Inspect the contact sheet and one full-size pin from every used template.

## Template system

Use the three-family system for every new batch. Set `template` explicitly in each `visuals.json` entry.

| Template | Choose when | Avoid when |
|---|---|---|
| `editorial` | default; calm premium treatment, flexible copy, framed source image | the source image needs nearly the whole canvas to read |
| `bold_photo` | a high-resolution image has clear overlay space and can carry the feed stop | text would cover the subject, crop destroys context, or contrast stays weak |
| `recipe_card` | verified ingredients, time, yield, or another compact fact improves scanning | the supporting fact is missing, uncertain, or too long |
| `classic` | re-rendering an old batch that already used the legacy schema | all new batches |

For an eight-pin batch where every family fits, start with three `editorial`, three `bold_photo`, and two `recipe_card` pins. Do not force the ratio: replace an unsuitable `bold_photo` or `recipe_card` with `editorial` and record the reason in `BATCH.md`.

### Composition rules

- Use `editorial` as the fallback when image or copy suitability is uncertain.
- Use `image_focus_x` and `image_focus_y` values from `0.0` to `1.0` to preserve the subject during aspect-fill crops.
- Keep the primary headline above 50 px after fitting; shorten the visible copy when it would need to become smaller.
- Use no more than two compact supporting facts on `bold_photo`.
- On `recipe_card`, use only source-verified `stat_value`, `stat_label`, `meta_strong`, and `proof` values.
- Treat color-only changes as one layout, not as meaningful template variety.

### Visual QA gate

Before approval:

1. view the contact sheet at approximately 500 px pin width
2. open one full-size output per used template
3. verify complete headline, CTA, pills, domain, and stat labels
4. verify at least 28 px left and right padding in every pill or card
5. verify text does not cover the source-image focal point
6. verify the source image has only been cropped and framed unless `ai_modified` says otherwise

## Background generation

When backgrounds add value, generate 2-4 reusable scenes per batch:

1. state vertical 2:3 and the account palette
2. reserve a large clean central or upper area
3. place decorative elements only at edges
4. prohibit text, logos, people, and fake products
5. copy generated files into the batch and record that use in `BATCH.md`

Set `ai_modified: true` for pins using generated backgrounds or material image edits. Keep it false for simple crops, layout, and typography around unchanged source photos unless current Pinterest policy requires otherwise.

## Destination and measurement

- Open each destination URL before scheduling.
- Prefer the most specific valid product, recipe, or article URL.
- Add unique UTMs when the account profile requires them.
- Do not replace a direct destination with a generic home page unless the source item is unavailable.
