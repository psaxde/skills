---
name: marketing-performance-check
description: Run recurring cross-source marketing performance checks using GA4, Google Search Console, advertising, commerce, CRM, SEO tool, and first-party or local data. Use when Codex needs to refresh or inspect marketing data, compare equal periods, reconcile apparently conflicting metrics, diagnose growth or decline, validate data freshness, prepare a weekly or monthly performance report, or turn analytics into prioritized actions.
---

# Marketing Performance Check

## Overview

Turn multiple marketing data sources into one evidence-based diagnosis. Lead with business impact, preserve source provenance, distinguish facts from inferences, and write the result in the user's requested language.

## Operating principles

- Prefer fresh first-party and business-system data over estimates when measuring outcomes.
- Treat local warehouses, generated reports, and existing collectors as first-class sources.
- Compare sources without pretending that unlike metrics are interchangeable. A GSC click is not a GA4 session, and either may differ from a first-party event.
- Keep all access read-only unless the user explicitly requests a platform change.
- Never print, copy, or commit credentials, tokens, account IDs, property IDs, private URLs, customer data, or private configuration.
- State data gaps and uncertainty instead of filling them with assumptions.

## Workflow

### 1. Establish the question

Determine the site or product, requested period, comparison period, primary business question, and output language. Infer these from available project context when safe; ask only when a missing choice would materially change the analysis.

Default to:

- the most recent complete period shared by the important sources;
- an immediately preceding period with the same number and pattern of days;
- a year-over-year comparison when seasonality matters and complete data exists;
- a concise status-first report followed by evidence and actions.

### 2. Discover the available evidence

Inspect project instructions, dashboards, collector scripts, warehouses, and recent generated reports before inventing a new retrieval path. Prefer an established refresh command when the project already has one.

Use live connectors or APIs when current data is required and access is available. Record every source's coverage end date, retrieval time, timezone, status, and relevant filters. Read [private-configuration.md](references/private-configuration.md) when setting up or troubleshooting a local profile.

### 3. Refresh safely

Refresh stale sources when an existing read-only collector or connector is available. Do not modify campaigns, analytics properties, consent settings, tags, or production data as part of a performance check.

Capture partial failures. Continue with usable evidence when doing so cannot create a misleading conclusion, and label the missing source prominently.

### 4. Align periods and definitions

Use the latest complete date shared by the sources needed for the main conclusion. Exclude incomplete current-day data unless the user explicitly asks for intraday monitoring.

Verify:

- equal comparison-window length;
- source and account timezone;
- filters, channel definitions, attribution windows, and currency;
- instrumentation or consent changes inside the comparison window;
- whether revenue includes tax, shipping, refunds, or cancellations;
- whether the source represents observed behavior or an external estimate.

Read [metric-guide.md](references/metric-guide.md) before reconciling unfamiliar metrics or sources.

### 5. Normalize and validate the snapshot

Normalize the evidence to the structure in [data-contract.md](references/data-contract.md) when several sources or metrics are involved. Use the bundled synthetic [example-snapshot.json](references/example-snapshot.json) as a shape example only.

Run the deterministic validator when a normalized snapshot exists:

```bash
python3 scripts/analyze_snapshot.py path/to/snapshot.json
```

Use `--format json` when another script will consume the result. Treat validator warnings as prompts for investigation, not automatic proof that the underlying data is wrong.

### 6. Analyze in business order

Analyze the evidence in this order:

1. Business outcomes: qualified leads, orders, revenue, margin, subscriptions, or another explicit goal.
2. Conversion: conversion rate, funnel completion, average order value, and revenue per visit.
3. Acquisition: traffic, clicks, sessions, channel mix, campaign performance, and search demand.
4. Quality and concentration: landing pages, queries, products, campaigns, geography, and new versus returning users.
5. Diagnostics: tracking gaps, consent effects, outages, attribution changes, seasonality, and source discrepancies.

Identify concentration explicitly. Growth driven by one page, query, campaign, or temporary event is less resilient than broad-based growth.

Do not use causal verbs such as `drove`, `caused`, or `resulted in` for movements that merely occurred together. Use `coincided with`, `is consistent with`, or `may have contributed` unless an experiment, attribution model, or joined event path supports causality. For rate metrics, report percentage-point change and optionally add relative percent change.

Separate each important conclusion into:

- **Observed:** directly supported by a named source and period.
- **Inferred:** the most plausible explanation, with competing explanations noted when material.
- **Action:** the smallest useful next step, its expected signal, and when to reassess.

### 7. Produce the report

Lead with a direct answer to the user's question. Then include:

1. overall status and the two to four most important changes;
2. data coverage and freshness, including failed or missing sources;
3. a compact comparison table with current, previous, delta, and interpretation;
4. the diagnosis of what contributed to the result and what remains weak;
5. prioritized actions with owners or checkpoints when known;
6. uncertainties and the next measurement date.

Use [report-template.md](assets/report-template.md) when saving a reusable report artifact. Link directly to generated artifacts when the environment supports file links.

## Quality gate

Before reporting completion:

- confirm that every headline number has a source and exact date range;
- confirm that comparison windows are aligned or disclose why they are not;
- confirm that source freshness supports the claimed conclusion;
- confirm that estimates are labeled as estimates;
- confirm that observed facts and causal inferences are separated;
- confirm that causal wording is supported by experimental, attribution, or joined-path evidence;
- confirm that no secret or private identifier appears in committed files or output artifacts;
- confirm that actions follow from the evidence rather than a generic marketing checklist.
