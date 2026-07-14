# Normalized snapshot contract

Use this contract when several sources or metrics need deterministic validation and comparison. Keep raw exports and private account configuration outside the skill repository.

## Top-level object

```json
{
  "generated_at": "2026-01-31T09:00:00+00:00",
  "timezone": "Europe/Berlin",
  "periods": {
    "current": {"start": "2026-01-01", "end": "2026-01-28"},
    "previous": {"start": "2025-12-04", "end": "2025-12-31"}
  },
  "sources": []
}
```

Required fields:

- `generated_at`: ISO 8601 timestamp with timezone.
- `timezone`: IANA timezone used for date boundaries.
- `periods.current` and `periods.previous`: inclusive ISO dates.
- `sources`: non-empty source array.

An optional `year_over_year` period may be present. The validator checks its length against `current` when supplied.

## Source object

```json
{
  "name": "analytics-platform",
  "as_of": "2026-01-30",
  "status": "ok",
  "notes": "Finalized through the stated date.",
  "metrics": []
}
```

- Use a stable, non-secret `name` such as `ga4`, `gsc`, `commerce`, or `first-party`.
- Set `as_of` to the latest date confirmed complete for the extracted data.
- Set `status` to `ok`, `partial`, or `failed`.
- Keep `notes` free of private URLs, IDs, tokens, and personal data.

## Metric object

```json
{
  "name": "organic_sessions",
  "current": 1200,
  "previous": 1000,
  "year_over_year": 900,
  "unit": "count",
  "higher_is_better": true
}
```

- Use numeric values or `null` when unavailable.
- Use `count`, `currency`, `percent`, `ratio`, `seconds`, or another short unit label.
- Set `higher_is_better` only when direction reliably conveys outcome quality. Omit it for contextual metrics such as impressions or channel share.
- Do not mix currencies, attribution windows, filters, or definitions in one metric row.

## Privacy boundary

Reject secret-bearing fields before analysis. Never put keys containing terms such as `token`, `secret`, `password`, `credential`, `api_key`, `client_secret`, `private_key`, or `access_token` into a snapshot.
