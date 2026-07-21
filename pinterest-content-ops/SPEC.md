# Pinterest Content Ops Specification

## Intent

Provide a reusable, account-agnostic production workflow for Pinterest batches. Separate offline creation, user approval, and live Pinterest writes so a preview request can never silently become publication.

## Scope

In scope:

- product, recipe, article, campaign, and seasonal pins
- source research and authentic asset capture
- SEO titles, descriptions, alt text, links, and UTMs
- 1000 x 1500 px creative rendering and contact sheets
- three reusable visual families with deterministic text fitting and crop focus
- existing-board mapping, scheduling, publishing, and verification
- reusable batch-local account profiles and manifests

Out of scope:

- paid Pinterest Ads campaign management
- autonomous publication without user authority
- fabricated product, health, ingredient, or fulfillment claims
- long-term analytics optimization without connected performance data

## Users And Trigger Context

- Primary users: operators producing Pinterest content for one or more accounts.
- Common requests: create pins from a category, preview a batch, fill a queue, schedule approved pins, or reuse the workflow for another account.
- Should not trigger for: generic social-media ideation with no Pinterest deliverable, image-only editing, or read-only account analytics unless batch operations are also requested.

## Runtime Contract

- Required first actions: determine authority mode, verify account and sources, inspect existing queue and boards.
- Required outputs: batch manifest, explicit per-pin template assignments, final creatives, labeled contact sheet, schedule, validation result, and live-status evidence when applicable.
- Non-negotiable constraints: authentic source imagery, approval gate, blank-pin board selection, no duplicate status claims, balanced component padding, and full-size QA for every used template.
- Expected runtime references: only the leaves routed by `SKILL.md` for the active branch.

## Source And Evidence Model

Authoritative sources:

- visible product, recipe, article, and Pinterest account state
- current user instruction and explicit approval
- bundled batch validator output
- verified batch-local account profile

Useful improvement sources:

- successful batch artifacts and contact sheets
- human-approved and rejected design comparisons
- accidental-publication or duplicate-board incidents
- Pinterest UI changes and selector drift
- outbound-click and conversion results after a sufficient evaluation window

Data that must not be stored:

- credentials, cookies, tokens, customer records, private messages, or unrelated browser state

## Reference Architecture

- `SKILL.md` contains universal runtime flow and safety gates.
- `references/` contains profile intake, content design, batch contract, Pinterest UI, and transformed examples.
- `references/evidence/` contains anonymized positive, negative, and holdout design examples.
- `scripts/` contains deterministic rendering and validation.
- `assets/` contains reusable generic templates.
- `SOURCES.md` contains public-safe provenance, decisions, and known gaps.

## Validation

- Lightweight validation: system skill validator plus `scripts/validate_batch.py` on a fixture.
- Deeper validation: render all three current templates plus the legacy compatibility path, inspect dimensions/contact sheet/full-size outputs, and test trigger/anti-trigger prompts.
- Holdout examples: long headline fitting, unsuitable full-bleed crop fallback, and recipe cards without verified stats.
- Acceptance gates: valid frontmatter, discoverable references, passing fixtures, 1000 x 1500 output, at least 28 px component padding, explicit approval boundary, and no host-specific runtime paths.

## Known Limitations

- Pinterest accessibility names and controls can change; the UI reference requires fresh snapshots.
- The bundled renderer uses macOS AppKit; non-macOS runs need an equivalent deterministic fallback.
- Template choice still requires visual judgment; the renderer cannot know whether text covers the semantic focal point.
- Scheduling requires an already authenticated Pinterest browser session.

## Maintenance Notes

- Update `SKILL.md` when authority, batch, or verification behavior changes.
- Update `references/pinterest-ui.md` when Pinterest controls or safety behavior changes.
- Keep account-specific profiles outside this public skill and derive batch-local copies from verified current sources.
- Add only anonymized outcome evidence to `SOURCES.md`; never add private account or customer data.
- Update design evidence when a user approves or rejects a template direction or a visual regression is found.
