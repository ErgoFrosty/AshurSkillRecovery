# Ashur Skill Recovery

Independent earned-progress recovery journal for Project Zomboid Build 42.20.

This repository is the development source. Test builds use the mod ID
`AshurSkillRecoveryDev`; release builds use `AshurSkillRecovery`.

## Core rule

Only progress earned after character creation is recorded. XP granted by the
character's profession and starting traits is captured as an exact baseline and
is never transferred.

For every perk:

```text
earned = max(0, currentXP - sourceBaselineXP)
target = recipientBaselineXP + earned * recoveryPercentage
grant  = max(0, target - recipientCurrentXP)
```

This makes recovery idempotent. Reading the same journal twice in one life
cannot grant the same XP twice, while a later character can reuse the journal
after another death.

## Current development scope

- Build 42.20 only.
- Singleplayer, hosted multiplayer, and dedicated-server code paths.
- Exact earned XP for vanilla and discovered modded perks.
- Optional learned-recipe recovery.
- Optional Fitness and Strength recovery using the same baseline rule.
- Server-side validation and calculation; clients never submit XP values.
- No external ledger files and no runtime dependencies.

Kills and arbitrary third-party `modData` are deliberately excluded from the
first version.

### Recorded skills

The mod does not maintain a fragile hard-coded skill allowlist. It enumerates
every perk registered by the running game whose parent is a real skill category.
This includes:

- Fitness and Strength (passive recovery is enabled by default and can be
  disabled in sandbox settings);
- Sprinting and the other physical/agility skills;
- melee weapon and maintenance skills;
- Aiming and Reloading;
- crafting, farming, and survival skills;
- compatible skills registered by other mods.

Only the exact XP above that character's creation baseline is recorded for all
of these skills.

### Recorded recipes

Recipes known at character creation are the recipe baseline and are excluded.
Any recipe added to the character's known-recipe list later is recorded,
including recipes learned through an item's **Learn/Study** interaction. On
recovery, only recipes the recipient does not already know are learned. Recipe
recovery is enabled by default and can be disabled in sandbox settings.

## Install a local test build

```powershell
./build.ps1 -LocalTest
```

Copy the resulting `dist/AshurSkillRecoveryDev` directory to the Project
Zomboid mods directory. The development ID is different from the eventual
public release, preventing accidental replacement of a stable install.

## Tests

Run the pure Lua recovery-math tests from the repository root:

```text
lua tests/test_math.lua
```

Without a standalone Lua executable, use `python tests/run_lua_tests.py`
(`lupa` is required). This also runs the mocked full journal lifecycle test.

Run the structure and localization checks with Python:

```text
python tests/validate_project.py
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and
[docs/TEST-MATRIX.md](docs/TEST-MATRIX.md) before multiplayer testing.

## License

MIT. This project is an independent implementation and does not include code,
art, translations, or branding from Skill Recovery Journal.
