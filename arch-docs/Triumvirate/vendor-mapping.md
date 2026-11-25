# Triumvirate — Enderal vendor mapping

How the 75 spells reach the player in Enderal. Produced for **WD-16**; implemented by
`src/Triumvirate/tools/15-distribution.ps1` plus the loose replacement script in
`src/Triumvirate/Scripts/`.

## What the original did, and why none of it worked

Enai's distribution is a StartGameEnabled quest (`TVR_PopulateSpellBooks2_Quest`) whose script
makes **76 runtime calls**: `AddToFaction` on 10 named Skyrim NPCs (turning priests and
herbalists into vendors selling from satellite chests parked in the mod's own utility cell),
`AddItem` of per-archetype-per-school **UseAll tome bundles** into 14 vanilla merchant chests,
and `AddForm` of 21 staves into vanilla staff loot lists. **Not one receiver exists in Enderal**
— every call would log a `Cannot call ... on a None object` line at game start and distribute
nothing.

## The rebuild

Record-level and deterministic, per the workspace's "place it directly" doctrine — but written
into SureAI's own hooks rather than the merchants' chests.

### Where the stock actually goes

Enderal ships **67 LeveledItems named `<Merchant>_CustomMerchandise`**, one per merchant, and
**every one is empty**: `UseAll`, no entries, no `ChanceNone`, no `Global`. Each merchant's chest
already contains its own. They are an extension point SureAI built and never filled.

Writing there rather than into the `CONT` gets the same result — `UseAll` with no `ChanceNone`
means everything we add is yielded in full on every restock — while touching none of the contested
chest records. That is what makes the mod conflict-free against EGO, Apocalypse and KataPUMB.

The entries are the mod's own `TVR_Tomes_Litem_<Archetype>_<School>` bundles, themselves `UseAll`,
so the full chain is:

```
merchant chest (untouched)
  └─ <Merchant>_CustomMerchandise   UseAll   ← the only record we override
       └─ TVR_Tomes_Litem_<Arch>_<School>   UseAll
            └─ TVR_Tomes_Litem_<Arch>_<tier>_<School>   UseAll
                 └─ the tome
```

Every link is `UseAll`, so one hook entry yields that archetype's entire school line — every tome,
every restock, forever. No scripting, no save-state, no leveled-list dice.

Two traps worth keeping: the empty hooks have **no `Entries:` key at all** (Spriggit omits an empty
collection), so the key is created rather than appended to; and the hook↔merchant pairing was read
out of each chest's own `Items:` list, **not** guessed from names — Adreyo's hook is `Vexin_`, the
Ark guard smith's is `ArkHofSchmied_`.

The populate quest survives with a **stripped VMAD** (3 properties) and a loose replacement
`TVR_PopulateSpellBooks_Script.pex` that keeps only the two live pieces of the original: it
starts `TVR_Conversion_Quest` (the Obedience/conversion mechanic — WD-17's warning about not
neutralising this wholesale) and shows the mod-ready message. The loose file beats the BSA's
copy, so the 76 dead calls are gone entirely.

## The merchants

**One merchant per archetype.** Each sells that archetype's whole line, Novice through Master, plus
its staves, and no other merchant sells any of it. The table lives once, in
`tools/00-common.ps1` (`$script:TvrVendors`), and both `15-distribution.ps1` and
`17-tier-gating.ps1` read it, so the two steps cannot disagree.

**We override none of these chests.** Stock goes into each merchant's `*_CustomMerchandise` hook
(see [Where the stock actually goes](#where-the-stock-actually-goes) above). The mod's entire
override surface against its masters is **four `LeveledItem`s and zero `Container`s**.

| Archetype | Merchant (hook) | Chest (NOT overridden) | Cell, resolved from the chest's placed ref | Gold |
|---|---|---|---|---:|
| Shadow | Sister Envy (`SisterEnvy_` `0302ED`) | `_00E_Merchant_Rhalata_SisterEnvyContainer` `01E893:FS` | `FSNQR03RhalataTemple` | 2700 |
| Cleric | **Halda Stronghand** (`HaldaHammerschlag_` `0302FF`) | `_00E_Merchant_STHalda` `118055:Skyrim.esm` | `SuntempleArmory` | 3500 |
| Warlock | Shrouded Mage, Undercity (`Wildmage_Undercity_` `0302F0`) | `_00E_FS_Merchant_Wildmage_UndercityBarracks1` `01E900:FS` | `UndercityBarracks1` | 630 |
| Druid + Shaman | **Torius Flameling** (`TuriousFlammentrunk_` `0302FE`) | `_00E_Merchant_STTurious` `118050:Skyrim.esm` | `SuntempleAlchemy` | 1430 |

The Sun Temple has exactly these two merchants. Halda is
the armory smith (not flagged Essential) and Torius the alchemist (Essential). Their EditorIDs are
German (`Hammerschlag`, `Flammentrunk`); the English display names are read from the NPC records'
`Name` blocks.

What each hook carries, per archetype: the three per-school parent bundles
(`TVR_Tomes_Litem_<Arch>_<School>`, Novice/Apprentice/Adept), the six Expert/Master tier bundles
(`TVR_Tomes_Litem_<Arch>_075|100_<School>`, added by step 17), and every `TVR_<Arch>_*_Staff_*`.
Staves: Shadow 4, Cleric 4, Warlock 8, Druid + Shaman 10, which is all 26.

### Shared ground: two of the four hooks are also written by other releases here

| Hook | Also written by | Effect for a player running both |
|---|---|---|
| `TuriousFlammentrunk_` | **Apocalypse** (its Apprentice tier) | The later-loading plugin's entries win; the other's vanish without error |
| `HaldaHammerschlag_` | **Holy Templar Magic** (Kittytail Conversions, not yet on `main`) | Same |

Accepted deliberately for this release: Apocalypse is due its own redistribution, which should move
off Torius. Before shipping Kittytail Conversions or the next Apocalypse update, resolve both,
either by moving one side or by shipping a merge patch. **The chests are no escape route:** EGO and
`EGO SE - Leveling Redone` override both Sun Temple chests, and KataPUMB overrides Torius's.

> **Sister Envy is the only Shadow vendor, and she is in a Forgotten Stories quest location.** Her
> chest is in `FSNQR03RhalataTemple`, not the Undercity. Under the previous layout that was why she
> sold only the low tiers. Now the whole Shadow line depends on the player reaching her. Confirm in
> game when she becomes reachable (checklist, Test B).

### History: the layouts this replaced

1. **Ten chest overrides (WD-16).** This conflicted: `_00E_Merchant_CCBlacksmithArkGuard` `02EFBD`,
   `_00E_Merchant_Rhalata_SisterEnvyContainer` `01E893` and `_00E_Merchant_UCHehler02` `030309` are
   all in EGO's `## Containers (319)`, so our plugin silently reverted EGO's changes to those three
   (guardrail 5). The lesson is in CLAUDE.md: **check claim sets by FormKey, and prefer the hook to
   the chest.**
2. **Ten hooks, Expert/Master confined to Ark and the Undercity (WD-16b/c).** Each line sat at three
   or four merchants (Adreyo, the Frostcliff and Duneville Shrouded Mages, Akatyr, the Undercity
   Shrouded Mage, Sister Envy, the Bash Hole, the Fence, Marius, the Ark guard smith). The top two
   tiers were sold only by the five Ark/Undercity merchants. It was correct, but it was hard to tell
   a player where to find a given spell.
3. **Four hooks, one per archetype (this layout).** Step 15 deletes any hook no longer in the table
   and rebuilds the four from the FS master's copy on every run, so a stale layout cannot survive a
   re-run.

## Tier gating

`tools/17-tier-gating.ps1`, run after `15-distribution.ps1`.

Enai's Adept/Expert/Master tier bundles carry vanilla Skyrim's spell-tome gate — `ChanceNone: 1`
plus `Global: PC<School><Adept|Expert|Master>` — and **in Enderal that gate never opens**, so 45
of the 75 tomes were unobtainable no matter which chest they sat in. See
[`enderal-gap-audit.md`](enderal-gap-audit.md#the-skill-tier-globals) for the evidence. Dropping
the `Global:` line lets Enai's authored `ChanceNone: 1` stand.

Step 17 still cuts Expert/Master out of the 15 per-school parent bundles and places the `_075_`/`_100_`
tier bundles in a hook directly. That structure dates from the Ark/Undercity confinement. It is kept
because it produces the right result: the hook is now the archetype's own vendor, so the vendor
ends up with all five tiers.

The generators assert all of it: 75 tomes resolved, 15 per tier, **every tome except withheld ones
sold by exactly one merchant, and that merchant is its archetype's vendor**, every staff at exactly
one merchant, no merchant stocking an archetype the table does not give it, **zero** container
overrides, and no hook stocking the vestigial `TVR_Tomes_Litem_All*` family, which belongs to Enai's
debug chest. Withheld tomes (`$script:TvrWithheldTomes`, currently Force of Nature) may be present
or absent, so 15 and 17 hold on either side of `20-withhold-force-of-nature.ps1`. Before this
change, 17 could not be re-run after 20.

## Decisions the ticket asked for

| Question | Decision |
|---|---|
| Tomes vs direct spell sale | **Tomes** — they already exist per spell, and Enderal itself teaches spells from books |
| Pricing | Enai's ladder is vanilla Skyrim's (~45/97/340/655/1370). Enderal's whole tome range is 20–350, so the top three tiers rescale by **per-tier ratio** (preserving intra-tier ordering): Adept ×0.43 → ~130–170, Expert ×0.35 → ~215–240, Master ×0.23 → ~285–345. Novice/Apprentice (41–105) already fit and stay |
| Scrolls | **N/A** — Triumvirate ships none (no SCRL records in the plugin) |
| Loot | **Vendors only**, matching the original design: Enai's own loot presence was staves-in-staff-lists only, and Enderal has no staff loot lists. Staves are sold instead |

## What was deleted (37 records)

The 14 vanilla merchant-chest overrides, the 6 vanilla `Services*` faction overrides, the 8 TVR
satellite chests and the 9 TVR `*_Faction_Services*` factions — plus the satellite chests'
placed refs in `TVR_Cell` (the holding-cell markers for Hurl/Exile stay). After this pass the
plugin overrides **nothing of any master except the merchant hooks above** (ten at the time, four now), and the dead-ref
audit reads **40**, all documented deliberate leaves (TwinSouls 13, ElementalPotency 10,
MasterOfTheMind 1, the orphaned Stone quest's 16).

`Enderal - Forgotten Stories.esm` is now a **declared master** (after `Update.esm`), which the
FS-keyed chest overrides require; RelentlessSword already proved FS survives as a declared
master under `GameRelease.EnderalSE`.

## Verified

- Build is **byte-identical across two consecutive deserializes** — the ticket's guard against
  silent leveled-list drops. Spriggit stays pinned at 0.40.0.
  - after WD-16 (chest overrides): SHA-256 `6C7BB02F…CAD29C`, 745,728 bytes
  - after WD-16b (tier gating): SHA-256 `881505F7…7164C7`, 745,651 bytes
  - after WD-16c (CustomMerchandise hooks): SHA-256 `43B8EF1E…161510`, 739,071 bytes
  - after one-vendor-per-archetype: SHA-256 `4D62DC89…3FC95ACB`, **737,067 bytes**
- `HEDR` 1.70, masters `Skyrim.esm, Update.esm, Enderal - Forgotten Stories.esm` — re-read out of
  the built binary at offset 30, not assumed.
- Both `15-distribution.ps1` and `17-tier-gating.ps1` are **idempotent**: a second run reports 0
  changes and re-proves every invariant.
- Override surface against the masters is **4 records, all `LeveledItem`, zero `Container`** —
  asserted by the generator. None is in EGO's conflict index; two are shared with this repo's own
  releases (see [Shared ground](#shared-ground-two-of-the-four-hooks-are-also-written-by-other-releases-here)).
- Missing-reference audit still reads **40**, the documented pre-existing baseline: no new
  dangling references.
- In-game proof (WD-18): visit one vendor per archetype and confirm the low tiers appear in
  barter; then **specifically confirm an Expert- or Master-tier tome at each of the four**, and
  no Triumvirate stock at a former vendor such as Marius. The lower tiers appearing proves nothing
  about the 45 that were gated. See `distribution-test-checklist.md`. Confirm game start produces **zero** `TVR_`
  Papyrus errors.
