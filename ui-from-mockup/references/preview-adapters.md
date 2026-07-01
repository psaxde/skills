# Preview Adapters

Use this reference when the target UI cannot be screenshot directly. Keep adapter code small,
dev-only, and easy to delete.

## Decision Tree

1. If a static mock or public route renders the target, do not add app code.
2. If auth is the only blocker, prefer storage/cookie seeding with `shot.mjs`.
3. If data/state is the blocker, add a dev-only preview route with fixture props.
4. If backend calls are the blocker, stub only the endpoints required by the component.
5. If production could ever reach the preview path, stop and redesign the guard.

## Generic Web Pattern

- Route: `/__preview/<feature>?state=<preset>`
- Guard: compile-time dev flag when available, plus no link from normal navigation.
- Input: fixture state chosen from a small preset map.
- Network: scoped fetch/mock layer for the feature's own calls only.
- Output: same app shell/theme/components as real UI.
- Verification: production build grep for `__preview`, fixture names, and dev-only API names when the bundler should remove them.

Example shape:

```tsx
if (import.meta.env.DEV) {
  routes.push({
    path: "/__preview/order-summary",
    element: <OrderSummaryPreview />,
  });
}
```

```tsx
export function OrderSummaryPreview() {
  const preset = new URLSearchParams(location.search).get("state") ?? "full";
  return (
    <AppThemeProvider>
      <OrderSummary {...previewStates[preset]} />
    </AppThemeProvider>
  );
}
```

## Next.js Pattern

- Prefer a route under `app/__preview/<feature>/page.tsx` or `pages/__preview/<feature>.tsx`.
- Gate with `process.env.NODE_ENV === "development"` or a project-approved preview flag.
- Return 404 outside allowed environments.

## Native/Mobile Pattern

- Flutter: create a widget test or golden harness that loads the app font and renders the widget at target viewport width.
- iOS/Android: use existing simulator tooling if the project already has it; otherwise use a narrow component preview or screenshot test harness.
- Treat `analyze`/lint as insufficient for visual parity. The target must render.

## Project Adapter Note

If this workflow will repeat in a repo, add a short project note such as `docs/ui-preview.md`
or an AGENTS/CLAUDE section with:

- dev server command and port
- preview route pattern
- theme/token files
- asset/font requirements
- screenshot commands
- CI-like validation commands
- any forbidden dependency changes

Keep project notes factual. The global skill owns the workflow.
