# Architecture

## Trust boundary

After a finite timed action, the client sends only the operation (`read`,
`write`, or `rename`), the local item ID, and the requested name when relevant.
The server resolves that ID recursively inside the requesting player's
authoritative inventory and validates the item type and owner.

XP amounts, perk lists, recipe lists, journal snapshots, recovery percentages,
and completion results are calculated from persisted character/item state by
the server. A client cannot point an operation at another player's journal or a
journal stored outside its inventory.

## Character baseline

`Events.OnCreatePlayer` initializes exact cumulative XP for each supported
vanilla perk and the set of known recipes in the character's persisted
`modData`, under `AshurSkillRecovery`. The server uses the same stored state
during journal operations and creates a conservative fallback baseline if an
older or incomplete character lacks it.

If the mod is added to an existing character, the state seen on first
initialization becomes the baseline. This refuses to recover older progress
instead of guessing which XP came from character creation.

Missing supported-perk entries introduced by a schema or game update are set to
current XP on first sight, preventing a windfall.

## Journal ownership and snapshot

The first write initializes an owner ID from the MP username or local-player
identity. Successive characters with that same identity can operate every
journal it owns; all other identities are rejected.

The item stores a schema-versioned snapshot:

- a generated journal ID and owner ID;
- a monotonically increasing revision;
- the maximum earned raw XP observed per supported vanilla perk;
- the union of recipes learned after character creation;
- the persisted custom name plus display-only author/update metadata.

Writing is a maximum merge, so a weaker or newer character cannot reduce an
older journal. Item `modData` and item fields are synchronized after server-side
writes and renames. The latter is required by Build 42 for a custom display name
to survive MP synchronization and server restarts.

## Idempotent recovery

Recovery establishes a floor rather than adding a consumable XP balance. The
target includes the recipient's own baseline, so starting bonuses are neither
lost nor copied. A repeated read has a zero deficit and grants nothing.

The verified Build 42.20 global `addXpNoMultiplier(player, perk, amount)` route
is used. It bypasses the literature/book multiplier and the normal XP multiplier
path, preventing recovered XP from being amplified. The mod measures XP before
and after the call and reports only the amount the engine actually accepted.

## Atomicity and networking

The timed action handles presentation and interruption only. Nothing changes on
its update ticks. At completion, the server performs a fresh validation,
calculation, and commit.

The item may otherwise use normal inventory behavior: moving it into a
container, dropping it, and trash deletion require no special ledger cleanup
because all journal state is stored on the item itself. Reading/writing/renaming
requires the item to be in the acting player's recursive inventory.
