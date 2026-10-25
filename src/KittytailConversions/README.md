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
| [Holy Templar Magic](https://www.nexusmods.com/skyrimspecialedition/mods/113360) (v1.5) | `Lightpower.esl` | `Holy Templar Magic - Enderal.esp` | **working in-game** (user-tested 2026-10-25) |
| [Ancient Blood Magic II](https://www.nexusmods.com/skyrimspecialedition/mods/115106) (v1.63) | `AncientBloodII.esl` | `Ancient Blood II - Enderal.esp` | **reported working in-game** (2026-10-25) |
| [Dark Hierophant Magic](https://www.nexusmods.com/skyrimspecialedition/mods/108499) (v1.43) | `Ghostlight.esl` | `Dark Hierophant - Enderal.esp` | builds and verifies; **not yet tested in-game** |

Shared code lives in `tools/KittytailCommon.ps1`: the cached FormKey index over `reference/base`,
the converter that collapses localized strings to English, and the list and block removers.

## Adding the next mod

1. Serialize the original plugin to `reference/mods/<Mod>/<Plugin>ESL/` (gitignored), with
   `--GameRelease EnderalSE`.
2. Run the kill-checks from `.claude/agents/skyrim-to-enderal-porter.md`: HEDR at offset 30, SKSE
   DLLs, BSA script names against `reference/base/EnderalScripts`, then resolve every external
   FormKey against `reference/base/Skyrim` + `EnderalFS` **and** the `*Real` vanilla trees.
3. Decide **substitute or copy** for the dead DLC references. Kittytail's mods lean heavily on
   Dawnguard's effects. Enderal's `Dawnguard.esm` is a stub, but **the assets ship with every
   Enderal SE install**, inside its copies of the SE `Skyrim - *.bsa` archives. So:
   - a handful of visuals with an obvious Enderal equivalent → **substitute**
     (`HolyTemplarMagic/tools/`, the simpler shape);
   - effects that *are* the mod (bats, gargoyles) → **copy the records** into the patch from
     `reference/base/*Real` (`AncientBloodII/tools/`). Run its verifier with `-GameData`, which
     proves every copied mesh and sound exists.
   Voice types are the exception: the engine finds voice files by plugin name, so a copied voice type
   is silent. Substitute an Enderal `Cr*Voice` instead.
4. **Pick a merchant hook no other release in this repo overrides.** Two patches here that override
   the same `<Merchant>_CustomMerchandise` would delete each other's stock. CLAUDE.md lists which
   release owns which; check the list with the `grep` there rather than trusting it. Apocalypse also
   owns the four `_00E_SpellBooksLoot*` lists, which is why no patch here injects into loot lists.
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

### Status

- **In-game: reported working** in a modlist on 2026-10-25, after a visit to Halda in the Sun Temple.
  Which of these the test covered was not recorded: the six spells' visuals, Consecrate Dead's ash
  pile and fever charge, Halda's stock, and a Sun Temple guard casting Hallowed Flare. The build side
  is verified: HEDR 1.70 / ESL / masters Skyrim + FS + Lightpower, all 524 FormKeys resolve.
- **Permissions.** Nexus blocked an automated read of the permissions tab. The patch redistributes
  nothing of Kittytail's, but confirm the terms before publishing anything derived.

## Ancient Blood Magic II (`AncientBloodII/`)

Fourteen tomes of blood and vampire magic: nine Elementalism (Destruction) spells, three Entropy
(Conjuration) summons and two lesser powers, Adept to Master. ~290 records, ESL, HEDR **1.70**, 8
`_AII_` scripts in its BSA with **no** collision with Enderal's script names.

```powershell
& $Tools.spriggitCli serialize --InputPath "<download>\AncientBloodII.esl" `
  --OutputPath reference\mods\AncientBloodII\AncientBloodIIESL --GameRelease EnderalSE `
  --PackageName Spriggit.Yaml.Skyrim --PackageVersion 0.40.0
powershell -File src\KittytailConversions\AncientBloodII\tools\01-generate-patch.ps1
powershell -File src\KittytailConversions\AncientBloodII\tools\verify-patch.ps1 -GameData "<Enderal>\Data"
```

The first run builds `reference/kittytail-formkey-index.tsv` (a few minutes). Pass `-Rebuild` to
`Get-KtFormKeyIndex` after re-serializing `reference/base`.

### What was broken in Enderal, and what the patch does

| Problem in the original | Evidence | Patch |
|---|---|---|
| **The mod's identity was built on Dawnguard records.** The bat swarms, the vampire-drain impact set, the bat projectiles and image space, the Stone Gargoyle's race abilities, body part data, class, combat style and footsteps, and the Eternal Legion's dragonbone first-person models and arrows are all Dawnguard records, with a few from Dragonborn. Enderal stubs every one | 189 of the mod's 291 records are reachable from the player's spells. They reach **63** dead references, resolved against `reference/base/*Real` | **70 records copied into the patch** (`0x810–0x855`, EditorIDs prefixed `_AIIE_`) from Bethesda's originals, de-localized to English, following their own references until the set closes. `verify-patch.ps1 -GameData` confirms all 45 of their mesh/sound paths ship with Enderal |
| Three vanilla records Enderal deleted are things the player sees: the tomes' inventory art (`HighPolyBookMQ103`), the Legion sword's enchantment, and the doom-atronach absorb effect that makes the Stone Gargoyle "resilient against magical threats" | absent from `reference/base/Skyrim` | Copied the same way |
| Dawnguard voice types on the gargoyle, the Herald of Torment and the Legion | the engine finds voice files by plugin name, so a copied voice type would be silent | `CrTrollVoice`, `CrChaurusVoice`, `CrDraugrVoice` |
| Sound templates pointing at Dawnguard's `AudioTemplateSkeletonMistman` and vanilla's deleted `AudioTemplateWerewolf` | Enderal has **no** `AudioTemplate*` NPCs | Template blocks removed from the 7 summons; they use their race's sounds |
| Dragonbone arrows at **25** damage on the Legion archers | Enderal's whole arrow ladder tops out at 10 (`_30E_AeternaArrow`) | 10 |
| **Distribution was dead.** The inject quest wrote 4 tomes into two vanilla loot lists that don't exist. A Castle Volkihar vendor chest held 3. All 14 drop from two bosses placed in the **Soul Cairn and Castle Volkihar courtyard**, which don't exist in Enderal either | `10FACA`, `04C165` absent; `DLC01SoulCairn`, `DLC1VampireCastleCourtyard` are Dawnguard worldspaces | All 14 tomes stocked by the **Fence in the Undercity barracks** (`_00E_UndercityHehler01`, 1,450-gold chest) through its empty `UndercityHehler01_CustomMerchandise 030306` hook. FS, EGO and Leveling Redone all keep that hook in the chest. The bosses are left alone: unreachable, harmless |
| The inject script also calls `Game.GetPlayer().AddPerk()`, and that perk is what lets The Eternal Legion summon three soldiers | `_aii_injectscript.psc` | **Not** stripped (the Holy Templar approach would have deleted the perk). Its two dead list properties point at an empty sink list `_AIIE_InjectSink 0x800`, so the script runs cleanly and the perk still lands |
| Mana costs up to **1038** (The Eternal Legion) | Enderal's ceiling is 310 | Per-tier ratio (Adept 0.49, Expert 0.33, Master 0.215): Adept 70–195, Expert 95–175, Master 115 / 225. Cascading Torment is Concentration, so it is set to **50/s**, Enderal's Expert Elementalism concentration ceiling (Flame Bite 40, Grounding 50). The two lesser powers stay at 150 / 300 |
| Tome prices 400–1800 | Enderal's 20–350 | 180–340 |
| One summon named **"Swordstress of Oblivion"** | Oblivion is an Elder Scrolls plane | "Swordstress of Ruin" |

No Arcane Fever: every heal in the mod is an Aimed drain or absorb, and Enderal's fever effect has no
precedent on Aimed spells (see CLAUDE.md). **No NPC distribution**: Kittytail's ini gives the spells
to vampires, and Enderal has no vampire, blood-mage or necromancer faction to aim at. The original
ini stays harmless.

### Status

- **In-game: reported working** on 2026-10-25. Which of the following the test covered was not
  recorded: the bat effects and swarms, the Stone Gargoyle (rendering, abilities, footsteps),
  the Herald of Torment, The Eternal Legion summoning three soldiers with working bows, the Fence's
  stock, and Bats Form / Harvest of Bats as lesser powers.
- **Copied records** are Bethesda's own data, unchanged apart from FormIDs and strings. They have
  never been tested *as records in a third-party ESL on Enderal*; the asset check proves the files
  exist, not that the effects look right.

## Dark Hierophant Magic (`DarkHierophant/`)

Ten tomes of radiant "searing light" magic, all Elementalism (Destruction), Adept to Master:
Penance, its two aura modes and the bound Penance Arm; Grand Cross, Retribution, Absolution and
Inhibition; Ordinance of Light and Mass Inhibition. ~140 records, ESL, HEDR **1.70**, 2 `_BL_`
scripts with **no** collision with Enderal's script names.

```powershell
& $Tools.spriggitCli serialize --InputPath "<download>\Ghostlight.esl" `
  --OutputPath reference\mods\DarkHierophant\GhostlightESL --GameRelease EnderalSE `
  --PackageName Spriggit.Yaml.Skyrim --PackageVersion 0.40.0
powershell -File src\KittytailConversions\DarkHierophant\tools\01-generate-patch.ps1
powershell -File src\KittytailConversions\DarkHierophant\tools\verify-patch.ps1 -GameData "<Enderal>\Data"
```

The cleanest of the three. The player's spells reach 119 of the mod's 142 records, and exactly
**one** dead reference: the tomes' inventory art. Kittytail built everything else from vanilla
records Enderal kept.

| Problem in the original | Evidence | Patch |
|---|---|---|
| **The tomes are crafted, at an altar Enderal does not have.** All ten are recipes at the *Ghostlight Altar*, a workbench placed only in the Forgotten Vale temple (`DLC1FalmerTemple01`, a Dawnguard cell). | the altar's only placement is in that cell | Sold instead by **Mirella Godshand** in Ark (`_00E_CapitalCity_Mirella`, a master mage trainer whose chest already stocks Enderal's spell-book list, 2,135 gold) through her empty `Mirella_CustomMerchandise 0302DF` hook. FS, EGO and Leveling Redone all keep that hook. The recipes, altar and temple cell are left alone: unreachable, harmless |
| Moving the altar into Enderal would not have fixed it. | The ten recipes need **20 filled black soul gems** and 20 ghost wrappings. Enderal contains **two** filled black soul gems (one container, one placed) and ghost wrappings only in 12 fixed containers, none in any leveled list | — |
| Mana costs up to **4,500** (Ordinance of Light). | Enderal's ceiling is 310 | Per-tier ratio (Adept 0.22, Expert 0.088, Master 0.055). The ratios are severe because the source is. Adept 55–105, Expert 80–115, Master 90 / 250. Absolution is Concentration: **50/s**, Enderal's Expert Elementalism concentration ceiling |
| Every tome priced at 100. | the recipe was the real cost | Authored per tier against the other two Kittytail patches: Adept 180, Expert 270, Master 340 |
| Tome inventory art is a Dawnguard static (`HighPolyDLC01DwemerBook01`). | Enderal ships its mesh, `clutter\books\book02\…\dlc01dwemerbook_highpoly.nif` | Copied into the patch (`0x810`) |

No strings needed renaming. No Arcane Fever: nothing in the mod heals. **No NPC distribution**:
Kittytail's ini gives the NPC variants to Gelebor and Vyrthur, two unique Dawnguard Snow Elves with
no Enderal counterpart, and the original ini stays harmless. Kittytail's `Ghostlight.ini` raises
the engine's particle cap (`[Particles] iMaxDesired=9750`). The engine reads it on Enderal as on
Skyrim, so leave it installed: the large light effects need it.

### Not yet established

- **In-game**: all ten spells (the Ordinance dome and the Inhibition restraints especially, since
  both are scripted), the bound Penance Arm one- and two-handed, Mirella's stock, and the copied
  inventory art.
