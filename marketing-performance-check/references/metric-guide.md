# Cross-source metric guide

Use this guide to decide what can be compared, what can only be triangulated, and which caveats belong in the report.

## GA4 and similar product analytics

- Use sessions and users for on-site behavior, not as substitutes for search clicks or ad-platform clicks.
- Verify property timezone, channel grouping, attribution model, consent coverage, internal-traffic filters, and reporting identity.
- Check for event-definition or consent changes before attributing a conversion-rate movement to user behavior.
- Treat modeled or thresholded data according to the platform's own labeling.

## Google Search Console

- Use clicks and impressions to measure Google Search visibility and demand captured in search results.
- Do not expect clicks to equal analytics sessions; browser behavior, consent, redirects, timezones, and measurement scope differ.
- Interpret average position as an aggregate diagnostic, not a literal rank.
- Inspect query and page concentration before calling site-wide growth.

## Advertising platforms

- Record spend, clicks, attributed conversions, attributed revenue, attribution window, currency, and account timezone together.
- Reconcile attributed conversions with the business system, but do not sum overlapping platform-attributed conversions.
- Prefer contribution margin or verified revenue over platform ROAS when the business question is profitability.

## Commerce, CRM, and billing systems

- Prefer these systems for orders, qualified leads, subscriptions, refunds, and realized revenue.
- Define whether revenue includes tax, shipping, discounts, cancellations, refunds, or recurring renewals.
- Separate order date, payment date, fulfillment date, and refund date when timing changes the conclusion.

## First-party and local event data

- Use internal event counts to validate that important actions occurred even when third-party analytics is blocked or modeled.
- Verify deduplication, bot filtering, event version, and instrumentation coverage.
- Treat server events and browser events as different measurement surfaces unless an explicit identifier supports reconciliation.

## SEO and market-estimation tools

- Label traffic, keyword, and competitor numbers as external estimates or snapshots.
- Use them for direction, visibility, and competitor context rather than direct reconciliation with observed analytics.
- Record the snapshot date and country or index scope.

## Recommended interpretation order

1. Verify business outcomes in the system of record.
2. Explain conversion changes with first-party behavior data.
3. Explain acquisition changes with analytics, search, and advertising sources.
4. Use estimates for context and hypothesis generation.
5. State unresolved discrepancies and define the next check that can resolve them.
