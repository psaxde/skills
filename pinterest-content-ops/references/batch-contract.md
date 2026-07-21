# Batch Contract

## Folder layout

```text
<batch>/
├── BATCH.md
├── brand-profile.json
├── pins.json or pins.csv
├── visuals.json
├── contact-sheet.jpg
├── assets/
│   ├── source/
│   └── backgrounds/
└── pins/
    └── <id>.jpg
```

Use an established private project path when present. Otherwise use `<project>/pinterest/batches/<date>-<slug>/`.

## Pin manifest

Each entry must include:

| Field | Meaning |
|---|---|
| `id` | unique stable batch identifier |
| `date`, `time` | ISO date and 24-hour local time |
| `board` | intended existing or approved new board |
| `title` | Pinterest title |
| `description` | Pinterest description |
| `alt` | visible-image description |
| `link` | final destination or UTM URL |
| `creative_file` | path relative to batch root |
| `status` | `draft`, `ready_for_preview`, `approved`, `scheduled`, `published`, or `failed` |
| `ai_modified` | boolean disclosure decision |

CSV aliases accepted by the validator include `pin_id`, `schedule_date`, `schedule_time`, `pin_title`, `pin_description`, `utm_url`, and `destination_url`.

## Visual manifest

`visuals.json` uses this shape:

```json
{
  "brand": {
    "name": "Example Brand",
    "mark": "E",
    "accent": "#8F2635",
    "ink": "#26352E",
    "light": "#FFF9F0",
    "secondary": "#E9DFF7",
    "highlight": "#E2A660",
    "domain": "EXAMPLE.COM",
    "cta": "Discover more"
  },
  "pins": [
    {
      "id": "01",
      "template": "editorial",
      "product": "assets/source/product.jpg",
      "badge": "Category",
      "headline": "A short, readable headline.",
      "subline": "One source-backed benefit or context line",
      "label": "Short label",
      "meta_strong": "Primary benefit",
      "meta_text": "supporting context",
      "proof": "Authentic, verified attributes",
      "headline_size": 68,
      "image_focus_x": 0.5,
      "image_focus_y": 0.5
    }
  ]
}
```

Paths resolve relative to `visuals.json`. Per-pin palette values override the profile defaults.

### Visual fields

| Field | Rule |
|---|---|
| `template` | required for new batches: `editorial`, `bold_photo`, or `recipe_card`; `classic` is legacy-only |
| `product` | authentic source image path |
| `background` | optional for `editorial`; required only by `classic` |
| `badge`, `headline`, `subline`, `label`, `meta_strong`, `meta_text`, `proof` | short source-backed visible strings |
| `stat_value`, `stat_label` | optional compact stat for `recipe_card`; falls back to `meta_text` and `label` |
| `card_kicker` | optional localized recipe-card eyebrow; defaults to `DETAILS` |
| `image_focus_x`, `image_focus_y` | optional crop focus from `0.0` to `1.0`; defaults to center |
| `headline_size` | optional preferred size; renderer fits downward to the template minimum |

The renderer prints structured JSON with output paths and per-template counts. Missing required fields, invalid colors, unsupported templates, text overflow, and unreadable images must fail rendering.

## State and approval

1. Start at `draft`.
2. Move to `ready_for_preview` only after renderer and validator pass.
3. Move to `approved` only after explicit approval or prior scheduling authority.
4. Move to `scheduled` or `published` only after live Pinterest verification.
5. Use `failed` with a concise reason for incomplete items; never silently skip them.

## Batch summary

`BATCH.md` should record:

- source scope and account
- visual strategy and generative elements
- date/time/board table
- approval and live status
- validation result
- links to manifest and contact sheet

## Validation loop

Run the validator after manifest creation and after rendering. Fix all errors, re-run, then inspect the contact sheet. Warnings require judgment; record intentionally accepted warnings in `BATCH.md`.
