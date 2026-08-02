# Architecture

## Trust boundary

The client sends only an operation kind (`read` or `write`) and the local item
ID after a finite timed action. The server resolves that ID inside the requesting
player's authoritative inventory and recalculates all XP and recipe changes.

The server never accepts an XP amount, perk list, baseline, recipe list, journal
payload, percentage, or completion result supplied by the client.

## Character baseline

`Events.OnCreatePlayer` captures exact total XP for every available perk and the
set of already known recipes. The data lives in the character's persisted
`modData` under `AshurSkillRecovery`.

If the mod is added to an existing character, their current state becomes the
baseline. This intentionally refuses to recover progress earned before the mod
was installed rather than guessing which XP came from character creation.

If another mod adds a perk later, its current XP becomes the baseline when it is
first discovered. This is also a conservative anti-windfall rule.

## Journal snapshot

The item stores a schema-versioned snapshot:

- server-generated journal ID;
- monotonically increasing revision;
- maximum earned raw XP observed per perk;
- union of recipes learned after character creation;
- display-only author and update timestamp.

Writing is a maximum merge. A weaker or newer character cannot reduce an older
journal.

## Idempotent recovery

Recovery establishes a floor rather than adding a consumable XP balance. The
target includes the recipient's own starting baseline, so starting bonuses are
neither lost nor copied. A repeated read has a zero deficit and therefore grants
nothing.

No per-account, per-life, or per-journal redemption ledger is required. The
journal remains reusable by later lives.

Raw XP is restored through the game's `XP:AddXPNoMultiplier` API. Trait, profession,
book, nutrition, and sandbox multipliers are not reverse-engineered and cannot
amplify restoration.

## Atomicity and networking

The timed action is presentation and interruption handling only. Nothing is
mutated on its update ticks. At completion the server performs one fresh
calculation and one commit.

Writing produces one item `modData` synchronization. Reading produces only the
required perk and recipe changes; there are no external JSON/TXT writes.
