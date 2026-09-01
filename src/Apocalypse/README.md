# Apocalypse — Enderal conversion

Enai Siaion's **Apocalypse — Magic of Skyrim** (373 spells, 175 of them tome-taught), converted for
Enderal SE. Pinned to upstream **10.3.0** — a different upstream version moves the records this tree
overrides by ID.

**Status: released, at 1.3.0.** Form version is down to 1.70, the Elder Scrolls proper nouns are
renamed, distribution is rebuilt onto Enderal's own merchants through SureAI's `CustomMerchandise`
hooks, the self-heals pay Arcane Fever, and mana costs are authored against Enderal's own bands
rather than left to the engine's duration-driven formula (`tools/14-magicka-costs.ps1`).
`build/manifest.json` carries the release, so CI builds it on every push and attaches the archive to
the PR.

Per-item test coverage is tracked in
[`arch-docs/Apocalypse/spell-test-matrix.md`](../../arch-docs/Apocalypse/spell-test-matrix.md).
Twelve renamed summons are deliberately held back from shops and loot until each is cast in game —
see the changelog's 1.3.0 entry and `tools/00-cut-summons.ps1`, which is the single definition of
that list.

## Shape

A **replacement plugin**. It ships under the original filename `Apocalypse - Magic of Skyrim.esp`
because the mod's two BSAs are named after the plugin and only load while that name is intact — so
the tree here holds *all ~3,890* of Enai's records, not just our edits. The player installs Enai's
mod for its assets and this release replaces the plugin.

Unlike Triumvirate, the replacement is not optional. **Enderal runs Skyrim SE 1.5.97, and that
engine silently refuses any plugin whose `HEDR` form version is 1.71** — no warning, no log line,
the plugin is simply absent from the game. Apocalypse ships at 1.71, so it never loaded in Enderal
at all. A patch cannot fix that from outside: it has to declare Apocalypse as a master, the engine
has already skipped it, and the patch dereferences null during data load. Do not "simplify" this
back into a patch.

That makes the author's permissions and on-page credit a release requirement, not a nicety.

## What is already known

Read **[`arch-docs/Apocalypse/enderal-gap-audit.md`](../../arch-docs/Apocalypse/enderal-gap-audit.md)**
first — it is the worked example of auditing a ported mod against Enderal's stripped `Skyrim.esm`,
and the reasoning behind steps 10–12 and the loose Papyrus stubs. The headlines:

* **The whole distribution system was inert.** A `StartGameEnabled` quest copies tomes, scrolls and
  staves into **54 vanilla Skyrim vendor and loot leveled lists**, and not one exists in Enderal.
  Neither do the five College-of-Winterhold globals it gates on. It ran, copied nothing into
  nothing, and logged 685 errors on a new game.
* It overrides worldspace **`00003C`**, which is `Tamriel` in Skyrim and **`MQP01Home`** — the
  prologue house — in Enderal. Same defect Triumvirate ships.
* **4,077 missing-reference occurrences** across 617 FormKeys, of which 3,498 were one `NAVI` record
  carrying Bethesda's navigation map. The count is not a severity ranking: *Locate Potion* is broken
  by seven, and two single lines cost an archer summon its bow.
* Its BSA ships the full vanilla `dgintimidate*` scripts over Enderal's deliberate DUMMY stubs,
  switching Skyrim's brawl system back on in a game built without it.
* All 67 staff recipes are built on Dragonborn content (Staff Enchanter, Heart Stones). Dropped,
  and the `Dragonborn.esm` master with them.

## Layout

```
ApocalypseESP/         Spriggit YAML — the source of truth, committed
Scripts/source/*.psc   Papyrus source, committed
Scripts/compiled/*.pex committed via a .gitignore exception — CI cannot compile Papyrus
tools/*.ps1            the numbered generators that rebuild the tree against a new upstream
```

`Scripts/` ships two loose `.pex`: verbatim copies of Enderal's `dgintimidate*` DUMMY stubs that
Apocalypse's BSA would otherwise overwrite with the Brawl Bugs Patch versions. **This mod must sit
after Apocalypse in MO2's file priority** — which it must anyway, to win the `.esp`. See
[`Scripts/README.md`](Scripts/README.md).

**`ApocalypseESP/` is derived, not authored.** Every conversion decision lives in a numbered script
under `tools/`, and a version bump is a re-run rather than a re-investigation — wipe the tree, re-run
the numbered generators in order, then the verifiers. [`tools/README.md`](tools/README.md) is the
step-by-step, the
gotchas, and the four hand edits the 10.3.0 bump silently reverted because they were not scripts.

The release is `Apocalypse - Enderal Patch` in `build/manifest.json` (`"fomod": false` — a plain
archive, since a single `.esp` plus loose scripts has nothing to ask the installer).

## Mana costs (`tools/14-magicka-costs.ps1`)

A `SPELL` only uses its stored `BaseCost` when `ManualCostCalc` is set. Without it the engine
recomputes at runtime as `MGEF.BaseCost * magnitude^1.1 * (duration / 10)^1.1`, summed over the
effects. **Enderal sets the flag on 271 of the 274 spells its own tomes teach**; Apocalypse set it
on **none** of its 175, so every cost was the Creation Kit's arithmetic — and the duration term
dominates, which is why the long summons and buffs were the worst offenders. Conjure Battlemage is
a 50-cost effect with a 180 s duration, so `(180/10)^1.1 = 23.9` and it billed **1201**, against a
mana pool that tops out near 400–500.

Step 14 sets the flag and rescales by a per-tier ratio, so Enai's ordering inside each tier survives
exactly and no magnitude, duration or effect is touched. Resulting medians **40 / 55 / 75 / 110 /
130** against Enderal's 21 / 40 / 55 / 65 / 80, ceiling 1607 → **305**. Conjure Battlemage is 230.
It is idempotent — always recomputed from `reference/mods/Apocalypse/esp/` rather than from our own
output — and `tools/verify-magicka-costs.ps1` re-asserts the flag and the band over the built tree.

A side effect worth knowing: with the flag set, **the Creation Kit can no longer inflate these
costs on save**, which is what previously made the Arcane-Fever'd self-heals dangerous to open in
the CK.

Full mechanism and the measured Enderal bands: CLAUDE.md, "A ported spell's MANA COST is computed by
the engine", and [`arch-docs/enderal/progression-and-classes.md`](../../arch-docs/enderal/progression-and-classes.md#mana-is-small-fixed-and-spell-costs-are-authored-against-it).
