# Private configuration boundary

Keep site-specific profiles and credentials outside this public skill repository. Prefer a user-owned configuration directory such as `~/.config/marketing-performance/` or an existing private project configuration.

## Sanitized profile shape

Use environment-variable names or local secret-store references instead of literal values:

```yaml
profile: example-site
timezone: Europe/Berlin
currency: EUR
sources:
  ga4:
    property_id_env: MARKETING_GA4_PROPERTY_ID
    authentication: application-default-credentials
  gsc:
    property_url_env: MARKETING_GSC_PROPERTY_URL
    authentication: application-default-credentials
  commerce:
    endpoint_env: MARKETING_COMMERCE_ENDPOINT
    token_env: MARKETING_COMMERCE_TOKEN
  local_warehouse:
    path_env: MARKETING_WAREHOUSE_PATH
```

## Rules

- Resolve profile paths through an explicit command argument or environment variable.
- Read credentials from the operating-system keychain, application-default credentials, or environment variables injected at runtime.
- Never echo resolved secret values in commands, logs, reports, exceptions, or debug output.
- Commit only synthetic examples with placeholder names.
- Keep property IDs, account mappings, private paths, internal endpoints, and customer data private even when they are not authentication secrets.
- Stop with a concise missing-configuration message when required private configuration is unavailable.
- Rotate any credential immediately if it ever enters Git history; adding it to `.gitignore` afterward is insufficient.
