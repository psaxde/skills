# Flutter Adapter

Use this reference when the visual source is HTML, screenshots, or another platform and the
implementation target is Flutter. Preserve the skill's normal spec and screenshot loop; replace
DOM assumptions with a reproducible widget or simulator harness.

## Contents

- [Workflow](#workflow)
- [Classify The Change](#classify-the-change)
- [Translate The Visual Model](#translate-the-visual-model)
- [Handle Shared Chrome And Native Geometry](#handle-shared-chrome-and-native-geometry)
- [Create Reachable States](#create-reachable-states)
- [Capture And Compare](#capture-and-compare)
- [Verify Behavior And Resilience](#verify-behavior-and-resilience)

## Workflow

1. Inspect the existing theme, shared widgets, routing, localization, test conventions, and
   supported device sizes before editing.
2. Render HTML references with `shot.mjs`; use `layout.mjs` to extract useful measurements when
   the source is browser-rendered.
3. Inventory shared app chrome separately from screen-specific content. Implement reusable
   headers, navigation, sheets, and tokens once.
4. Classify every requested difference before treating it as implementation work.
5. Build one deterministic Flutter state at a time through an existing route, widget harness,
   golden test, or dev-only preview entry.
6. Capture the actual Flutter output, compare it with the reference PNG, and fix differences in
   the normal layout-to-polish order.
7. Verify interactions, compact widths, localization, text scaling, and safe areas before
   declaring parity.

## Classify The Change

| Class | Examples | Required response |
|---|---|---|
| Visual | spacing, color, typography, radius, icon, composition | Implement with existing widgets and tokens |
| Client behavior | navigation, sheet state, validation, multistep flow | Add state and focused widget tests |
| External contract | new API, persistence, permission, authentication method | Identify and implement or explicitly scope the non-UI dependency |

Do not imply that a visual implementation completes an external contract. Keep backend-specific
details out of this skill and route that work through the target project's own contract workflow.

## Translate The Visual Model

- Treat exported HTML and CSS as measurable evidence, not Flutter source code. Do not embed the
  mockup in a WebView unless the product requirement is genuinely web content.
- Map layout intent instead of copying DOM structure:
  - flex row/column -> `Row` or `Column`
  - wrapping content -> `Wrap`
  - scrollable document -> `ListView`, `CustomScrollView`, or slivers
  - true overlay -> `Stack` and `Positioned`
  - reusable surface styling -> theme tokens, shared widgets, and `BoxDecoration`
- Use `Expanded`, `Flexible`, constraints, and wrapping before introducing fixed widths.
- Reserve absolute positioning for genuine overlays. Coordinates copied from a fixed HTML canvas
  commonly overflow on narrower devices.
- Preserve application localization, semantics, accessibility labels, routing, and data behavior
  even when the reference contains static replacement content.
- Prefer the project's icon and font assets. Record unavoidable platform rendering differences in
  the spec rather than compensating with unexplained pixel offsets.

## Handle Shared Chrome And Native Geometry

- Paint full-bleed backgrounds outside `SafeArea`; apply safe-area padding to foreground content.
  Wrapping the entire header in `SafeArea` can visibly cut off gradients and background artwork.
- Avoid hardcoded status-bar and home-indicator heights. Read `MediaQuery.padding`,
  `viewPadding`, and `viewInsets`, and check whether `Scaffold` or `AppBar` already consumes them.
- Account for keyboard insets and bottom navigation when sizing scrollable content.
- Use edge-to-edge or body-extension APIs only when the design requires content behind system
  chrome, and set status-bar icon brightness deliberately.
- Implement shared headers and bottom navigation in the app shell when the design applies to many
  screens. Do not duplicate them page by page.
- For data-driven navigation, keep semantic roles such as primary action explicit in configuration
  and let the renderer own appearance. Do not infer a special control solely from its label or
  position.

## Create Reachable States

- Prefer the project's existing widget/golden test harness.
- Load the real theme, fonts, localization delegates, and directionality.
- Use small deterministic fixtures for default, loading, empty, error, selected, sheet-open, and
  relevant flow steps.
- Stub only the boundary required to render the state. Do not put production credentials or
  untracked environment secrets in a visual harness.
- Keep preview entry points compile-time or development guarded and unreachable in release builds.
- Use simulator capture when system chrome or platform rendering matters; use golden tests for
  faster deterministic component and app-surface iteration.

## Capture And Compare

Capture an HTML reference at the same logical size and device-pixel ratio as the Flutter output:

```bash
node /absolute/path/ui-from-mockup/scripts/shot.mjs \
  --url file:///absolute/path/mockup.html \
  --out /tmp/flutter-target.png \
  --vw 390 --vh 844 --dpr 3 \
  --freeze
```

Reach the exact state in the selected simulator or emulator, then capture it:

```bash
xcrun simctl io booted screenshot /tmp/flutter-actual.png
adb exec-out screencap -p > /tmp/flutter-actual.png
```

Use the platform command that matches the active target. Before running `diff.mjs`, confirm both
PNGs have identical pixel dimensions, crop, orientation, system-chrome inclusion, locale, text
scale, and seeded state. A `390x844` logical viewport at `3x` produces `1170x2532` output pixels.
Define the acceptable visual tolerance and intentional platform differences in the spec; there is
no universal diff percentage that proves parity.

Golden tests usually omit real operating-system chrome. Compare them against a reference cropped
to the app surface, or emulate the intended insets in the harness. Do not compare a full simulator
screenshot with an app-surface-only golden.

## Verify Behavior And Resilience

- Add widget tests for taps, navigation, sheets, validation, and flow transitions introduced by
  the mockup.
- Test at the narrowest supported width and inspect `tester.takeException()` for overflow.
- Exercise longer localized strings and a larger supported text scale.
- Verify scrolling with the keyboard open and with bottom system/navigation insets.
- Use goldens for stable visual contracts, not for rapidly changing or platform-dependent pixels.
- Finish only after the rendered state, behavior tests, analyzer/lint, and project verification
  commands agree with the extracted spec.
