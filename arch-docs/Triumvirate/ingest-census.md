# Triumvirate — ingest census and baseline

The record baseline every later Triumvirate diff is measured against, plus the results of the cheap
kill-checks run at ingest. Produced for **WD-8**; the per-reference verdicts it flags belong to
**WD-9**.

Everything below was read off the plugin, not recalled. Re-derive it with the commands in
[How to reproduce](#how-to-reproduce).

## Upstream

| | |
|---|---|
| Mod | **Triumvirate — Mage Archetypes** 1.8.0 (Nexus 39170) |
| Author | Enai Siaion (& Mihail) |
| Plugin | `Triumvirate - Mage Archetypes.esp`, 804,064 bytes |
| Ships | `Triumvirate - Mage Archetypes.bsa` (29.3 MB), `Triumvirate - Mage Archetypes - Textures.bsa` (36.9 MB) |
| Ingested | 2026-08-24, from the `zenderal` MO2 instance |
| Pristine copy | `reference/mods/Triumvirate/` (gitignored) — plugin, both BSAs, `meta.ini`, and `esp/` holding the untouched serialization for diffing against our tree |

## Kill-checks

| Check | Result |
|---|---|
| **HEDR form version** | **1.70** — bytes `9A 99 D9 3F` at file offset 30. **Already under the ceiling; no rebuild is needed for this reason.** |
| Plugin flags | `0x0000` — a plain ESP. Not ESM, not ESL-flagged. |
| Masters | `Skyrim.esm`, `Update.esm`, **`Dawnguard.esm`, `HearthFires.esm`, `Dragonborn.esm`** |
| BSA coupling | Two BSAs named after the plugin, so the archives only load while the plugin keeps its **exact original filename**. That makes this a **replacement plugin**, the Apocalypse shape — not a patch. |
| Override surface | **36 records of 1882** — small, and almost entirely vendor distribution. See below. |

> **The ticket's premise was wrong in our favour.** WD-8 is titled "rebuild at form version 1.70" and
> its DLC step warns that a DLC-mastered plugin "fails to load in game". Neither applies: the plugin
> is *already* 1.70, and CLAUDE.md records **[verified 2026-08-02]** that the engine loads all three
> DLC stubs unconditionally, so a DLC-mastered plugin loads with no user action. Stripping the DLC
> masters is hygiene — and WD-18's release gate — not a blocker. See
> [DLC masters](#dlc-masters--why-they-are-still-here).

## Baseline census

**1882 records**, of which **1846 are Triumvirate's own** and 36 are overrides.

| Sig | Count | Sig | Count | Sig | Count |
|---|---:|---|---:|---|---:|
| MGEF | 363 | ENCH | 31 | IPCT | 14 |
| SNDR | 273 | GLOB | 31 | REFR | 13 |
| SPEL | 185 | STAT | 30 | PERK | 11 |
| ARTO | 102 | WEAP | 29 | HAZD | 11 |
| IMAD | 100 | CONT | 29 | IPDS | 11 |
| LVLI | 96 | EXPL | 29 | ACTI | 11 |
| KYWD | 86 | FLST | 23 | DIAL | 9 |
| BOOK | 75 | MESG | 22 | CELL | 6 |
| EFSH | 47 | QUST | 18 | DLBR | 5 |
| NPC_ | 41 | FACT | 18 | ACHR | 4 |
| LIGH | 40 | SOUN | 17 | OTFT | 2 |
| | | ARMO | 16 | TXST | 1 |
| | | PROJ | 16 | DEBR | 1 |
| | | RACE | 16 | CLAS | 1 |
| | | RFCT | 15 | WRLD | 1 |
| | | INFO | 15 | VTYP | 1 |
| | | ARMA | 15 | ALCH | 1 |
| | | | | PACK | 1 |

Overrides by master: **Skyrim.esm 30**, **Dragonborn.esm 5**, **Dawnguard.esm 1**. `Update.esm` and
`HearthFires.esm` are mastered but nothing overrides them — they are carried by references alone.

## Round-trip proof

Deserializing `src/Triumvirate/TriumvirateESP/` back to a plugin is **lossless**:

```
FILE         FLAGS      HEDR   MASTERS
ORIGINAL     0x0000     1.7    Skyrim.esm, Update.esm, Dawnguard.esm, HearthFires.esm, Dragonborn.esm
REBUILT      0x0000     1.7    Skyrim.esm, Update.esm, Dawnguard.esm, HearthFires.esm, Dragonborn.esm

records: original=1882  rebuilt=1882
only in ORIGINAL : 0
only in REBUILT  : 0
type mismatches  : 0
-- record counts by signature --
   identical across every record type
```

Re-serializing the rebuilt plugin and diffing the two YAML trees gives **1876 files, identical bar
three lines**, each a negative-zero normalisation Mutagen performs on write:

```
Cells/3/8/MarkarthTempleofDibella - 016DF3_Skyrim.esm      Rotation: 0, -0, 3.141595  ->  0, 0, 3.141595
Cells/4/7/SolitudeTempleoftheDivines - 016A02_Skyrim.esm   Rotation: 0, -0, 2.7831957 ->  0, 0, 2.7831957
Cells/9/5/TVR_Cell - 2E99EB_Triumvirate…                   Position: 0, -0, 256       ->  0, 0, 256
```

`-0.0` and `0.0` are numerically equal; no placement changes. Expect those three lines to settle on
`0` the first time anyone re-serializes, and do not read it as a diff.

`ModHeader.Stats.Version: 1.7` is written explicitly in `RecordData.yaml`, so the build keeps 1.70
rather than falling through to Mutagen's **1.71** default.

## The 36 overrides — what they are

Almost the whole override surface is Enai's vendor distribution, which WD-16 replaces wholesale.

**Merchant chests (CONT, 14)** — `MerchantWCollegeEnthirChest 0EE9F7`, `MerchantWhiterunFarengarsChest
0A298A`, `MerchantSolitudeSybilleStentorChest 0A2989`, `MerchantWindhelmWuunferthsChest 0A3F1B`,
`MerchantWinterholdNelacarChest 0E7BCD`, `MerchantMorthalFalionsChest 09DA56`,
`MerchantMarkarthHagsCureChest 09E0D7`, `MerchantKynesgroveDravyneaChest 0A3F02`,
`MerchantDBSanctuaryMerchantChest 0ABD9E`, `TGFenceMerchantChestGulumEi 0D882D`, and four
orc-stronghold wise-woman chests — plus the five DLC chests listed further down.

**Services factions (FACT, 6)** — `ServicesDBBabette 0ABD9C`, `ServicesDushnikYalWiseWoman 09E12B`,
`ServicesLargashburAtub 0ACB6E`, `ServicesMarkarthHagsCure 094382`, `ServicesMorKhazgurWiseWoman
09E46B`, `ServicesNarzulburBolar 0B3FDF`.

**Cells and worldspace (5)** — `RiftenHouseofClanSnowShod 016BDE`, `MarkarthTempleofDibella 016DF3`,
`SolitudeTempleoftheDivines 016A02`, exterior `Riverwood 009732`, and worldspace **`00003C`**.

### Flagged for WD-9

1. **`00003C` is not `Tamriel` here — it is `MQP01Home`.** Triumvirate ships a `Tamriel` WRLD
   override at that FormID. In Enderal `00003C` resolves to **`MQP01Home`**, the prologue house, in
   both base Enderal (`reference/base/Skyrim/Worldspaces/MQP01Home - 00003C_Skyrim.esm`) and
   Forgotten Stories, which also overrides it. **This is the second occurrence of the exact defect
   Apocalypse shipped** — see `arch-docs/Apocalypse/enderal-gap-audit.md`. The Apocalypse fix
   (forward the **Forgotten Stories** record back, guardrail 5) is the precedent.
2. **The other four cells do not exist in Enderal at all.** `016BDE`, `016DF3`, `016A02` and
   `009732` resolve to nothing in `reference/base/Skyrim`, `EnderalFS` or `Update`, so those
   overrides are dead weight that *injects* four Skyrim cells into Enderal's FormID space. The
   13 `REFR` and 4 `ACHR` records the tree carries live in them and in Triumvirate's own `TVR_Cell`.
3. **Every merchant chest and Services faction is a Skyrim vendor**, none of which Enderal has. The
   distribution is inert exactly as Apocalypse's was; WD-16 rebuilds it onto Enderal merchants.

## DLC masters — why they are still here

Triumvirate points into the three stubs in **260 places across 136 distinct FormKeys and 53 files**:

| Master | Occurrences | Distinct FormKeys | Files |
|---|---:|---:|---:|
| `Dawnguard.esm` | 62 | 38 | 36 |
| `HearthFires.esm` | 103 | 36 | 3 |
| `Dragonborn.esm` | 95 | 62 | 23 |

They fall into three shapes, and only the first is mechanical:

* **Six whole records that override a DLC record** — the five DLC vendor chests
  (`DLC1VendorChestFlorentius`, `DLC2dunFrostmoonVendorChest`, `DLC2MerchantTelMithrynNelothChest`,
  `DLC2SkaalBlacksmithChest`, `DLC2SkaalMerchantChest`) and
  `DLC2dunFrostmoonWerewolvesVendorFaction`. Deleting these is unambiguous: they override records
  Enderal does not have, and WD-16 replaces the distribution anyway.
* **~120 FormList entries** — the Hearthfires garden plants and the Dragonborn/Dawnguard ores and
  ingredients behind `TVR_Veil_FormList_Mark_Plant`, `TVR_Veil_FormList_Mark_Ore`,
  `TVR_Verdant_FormList_Ingredients`, `TVR_Elemental_FormList_ControlFlames_FireSources`,
  `TVR_Ancestors_FormList_Conversion_VoiceTypes` and the unused
  `TVR_Diviner_FormList_Mark_Gold_UNUSED_ATM`. Dropping a dead list entry is safe, but *what these
  lists should hold in Enderal* is a WD-9 question, not a deletion — and note the emptying trap in
  CLAUDE.md: an empty collection means **deleting the key**, not leaving `Items:` bare.
* **~55 single-field references inside Triumvirate's own records** — `Race:` / `MorphRace:` /
  `ArmorRace:` on the Leviathan, `Voice:` and `Class:` on the Ravagor and Temple Grim,
  `BodyPartData` and `BaseMovementDefault*` on the Raven, plus `HitShader`, `ImageSpaceModifier`,
  `MenuDisplayObject`, `OutputModel`, impact `Material`, and several cloak/keyword conditions.
  **These need a substitute, not a deletion** — CLAUDE.md is explicit that a dangling FormID is
  proven harmless here while a null is not automatically better.

So the master list stays as-is through WD-8. **The masters can only come off once WD-9 has assigned a
verdict to each of the third group**; strip them earlier and the choice gets made by whichever script
did the stripping. WD-18's release gate ("no DLC masters") still stands.

## How to reproduce

```powershell
. ".claude/config/tools.ps1"

# serialize (the pristine copy and the working tree were produced the same way)
& $Tools.spriggitCli serialize `
  --InputPath  "reference/mods/Triumvirate/Triumvirate - Mage Archetypes.esp" `
  --OutputPath "./src/Triumvirate/TriumvirateESP" `
  --GameRelease $Tools.spriggit.gameRelease `
  --PackageName $Tools.spriggit.packageName `
  --PackageVersion $Tools.spriggit.packageVersion

# round-trip
& $Tools.spriggitCli deserialize `
  --InputPath  "./src/Triumvirate/TriumvirateESP" `
  --OutputPath "<tmp>/Triumvirate - Mage Archetypes.esp" `
  --PackageName $Tools.spriggit.packageName `
  --PackageVersion $Tools.spriggit.packageVersion

# census: original vs rebuilt (the tool is generic; it lives in Apocalypse's tools/)
powershell -File src/Apocalypse/tools/verify-plugin-census.ps1 `
  "reference/mods/Triumvirate/Triumvirate - Mage Archetypes.esp" `
  "<tmp>/Triumvirate - Mage Archetypes.esp"
```
