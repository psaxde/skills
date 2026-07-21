# Holdout Design Examples

## EX-H01: Long compound headline

- Label: negative
- Kind: edge-case
- Origin: synthetic
- Source: renderer regression fixture
- Status: resolved
- Expected behavior: fit above the template minimum or require shorter visible copy; never clip silently.
- Observed behavior: passed post-change replay; the full headline fit at or above the editorial minimum without clipping.
- Skill delta: fitted headline helper with template minimums.
- Anonymization: synthetic content only.

### Content

An editorial pin with a multi-line headline near the maximum useful visible length.

## EX-H02: Busy full-bleed photo

- Label: negative
- Kind: edge-case
- Origin: mixed
- Source: anonymized source-image review pattern
- Status: holdout
- Expected behavior: choose `editorial` instead of forcing `bold_photo` when no safe overlay area exists.
- Observed behavior: pending future source-specific review.
- Skill delta: explicit template suitability and fallback rule.
- Anonymization: source identity removed.

### Content

A tightly framed source photo whose subject occupies both the headline and CTA overlay zones.

## EX-H03: Unverified stat

- Label: negative
- Kind: edge-case
- Origin: synthetic
- Source: copy-integrity regression scenario
- Status: holdout
- Expected behavior: do not invent a time, yield, or other stat; select `editorial` or use another verified fact.
- Observed behavior: pending future source-specific review.
- Skill delta: source-verification rule for `recipe_card` stats.
- Anonymization: synthetic content only.

### Content

A source page with descriptive content but no visible compact fact suitable for a stat card.
