# AGENTS.md

## Agent skills

### Issue tracker

Issues and specs live as GitHub issues in `LarryMKott/AutoBuildImmortalWrt`, driven with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage roles, each label string equal to its role name (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

multi-context: a root `GLOSSARY-MAP.md` points at one `GLOSSARY.md` per build-profile context, with `docs/adr/` for system-wide and `<context>/docs/adr/` for context-scoped decisions. See `docs/agents/domain.md`.
