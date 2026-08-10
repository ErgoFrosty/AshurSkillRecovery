# Ashur Skill Recovery

An owner-bound recovery journal for Project Zomboid Build 42.20. It records
skill XP and recipes learned after character creation and lets another
character belonging to the same player restore that progress.

This repository is the development source. Test builds use the mod ID
`AshurSkillRecoveryDev`; release builds use `AshurSkillRecovery`.

Russian documentation: [README.ru.md](README.ru.md).

## How it works

1. Craft a Recovery Journal from a notebook/diary, glue, and thread, twine,
   fishing line, or dental floss.
2. Carry it in the character's inventory and use the context menu to record
   progress, restore progress, or rename the journal.
3. Store it in containers, move it between characters, or destroy it normally.
   Its content and custom name are persisted with the item across restarts.

The first character to write to a new journal becomes its owner. In multiplayer
the stable account username identifies the owner, so other characters on that
account may use any journal it owns. Other players cannot inspect, write,
restore from, or rename it. The same rule applies to successive local
characters in singleplayer.

Writing is non-destructive: each journal keeps the greatest earned XP ever
written for each skill, the union of learned recipes, and the set of completed
recipe magazines. A later write can add progress but cannot reduce the saved
snapshot. Reading is also non-destructive, so the same journal remains useful
after later deaths.

## XP rule

Only progress earned after character creation is recorded. XP granted by the
source character's profession and starting traits is captured as an exact
baseline and is not transferred.

```text
earned = max(0, currentXP - sourceBaselineXP)
target = recipientBaselineXP + earned * recoveryPercentage
grant  = max(0, target - recipientCurrentXP)
```

This makes recovery idempotent: reading the same journal twice during one life
cannot grant the same XP twice. Partial progress inside a level is preserved;
the calculation uses cumulative raw XP rather than whole levels.

Restoration calls Build 42.20's verified `addXpNoMultiplier` path. Active skill
book/literature multipliers therefore do not multiply restored journal XP. The
success message reports the XP the game actually applied, which is relevant to
engine restrictions on passive skills such as Fitness.

## Skills and recipes

The mod records an explicit allow-list of vanilla Build 42.20 skills. Skills
added by other mods are deliberately ignored so unknown category perks cannot
be mistaken for recoverable player skills.

Every supported vanilla skill, including Fitness and Strength, has independent
**Record** and **Restore** checkboxes. Administrators can therefore disable
either passive skill without affecting the other and can exclude any skill in
either direction. First Aid uses the
actual Build 42 perk ID `Doctor`; Carpentry uses `Woodwork`; Foraging uses
`PlantScavenging`.

Recipes known at character creation form the recipe baseline and are excluded.
Recipes learned later—including through an item's Learn/Study action—are saved
and restored only when the recipient does not already know them. Recipe
magazines completed by the writer are recorded separately and restored as read,
so `MechanicMag1`, which teaches `Basic Mechanics`, appears in the recipient's
literature history.
Skill books, partially read pages, and literature XP multipliers are not copied.

In multiplayer, restored recipes and completed-magazine markers are synchronized
from the authoritative server to the client using the same player-field flags as
the vanilla reading action. One sandbox checkbox disables recording and
restoration of both recipes and recipe-magazine history.

## Sandbox settings

- recovery percentage: `0–100%`;
- record/restore learned recipes and completed recipe magazines;
- separate record and restore switches for every supported vanilla skill,
  including independent Fitness and Strength controls;
- recording and recovery action durations: `10–5000` action units.

All options default to enabled and the recovery percentage defaults to 100%.

## SP and MP behavior

Singleplayer performs the same validation locally. In hosted multiplayer and on
dedicated servers, the server resolves the requested item in the player's
inventory, checks ownership, and calculates the operation from the authoritative
character and item state. Clients do not submit XP amounts or journal content.

If the mod is enabled for an existing character, that character's state when the
mod first initializes becomes the baseline. Earlier progress is intentionally
not guessed or made recoverable.

## Build and tests

Create a development build:

```powershell
./build.ps1
```

Create and install a local test build:

```powershell
./build.ps1 -LocalTest
```

Run the automated checks from the repository root:

```powershell
.venv\Scripts\python.exe tests\run_lua_tests.py
.venv\Scripts\python.exe tests\validate_project.py
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and
[docs/TEST-MATRIX.md](docs/TEST-MATRIX.md) before multiplayer release testing.

## License

MIT. This project is an independent implementation and does not include code,
art, translations, or branding from Skill Recovery Journal.
