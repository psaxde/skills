# Sources And Decisions

## Public-safe source inventory

| Source | Trust | Contribution |
|---|---|---|
| Anonymized operational Pinterest batch outcomes across retail and editorial accounts | operational evidence | approval gates, board-first safety, queue verification, 2:3 rendering, UTMs, and AI disclosure |
| Pinterest's visible creation and planner interfaces | live evidence | current fields, board selection, scheduling, and final-status verification |
| Local skill authoring and validation guidance | high | portable layout, routed references, specification, validation, and trigger requirements |

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

## Coverage

- Happy path: complete for source-backed category batches from preview through verified scheduling.
- Robust behavior: complete for preview-only authority, account checks, queue collisions, board mapping, selector drift, and partial completion.
- Negative behavior: complete for accidental publication risk caused by selecting a board after filling a pin.
- Measurement: complete for optional or required UTMs and delayed evaluation.
- Portability: partial; the non-macOS renderer fallback is documented but not bundled.

## Retrieval stop

The evidence covers the repeated decisions required for sourcing, creative production, approval, scheduling, and verification. New evidence should be added only when it changes one of those decisions and can be anonymized safely.
