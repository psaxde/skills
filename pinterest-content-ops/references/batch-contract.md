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
    "cta": "Discover more"
  },
  "pins": [
    {
      "id": "01",
      "background": "assets/backgrounds/scene.png",
      "product": "assets/source/product.jpg",
      "badge": "Category",
      "headline": "A short, readable headline.",
      "subline": "One source-backed benefit or context line",
      "label": "Short label",
      "meta_strong": "Primary benefit",
      "meta_text": "supporting context",
      "proof": "Authentic, verified attributes",
      "headline_size": 68,
      "dark": false
    }
  ]
}
```

Paths resolve relative to `visuals.json`. Per-pin `accent` and `ink` override the profile defaults.

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
