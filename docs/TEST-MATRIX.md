# Build 42.20 test matrix

Every row must pass in singleplayer, hosted multiplayer, and dedicated server
unless marked otherwise.

## Baseline and XP

- New character with no starting perk levels: earn XP, write, die, read.
- Source starts with +1, +2, or +3 perk levels: verify those levels are excluded.
- Recipient has a different starting bonus: verify its own baseline is preserved.
- Fitness and Strength enabled and disabled.
- Recovery percentage 0, 1, 50, 99, and 100.
- Read twice in the same life: second read grants zero.
- Read, die without writing, then read with a third character: recovery works.
- Read, earn more XP, update journal, die, then restore the larger maximum.
- Character already exceeds the journal in one or all perks: no XP is removed.
- Perk reaches level 10: target is capped and the action terminates.

## Persistence and interruption

- Restart the game/server before and after writing.
- Disconnect during the timed action: no partial mutation.
- Disconnect immediately after completion: committed state persists.
- Move or drop the journal during the action: server rejects the commit.
- Two players attempt to update the same journal sequentially.
- Duplicate an item in debug mode: repeated reading remains idempotent.

## Recipes and compatibility

- Profession/trait recipes present at creation are not recorded.
- Recipe learned later is recorded and restored.
- Recipe learned through an item's Learn/Study interaction is recorded and restored.
- Recipes disabled in sandbox settings.
- Mod added to an existing character: existing XP/recipes become baseline.
- Add a modded perk after character creation: existing XP becomes its baseline.
- Remove a mod that supplied a recorded perk or recipe: journal remains usable.
- Verify the static crafting recipe in a fresh 42.20 world and dedicated server.

## Security and diagnostics

- Client submits an unknown item ID, another item type, invalid mode, or journal
  outside their inventory: server rejects it.
- Tampered negative, NaN, infinite, and excessive stored XP cannot reduce or
  over-cap a skill.
- Exact XP is applied through the verified Build 42.20 `AddXPNoMultiplier` API.
