---
name: autopilot:update
description: Check for and install autopilot-cc updates from npm
allowed-tools:
  - Read
  - Bash
---

<update_check>
**Before any output**, check for updates using `__INSTALL_BASE__/cache/autopilot-update-check.json`.
Full instructions: read `__INSTALL_BASE__/autopilot/protocols/update-check-banner.md`.
If neither file is readable, skip silently. Banner format: `Update available: v{installed} -> v{latest} -- run /autopilot:update`
</update_check>

<objective>
Check for autopilot-cc updates and install them if available. Fully native to autopilot-cc -- no external dependencies.

**What it does:**
1. Reads the currently installed version
2. Checks npm for the latest published version
3. If already up to date, reports and stops
4. If an update is available, installs it and reports
</objective>

<execution>

## On Invocation

1. **Read installed version:**

   ```
   Read __INSTALL_BASE__/autopilot/VERSION
   ```

   Extract the version string (e.g., `1.8.0`). If the file is missing, fall back to `unknown`.

2. **Check npm for latest version:**

   ```bash
   npm view autopilot-cc version
   ```

   If the command fails (network error, npm not available), report: "Could not check for updates. Verify network connectivity and try again." and stop.

3. **Compare versions:**

   - If the installed version matches the latest: display `Already up to date (v{version})` and stop.
   - If an update is available: continue to step 4.

4. **Show update notification:**

   ```
   Update available: v{installed} -> v{latest}. Installing...
   ```

5. **Determine install mode:**

   Check whether the current install is global or local:
   - If `__INSTALL_BASE__` resolves to a path under the user's home directory (`~/.claude/`), it's a global install
   - If it resolves to a project-local `.claude/` directory, it's a local install with `--local` flag

6. **Run the update:**

   For global install:
   ```bash
   npx autopilot-cc@latest
   ```

   For local install:
   ```bash
   npx autopilot-cc@latest --local
   ```

7. **Report completion:**

   ```
   Updated autopilot-cc to v{latest}.
   Restart Claude Code to activate the update.
   ```

## Error Handling

- If npm is not available: "npm is required for updates. Install Node.js and npm first."
- If network is unavailable: "Could not reach npm registry. Check your internet connection."
- If install fails: Show the error output from npx and suggest running the install command manually.

</execution>

<success_criteria>
- [ ] Reads installed version from VERSION file
- [ ] Checks npm registry for latest version
- [ ] Correctly detects when already up to date
- [ ] Installs update when available
- [ ] Preserves global/local install mode
- [ ] Reports restart requirement after update
</success_criteria>
