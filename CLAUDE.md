# autopilot-cc

## Versioning Rules (MUST follow after every phase completion)

After every completed phase, bump the version in ALL three files:

- `package.json` ("version" field)
- `VERSION` (single line)
- `CHANGELOG.md` (new section at top)

### Version Scheme: `MAJOR.MINOR.PATCH`

| Event                                | Bump                                              | Example       |
| ------------------------------------ | ------------------------------------------------- | ------------- |
| Integer phase completes (4, 5, 6, 7) | **Minor** — increment middle, reset patch to 0    | 1.1.1 → 1.2.0 |
| Decimal phase completes (3.1, 4.1)   | **Patch** — increment last number                 | 1.1.0 → 1.1.1 |
| ALL roadmap phases complete          | **Major** — bump to next major, reset minor+patch | 1.5.0 → 2.0.0 |

### Current Version Map

Starting from v1.1.0 (phases 1-3 done):

```
Phase 3.1 done → 1.1.1
Phase 4 done   → 1.2.0
Phase 4.1 done → 1.2.1
Phase 5 done   → 1.3.0
Phase 6 done   → 1.4.0
Phase 7 done   → 1.5.0
```

You are not allowed to change the number 2.0.0 until the user gives explicit permissions

### CHANGELOG Format

Each version entry must list the phase name and a 1-line summary per requirement addressed:

```markdown
## X.Y.Z (YYYY-MM-DD)

### Features

- **Phase Name (Phase N):** One-line summary of what was added/changed
```

### When to Bump

The orchestrator (or whoever completes a phase) bumps the version as part of the completion protocol — AFTER all phase commits are done, BEFORE the completion report. The version bump is its own commit with message: `chore: bump to vX.Y.Z after phase N`.
