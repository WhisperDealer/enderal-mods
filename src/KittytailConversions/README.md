# Kittytail Conversions

Enderal SE conversions of **Kittytail's** Skyrim SE magic mods. One release, a FOMOD with one
option per converted mod: the player installs each original mod as Kittytail ships it, then ticks
the patch for every one they have.

Every conversion here is an **ESL override patch** that masters the original plugin, not a
replacement. Kittytail's plugins, meshes, sounds and scripts are never redistributed. That is a
deliberate choice: a patch needs nothing from the author, and a replacement is only legitimate with
modify-and-reupload permission. If a future Kittytail mod is form version 1.71, or needs records
*deleted* rather than overridden, that changes. Check the author's permissions before building a
replacement.

| Mod | Original plugin | Patch | Status |
|---|---|---|---|
| [Holy Templar Magic](https://www.nexusmods.com/skyrimspecialedition/mods/113360) (v1.5) | `Lightpower.esl` | `Holy Templar Magic - Enderal.esp` | builds and verifies; **not yet tested in-game** |

## Adding the next mod

1. Serialize the original plugin to `reference/mods/<Mod>/<Plugin>ESL/` (gitignored), with
   `--GameRelease EnderalSE`.
2. Run the kill-checks from `.claude/agents/skyrim-to-enderal-porter.md`: HEDR at offset 30, SKSE
   DLLs, BSA script names against `reference/base/EnderalScripts`, then resolve every external
   FormKey against `reference/base/Skyrim` + `EnderalFS` **and** the `*Real` vanilla trees.
3. Copy `HolyTemplarMagic/tools/` as the starting point: one generator that wipes and rebuilds the
   patch tree, plus one verifier.
4. **Pick a merchant hook no other release in this repo overrides.** Two patches here that override
   the same `<Merchant>_CustomMerchandise` would delete each other's stock. Holy Templar Magic owns
   `HaldaHammerschlag_CustomMerchandise`. Apocalypse and Triumvirate own 13 more, and Apocalypse also
   owns the four `_00E_SpellBooksLoot*` lists. That last point is why no patch here injects into loot lists.
5. Add the plugin and its assets to the `Kittytail Conversions` release in `build/manifest.json`,
   staged under `<Mod>/`, and add a `<plugin>` to `build/staging/Kittytail Conversions/fomod/ModuleConfig.xml`.

## Holy Templar Magic (`HolyTemplarMagic/`)

Six Light Magic (Restoration) spells: Consecrate Dead, Sun Shards, Sunlight Targe, Hallowed Flare,
Sanctuary, Wrath of the Heavens. ~100 records, ESL, HEDR **1.70**, 7 `_LIP_` scripts in its BSA
with **no** collision with Enderal's script names.

Regenerate and check:

```powershell
# once per upstream version: serialize Kittytail's plugin for lookup
& $Tools.spriggitCli serialize --InputPath "<download>\Lightpower.esl" `
  --OutputPath reference\mods\HolyTemplarMagic\LightpowerESL --GameRelease EnderalSE `
  --PackageName Spriggit.Yaml.Skyrim --PackageVersion 0.40.0
powershell -File src\KittytailConversions\HolyTemplarMagic\tools\01-generate-patch.ps1
powershell -File src\KittytailConversions\HolyTemplarMagic\tools\verify-patch.ps1
```

### What was broken in Enderal, and what the patch does

| Problem in the original | Evidence | Patch |
|---|---|---|
| Nearly every visual pointed into **Dawnguard**: 47 menu icons, 31 casting arts, 24 hit shaders, impact sets, script shader properties, two sounds. Enderal's `Dawnguard.esm` is a stub, so all of them resolved to nothing | `018F02` `DLC1MAGINVVampireBane`, `00F64A` `DLC1_VampireBaneHandFX`, `019C9D` `DLC1SunFireImpactFXShader`… resolved against `reference/base/DawnguardReal` | Repointed onto vanilla's **Turn Undead / Bane of the Undead** effects, which Enderal kept and uses for its own anti-undead spells (`BaneUndeadHandEffects 0E755B`, `MAGINVTurnUndead 1097CA`, `TurnUndeadFlamesFXS 0E7557`, `MAGTurnUnlImpactSet 04C6DA`). 7 Dawnguard image-space modifiers dropped (no counterpart) |
| Consecrate Dead attached `DLC2AshSpawnAshPile` (Dragonborn stub) to destroyed corpses | `_LIP_ConsecrateMGEF` property `AshPileObject` | `DefaultAshPile1 00001B` |
| **Distribution was dead.** Two `StartGameEnabled` quests `AddForm` into five vanilla tome lists plus `LItemVigilantBooks`; none exist in Enderal. Two tomes were placed in Fort Dawnguard's interior (`001DBA:Dawnguard.esm`), which doesn't exist here either | `09E2B4`, `0A272E`, `0DD648`, `10F652`, `0A2981`, `10BFF1` absent from `reference/base/Skyrim` + `EnderalFS` | Inject scripts removed from both quests. All six tomes stocked by **Halda Stronghand** in the Sun Temple through her empty `HaldaHammerschlag_CustomMerchandise 0302FF` hook. Her chest keeps that hook in FS, EGO and EGO Leveling Redone, so the stock survives whichever wins. The orphan Dawnguard cell is left alone: unreachable, harmless, and a patch cannot delete it |
| SPID ini targeted the Vigilants of Stendarr, Florentius, Gelebor, the Dawnguard | `0B3292`, `0x200F82D`, `0x201681B`, `0x2014217` all absent | New `Holy Templar Magic - Enderal_DISTR.ini` gives the same two spells to `SuntempleGuardFaction 0F76C0` (13 Sun Temple guards). The NPC spells' friendly-fire conditions now exclude the two Sun Temple factions instead of Vigilants and Dawnguard |
| Mana costs on Skyrim's scale (700 and 925 at Master, over Enderal's 310 ceiling) | Enderal band table in CLAUDE.md | Per-tier ratio: Adept 180→**80**, Expert 275→**110**, Master 700→**145**, 925→**195**. Novice 25 and Apprentice 41→40 already sat inside Enderal's bands |
| Tome prices on Skyrim's ladder (75–1000) | Enderal tomes run 20–350 | 55 / 140 / 150 / 285 / 300 / 300 |
| Consecrate Dead's heal (60 HP + Magicka + Stamina) was free healing magic | Every Enderal self-heal raises Arcane Fever | `_LIP_ConsecrateDeadHeal` pays **3** fever (20 HP/point, under Enderal's 26 burst ceiling) via `11A4B6` |

No strings needed renaming. The mod names no Elder Scrolls gods, and Enderal's own spells use
"Undead" (Turn Undead, Bane of the Undead).

### Not yet established

- **In-game.** The patch builds, the header reads HEDR 1.70 / ESL / masters Skyrim + FS +
  Lightpower, and all 524 emitted FormKeys resolve. Nobody has cast these spells in Enderal yet.
  Test the six spells' visuals, Consecrate Dead's ash pile and fever charge, Halda's stock (vendor
  stock is cached in the save, so use a new game or wait out the 2-day restock), and a Sun Temple
  guard casting Hallowed Flare.
- **Permissions.** Nexus blocked an automated read of the permissions tab. The patch redistributes
  nothing of Kittytail's, but confirm the terms before publishing anything derived.
