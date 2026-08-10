# Build 42.20 test matrix

Every row must pass in singleplayer, hosted multiplayer, and dedicated server
unless marked otherwise.

## Baseline and XP

- New character with no starting perk levels: earn XP, write, die, read.
- Source starts with +1, +2, or +3 perk levels: verify those exact starting XP
  values are excluded.
- Record and restore partial progress inside a level.
- Recipient has a different starting bonus: verify its own baseline is kept.
- Independently enable and disable Record/Restore for Fitness and Strength.
- Recovery percentage 0, 1, 50, 99, and 100.
- Read twice in the same life: the second read grants zero.
- Read, die without writing, then read with a third character: recovery works.
- Read, earn more XP, update journal, die, then restore the larger maximum.
- Character already exceeds the journal in one or all perks: no XP is removed.
- Perk reaches level 10: target is capped and the action terminates.
- Activate every available skill-book multiplier before reading: restored XP is
  not multiplied.

## Ownership, persistence, and interruption

- A second character on the same SP save/account can use the owner's journal.
- A second MP character with the same username can use the owner's journal.
- Another MP username cannot inspect, write, read, or rename the journal.
- Rename to Latin, Cyrillic, and mixed text; verify 64 characters succeeds and
  65 fails.
- Restart the game/server after renaming: the custom name remains unchanged.
- Put the journal into nested containers, drop it, pick it up, and delete it via
  trash; no separate state remains.
- Disconnect during the timed action: no partial mutation.
- Disconnect immediately after completion: committed state persists.
- Move or drop the journal during the action: the server rejects the commit.
- Two characters belonging to the owner update the same journal sequentially.
- Duplicate an item in debug mode: repeated reading remains idempotent.

## Recipes, settings, and compatibility

- Profession/trait recipes present at creation are not recorded.
- Recipe learned later is recorded and restored.
- Recipe learned through an item's Learn/Study interaction is recorded and
  restored.
- Disable recipe recovery: neither writing nor reading transfers recipes.
- Disable Record for each vanilla skill: new XP for that skill is not written.
- Disable Restore for each vanilla skill: saved XP for that skill is not added.
- Verify First Aid (`Doctor`), Carpentry (`Woodwork`), and Foraging
  (`PlantScavenging`) switches affect their actual Build 42 perks.
- Set action time below the old 300-unit floor (for example 10): the configured
  duration is honored.
- Mod added to an existing character: existing XP/recipes become baseline.
- A recorded vanilla perk or recipe unavailable after a game/mod change is
  ignored and the journal remains usable.
- Verify the crafting recipe and custom 32×32 transparent icon in a fresh world
  and dedicated server.

## Security and diagnostics

- Client submits an unknown item ID, another item type, invalid mode, or a
  journal outside its inventory: the server rejects it.
- Tampered negative, NaN, infinite, and excessive stored XP cannot reduce or
  over-cap a skill.
- Exact XP is applied through the verified Build 42.20
  `addXpNoMultiplier(player, perk, amount)` API.
