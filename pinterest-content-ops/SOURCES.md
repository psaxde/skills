# Sources And Decisions

## Public-safe source inventory

| Source | Trust | Contribution |
|---|---|---|
| Anonymized operational Pinterest batch outcomes across retail and editorial accounts | operational evidence | approval gates, board-first safety, queue verification, 2:3 rendering, UTMs, and AI disclosure |
| Pinterest's visible creation and planner interfaces | live evidence | current fields, board selection, scheduling, and final-status verification |
| Local skill authoring and validation guidance | high | portable layout, routed references, specification, validation, and trigger requirements |
| Anonymized human-reviewed three-template comparison | human-verified | approved `editorial`, `bold_photo`, and `recipe_card` direction; exposed a legacy component-padding defect |

No account names, domains, local project paths, credentials, cookies, customer data, or private batch artifacts are included in this public bundle.

## Decisions

| Decision | Status | Reason |
|---|---|---|
| Primary shape: script-backed workflow | adopted | rendering and manifest validation are repeatable and error-prone in prose |
| Secondary shape: reference-backed expert | adopted | design and Pinterest UI details are needed only on their branches |
| Standard mode: preview | adopted | prevents unintended external publication |
| Existing boards before new boards | adopted | avoids weak near-duplicate boards and split signals |
| Authentic source imagery | adopted | generative substitution would misrepresent the destination |
| Generic public profile only | adopted | account-specific details belong in private or batch-local configuration |
| macOS Swift renderer | adopted with fallback | AppKit offers deterministic local rendering; an HTML/CSS fallback preserves portability |
| Automated live Pinterest script | rejected | UI state and selectors drift; fresh snapshots and field verification are safer |
| Three-family renderer | adopted | distinct compositions create useful batch variety beyond color-only variants |
| `editorial` default and fallback | adopted | it tolerates more source-photo and copy shapes than full-bleed or stat-led layouts |
| Eight-pin `3 / 3 / 2` starting mix | adopted | it provides meaningful layout variety while remaining adjustable for unsuitable sources |
| Symmetric 28 px component padding | adopted | it fixes observed edge collisions and creates a reusable geometry invariant |
| Missing `template` falling back to `classic` | adopted for compatibility | it preserves reproducible old configs; new contracts require an explicit modern template |

## Coverage

- Happy path: complete for source-backed category batches from preview through verified scheduling.
- Robust behavior: complete for preview-only authority, account checks, queue collisions, board mapping, selector drift, and partial completion.
- Negative behavior: complete for accidental publication risk caused by selecting a board after filling a pin.
- Measurement: complete for optional or required UTMs and delayed evaluation.
- Portability: partial; the non-macOS renderer fallback is documented but not bundled.
- Visual-system coverage: complete for three current templates, long-text fitting, crop focus, component padding, and classic compatibility.

## Trigger check

Should trigger:

- “Create the next Pinterest batch with the new templates.”
- “Make three Pinterest design variants from this article and show the preview first.”
- “Schedule these product pins on my existing boards.”

Should not trigger:

- “Crop this photo to 2:3.”
- “Create general short-form video ideas.”
- “How many Pinterest impressions did we get yesterday?”

The description already separates full Pinterest deliverables from image-only editing and analytics, so no description wording change was needed.

## Changelog

### 2026-07-21

- promoted a human-approved comparison into three reusable renderer templates
- added crop focus, fitted headlines, labeled contact sheets, palette extensions, and symmetric component padding
- retained `classic` only as a compatibility route for existing visual manifests
- added persistent anonymized working and holdout evidence for future design iterations

## Retrieval stop

The evidence covers the repeated decisions required for sourcing, creative production, approval, scheduling, and verification. New evidence should be added only when it changes one of those decisions and can be anonymized safely.
