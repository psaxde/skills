---
name: pinterest-content-ops
description: Creates complete Pinterest pin batches from product shops, category pages, blog posts, recipes, campaigns, or local assets, including source research, authentic images, SEO copy, 1000x1500 creatives, contact-sheet previews, board mapping, approval gates, scheduling or publishing in a logged-in Pinterest account, UTMs, and final verification. Use when asked to create, preview, plan, schedule, publish, refresh, or batch Pinterest pins for any brand or Pinterest account.
---

# Pinterest Content Ops

Produce a traceable Pinterest batch from source discovery through verified scheduling. Preserve authentic source imagery and stop at the preview gate unless the user has authorized live Pinterest writes.

## Route references

| Need | Read |
|---|---|
| Create or adapt an account profile | `references/brand-profiles.md` |
| Write SEO copy, select images, generate backgrounds, and design pins | `references/content-design.md` |
| Create the batch folder, manifests, states, UTMs, and validation outputs | `references/batch-contract.md` |
| Operate the logged-in Pinterest UI and avoid accidental publication | `references/pinterest-ui.md` |
| Compare a good run, a cautious run, and a corrected anti-pattern | `references/examples.md` |

## Determine authority first

Classify the request before changing external state:

| Mode | User intent | Allowed end state |
|---|---|---|
| `preview` | create, generate, prepare, show a preview | local batch and contact sheet only |
| `schedule` | plan or schedule pins | local batch plus scheduled Pinterest cards |
| `publish` | publish now | local batch plus live pins |
| `audit` | review, diagnose, report | read-only findings only |

Treat “show me a preview first”, “prepare only”, or equivalent as a hard approval gate. Do not infer scheduling authority from access to a logged-in account.

## Core workflow

1. **Preflight**
   - Verify the active Pinterest profile before any live write.
   - Confirm source URLs, target period, quantity, language, and request mode from the prompt or current context.
   - Inspect the existing queue before choosing dates. Avoid collisions and unintended same-slot duplicates.
   - Copy the generic profile into the batch and adapt it from verified account information.

2. **Collect authentic sources**
   - Inspect the actual category, product, recipe, or article pages.
   - Capture exact titles, destination URLs, main images, attributes, and claims from visible source content.
   - Prefer the connected browser's page-asset export for authenticated or rendered pages.
   - Never invent a product, price, ingredient, personalization option, medical claim, or delivery promise.

3. **Choose the batch mix**
   - Prefer topical and visual variety over near-identical variants.
   - Map each pin to an existing relevant board. Propose a new board only for a genuine coverage gap.
   - Use multiple pins per destination only when headline, crop, intent, or layout differs materially.
   - Assign every new creative one of `editorial`, `bold_photo`, or `recipe_card`; keep `classic` only for reproducible legacy batches.
   - For an eight-pin batch where every family is suitable, start with `3 editorial / 3 bold_photo / 2 recipe_card` and adapt from there.
   - Choose dates after the last scheduled item unless the user requested a campaign window.

4. **Build the offline batch**
   - Create the folder contract from `references/batch-contract.md`.
   - Write `pins.json` or `pins.csv` before scheduling.
   - Create `visuals.json` with an explicit per-pin `template`, generate decorative backgrounds when useful, and render 1000 x 1500 px JPGs.
   - Keep source products, food, people, and article imagery unchanged. Generative elements may frame or support them, not replace them.
   - Generate `contact-sheet.jpg` and a concise `BATCH.md`.

5. **Validate and review**
   - Run `scripts/validate_batch.py --manifest <pins.json-or-csv> --images-root <batch-dir>`.
   - Fix every error and re-run until `ok: true`.
   - Inspect the contact sheet and one full-size pin from every used template for clipping, contrast, mobile readability, image integrity, balanced component padding, and duplicate layouts.
   - Verify every destination URL once before live scheduling.

6. **Apply the approval gate**
   - In `preview` mode, stop and present the contact sheet, schedule, board mapping, and artifact paths.
   - Continue only after explicit approval or when the original request already authorized `schedule` or `publish` mode.

7. **Schedule or publish**
   - Read `references/pinterest-ui.md` completely before live Pinterest writes.
   - Select the board while the pin is still blank.
   - Fill image, title, description, alt text, link, AI disclosure, date, and time.
   - Verify all fields immediately before the final Pinterest action.

8. **Verify the live result**
   - Confirm every title appears exactly once in the planner or published list.
   - Confirm each card has the intended status and date.
   - Preserve the planner or account page as the final browser handoff.
   - Update `BATCH.md` or a status result file with actual outcomes and Pinterest IDs when available.

## Bundled tools

### Render pins

Use the macOS renderer when `swift` and AppKit are available:

```bash
swift scripts/render_pins.swift \
  --config /path/to/batch/visuals.json \
  --out /path/to/batch/pins \
  --contact-sheet /path/to/batch/contact-sheet.jpg
```

Input and output fields are defined in `references/batch-contract.md`. If Swift is unavailable, create an equivalent deterministic HTML/CSS renderer and keep the same manifest and output contract.

### Validate a batch

```bash
python3 scripts/validate_batch.py \
  --manifest /path/to/batch/pins.json \
  --images-root /path/to/batch
```

Add `--require-utm` when the account profile requires measurable outbound URLs. The validator prints JSON and exits non-zero on errors.

## Non-negotiable rules

- Use authentic source images for actual products, food, recipes, pets, and people.
- Do not place changeable prices or unsupported urgency claims inside evergreen graphics.
- Do not create a near-duplicate board when an existing board fits.
- Do not publish while selecting a board for a filled pin; use the blank-pin sequence.
- Mark generative or materially AI-modified creative elements when the Pinterest UI provides that disclosure.
- Never store credentials, cookies, customer data, or private browser state in a batch or this skill.
- Report partial completion precisely; never label an unverified pin as scheduled or published.

## Final handoff

Lead with the outcome. Include:

1. number of pins created and live status
2. dates, times, boards, and account
3. contact sheet and batch folder links
4. verification result and any failed or intentionally skipped items
5. whether existing boards were reused or a new board was created
