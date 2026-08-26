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

Record-level and deterministic, per the workspace's "place it directly" doctrine: ten Enderal
merchant chest **CONT overrides**, each copied verbatim from the winning (Forgotten Stories)
version and extended with the mod's own `TVR_Tomes_Litem_<Archetype>_<School>` bundles as
ordinary `Items` entries. The bundles are **UseAll** leveled items, so one entry yields that
archetype's *entire* school line — every tome, every restock, forever. No scripting, no
save-state, no leveled-list dice.

The populate quest survives with a **stripped VMAD** (3 properties) and a loose replacement
`TVR_PopulateSpellBooks_Script.pex` that keeps only the two live pieces of the original: it
starts `TVR_Conversion_Quest` (the Obedience/conversion mechanic — WD-17's warning about not
neutralising this wholesale) and shows the mod-ready message. The loose file beats the BSA's
copy, so the 76 dead calls are gone entirely.

## The merchants

Every chest was checked against **Apocalypse's six chest overrides** (both mods ship from this
repo — overriding the same chest would make load order silently delete one mod's stock) and
**KataPUMB's three staff chests** (Tarhutie stays untouched, preserving Kata's full set per the
CLAUDE.md precedent), and is free of both.

> **Correction (2026-08-26): three of the ten ARE overridden by EGO.** This section previously
> claimed all ten were free of EGO's 319 container overrides as well. They are not. Grepping the
> `## Containers (319)` section of [`arch-docs/EGO/conflict-index.md`](../EGO/conflict-index.md)
> by exact FormKey finds **`_00E_Merchant_CCBlacksmithArkGuard` `02EFBD`**,
> **`_00E_Merchant_Rhalata_SisterEnvyContainer` `01E893`** and **`_00E_Merchant_UCHehler02`
> `030309`**. Our plugin loads after EGO and copies the *Forgotten Stories* version of each, so in
> an EGO list those three chests silently revert EGO's changes to them — guardrail 5, unresolved.
>
> Re-homing them is not straightforward, because **EGO owns essentially all of Ark's commerce**:
> of the capital's 55 merchant chests only **six** are EGO-clear, and all six are 250–405 gold
> (Marius' library, a tavern, a butcher, a fruit stall). Every Ark chest at 900 gold or more is
> EGO's. So the choice is between accepting the conflict, building those three overrides from
> EGO's records (which makes EGO a soft dependency), or shipping a separate EGO patch. Deferred —
> but it must be settled before release, and **the claim-set check must be re-run by FormKey**,
> not by the assumption recorded here.

| Chest | Who / where | Gold | Sells | Why |
|---|---|---:|---|---|
| `_00E_Merchant_FlusshaimAdreyoContainer` `05BCD4:Skyrim.esm` | Adreyo, Riverville general trader | 380 | Druid, Cleric | The starting town's shop — sells mushrooms, herbs and arcana books already; early access for the two "respectable" lines |
| `_00E_FS_Merchant_Wildmage_FrostcliffTavern` `01E904:FS` | Wild Mage, Frostcliff Tavern | 674 | Druid, Shaman + **Druid staves** | FS's Wild Mages literally sell forbidden spell literature; the mountain one is the nature-magic seller |
| `_00E_FS_Merchant_Wildmage_Duneville` `01E90A:FS` | Wild Mage, Duneville | 707 | Shaman, Druid + **Shaman staves** | The desert-village Wild Mage — the closest thing Enderal has to a tribal spirit-seller |
| `_00E_Merchant_DunevilleSmithHunter` `02F2BF:FS` | Duneville smith & hunter | 2200 | Shaman | The tribal smith — the Baldor Iron-Shaper analogue from the original roster |
| `_00E_FS_Merchant_Wildmage_UndercityBarracks1` `01E900:FS` | Wild Mage, Undercity barracks | 630 | Warlock, Shadow | The Wild Mage who works out of the Undercity — forbidden magic in the underworld |
| `_00E_Merchant_Rhalata_SisterEnvyContainer` `01E893:FS` | Sister Envy, the Rhalata | 2700 | Warlock, Shadow + **Warlock staves** | The murder-cult quartermaster: soul gems, poisons, scrolls. The Babette/Atub slot, and the richest vendor in the set |
| `_00E_FS_UndercityBashHole_Merchant` `02F2F0:FS` | The Bash Hole, Undercity | 2200 | Warlock | An underworld dive trading in everything |
| `_00E_Merchant_UCHehler02` `030309:FS` | Undercity fence | 1450 | Shadow + **Shadow staves** | *Hehler* = fence — the Gulum-Ei slot, verbatim |
| `_00E_Merchant_CCMarius` `046AEF:Skyrim.esm` | Marius, Ark bookseller | 250 | Cleric, Shadow + **Cleric staves** | Ark's bookshop (42 titles, including the Holy Order's own literature) — the natural home of any spell tome |
| `_00E_Merchant_CCBlacksmithArkGuard` `02EFBD:FS` | Ark guard blacksmith | 2200 | Cleric | The Order's garrison smith — the paladin-facing seller |

The table's **Sells** column is the Novice/Apprentice/Adept line. Source counts for those:
**36 spells at 3 vendors, the 9 Shadow Mage ones at 4**. Each archetype's **staves** (26 total)
sit at one flavour-fit vendor apiece. Expert and Master are Ark/Undercity only — see below.

## Tier gating — where the top two tiers are sold

`tools/17-tier-gating.ps1`, run after `15-distribution.ps1`.

Enai's Adept/Expert/Master tier bundles carry vanilla Skyrim's spell-tome gate — `ChanceNone: 1`
plus `Global: PC<School><Adept|Expert|Master>` — and **in Enderal that gate never opens**, so 45
of the 75 tomes were unobtainable no matter which chest they sat in. See
[`enderal-gap-audit.md`](enderal-gap-audit.md#the-skill-tier-globals) for the evidence. Dropping
the `Global:` line lets Enai's authored `ChanceNone: 1` stand.

With the gate gone all ten vendors would sell all five tiers, so **Expert and Master are cut out
of the 15 per-school parent bundles and placed directly at the five Ark/Undercity chests
instead**. No new records: the `_075_`/`_100_` tier bundles already exist and are already
`UseAll`-with-one-entry, so they go into the chests as ordinary `Items` entries.

| Chest | Cell (verified via its placed ref) | Expert/Master it carries |
|---|---|---|
| `_00E_Merchant_CCMarius` | `CapitalCityBibliothek` — Ark, the library | Cleric, Shadow, **Druid, Shaman** |
| `_00E_Merchant_CCBlacksmithArkGuard` | `CapitalCityCastleWorld` — Ark, the castle | Cleric |
| `_00E_FS_Merchant_Wildmage_UndercityBarracks1` | `UndercityBarracks1` | Warlock, Shadow, **Druid, Shaman** |
| `_00E_FS_UndercityBashHole_Merchant` | `UndercityBarracks3BashHole` | Warlock |
| `_00E_Merchant_UCHehler02` | `UndercityBarracks0FalseDogTavern` | Shadow |

Druid and Shaman have no Ark/Undercity vendor of their own, so restricting the top tiers to those
five chests would have left 12 tomes with nowhere to go — re-breaking a sixth of the mod while
fixing 45. They are added to the two shops that can carry anything: **Marius** (a library, 42
titles) and the **Undercity Wild Mage** (FS's Wild Mages sell forbidden spell literature). Every
archetype ends with **at least two** Expert/Master sources.

> **Sister Envy is not Undercity.** Her chest sits in `FSNQR03RhalataTemple`, not the Undercity —
> checked by resolving the container's placed ref rather than by reading the name. So the richest
> vendor in the set (2700 gold) carries the low tiers only.

The generator asserts all of it: 75/75 tomes obtainable, 15 per tier, every Expert/Master tome
sourced **only** from those five chests and from at least two of them, every lower-tier tome still
at three or more. It also refuses to let a merchant chest stock the vestigial
`TVR_Tomes_Litem_All*` family, which belongs to Enai's debug chest.

> **The Cleric caveat.** Enderal has no priest-merchants at all — its temples do not trade, and
> the two Sun Temple vendors are claimed (STTurious by Apocalypse, STHalda by EGO). The Cleric
> line therefore goes to the *civic/Order-adjacent* vendors — the capital's bookshop, the
> garrison smith, the starting town's trader — rather than to literal priests. Recorded here so
> nobody "fixes" it onto an EGO-claimed chest later.

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
plugin overrides **nothing of any master except the ten chest records above**, and the dead-ref
audit reads **40**, all documented deliberate leaves (TwinSouls 13, ElementalPotency 10,
MasterOfTheMind 1, the orphaned Stone quest's 16).

`Enderal - Forgotten Stories.esm` is now a **declared master** (after `Update.esm`), which the
FS-keyed chest overrides require; RelentlessSword already proved FS survives as a declared
master under `GameRelease.EnderalSE`.

## Verified

- Build is **byte-identical across two consecutive deserializes** — the ticket's guard against
  silent leveled-list drops. Spriggit stays pinned at 0.40.0.
  - after WD-16: SHA-256 `6C7BB02F…CAD29C`, 745,728 bytes
  - after WD-16b (tier gating): SHA-256 `881505F7…7164C7`, 745,651 bytes
- `HEDR` 1.70, masters `Skyrim.esm, Update.esm, Enderal - Forgotten Stories.esm` — re-read out of
  the built binary at offset 30, not assumed.
- `17-tier-gating.ps1` is **idempotent**: a second run reports 0 changes and re-proves every
  invariant.
- In-game proof (WD-18): visit one vendor per archetype and confirm the low tiers appear in
  barter; then **specifically confirm an Expert- or Master-tier tome at Marius or an Undercity
  merchant, and its absence from Adreyo and the two Wild Mages** — the lower tiers appearing
  proves nothing about the 45 that were gated. Confirm game start produces **zero** `TVR_`
  Papyrus errors.
