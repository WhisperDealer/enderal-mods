# Triumvirate — Enderal gap audit

**Everything Triumvirate points at that Enderal does not have, or has as something else**, with the
record evidence beside each verdict. Produced for **WD-9**; every archetype story (WD-11…WD-15) and
the distribution rebuild (WD-16) scope off this.

Baseline census, kill-checks and the ingest findings are in
[`ingest-census.md`](ingest-census.md) — this document does not repeat them.

> **Method.** Absolute, not diff-based. A check that only reports what *we* newly broke reads zero
> forever while the mod ships thousands of inherited dead references — the lesson from
> [`../Apocalypse/enderal-gap-audit.md`](../Apocalypse/enderal-gap-audit.md). Every reference is
> keyed by `<hex>:<master>` (never hex alone), resolved against Enderal's trees **and** against the
> real Bethesda masters, so "dead", "renamed" and "now a different record" are told apart rather
> than lumped together.

## Headline

| | |
|---|---|
| References examined | **11,289** |
| Resolve correctly in Enderal | **10,587 (94%)** |
| Dead — Enderal has nothing at that FormID | **702 occurrences, 311 distinct FormKeys, 149 records** |
| Survived but became a **different** record | **15 FormKeys** (1 retyped, 14 drifted) |
| Dead references that never existed in vanilla either | **0** — all 311 resolve in a real Bethesda master |

**Triumvirate ports far better than Apocalypse did.** The comparable Apocalypse figure was 4,077
dead occurrences across 617 FormKeys; this is 702 across 311, and the damage is concentrated in
distribution and in a handful of named mechanics rather than spread through the spell set.

Do **not** read the occurrence count as a severity ranking. 254 of the 702 are vendor leveled lists
that WD-16 replaces wholesale, while a single dead perk (`TwinSouls`) silently removes a headline
feature from two archetypes.

## Tooling

Three committed generators under `src/Triumvirate/tools/`, all re-runnable:

| Script | Answers | Output |
|---|---|---|
| `verify-missing-refs.ps1` | What does Enderal not have? | `build/dist/triumvirate-refs.csv` (every reference, classified) |
| `resolve-dead-refs.ps1` | What was each dead reference *meant* to be? | `build/dist/triumvirate-dead-refs.csv` |
| `verify-ref-drift.ps1` | Which surviving FormIDs became a **different** record? | `build/dist/triumvirate-ref-drift.csv` |

The last two need the **real** Bethesda masters serialized alongside Enderal's replacements:

```
reference/base/SkyrimReal        real Skyrim.esm       853,721 records   (vs Enderal's 792,831)
reference/base/UpdateReal        real Update.esm        14,032
reference/base/DawnguardReal     real Dawnguard.esm     93,218            (vs a 44 KB stub)
reference/base/HearthFiresReal   real HearthFires.esm   17,480            (vs an 80-byte stub)
reference/base/DragonbornReal    real Dragonborn.esm   176,956            (vs a 44 KB stub)
```

All five are gitignored and regenerable with `/spriggit-decompile-reference` from the Skyrim SE
install in `tools.json`. **This is the single highest-leverage thing this audit added**: without the
vanilla trees a dead FormID is an opaque hex string, and with them it is a named record you can pick
a substitute for. `DawnguardReal` fails Spriggit's own round-trip check on one LZ4-compressed NPC
record; the serialized tree is complete and correct for lookup, which is all it is used for.

## Verdicts

### 1. Spell tiering already works — do not touch it — **LEAVE**

The most important negative finding. Enderal reuses **all 25 vanilla school perks**
(`AlterationNovice00` … `RestorationMaster100`), and its own class talents read them through
`SpellHasCastingPerkConditionData` — the condition that asks *"is this spell's `HalfCostPerk` X?"*.

```yaml
# reference/base/Skyrim/Perks/_00E_Class_Thaumaturge_P02_MentalNovice - 069D00_Skyrim.esm.yaml
# "Reduces the Mana costs of mental and light spells of the novice and apprentice level by 30 percent."
- MutagenObjectType: PerkEntryPointModifyValue
  Conditions:
  - Conditions:
    - Data: { MutagenObjectType: SpellHasCastingPerkConditionData, Perk: 0F2CAA:Skyrim.esm }  # RestorationNovice00
    - Data: { MutagenObjectType: SpellHasCastingPerkConditionData, Perk: 0C44C7:Skyrim.esm }  # RestorationApprentice25
    - Data: { MutagenObjectType: SpellHasCastingPerkConditionData, Perk: 0F2CA6:Skyrim.esm }  # AlterationNovice00
    - Data: { MutagenObjectType: SpellHasCastingPerkConditionData, Perk: 0C44B7:Skyrim.esm }  # AlterationApprentice25
  EntryPoint: ModSpellCost
  Modification: Multiply
  Value: 0.7
```

**14 Enderal talent perks** across the Elementalist, Sinistrope, Thaumaturge and Affinity lines do
this, and between them they test **every one of the 25 vanilla tier perks**. All 126 of Triumvirate's
`HalfCostPerk` references resolve.

> **So a ported Skyrim spell's tier tag is not merely harmless — it is exactly the hook Enderal's
> talent system already reads.** Leave `HalfCostPerk` alone on every ported spell; setting it
> correctly is what makes an Enderal mage's talent discounts apply. This generalises to any ported
> magic mod and is worth revisiting for Apocalypse.

The five `MagicSkill` ActorValues are likewise kept and only renamed (CLAUDE.md, "The five magic
schools are renamed, not replaced"), so `GetActorValue`-style scaling reads a real value. Remember
the pairing that catches people out: **Alteration is Mentalism, Illusion is Psionics.**

### 2. Four dead perks — three cost a real mechanic — **FIX**

| Dead FormKey | Was | Refs | Costs |
|---|---|---:|---|
| `0D5F1C:Skyrim.esm` | **`TwinSouls`** | 13 | Every `*_TwinSouls` effect on the Druid's Raven / Hound of Hircine and the Warlock's demons — **the minion-doubling feature, in two archetypes** |
| `0CB41A:Skyrim.esm` | **`ElementalPotency`** | 10 | Dual-cast potency on Gremlin / Leviathan / Ravagor / Temple Grim summons |
| `059B76:Skyrim.esm` | **`MasterOfTheMind`** | 1 | `TVR_Shadow_Possess_Effect_TraitorousShadow` working on undead/daedra/automatons |
| `0177B4:Dragonborn.esm` | `DLC2AshShellDmgPerk` | 1 | Cosmetic, on the Shaman's Worldshatter ash-shell hazard |

Enderal replaced Skyrim's perk trees with its own talents, so there is no drop-in equivalent — these
must be rebuilt as Triumvirate-owned perks hung off Enderal talents, or the feature cut. Decide per
archetype in WD-11…WD-15; **`TwinSouls` is the one to decide first**, because "summon two" is a
selling point of both the Druid and the Warlock.

### 3. `MagicAllegianceFaction` is gone — Enderal has a direct archetype — **REPLACE**

`09E0C9:Skyrim.esm` `MagicAllegianceFaction` is dead, with **25 references** — one on every
`TVR_Ancestors_Actor_SpiritGuardian_*` (the Shaman's 25 per-race/sex ancestor summons). Nothing in
Enderal references it.

Enderal's own summons use **`Creature__SummonableFaction` `046E6B:Skyrim.esm`** instead:

```yaml
FormKey: 046E6B:Skyrim.esm
EditorID: Creature__SummonableFaction
Flags: [HiddenFromPC]
CrimeValues: { Arrest: True, AttackOnSight: True }
```

**60 Enderal actors are in it** — the `_NNE_Summonable*_Player` / `_NPC` pairs (Ghostly Wolf,
Skeleton, the four elementals, Oorbaya…). That is the proven archetype; use it rather than
recreating Bethesda's faction. Note the Enderal naming convention while you are there:
`_<level>E_Summonable<Creature>_Player`, with a separate `_NPC` variant — worth matching in
WD-11…WD-15.

Also dead and animal-summon related: `PredatorFaction 02E893` (4 refs — Wolf, Snow Leopard, the two
Fylgja) and `PreyFaction 02E894` (2 refs — the Raven).

### 4. The Cleric's Dawnguard dependency is cosmetic only — **DROP the fields**

The ticket flagged the Cleric's sun damage and anti-undead multipliers as Dawnguard-dependent. They
are not. Everything the Cleric loses to Dawnguard is a visual:

| Dead | Was | Refs | Field |
|---|---|---:|---|
| `00A3BB:Dawnguard.esm` | `DLC1SunFireFXShader` | 5 | `HitShader` |
| `019C9E:Dawnguard.esm` | `DLC1SunDamageImpactSmoke` | 2 | condition `Object` |
| `00AE9D:Dawnguard.esm` | `DLCAurielsBowEffectImod` | 1 | `ImageSpaceModifier` |

The mechanic itself is Triumvirate's own and works: `TVR_Cleric_Auras_Effect_Aura_1_CloakProc_VsUndead`
gates on `IsHostileToActorConditionData` plus keyword tests, and **`ActorTypeUndead 013796`,
`ActorTypeAnimal 013798` and `ActorTypeDaedra 013797` all exist in Enderal and are actively used —
by 197, 70 and 24 NPC/Race records respectively.** So the anti-undead multiplier fires on Enderal's
Lost Ones with no change.

Drop the three visual fields or substitute an Enderal shader. Do not invent a mechanism.

### 5. Distribution is completely inert — **REPLACE (WD-16)**

Same shape as Apocalypse, and just as dead. `TVR_PopulateSpellBooks2_Quest` (`StartGameEnabled` +
`RunOnce`) carries a `TVR_PopulateSpellBooks_Script` with **90 script object properties**: 44 are
Triumvirate's own and live; **46 point at Bethesda records, of which 36 are dead** — 11 named Skyrim
NPCs (Danica Pure-Spring, Dravynea, Froki, Hamal, Jora, Maramal, Nura, Rorlund, Runil), 22
`LItemStaff*` leveled lists, `JobMerchantFaction`, and the DLC chests.

The dead vendor economy behind it, by occurrence: `PerkMasterTraderGold` (26), `VendorGoldSpells`
(15), `LItemSpellVendorScrolls75` (15), the `LItemApothecary*75` family (~40 across 6 lists),
`LItemSpellTomes00/25All*` per school. **92 dead LeveledItems in 254 occurrences** — 36% of all dead
references.

> **The remaining 10 are worse than dead: they bind to Enderal scenery.** Ten of the quest's
> properties resolve in Enderal only as *placed references* — the FormID survived as an unrelated
> object. Two confirmed by reading the cell:
>
> | Property | FormID | In Enderal |
> |---|---|---|
> | `MerchantWCollegeEnthirChest` | `0EE9F8` | a `PlacedObject` (base `03E229`) in **UndercityBarracksHiddenWalkway** |
> | `MerchantDBSanctuaryMerchantChest` | `0ABD9F` | a `PlacedObject` (base `0BC9CE`) in **AgnodLevel01Engine** |
>
> A Papyrus `ObjectReference` property binds successfully here, because the reference exists — it is
> simply the wrong object. Whether `AddItem` on it no-ops or errors is a **WD-17** question to answer
> by reading the script, not to assume. Either way the tomes never reach a merchant.
>
> CLAUDE.md's rule from Apocalypse applies: **make the work empty rather than trying to stop the
> script**, and `grep` the whole script set for the symbol first — Apocalypse had a second entry
> point (an MCM "Repopulate" button) driving the same loop over duplicate lists.

Triumvirate also ships **14 merchant-chest overrides and 6 `Services*` faction overrides** for Skyrim
vendors that do not exist here, plus its own `TVR_*_Container_Merchant*Chest` records keyed to the
same absent NPCs. WD-16 rehomes all of it onto Enderal's merchants; Enderal's own spell-book lists
and the merchant wealth ladder are tabulated in CLAUDE.md.

### 6. FormIDs that survived as a *different* record — **the live-bug class**

15 of 1,462 distinct surviving `:Skyrim.esm` references are not the record Bethesda had. 1,402 are
exact `MATCH`, which is why these stand out.

**RETYPED — a different record type entirely (1):**

| FormKey | Vanilla | Enderal |
|---|---|---|
| `041449` | `Regions/TundraMegan01` | **`Statics/_00E_Ark_1024WallRound01`** |

This is inside Triumvirate's `Tamriel 00003C` worldspace override — the same FormID CLAUDE.md already
records from Apocalypse. It disappears when that override is dropped (see ingest-census finding 1).

**DRIFTED — same type, unrelated record (14).** Most are harmless or accidentally right:

| FormKey | Vanilla | Enderal | Verdict |
|---|---|---|---|
| `10E93B` `10E99A` `10EE3F` `10EE64` `10FC0F` | `MineOreBlackreach01–04` | `_00E_MineOreShadowsteel*` | **LEAVE — accidentally correct.** The Druid's Mark Ore list wanted ore veins and Enderal put ore veins at those IDs |
| `09748B` `07EE00` | `GlowingMushroom*` | `_00E_Mistshroom*` | **LEAVE** — still a mushroom |
| `0BB94D` `0BB94E` | `TreeFloraDragonsTongue01/02` | `TreeFloraVatyrsTongue01/02` | **LEAVE** — Enderal's rename of the same plant |
| `013AE6` `0AA8D3` | `MaleNord`, `MaleGuard` | `VT_Male_Merchant_Old`, `VT_Male_OrderGuard01` | **LEAVE** — still voice types; a summon gets an Enderal voice |
| `0516C8` | `deathBell` | `BaldrisRoot` | **LEAVE** — ingredient for ingredient, in a chest WD-16 replaces |
| `092A6C` | an art-attach named node | **`SomeWolfKeyword`** | **READ IT.** In the Keywords list of `TVR_Primal_Race_CallWolf` (where it is accidentally apt) *and* `TVR_Warrior_Race_Fylgja` (where it is not) |
| **`0C891B`** | **`ReligiousMaraLove`** (Amulet of Mara) | **`_04E_30_Unique_SongOfTheWinter`** | **FIX.** An `Item` in `TVR_Cleric_Container_MerchantMaramalChest` |

> **`0C891B` is the third mod in this workspace to hit that exact FormID.** CLAUDE.md documents it
> from Biggie Traits, where the Amulet-of-the-Divines OR-group resolved it to that same Enderal
> unique weapon and fired Divine-amulet effects on it. Here the blast radius is small — the container
> belongs to a merchant Enderal does not have and WD-16 deletes it — but the pattern is now proven
> three times over: **a `:Skyrim.esm` FormID that resolves is not thereby correct.**

### 7. DLC masters — verdicts (moved here from WD-8)

260 references, 136 distinct FormKeys, 53 files. Every one now has a vanilla name, so each gets a
verdict rather than a guess.

| Shape | Count | Verdict |
|---|---:|---|
| Whole records overriding a DLC record — 5 DLC vendor chests + `DLC2dunFrostmoonWerewolvesVendorFaction` | 6 records | **DELETE.** They override records Enderal does not have; WD-16 replaces the distribution |
| Hearthfires garden plants and Dawnguard/Dragonborn flora — `BYOHHouseFloraCabbage01`, `BYOHButterChurn`, `DLC1TreeFloraMountainFlower*`, `DLC01Gleamblossom01old`… behind `TVR_Veil_FormList_Mark_Plant`, `…Mark_Ore`, `TVR_Verdant_FormList_Ingredients` | ~120 entries | **DROP the entries, then repopulate from Enderal's own flora.** Deleting alone leaves the Druid tracking a shorter list; the Blackreach→Shadowsteel drift above shows Enderal has real targets to point at. Mind the emptying trap: an empty collection means deleting the key, not leaving `Items:` bare |
| Single fields on Triumvirate's own records — `CrGargoyleVoice` (3), `CrDogDeathHound` (3), `DLC2EncClassDeathhound` (2), `DLC1csChaurusHunter` (1), the three Cleric sun visuals (8), Leviathan `Race`/`MorphRace`/`ArmorRace` → `DLC2MiraakRace`… | ~55 | **SUBSTITUTE per record**, from Enderal's bestiary. Never blanket-null: CLAUDE.md is explicit that a dangling FormID is proven harmless here while a null is not automatically better, and null `BNAM` on a `COBJ` was shipped once on exactly that untested reasoning |

Once those land, the three DLC masters come off the plugin and WD-18's gate is satisfiable.

### 8. The four Skyrim cells and their contents — **DELETE**

`RiftenHouseofClanSnowShod 016BDE`, `MarkarthTempleofDibella 016DF3`,
`SolitudeTempleoftheDivines 016A02` and exterior `Riverwood 009732` do not exist in Enderal, so
Triumvirate's overrides *inject* four Skyrim cells. Their supporting references are dead too —
`RiverwoodLocation`, `MarkarthTempleofDibellaLocation`,
`SolitudeTempleoftheEightDivinesLocation`, `RiftenHouseofClanSnowShodLocation`, and the `WETravel` /
`WESceneCenter` `LocationReferenceTypes` (8 refs each).

Delete the cell overrides, the worldspace override, and the 13 `REFR` / 4 `ACHR` that live in them.
Triumvirate's own `TVR_Cell 2E99EB` stays — it is the Night Gate portal interior and is self-contained.

## Not yet swept

Stated plainly rather than left implied:

* **Assets.** Nothing in Triumvirate's two BSAs has been examined. `bsab` and `bsarch` are both
  unset in `tools.json` and `BSArch64.exe` is not in this machine's xEdit folder, so no extractor is
  configured. **This matters more than it sounds**: CLAUDE.md records that Apocalypse's BSA shipped
  `dgintimidateplayerscript.pex` over Enderal's deliberate 4-line stubs, restoring a brawl system
  Enderal removed. The check is one command once an extractor exists — list the archive and
  intersect the script names with `reference/base/EnderalScripts/source/scripts/`. **WD-17.**
* **Script internals.** `TVR_PopulateSpellBooks_Script` and the archetype scripts have not been
  decompiled, so every claim here about *runtime* behaviour is bounded by what the records show.
  **WD-17.**
* **Per-summon actor mapping.** Which of the ~15 summons has a usable Enderal base actor is scoped
  but not decided; the faction, voice and class substitutes above are the framework.
  **WD-11…WD-15.**

## How to reproduce

```powershell
powershell -File src/Triumvirate/tools/verify-missing-refs.ps1   # -> triumvirate-refs.csv
powershell -File src/Triumvirate/tools/resolve-dead-refs.ps1     # -> triumvirate-dead-refs.csv
powershell -File src/Triumvirate/tools/verify-ref-drift.ps1      # -> triumvirate-ref-drift.csv
```

The first runs against Enderal's trees alone. The other two need `reference/base/*Real`; serialize
them once with `/spriggit-decompile-reference` against the Skyrim SE install named in `tools.json`.

Once the verdicts above are applied, re-run the first with `-Baseline <n>` to ratchet the dead-
reference count down and hold it.
