# Regenerating the Apocalypse conversion

`src/Apocalypse/ApocalypseESP/` is Enai Siaion's plugin with our changes applied. It is **committed
in full** so CI can build it, but it is *derived* — these scripts are how it was produced, and how it
gets reproduced against a new Apocalypse version.

They are also the reason a version bump is a re-run rather than a re-investigation. Every one asserts
what it changed and throws on zero matches, per CLAUDE.md guardrail 11.

## Why this is a replacement plugin and not a patch

**Enderal SE runs Skyrim SE 1.5.97, and that engine silently refuses any plugin whose `HEDR` form
version is 1.71** — no warning, no log line, the plugin is simply absent from the game. Apocalypse
ships at 1.71, so it never loaded in Enderal at all. A patch plugin cannot fix that from outside,
because it has to declare Apocalypse as a master and the engine has already skipped it — which
produces a null-pointer CTD during data load. The plugin itself must be rebuilt at **1.70**.

That single fact drives the whole architecture. Do not "simplify" this back into a patch.

## Pinned to Apocalypse 10.3.0

`reference/mods/Apocalypse/esp/` must be **Enai's** plugin, serialized — not a previous release of
ours. Check `RecordData.yaml`'s `Author:` before running anything: `Enai Siaion` is upstream,
`Enai Siaion / Whisperdealer` is one of our own builds that got re-ingested, and running the
pipeline against that would layer our edits on top of themselves.

## Regenerating against a new upstream version

**Wipe `src/Apocalypse/ApocalypseESP/` first, then run 01 → 14 in order.** Step 5 merges Enai's
records in under an "our edit wins" rule, so anything already in the tree survives untouched — which
means a regeneration *over the top* of the existing tree does almost nothing.

That wipe is also why every conversion decision has to live in a script. The 10.3.0 bump found four
that did not, all of them silently reverted by the regeneration:

| Reverted | Now |
|---|---|
| the `Enderal - Forgotten Stories.esm` master, hand-added to the header | emitted by step 5, and step 5b **asserts** every master the records reference is declared |
| three `Dragonborn.esm` references, hand-deleted | step **5b** deletes the list entry containing any DLC FormKey |
| `WB_IllusionNightmare_MPS_Seidsigil`'s NodeIndex, hand-set to 746 | step **5c**, which re-proves the collision and that 746 is still free |
| ~32 Elder Scrolls nouns in groups step 1 never scanned | step 1 scans **every** group and carries the missing renames |

The first of those is not a degradation but a hard build failure — Spriggit cannot map an FS FormKey
without the master — so a regeneration fails loudly. The other three build clean and ship wrong.

## Order

Run against a fresh `reference/mods/Apocalypse/esp/` produced by `/spriggit-decompile-reference`.
Several stages also read the base trees — `reference/base/Skyrim`, `EnderalFS`, `Update` and
`Dragonborn-stub`. All of `reference/` is gitignored, so on a fresh clone these scripts fail with
"cannot find path …\reference\…" until you regenerate it; that is the expected first error, not a
broken script. Each derives the repo root from its own location, so run them from anywhere.

| # | Script | Does |
|---|---|---|
| 1 | `01-gen-renames.ps1` | Elder Scrolls proper nouns → Enderal equivalents, across every user-visible string in **every** record group, plus the five dead load-screen NIFs. Throws if any rename matches nothing |
| 2 | `02-gen-distribution.ps1` | Builds the six tome/scroll sublists and injects them into Enderal's nine vendor/loot lists |
| 3 | `03-forward-leveled-lists.ps1` | Rebuilds those nine host lists from the **winning** record — Forgotten Stories overrides eight of them, and building from base Enderal silently reverts FS's edits |
| 4 | `04-forward-worldspace.ps1` | Replaces Apocalypse's `Tamriel` override of `00003C` with Enderal's `MQP01Home`, **keeping Apocalypse's three persistent refs** — a quest and a faction still point at them |
| 5 | `05-merge-tree.ps1` | Merges Enai's tree with our edits, drops the 67 staff recipes, re-homes our six new records into Apocalypse's own FormID space, writes the header at form version 1.7 |
| 5b | `05b-strip-dlc-refs.ps1` | Deletes every list entry holding a `Dawnguard/HearthFires/Dragonborn` FormKey — we drop those masters, so Spriggit cannot map the FormKey and the build fails outright. Then asserts every master the tree references is one the header declares |
| 5c | `05c-fix-addonnode-index.ps1` | Moves `WB_IllusionNightmare_MPS_Seidsigil` from AddonNode index 110 (Enderal's `_00E_MPSWildWaveFlames`) to 746, re-proving both the collision and that 746 is free |
| 6 | `06-weight-distribution.ps1` | Duplicates each injected **loot** entry until those lists are ~11–19% Apocalypse. One entry per host list gives 160 tomes the same odds as a single Enderal book — see below. Idempotent; run after 05 |
| 7 | `07-place-vendor-tomes.ps1` | Writes all 160 tomes **directly** to six named merchants, tiered by the gold in their chest — into SureAI's own `<Merchant>_CustomMerchandise` hooks, so **no container record of any master is overridden**. This is what actually makes the spells obtainable; the vendor leveled lists no longer carry them. Migrates away any leftover chest override. Idempotent — always rebuilds from the Forgotten Stories record |
| 8 | `08-reprice.ps1` | Rescales all 175 tome and 144 scroll gold values onto Enderal's economy. Apocalypse prices on vanilla Skyrim's ladder, which Enderal does not use. Idempotent — always recomputes from Enai's untouched tree |
| 9 | `09-arcane-fever-heals.ps1` | Appends Enderal's Arcane Fever effect to the 19 player self-heals (14 spells, 5 scrolls). Every Enderal healing spell pays Fever; Apocalypse's paid nothing. Idempotent — strips its own block and re-appends |
| 10 | `10-strip-vanilla-navi.ps1` | Cuts Bethesda's navigation map out of the `NAVI` record the CK regenerated, keeping only Apocalypse's own three entries. **3,498 of the plugin's 4,077 missing references were in this one record** |
| 11 | `11-neutralise-populate-lists.ps1` | Empties the **twelve** FormLists behind Apocalypse's runtime list-population, so its loops iterate zero times. Its script `AddForm`s into 83 vanilla leveled lists Enderal does not have — 685 errors on a new game, verified. Clearing `StartGameEnabled` alone does **not** stop it, and the MCM "Repopulate" button is a second entry point with its own six lists |
| 12 | `12-strip-scroll-menudisplay.ps1` | Removes the dangling `MenuDisplayObject` from all 144 scrolls. Enderal's own 34 scrolls carry none |
| 14 | `14-magicka-costs.ps1` | Sets `ManualCostCalc` on the 182 player-castable spells and rescales their mana costs onto Enderal's bands. Without the flag the engine derives the cost from effect duration at runtime, which is why a 180 s summon billed 1201. Idempotent — always recomputes from Enai's untouched tree |
| 15 | `15-summon-ammo.ps1` | Repoints the two archer summons' quivers from vanilla Daedric arrows (`0139C0`, and the `037C14` list of the same) onto Enderal's `_30E_AeternaArrow` `13E219`. Neither vanilla FormID exists here, so Herne and the Dremora Assassin spawned holding a bow with nothing to fire. Idempotent |
| 16 | `16-craftlord-outfit.ps1` | Repoints `WB_ConjureCraftlord_Outfit`'s body, hands and feet from vanilla Dwarven armour (`01394D`/`01394C`/`01394E`) onto Enderal's `_04E_30_EndreleanPlate*` set. The race's Skin is `SkinNaked`, so the summon arrived hooded, cloaked and otherwise naked. Asserts each replacement fills the same slot **and** that its armature covers the wearer's `ArmorRace` — a swap that resolves but does not render is silent. Idempotent |
| 13 | `13-gen-test-matrix.ps1` | Generates [`arch-docs/Apocalypse/spell-test-matrix.md`](../../../arch-docs/Apocalypse/spell-test-matrix.md) and, with `-ModIndex`, the console batch files. Not part of the conversion — run it after any change that adds, reprices or re-homes an item |

The AddonNode re-index (`WB_IllusionNightmare_MPS_Seidsigil` 110 → 746) **used to be** a single
committed record rather than a script, and the 10.3.0 regeneration duly reverted it to 110 —
`verify-addonnode-indices.ps1` caught it, which is the only reason it did not ship. It is step 5c now.

The release also ships two loose Papyrus stubs, which are committed files rather than a generator
step; see [`../Scripts/README.md`](../Scripts/README.md). The reasoning behind steps 10–12 and the
stubs is in
[`arch-docs/Apocalypse/enderal-gap-audit.md`](../../../arch-docs/Apocalypse/enderal-gap-audit.md).

## Verify

| Script | Checks |
|---|---|
| `verify-plugin-census.ps1 <orig.esp> <built.esp>` | record counts by signature, FormID set, masters, `HEDR`. Against 10.3.0 expect `COBJ 0` (all 67 dropped), `LVLI 29`, `CONT 9` (all Apocalypse's own), `WRLD 1`, `HEDR 1.7`, masters Skyrim/Update/FS |
| `verify-vendor-reachability.ps1` | that the tomes can actually be **bought**: each hook is `UseAll` with no `ChanceNone` and no `Global`, is still carried by its merchant's chest in base Enderal **and in every `reference/mods/` override of that chest**, and covers all 160 tomes exactly once, all priced. Also asserts 0 container overrides |
| `verify-missing-refs.ps1 [-Baseline N]` | **absolute** audit: everything the tree points at that Enderal does not have, with each surviving reference resolved to its Enderal group and EditorID. Currently **264**. `-Baseline` fails when the count rises |
| `verify-dangling-diff.ps1` | unresolved references **relative to Enai's original** — a different question. Expect **0 new** |
| `verify-addonnode-indices.ps1 [-Upstream]` | no `ADDN` index shared with Enderal. Defaults to our tree; `-Upstream` checks Enai's |
| `verify-magicka-costs.ps1` | that all 175 tome-taught spells carry `ManualCostCalc` and sit inside Enderal's authored cost band for their tier. Fails the build rather than shipping a spell nobody can cast |
| `verify-summon-ammo.ps1` | that every NPC holding a bow also holds ammunition that resolves — in our tree or in Enderal's masters. Expect **3** archers, all OK. This is the invariant, not the reference: a dead quiver is one line of ~267 in the missing-refs audit and nothing there says it costs a spell its whole function |
| `verify-summon-outfits.ps1` | that every entry of every outfit worn by a `Summonable` NPC resolves, and that any `Armor` among them has an armature covering the wearer's `ArmorRace`. Expect **34** summons, **104** entries. Deliberately does *not* assert slot coverage: bare hands and feet are design throughout Apocalypse, and the Deadeye Captain has no body armour because his race skin is the body |
| `verify-plugin-structure.ps1 <esp>` | header, masters, group/record framing |
| `debug-make-masters.ps1` | builds a hand-written plugin with a chosen master list and no records — the control that isolates a load crash to the header rather than the records |

> **Use both reference checks, not one.** `verify-dangling-diff.ps1` has read **0 new** since the
> first build and was right to; it only ever asked "did *we* break something". It cannot see the
> ~4,000 references Apocalypse inherited, and that is where the real defects were.

## FormID allocation

Our six new records live in **Apocalypse's own space at `1C1E71`–`1C1E76`** (its highest own FormID
is `1C1E70`). This is not an ESL block — the merged plugin has ~3,890 records and is a full ESP.

## Gotchas

- The plugin **must** declare `Enderal - Forgotten Stories.esm` as a master. The forwarded leveled
  lists contain 63 FS FormKeys; without it Spriggit fails with "Could not map FormKey to a master
  index".
- Set `ModHeader.Stats.Version: 1.7` explicitly. Mutagen defaults to **1.71**, which is exactly the
  value that makes the plugin invisible to Enderal.
- Never re-add a `Dragonborn.esm` master. After step 5 the tree should contain zero matches for it.
- **A leveled list picks one entry per draw, so one injected entry ≠ one item's worth of odds — it is
  one *slot's* worth, shared by everything behind it.** Shipped that way first and merchants looked
  empty: 160 tomes behind a single slot in a 15-entry list meant ~1 Apocalypse book at the game's
  richest spell vendor and usually none at the smaller ones. Step 6 fixes it. Re-do the arithmetic
  (`draws x your-entries / entries-at-or-below-player-level`) if the host lists change.
- **`ChanceNone` is not dilution.** It decides whether the list yields anything at all, not what
  share of the yield is ours — so the loot lists need the same weight as the vendor lists did, not
  less. Weighting loot lower on that reasoning was the first pass's mistake.
- **Weight per host list, not per injection.** `_00E_SpellBooksLootB`'s band admits only one
  Apocalypse rank (R025) where A/C/D admit two, so an equal per-injection multiplier leaves it on
  half the share of its neighbours. It carries 8x to land in the same band as everything else.
- **Weighting a leveled list has a ceiling, and the vendor lists hit it.** A list is rolled per draw,
  so which tomes a shop has stays random however heavy the entry is — most of the 160 were
  purchasable nowhere even at a 38% share. Step 7 replaced that with direct placement (into the
  merchant hooks) and the four
  `_00ETraderSpellBooksLevel*` overrides were deleted outright, handing those lists back to Forgotten
  Stories. Do not reintroduce them: the tomes would then be sold twice over.
- **Gold values are Skyrim's, not Enderal's, and nothing warns you.** Apocalypse prices tomes on
  vanilla Skyrim's ladder (~50/175/330/700/1300 novice→master). **Enderal's entire spell-tome range
  is 20–350**, with two outliers above it (Paralyze Rank II 400, the unique Death Storm 600); its
  scrolls run 10–100 with two at 500. Enai's masters at a 1407 median were 5.6x Enderal's top tome
  and its X-school scrolls at 2500 were 5x Enderal's dearest scroll. Step 8 rescales by a per-tier
  ratio so his internal ordering survives. Re-derive the ratios if a new Apocalypse version reprices.
- **The chest overrides are gone — stock goes into `<Merchant>_CustomMerchandise` instead.**
  Enderal ships 67 of those, one per merchant, every one an **empty `UseAll` LeveledItem already
  sitting in that merchant's chest**. Writing there stocks the shop just as deterministically
  while overriding **no container of any master**. That dissolved a real conflict, not a
  hypothetical one: `EGO SE - Leveling Redone.esp` overrides **all six** of the chests this step
  used to claim, and `KataPUMBSpellPack.esp`, `KataEmberlord` and `xxOpenSpells` override some of
  them too — whichever loaded last simply erased the other's additions. **All five of those mods
  keep the hook in the chests they rewrite**, so our stock now survives every one of them, and
  KataPUMB's 15 staves survive us. That is also why **the Apprentice tier moved back to Tarhutie**
  (630 gold) from Maxus Tabbakus, who was only ever the stand-in and has no hook at all.
  `verify-vendor-reachability.ps1` re-proves the whole chain rather than trusting this note.
- **Do not add `(Rank N)` to the tome names.** In Enderal that suffix means the same spell exists at
  another strength, gated on player level (`_01E_`/`_10E_`/`_18E_`/`_28E_`/`_38E_`/`_48E_` = levels
  1/10/18/28/38/48). Apocalypse spells have one version each, and Enderal leaves its own 13
  single-strength tomes unsuffixed for exactly that reason. `Spell Tome: <name>` is correct.
- **10.3.0 moved Enai's injected keywords.** The five `MAG_*` keywords at `A00105`/`A00106`/`A00108`/
  `A00170`/`A00666` in `Update.esm`'s space are gone, replaced by seven `Futhark_InjectedKeyword_*`
  at `DEAD03`–`DEAD11`, and ~15 magic effects and one perk repoint to them. Nothing in Enderal or in
  any mod under `reference/mods/` defines a record at those IDs, so the injection is safe — but it is
  worth re-checking on the next bump, because an injected FormID colliding with a real record is the
  one way this pattern bites.
- **10.3.0 added one dead-ish reference.** `WB_Des_Spectral3_Effect_Multivortex` gained a
  `GetInFaction 084D1B:Skyrim.esm` condition. That FormID *survives* in Enderal, but as a placed
  reference inside `CapitalCityDalGeyssHouse`, not a faction — so the check can never be true. It is
  one of several `OR`-flagged terms, so the effect still works; left alone deliberately.
- **Enai's own FormIDs now reach `1C4D39`.** Our six records sit at `1C1E71`–`1C1E76`, in a gap he has
  skipped past (his `nextObjectID` is `1C7C02`). Re-run the collision check on every bump anyway —
  `05-merge-tree.ps1` re-homes them and would happily write over an upstream record.
- Vendor inventories are cached in the save (`iDaysToRespawnVendor: 2`). To test distribution without
  waiting, `player.additem <LVLI FormID> 1` resolves the leveled list directly.
- **Enderal taxes healing MAGIC, and Apocalypse's heals paid nothing.** Every one of Enderal's own
  healing spells raises Arcane Fever; only 11 of its 837 spells raise it at all and every one is a
  self-heal. Note Enderal **does** have healing potions — five `_NNE_Genesungstrank` tiers (36–160 HP,
  25–190 gold) plus `_00E_Medicine` — and none of them costs Fever, so the design is a trade: potions
  are the finite gold-priced heal, magic is the renewable one that costs Fever. An untaxed Apocalypse
  heal beat both. (This README previously claimed Enderal had no healing potions; that was wrong, from
  an English-only name search — the EditorIDs are German.) Step 9 appends `11A4B6:Skyrim.esm`
  (`_00E_IncreaseArcaneFeverFFSelf`) to the 19 player self-heals. Rates are Enderal's own ceilings, never beaten: **26 HP per fever point** for burst
  (`_55E_SpellFlashHeal 12E168`, 130 HP / 5) and **78** for over-time (`_40E_SpellBoon 12E165`,
  39 HP/s ÷ 0.5). Floors are 5 for spells and 2.5 for scrolls, both Enderal's own. The script asserts
  each record's heal magnitude still matches what the rate was derived from, so an upstream rebalance
  is a script failure rather than a silently stale tax.
- **The leech/absorb spells are `TargetType: Aimed` and `11A4B6` is Self — do not add them.**
  Decompose, Leech Seed, Lamb of Irlanda, Poisoned Chalice and Nature's Balance all heal by draining
  a target. A Self-delivery MGEF on an Aimed spell has **zero precedent across 370 non-Self spells**
  in base Enderal, Forgotten Stories and Apocalypse combined: it would build clean, pass xEdit, and
  do nothing in-game. Step 9 throws on any record carrying a top-level `TargetType`, specifically to
  stop that. Two of them also heal an unbounded variable amount, so there is no number to price.
  If they must be taxed one day, the only shape with precedent is a **new Aimed MGEF** in
  Apocalypse's own space (`1C1E77+`) carrying `_00E_ArkanistenfieberBlitzheilungSCN` — that script
  charges on `akCaster == PlayerREF`, so it would still bill the player. Separate job.
- **`WB_Alt_Metamagic3_Spell_SpellTwine_Proc3 0870D1` is not a heal.** It restores 5 HP total as one
  of nine random procs. The minimum meaningful charge would cost a fever point per HP. Left alone
  deliberately — do not "discover" it and add it.
- **Respite (`0581F9:Skyrim.esm`) is unobtainable in Enderal.** The record exists but is not on the
  `Player` NPC and Enderal has no vanilla perk UI, so every `HasPerk 0581F9` effect item in
  Apocalypse — the Stamina twin on each heal — is permanently inert. The base magnitudes are the real
  heal numbers, which is what step 9's rates are derived from.
- **Mana costs were the Creation Kit's arithmetic, not Enai's design, and they made the top tier
  uncastable.** A `SPELL` only uses its stored `BaseCost` when `ManualCostCalc` is set; without it the
  engine recomputes at runtime as `MGEF.BaseCost * magnitude^1.1 * (duration/10)^1.1` summed over the
  effects. **Enderal sets the flag on 271 of the 274 spells its own tomes teach** — every SureAI cost
  is typed by hand — and Apocalypse set it on **none** of its 175. The duration term does the damage:
  Conjure Battlemage is a 50-cost effect with a 180 s duration, so it billed **1201** against a mana
  pool that tops out near 400–500 (`+8` per level, and only if the player spends that level's
  attribute choice on it). Step 14 sets the flag and rescales; Conjure Battlemage is now 230.
- **Now that these records carry `ManualCostCalc`, the Creation Kit can no longer inflate them.**
  Before step 14 none of the 19 fever-taxed self-heals had the flag, so opening one in the CK would
  silently recalculate `BaseCost` upward by the fever effect's contribution. That hole is closed as a
  side effect. Edit the YAML only anyway.
