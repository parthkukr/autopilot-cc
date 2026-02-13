# Update Check Banner

**Purpose:** Display a passive update notification before command output. Called by all `/autopilot:*` commands.

## Instructions

1. Read the file at `__INSTALL_BASE__/cache/autopilot-update-check.json` -- if missing or unreadable, skip silently (no error, no output)
2. Parse JSON. Check the `expires` field (ISO-8601 datetime string). If the current date/time is PAST the `expires` value, the cache is stale -- skip silently. If there is no `expires` field, fall back to checking `checked` (Unix epoch seconds) -- if more than 86400 seconds old, skip silently.
3. If `update_available` is `true` and the cache is fresh (not stale per step 2), display this single line BEFORE all other output:
   ```
   Update available: v{installed} -> v{latest} -- run /autopilot:update
   ```
   where `{installed}` and `{latest}` are the corresponding fields from the JSON.
4. If the file is missing, malformed, stale, or `update_available` is `false`, display nothing -- proceed silently.

**This check must never block or delay command execution.**

## Cache File Schema

```json
{
  "update_available": true,
  "installed": "1.8.0",
  "latest": "1.9.0",
  "checked": 1739450000,
  "expires": "2025-02-14T12:00:00Z"
}
```

- `update_available` (boolean): Whether a newer version exists on npm
- `installed` (string): Currently installed version
- `latest` (string): Latest version on npm
- `checked` (integer): Unix epoch seconds when the check ran
- `expires` (string): ISO-8601 datetime after which this cache entry is stale (24h after `checked`)
