# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

**Layout: multi-context.** A `GLOSSARY-MAP.md` at the repo root points at one `GLOSSARY.md` per context. This repo is a multi-profile OpenWrt build tree: each build profile directory (`n1/`, `rockchip/`, `x86-64/`, `sunxi-cortexa53/`, `mediatek-filogic/`, `glinet/`, `raspberrypi/`, `armsr-armv8/`, `arch/`) plus the shared script and packaging directories (`shell/`, `files/`, `model/`) is its own context.

## Before exploring, read these

- **`GLOSSARY-MAP.md`** at the repo root: it points at one `GLOSSARY.md` per context. Read each one relevant to the topic.
- **`docs/adr/`**: read ADRs that touch the area you're about to work in. In multi-context repos, also check `<context>/docs/adr/` (e.g. `n1/docs/adr/`) for context-scoped decisions.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## File structure

Multi-context repo (presence of `GLOSSARY-MAP.md` at the root):

```
/
├── GLOSSARY-MAP.md
├── docs/adr/                          ← system-wide decisions
├── n1/
│   ├── GLOSSARY.md
│   └── docs/adr/                      ← context-specific decisions
├── rockchip/
│   ├── GLOSSARY.md
│   └── docs/adr/
├── x86-64/
│   ├── GLOSSARY.md
│   └── docs/adr/
└── shell/
    ├── GLOSSARY.md
    └── docs/adr/
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in the relevant `GLOSSARY.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders), but worth reopening because…_
