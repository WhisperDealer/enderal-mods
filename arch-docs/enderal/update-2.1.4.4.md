# Enderal SE 2.1.4.4 — what changed from 2.0.12.4

Measured **2026-11-25** by re-serializing the updated install
(`C:/Gaming/steamapps/common/Enderal Special Edition`, files dated 2026-10-27) and diffing it against
the 2.0.12.4 trees, which are kept under `reference/base-2.0.12.4/` for exactly this. Version string
from `Data/SKSE/Plugins/EnderalVersion.ini`. Everything here is **[verified]** from files unless
marked otherwise. **Nothing in this document has been verified in game.**

## The engine moved: SSE 1.5.97 → 1.7.104

| | 2.0.12.4 | 2.1.4.4 |
|---|---|---|
| `SkyrimSE.exe` | 1.5.97 | **1.7.104.0** |
| SKSE | `skse64_1_5_97.dll` | **`skse64_1_7_104.dll`**, loader 0.2.3.1 (SKSE **2.3.1**) |
| Address library | `version-1-5-97-0.bin` | `versionlib-1-7-104-0.bin` (plus 1.6.x / 1.7.99 files; the old 1.5.97 bin is a leftover) |
| Bundled SKSE plugins | — | `EnderalSE.dll`, `EnderalSteam.dll`, `EngineFixes.dll`, `CrashLogger.dll`, `SSEDisplayTweaks.dll`, `YesImSure.dll`, `SkyrimRedirector.dll` |

What this invalidates, in order of how much it costs:

- **Every SKSE plugin must now be a 1.7.104-capable build.** SKSE 2.3.1's own changelog says
  1.7.x *"need[s] to be rebuilt due to the address library change"*. A 1.5.97 "SE" DLL (exports
  `SKSEPlugin_Query` only) will **not** load. An AE build for 1.6.x may not either, until its author
  rebuilds. The old rule ("must be a 1.5.97 build") is now backwards. **[upstream]**
- **The `HEDR` 1.71 form-version ceiling is very probably gone.** 1.6+ engines load 1.71 plugins;
  that is what the ceiling was. **[unverified in game]** Prove it before relying on it: a 1.71 plugin
  enabled, `help <its record> 4` in the console. Keep authoring at 1.70 regardless.
- **BEES is irrelevant on 1.7.104.** It backports 1.71 support *to 1.5.97*.

## Plugins and load order

`%LOCALAPPDATA%\Enderal Special Edition\plugins.txt` is now **empty** (header comment only). The
stock plugins are listed in **`Skyrim.ccc`** in the game root:

```
ccBGSSSE001-Fish.esm         80 bytes, header only, masters Skyrim.esm
ccQDRSSE001-SurvivalMode.esl 66 bytes, header only
ccBGSSSE037-Curios.esl       66 bytes, header only
ccBGSSSE025-AdvDSGS.esm      80 bytes, header only, masters Skyrim.esm
_ResourcePack.esl            66 bytes, header only
Enderal - Forgotten Stories.esm
SkyUI_SE.esp
```

The five new plugins hold **zero records**, but their BSAs are real and large: AdvDSGS 1.09 GB,
`_ResourcePack.bsa` 0.92 GB, Fish 378 MB, Curios 112 MB, Survival 13 MB. That is the same
"records stubbed, assets shipped" shape as the DLC, so the assets are available to a mod that
supplies its own records. New `Skyrim - Textures7/8.bsa` too.

| Plugin | 2.0.12.4 | 2.1.4.4 |
|---|---|---|
| `Skyrim.esm` (base Enderal, author `mcarofano`) | 191,827,554 B · 86,635 records | **202,099,845 B · 86,723** |
| `Enderal - Forgotten Stories.esm` (`Niseam`, masters Skyrim + Update) | 13,868 records | **14,944** |
| `Update.esm` | 403 records | **860** · 176,683 B |
| `Dawnguard.esm` stub | 1 record | **3**: `DLC1NordRace`, `DLC1DawnguardFaction`, `DLC1VampireFaction` |
| `Dragonborn.esm` stub | 1 | **2**: `DLC2MiraakRace`, `DLC2DremoraRace` (81,662 B) |
| `HearthFires.esm` stub | 0 | 0 (still 80 B) |

All `HEDR` 1.70. Record counts are FormKey-bearing YAML files, so they run slightly under CLAUDE.md's
older counts, which were taken a different way.

## Record changes

Diffed by FormKey after **dropping non-English localized strings**. The new `Strings` folder adds
Czech, French, Italian, Japanese, Polish, Russian and Spanish, which alone touches ~21,000 base
records and is noise for patching.

| Tree | Added | Removed | Changed | EditorID changed |
|---|---|---|---|---|
| `Skyrim.esm` | 99 | 11 | **10,897** (Worldspaces 5607, Statics 1303, Npcs 823, Activators 594…) | 10 |
| FS | 1,387 (Statics 1293) | 311 (**Doors 171, Containers 125**) | **2,959** (Worldspaces 716, COBJ 589, Npcs 562, Books 286…) | 100 |
| `Update.esm` | 459 | 2 | 13 | 0 |

The FS removals are records FS **no longer overrides**; for `:Skyrim.esm` keys the base record still
stands. **No record that any mod in `src/` overrides or references was deleted.**

Notable individual changes:

- **Races renamed:** `013746` `NordRaceSkyrim` → `NordRace`, `013748` `RedguardRaceSkyrim` →
  `RedguardRace`. Same FormIDs, so references still resolve.
- **Ore veins** (`_00E_MineOre*`, 561 of them) now run `MineOreEnderal` instead of `MineOreScript`.
- **The NAVI moved:** FS's NavigationMeshInfoMap `000802:Enderal - Forgotten Stories.esm` is gone,
  and FS now carries a **null-FormKey NAVI**, the same as `Skyrim.esm`. So **FS no longer passes
  Spriggit 0.40.0's round-trip check** (`Malformed FormKey string: 89103`). Its tree is complete
  for lookup, but the old note that FS's NAVI is a real record and navmesh-adjacent patches are
  buildable no longer holds as written.
- **The 67 `<Merchant>_CustomMerchandise` hooks are unchanged**: still 67, all empty `UseAll`, and the
  merchant chests that held one in 2.0.12.4 still do.
- **The `PC<School><Tier>` spell-tome globals are still never set by any script**, so the
  tier-gating fix ported spell mods need still applies.
- **All of Enderal's distribution lists survive**: the spell-book vendor/loot lists,
  `00E_ScrollsLowChance` and the three blueprint lists.
- **Leveling still grants +8 max mana**, only when the player picks it
  (`_00e_epupdatefunctions.psc`, changed in other respects).

### Arcane Fever is now applied by the engine, with Mental Expert split into a second effect

The single biggest change for anyone **authoring** content against Enderal.

| | 2.0.12.4 | 2.1.4.4 (FS's winning copy) |
|---|---|---|
| `_00E_IncreaseArcaneFeverFFSelf` `11A4B6` archetype | `Script` | **ValueModifier on `LastFlattered`**, `Detrimental` |
| Its conditions | none | **target is the Player AND player does NOT have Mental Expert `069D07`** |
| `_00E_ArkanistenfieberBlitzheilungSCN` | applied the fever (`ModAV`), ×0.67 for Mental Expert | **only shows the message and the visuals**; the engine applies the value |
| Mental Expert discount | inside the script | **a new effect, `_00E_IncreaseArcaneFeverFFSelf_MentalExpert` `0493DF`**, conditioned on HAVING the perk |

Enderal's own heals now carry **both** effects, the second at 0.67× the first. `_07E_SpellFlashHeal`
pays `11A4B6` at 5 and `0493DF` at 3.35. **A spell that attaches only `11A4B6`, which was the
correct recipe before, now charges a Mental Expert player nothing.** New recipe: attach both, with
the magnitudes in Enderal's 1 : 0.67 ratio. `_00E_FS_AlchAddArcaneFever` was removed; potions use
`_00E_AlchArcaneFever` (`02F21D`), which does its own Mental Expert check.

## Scripts

`ScriptsEnderal.zip`: **4,808** `.psc` (was 5,029): **736 removed, 515 added, 2,829 changed**.

- **SKSE's Papyrus source is no longer shipped loose.** `Data/Source/Scripts` is gone. The
  workspace keeps the 74-file tree from 2.0.12.4 as `reference/base/SKSEScripts/` for compiling.
  SKSE's Papyrus API only grows, so it compiles; it may lack functions newer than SKSE 2.0.x.
- **Script names shared with vanilla: 448** (was 56). The `-i` order rule (Enderal first) matters far
  more than before.
- `_00E_`-prefixed scripts: 1,125 (was 1,258).
- **`_00E_Game_SkillmenuSC` is removed.** Its affinity logic is now `_00E_AffinityControl`
  (ReferenceAlias, *"a new affinity system that requires FS"*), and no `_00E_` script registers for
  `"Journal Menu"` any more. The character sheet is presumably drawn by `EnderalSE.dll`.
  **[inference — unverified]**
- **A new `_00E_BrawlControl`** (Quest) joins the `DGIntimidate*` quest scripts. The
  vanilla-named `dgintimidateplayerscript` / `dgintimidatealiasscript` DUMMY stubs are **no longer
  shipped** (not in the zip, not in `E - Misc.bsa`). Enderal's records attach the `_00E_`-prefixed
  versions, which extend `ReferenceAlias`, and **they already did in 2.0.12.4**. So the vanilla
  names were never on Enderal's live path, and a mod's BSA copy of them was dead code, not a
  revived brawl system.

## What this means for this repo's releases

| Release | Effect | Action |
|---|---|---|
| **Triumvirate** | Overrides (4 hooks) unchanged; 0 of 1,414 references died; generators and every verifier pass on the new reference; vendors' chests and hooks intact. Its loose `dgintimidate*` stubs now shadow nothing | None required. The stubs can be dropped in a later release |
| **Apocalypse** | **Its Arcane-Fever self-heals carry only `11A4B6`, so Mental Experts now pay no fever.** Its forwarded `00003C` `MQP01Home` worldspace changed in FS, so the forwarded copy is stale (guardrail 5). Its `dgintimidate*` stubs are inert | **Done** on `feat/apocalypse-enderal-2.1.4.4`: step 09 attaches `0493DF` at 0.67× (truncated, as Enderal does) to all 19 heals, and step 04 re-forwarded `00003C`. The five forwarded loot lists and six hooks were re-checked against 2.1.4.4 and are unchanged. The stubs were dropped |
| **Relentless Sword** | Forwarded `FlusshaimTemple` `015282` cell changed in FS (stale forward). Keyword `02F336` renamed `InvisibleDismantling` → `CraftingSmelterDismantling` | Re-forward the cell; check the keyword still means a smelter-dismantle recipe |
| **Biggie Traits**, **Zen Traits** | Only the race renames; nothing dead | None |
| **Every release with an SKSE dependency** | The dependency must now be a 1.7.104 build | Re-check each mod page's requirements |
