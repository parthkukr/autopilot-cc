# autopilot-cc

## Versioning Rules (MUST follow after every phase completion)

After every completed phase, bump the version in ALL three files:
- `package.json` ("version" field)
- `VERSION` (single line)
- `CHANGELOG.md` (new section at top)

### Version Scheme: `MAJOR.MINOR.PATCH`

- **Minor bump** (increment middle, reset patch to 0): An integer phase completes (e.g., Phase 4, Phase 5). These are the main roadmap phases — each one is a meaningful capability addition.
- **Patch bump** (increment last number): A decimal/inserted phase completes (e.g., Phase 3.1, Phase 4.1). These are smaller insertions between main phases.
- **Major bump to 2.0.0**: NEVER do this automatically. Only bump major when the user explicitly approves it. Even if every phase in the roadmap is done, stay on 1.x — the user needs to usertest before releasing 2.0.

Read `package.json` for the current version, then apply the logic above based on which phase just completed.

### CHANGELOG Format

Each version entry must list the phase name and a 1-line summary per requirement addressed:

```markdown
## X.Y.Z (YYYY-MM-DD)

### Features

- **Phase Name (Phase N):** One-line summary of what was added/changed
```

### When to Bump

The orchestrator (or whoever completes a phase) bumps the version as part of the completion protocol — AFTER all phase commits are done, BEFORE the completion report. The version bump is its own commit with message: `chore: bump to vX.Y.Z after phase N`.
