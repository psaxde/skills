---
name: ui-from-mockup
description: Build or refine frontend UI from a mockup, screenshot, design export, HTML mock, Figma screenshot, or visual reference by using a closed render screenshot compare loop plus optional DOM layout snapshots, PNG diff heatmaps, region crops, and global-shift diagnostics. Use when Codex is asked to recreate UI accurately, make an implementation match a mockup, compare two screenshots, explain visual differences, generate a visual diff, port a design across web, Flutter, or native mobile targets, convert an HTML design into Flutter widgets, reduce visual QA rounds, create a dev-only preview route or widget harness, extract a UI spec before coding, or verify layout/animation fidelity with screenshots or golden tests.
---

# UI From Mockup

Use this skill to stop coding UI blind. The goal is a reusable, project-neutral workflow:
make the target screen reachable, extract a short spec from the visual source, implement from
that spec, take screenshots, read the PNGs, fix, and repeat until only cosmetic differences remain.

## Load Only When Needed

- For screenshot commands, use `scripts/shot.mjs`.
- For PNG screenshot diffs and heatmaps, use `scripts/diff.mjs`.
- For machine-readable DOM/layout snapshots, use `scripts/layout.mjs`.
- For debugging unreachable pages, use `scripts/diag.mjs`.
- For project-specific preview-route patterns, read `references/preview-adapters.md`.
- For Flutter implementation, safe areas, widget harnesses, simulator capture, and golden testing, read `references/flutter.md`.
- For the extracted implementation spec, copy `assets/spec.template.md` into the project, usually under `docs/plans/<feature>/spec.md`.

## Core Rules

1. Reach the screen first. If the app cannot render the desired state without login, backend data, feature flags, or manual clicking, create a dev-only preview route or fixture harness before doing visual diff work.
2. Extract a spec before coding. Do not feed a huge HTML mock or image blob directly to implementation subagents. Distill blocks, spacing, states, colors/tokens, and animation frames into `spec.md`.
3. Render wins over markup. If a source HTML mock and user screenshot disagree, follow the rendered screenshot and note the disagreement.
4. Missing blocks beat pixel drift. Check that every visible block exists before obsessing over exact spacing.
5. Use app tokens. Keep layout faithful to the mockup, but map colors, typography, radius, shadows, and spacing to the app's design tokens when they exist. New raw colors should become named tokens, not scattered hex literals.
6. Verify motion with frames. "Add animation" is too vague; capture or specify properties, duration, easing, delay, and keyframes.
7. Keep visual tooling out of product deps unless the project already has it. Prefer this skill's Playwright helper or an existing project test stack.
8. Treat pixel diff as evidence, not judgment. Heatmaps show where pixels differ; the agent must still inspect screenshots to decide whether the difference is missing content, wrong state, font/rendering drift, antialiasing, or acceptable polish.
9. Match capture conditions before trusting diffs. Use the same viewport, crop/selector, seeded state, wait condition, scroll position, browser, font environment, and freeze setting for target and actual captures.
10. Prefer explainable artifacts over red overlays. Read the compare sheet, region crops, layout JSON, and shift report before deciding what to change.
11. Classify each discrepancy as visual, client behavior, or external contract work. A mockup can imply new behavior, but UI code alone does not implement a missing API, persistence rule, permission, or platform capability.

## Workflow

### Gate 0: Reachability

Pick the lightest route or harness that renders the target state reproducibly:

- Public/static screen: screenshot the real URL or `file://` mockup directly.
- Stateful app screen: seed URL params, localStorage/sessionStorage, cookies, or fixtures.
- Protected or backend-dependent screen: add a dev-only preview route like `/__preview/<feature>?state=full` that mounts the component with fixture props and scoped API stubs.
- Native/mobile target: create a widget/golden harness or web/simulator preview that produces a screenshot.

Read `references/preview-adapters.md` when adding a preview route.

### Gate 1: Spec Extraction

Create `docs/plans/<feature>/spec.md` from `assets/spec.template.md`. Fill it with:

- visible block inventory
- exact spacing/sizing where the mockup is specific
- states: default, hover, focus, error, empty, loading, disabled
- animation numbers: property from/to, duration, easing, delay/stagger, loop
- token mapping: mockup value -> app token, with named-token TODOs for new values
- platform geometry: logical size, output pixels/DPR, safe-area insets, system chrome, locale, and text scale
- change classification: visual, client behavior, or external contract
- source/render disagreements and scope decisions

This spec is the shared input for implementation and any subagent. The raw mockup remains evidence, not the operating manual.

### Gate 2: Scope Check

Before coding net-new or ambiguous items, state the intended interpretation in one sentence. Example:
`I will add the missing consent block below the summary section because it appears in the rendered screenshot.`

### Gate 3: Implementation

Implement from the spec using the project's existing UI components, tokens, routing, and test style.
For multi-target work, use the same spec for every target and document intentional platform differences.
For Flutter targets, read `references/flutter.md` before choosing the widget structure or capture harness.

### Gate 4: Checklist Diff

Before screenshot polishing, walk the block inventory in `spec.md` and mark whether each block exists in each target. Fix absent blocks first.

### Gate 5: Visual Loop

Install the helper once in this skill folder when needed:

```bash
cd /Users/ben/.codex/skills/ui-from-mockup/scripts
npm install
npx playwright install chromium
```

Capture the target and actual UI:

```bash
node /Users/ben/.codex/skills/ui-from-mockup/scripts/shot.mjs \
  --url file:///absolute/path/mockup.html \
  --out /tmp/ui-target-1280.png \
  --vw 1280 \
  --freeze

node /Users/ben/.codex/skills/ui-from-mockup/scripts/shot.mjs \
  --url http://localhost:5173/__preview/example?state=full \
  --out /tmp/ui-actual-1280.png \
  --vw 1280 \
  --freeze
```

Use identical capture conditions for both screenshots: viewport, selector/crop, seeded state, wait condition, scroll position, browser, and `--freeze`. If one screenshot is full-page and the other is viewport-only, the diff will mostly measure capture drift.

Read both PNGs visually. Compare in this order: layout, missing blocks, spacing, type scale, color/token mismatches, icons/assets, fine polish. Repeat until differences are cosmetic or progress stalls.

Create a layout snapshot when the actual UI is browser-rendered. This gives the agent concrete boxes, text, and computed styles to inspect instead of guessing from a red overlay:

```bash
node /Users/ben/.codex/skills/ui-from-mockup/scripts/layout.mjs \
  --url http://localhost:5173/__preview/example?state=full \
  --out /tmp/ui-actual-layout-1280.json \
  --vw 1280 \
  --freeze \
  --wait "[data-ready]"
```

If the mockup is renderable HTML, capture a target layout JSON too and compare the key blocks by text/role/test id plus x/y/width/height. If the mockup is only a PNG, use the layout JSON for actual UI and the visual spec/checklist for expected positions.

Generate a diff heatmap when the visual differences are not obvious, when tracking progress across iterations, or when you need a concrete artifact:

```bash
node /Users/ben/.codex/skills/ui-from-mockup/scripts/diff.mjs \
  --expected /tmp/ui-target-1280.png \
  --actual /tmp/ui-actual-1280.png \
  --out /tmp/ui-diff-1280.png \
  --compare-out /tmp/ui-compare-1280.png \
  --regions-dir /tmp/ui-diff-regions \
  --threshold 0.06
```

Prefer reading `--compare-out`, region crops, and layout JSON over reading the heatmap alone. The compare image is a three-panel sheet: expected screenshot with a blue frame, actual screenshot with a green frame, diff heatmap with a red frame. Region crops use the same order and make the "what changed" visible. Use the reported total percentage and largest boxes to focus inspection. A low percentage can still hide a missing small element, and a high percentage can be caused by one global shift or font mismatch.

The diff summary includes `shift.actualOffset` and `shift.suggestedCorrection`. Example: `actualOffset.y = 8` means the actual screenshot appears roughly 8px lower than the target; the suggested correction is about `-8px`. Treat this as a coarse diagnostic, then confirm with the screenshots and layout boxes.

For mobile, capture a real logical viewport such as `--vw 390 --vh 844`. If the actual screenshot
comes from a native device or simulator, add `--dpr` so the target PNG has matching physical
dimensions. For full web pages, add `--full`. Read `references/flutter.md` for the native loop.

For animation:

```bash
node /Users/ben/.codex/skills/ui-from-mockup/scripts/shot.mjs \
  --url http://localhost:5173/__preview/example?state=full \
  --click "[data-open-details]" \
  --frames 5 \
  --interval 120 \
  --out /tmp/ui-motion.png
```

Do not combine `--freeze` with animation frames.

### Gate 6: Done

Finish with:

- screenshots or golden artifacts checked by the agent
- checklist-diff updated in `spec.md`
- focused logic tests where behavior changed
- project verification commands run, using the exact CI-like commands when known
- no visual-tool dependency churn in the app unless intentionally requested

## Practical Commands

Debug why a route does not render:

```bash
node /Users/ben/.codex/skills/ui-from-mockup/scripts/diag.mjs \
  --url http://localhost:5173/some/route \
  --wait 3000 \
  --grep "/api|/auth|/feature"
```

Compare two existing PNG screenshots:

```bash
node /Users/ben/.codex/skills/ui-from-mockup/scripts/diff.mjs \
  --expected ./mockup.png \
  --actual ./actual.png \
  --out ./diff.png \
  --compare-out ./compare.png \
  --regions-dir ./diff-regions \
  --json ./diff.json \
  --threshold 0.06 \
  --min-region-pixels 30
```

Extract a browser layout snapshot:

```bash
node /Users/ben/.codex/skills/ui-from-mockup/scripts/layout.mjs \
  --url http://localhost:5173/some/route \
  --out ./layout.json \
  --vw 1280 \
  --vh 900 \
  --freeze \
  --wait "[data-ready]"
```

Seed storage for a protected local route:

```bash
node /Users/ben/.codex/skills/ui-from-mockup/scripts/shot.mjs \
  --url http://localhost:5173/some/route \
  --out /tmp/ui-auth.png \
  --ls access_token=REDACTED \
  --ss preview_state=full \
  --wait "[data-ready]"
```
