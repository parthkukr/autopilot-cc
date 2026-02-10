# Changelog

## 1.0.0 (2026-02-09)

### Initial Release

- 3-tier autonomous phase execution (orchestrator -> phase-runner -> step agents)
- Adversarial verification pipeline (verifier + judge)
- Circuit breaker system with 10 tunable thresholds
- Crash recovery via idempotent state file
- Inlined autopilot_mode context in spawn prompts (no modified GSD agents needed)
- SessionStart hook for background update checks
- Global and local install support
- `/autopilot update` command for in-place updates
