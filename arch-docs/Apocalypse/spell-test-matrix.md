# Apocalypse for Enderal -- spell test matrix

> **Generated** by `src/Apocalypse/tools/13-gen-test-matrix.ps1` from the Spriggit YAML. Do not
> hand-edit -- re-run it. Tick the boxes in a working copy or a PR comment.

Covers every obtainable item this release ships: **175 tome spells** and **144 scrolls**.
(`WB_SecretChest_Note` is a note, not a tome, and is excluded.)

## Before you start

**1. Find the plugin's load-order index.** It is not knowable from the repo. In the console:

```
help "Spell Tome: Alarm" 0
```

It prints something like `BOOK: 0703C517 'Spell Tome: Alarm'`. The leading **two hex digits** are
the index -- `07` here. **If this returns nothing, stop:** the plugin is not loading at all, which
on Enderal almost always means the `HEDR` form version is 1.71 rather than 1.70.

**2. Generate the batch files** with that index (this doc currently shows `XX`):

```
powershell -File src/Apocalypse/tools/13-gen-test-matrix.ps1 -ModIndex 07
```

Copy the resulting `apoc-*.txt` into Enderal's game root (beside `SkyrimSE.exe`) and run e.g.
`bat apoc-elementalism` in the console.

**3. Set up a test character.** `tgm` for god mode, `player.setav magicka 100000`,
`player.setlevel 50` so level-gated distribution is live, and `player.advskill destruction 100000`
(repeat per school) so skill-scaled magnitudes read true.

**4. Turn on the Papyrus log.** [verified 2026-08-07] Under MO2 the INI the game reads is the
**profile's**, not the one in `Documents` -- `settings.ini` has `LocalSettings=true`. So edit
`<modlist>\profiles\<profile>\Enderal.ini`, `[Papyrus]` section:

```
bEnableLogging=1
bEnableTrace=1
bEnableProfiling=0
```

`bEnableTrace` is the one that matters -- the lines you are looking for are `Debug.Trace` calls
and they are suppressed without it. Leave profiling off; it is a heavy frame cost.

The log then appears at

```
Documents\My Games\Skyrim Special Edition\Logs\Script\Papyrus.0.log
```

**Skyrim's folder, not Enderal's** -- the same quirk that puts the SKSE and crash logs there,
confirmed on this machine. Turn both settings back to `0` when you are done; a long session with
logging on produces a very large file.

## Must-pass gate

Nothing below is worth doing until these are green. Each is one launch.

> **PASSED in full on 2026-08-07**, over two sessions, against the build in this branch. The list
> stays here because it has to be re-run on any Apocalypse version bump or record change -- treat
> the ticks as a record of that run, not as permanently true.

- [x] Enderal starts with the rebuilt `.esp` installed and enabled.
- [x] No new crash log in `Documents\My Games\Skyrim Special Edition\SKSE\` -- **not** Enderal's
      folder, which only holds INIs and saves. If there is one, `PLUGINS: Total:` must be non-zero;
      `Total: 0` means the crash happened during file loading, so suspect the header, not records.
- [x] `help "Spell Tome: Alarm" 0` returns a hit (the plugin is not form-version-invisible).
- [x] **NAVI strip -- three specific places, not a general sweep.** See "Testing the NAVI strip"
      below. Ark and Riverville are *not* the test; the removed data never named a navmesh in
      either. *All three checked, no issues.*
- [x] **Brawl / intimidate dialogue behaves as base Enderal does** (it should do nothing special).
      This is the test of the loose `dgintimidate*` stubs. Confirm the mod sits *below* Apocalypse
      in MO2's file order, or its BSA wins and the stubs never load.
- [x] Start a new game, wait 90 seconds, then read the Papyrus log (see below). **Zero**
      `Cannot call AddForm() on a None object` errors. The four `APOCALYPSE DEBUG:` trace lines
      are expected and fine -- the script still runs, it just has nothing to iterate now.
      *Confirmed: 0 in the whole log, down from 685.*
- [x] Open Apocalypse's MCM and press **Repopulate**. Same expectation: traces yes, `AddForm`
      errors no. It runs the identical loop against its own six `_Replenish` FormLists, so it is
      a separate path from the automatic one and has to be checked separately.
- [x] All six merchants stock Apocalypse tomes (see the shop table below).
- [x] `player.additem XX1C1E71 5` ... `XX1C1E75 5` each yield Apocalypse tomes, and
      `player.additem XX1C1E76 10` yields Apocalypse scrolls. `additem` resolves a leveled
      list on the spot, so this proves loot distribution without waiting out `iDaysToRespawnVendor: 2`.

### Testing the NAVI strip

An earlier draft of this checklist said "walk around Ark and Riverville and watch the NPCs". That
was a guess, and resolving the removed record against Enderal shows it is the wrong test:

| What was removed | Could it affect Enderal? |
|---|---|
| 10 vanilla `MapInfos` entries | **No.** Every one parents to worldspace `00003C` -- Tamriel in Skyrim, **`MQP01Home`** in Enderal. And **0 of their 71 distinct FormIDs** is a navmesh Enderal defines |
| `PreferredPathing`, 6,312 refs | **Almost no.** Of 650 distinct FormIDs, **exactly 1** (`075393`) is a real Enderal navmesh |

So 720 of 721 distinct FormIDs in that record named navmeshes that do not exist here -- the engine
had nothing to apply them to. Ark and Riverville were never named at all. **Treat this as a
regression check, not a fix confirmation: the expected result everywhere is "no difference".**

The three places worth actually visiting, in order of value:

- [ ] **`coc WB_Entomb_Cell`** and **`coc WB_Dreamscape_Cell`** -- Apocalypse's own interior cells,
      whose three NAVI entries we **kept**. This is the only place the strip could have *broken*
      something, so it matters more than anything we removed. In each: cast an Entropy summon
      (`bat apoc-entropy` gives you the school), walk to the far side of the cell, and confirm the
      summon **walks** after you rather than standing still or teleporting. Entomb is also reachable
      naturally -- `player.addspell XX04581C`, cast it at an NPC, then cast again to free them; the
      target should walk out under its own power.
- [ ] **`cow Vyn -8 -3`** -- the single unnamed exterior cell whose navmesh (`075393`) the removed
      `PreferredPathing` block actually named. Summon something (`bat apoc-entropy` gives you the
      whole school) and confirm it follows you across the cell and over its boundaries.
- [ ] **`cow MQP01Home 0 0`** -- the worldspace all 10 removed entries parented to. Nothing of
      Enderal's should have changed here, but it is the one worldspace that was named.

**How to read "pathing works".** Standing NPCs prove nothing -- an idle NPC with no package looks
identical to one that cannot path. Use something that must move continuously:

- A **summon or follower** is the sharpest instrument. It re-paths constantly. Repeated
  teleport-to-catch-up, or a summon that spawns and then never closes distance, is the failure.
- **Combat** second: a hostile that will not approach, or circles without closing, is a navmesh
  problem rather than an AI one. `tcai` off and on again to confirm it is pathing and not fleeing.
- Walking into walls, refusing to cross a cell boundary, or sinking through the floor are the
  unambiguous signs.

### Log lines that are expected, not bugs

Seen on a clean run [verified 2026-08-07]. Do not chase these:

```
Error: Property MagicAllegianceFaction on script QF_WBA_Dominate_Quest_0200DBCB attached to
  WB_EnslaveTheWeak_Quest (..00DBCB) cannot be bound because <nullptr form> (0009E0C9) is not
  the right type
Error: Element of property WB_VendorChest on script wb_newmanager_quest_script attached to
  WB_NewManager_Quest (..08095C) ... <nullptr form> ... is not the right type          x4
```

Both are audit findings showing up at runtime: `09E0C9` is the missing allegiance faction behind
the Psionics simulacrum spells, and `WB_NewManager_Quest` binds six missing forms -- the College
of Winterhold ritual quests and books (`0D0755`, `0CD987`, `0FDE76`, `0FDE73`) and two vendor
chests (`098BAC`, `098B9F`) -- for content Enderal has no home for. All of them bind once at load
and cost nothing after.

One more, from actually casting Entomb:

```
Error:  (00051181): does not have 3d and cannot have an effect shader played on it.
stack:
  [ (..00AB5A)].EffectShader.Play() - "<native>"
  [WB_Entomb_Quest].wb_entomb_quest_script.ReleaseCurrentVictim()
  [ (FF00084A)].WB_Entomb_Activator_Script.OnLoad()
```

`ReleaseCurrentVictim()` plays a shader on the freed victim without checking `Is3DLoaded()` first,
so releasing someone whose cell is not loaded logs this once and carries on. Enai's own script,
unrelated to the conversion. Harmless -- the victim is still released.

## The shops

| `coc` target | Shop | Gold | Tier | Tomes | Hook |
|---|---|---:|---|---:|---|
| `CapitalCityMagierkram` | Ark -- Emberlord and Fireflash | 1800 | Master | 45 | `GabrielleFunkenfrst_CustomMerchandise` |
| `SuntempleAlchemy` | Sun Temple -- Torius Flameling | 1430 | Expert | 39 | `TuriousFlammentrunk_CustomMerchandise` |
| `UndercityBarracks2Barnabas` | Undercity -- Barnabas | 1050 | Adept (Mentalism/Entropy/Elementalism) | 19 | `Barnabas_CustomMerchandise` |
| -- | Ark -- Ora Stonehand | 980 | Adept (Psionics/Light Magic) | 14 | `OraSteinschlag_CustomMerchandise` |
| -- | Riverville -- Tarhutie | 630 | Apprentice | 28 | `Tarhutie_CustomMerchandise` |
| -- | Ark -- Milbert Foxhand | 530 | Novice | 15 | `MilbertFuchshand_CustomMerchandise` |

The three shops without a `coc` target are outdoor Ark and Riverville market stalls -- their chests
are placed in `CapitalCityMarketArea`, `CapitalCityStrangerArea` and `Vyn` rather than an interior.

The stock lives in each merchant's `*_CustomMerchandise` hook, not in the chest. Those are SureAI's
own empty `UseAll` LeveledItems -- one per merchant, already inside the chest -- so **this
conversion overrides no container record of any master**, and nothing it sells can be reverted by
an overhaul that rewrites the chest.

Vendor stock is cached in the save (`iDaysToRespawnVendor: 2`), so a merchant only re-rolls every
two in-game days. Sleeping three days is the reliable way to force a restock.

## Risk flags

Auto-derived from `verify-missing-refs.ps1`. A flag is **not** proof the spell is broken -- it says
this row is where to look first, and what to look at.

| Flag | Means | What to check |
|---|---|---|
| `DEAD-PERK` | An effect applies a vanilla perk Enderal does not have (`Disintegrate 0F3F0E`, `Deep Freeze 0F3933`, `Intense Flames 0F392E`, `0153D2`, Illusion `059B76`) | The spell's main effect should work; the rider will not fire. Confirm the base damage/effect still lands |
| `RESPITE-INERT` | Gated on `Respite 0581F9`, which exists in Enderal but is on no perk tree and not on the `Player` record | The Stamina half of a heal never fires. Health restore is the real number |
| `DEAD-SCRIPT-PROP` | A script property points at a missing form. Usually the harmless vanilla helpers (`SayOnHitByMagicEffectScript.TopicToSay`, `MG01FireEffectScript.MG01`) | Watch `Papyrus.0.log` while casting. Errors are expected to be noise; a spell that does nothing is not |
| `VANILLA-LIST` | Behaviour depends on a FormList with dangling entries | Does the spell find or affect anything at all |
| `SUMMON-GAP` | Summons an actor whose gear, perks or death item are missing | Does the summon appear, is it hostile, does it have a weapon |
| `MISSING-EFFECT` | An effect record the spell references does not exist | Almost certainly broken. Investigate before shipping |
| `NOT-SOLD` | Stocked by no merchant and in no leveled list -- unobtainable by design (the 15 Daedric/Dwemer summons) | Confirm it is genuinely unreachable, then skip the row |

The walk stops one hop past the spell's magic effects. Going further flagged a third more rows
without reaching anything new, so what lies deeper is listed by hand below instead.

### Suggested order

The must-pass gate is green, so what remains is the rows. They are not equally worth your time --
of the 319 rows:

| Do | Rows | Why |
|---|---:|---|
| **1. Flagged rows** | 54 | The audit says something they touch is missing. Highest chance of finding a real defect per cast |
| **2. The "Known gaps" list below** | ~18 | Locate Object's ten modes, Control Weather, the six simulacrum spells. Hand-found, so no flag marks them |
| **3. NOT-SOLD rows** | 21 | Not casts at all -- one merchant sweep confirms a player cannot reach them |
| **4. Everything else** | 244 | The bulk. Lowest yield per row; batch it by school |

**Leave Papyrus logging on for the whole run.** A spell that silently does nothing looks the same
as one that works if you are only watching the screen, and the log is what tells them apart. Cast
through a school with `bat apoc-<school>`, then afterwards:

```
grep -nE "Error|cannot|None" Papyrus.0.log | grep -i "WB_"
```

That turns 35 casts into one thing to read, and it catches the failures an eye test misses.

## Known gaps the flags do not reach

Found by reading the records, not by the scan. Test these deliberately.

- [ ] **Locate Object** (`XX00C143`, Mentalism Adept) is one spell that cycles ten categories, each
      driven by its own quest and inclusion/exclusion FormList. Those lists are vanilla base objects,
      and Enderal kept some and dropped others, so the modes do not stand or fall together:
  - [ ] **Ore vein** -- expected to WORK. Its inclusion list resolves to 561 live Activators,
        including Enderal's own `_00E_MineOreShadowsteel`.
  - [ ] **Plant** -- expected to WORK. Resolves to live `TreeFlora*` records, e.g.
        `TreeFloraVatyrsTongue01`.
  - [ ] **Potion** -- expected to FAIL. `WB_AlterationAlt_FormList_LocatePotion_Inclusion` is
        7 entries and **all 7 are missing** from Enderal. There is nothing it can match.
  - [ ] **Written text** -- partly dead: the word-wall FormList has a dangling entry.
  - [ ] Gold, container, door, key, soul gem, mineral, equipment -- unverified either way. Note
        which find something and which do not.
- [ ] **The `Locate Container` exclusion list is 68-for-68 dangling.** It is an *exclusion*, so the
      failure mode is over-matching (highlighting containers it should skip), not silence.
- [ ] **Control Weather** (Mentalism Master) backs up and restores the active weather through
      FormLists, and two of its script properties point at missing vanilla records
      (`MAGProjectileStormVar 101DAB`, `MQClearSkyFogSpell 10387F`). Enderal replaces every weather
      setting, so cast it, then confirm the weather **returns to normal** afterwards rather than
      sticking. Watch cutscene fades for a while after -- they are a known casualty of weather
      meddling in Enderal.
- [ ] **The Psionics simulacrum line.** Six effects run six different scripts
      (`WB_EvilTwin_Script`, `WB_EvilTwinAtTarget_Script`, `WB_SeidstoneHazard_Script`,
      `WB_PullFromEternity_Script`, `WB_Warband_Script`) but every one takes a
      `MagicAllegianceFaction` property pointing at `09E0C9`, which Enderal does not have. That
      covers **Pale Shadow, Evil Twin, Fold Into Ether, Seidstone, Pull From Eternity** and
      **Spectral Warband**. Check the summoned copy is **friendly and follows**, not hostile or
      inert. `Compelling Whispers` reads the same property from its proc effect -- check the
      charmed target actually fights for you.

## Elementalism -- *Destruction* (35 spells)

player.advskill destruction 100000 first, so magnitudes read at full skill.

### Novice (000) -- Ark - Milbert Foxhand

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Blaze** | `player.addspell XX085594` | FireAndForget / Aimed | 25 | 45 | Ark - Milbert Foxhand | Bolt of wildfire that deals 10 damage. | DEAD-SCRIPT-PROP |
| [ ] | **Crackle** | `player.addspell XX109653` | FireAndForget / Aimed | 25 | 50 | Ark - Milbert Foxhand | Does 10 damage to Health and Magicka. |  |
| [ ] | **Hailstone** | `player.addspell XX02E634` | FireAndForget / Aimed | 25 | 45 | Ark - Milbert Foxhand | An ice crystal that shatters for 15 frost damage to Health and Stamina. Direct hits bypass Frost Resist. |  |

### Apprentice (025) -- Riverville - Tarhutie

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Creeping Cold** | `player.addspell XX0279BD` | Concentration / Aimed | 27 | 90 | Riverville - Tarhutie | Deals 10 frost damage per second to Health and Stamina. |  |
| [ ] | **Dragon's Teeth** | `player.addspell XX024361` | FireAndForget / Aimed | 35 | 90 | Riverville - Tarhutie | Ignites all targets, doing 5 damage for 4 seconds. | DEAD-SCRIPT-PROP |
| [ ] | **Fracture** | `player.addspell XX0279C0` | FireAndForget / Aimed | 40 | 85 | Riverville - Tarhutie | A layer of thin ice deals 5 damage to Health and Stamina for 3 seconds. |  |
| [ ] | **Inferno** | `player.addspell XX022DAB` | FireAndForget | 125 | 90 | Riverville - Tarhutie | Attunes the caster to fire, equipping the Ember Bolt spell for up to 15 seconds. It deals 40 fire damage. |  |
| [ ] | **Rift Bolt** | `player.addspell XX0253C2` | FireAndForget / Aimed | 40 | 110 | Riverville - Tarhutie | Deals 20 shock damage to Health and Magicka and teleports the target backwards. |  |
| [ ] | **Thundercrack** | `player.addspell XX07C83B` | FireAndForget / Aimed | 30 | 90 | Riverville - Tarhutie | Deafening close range blast that deals 40 points of shock damage to Health and Magicka. |  |

### Adept (050) -- Undercity - Barnabas

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Bolide** | `player.addspell XX0294CD` | FireAndForget / Aimed | 60 | 200 | Undercity - Barnabas | Meteoric rock that deals 25 fire damage. It heats up as it travels, dealing up to x<5> damage based on distance. | DEAD-SCRIPT-PROP |
| [ ] | **Electrosphere** | `player.addspell XX001879` | FireAndForget / Aimed | 60 | 210 | Undercity - Barnabas | Slow moving ball lightning that strikes for 55 damage to Health and Magicka. |  |
| [ ] | **Frost Nova** | `player.addspell XX1347EE` | FireAndForget | 60 | 200 | Undercity - Barnabas | Radial frost explosion that deals 30 damage to Health and Stamina. Closer targets take up to x<2> damage. | DEAD-PERK |
| [ ] | **Ice Shiv** | `player.addspell XX024B44` | FireAndForget / Aimed | 65 | 210 | Undercity - Barnabas | Jagged shard that deals 30 frost damage to Health and Stamina. Targets hit from behind take x<3> damage. |  |
| [ ] | **Incendiary Flow** | `player.addspell XX085910` | FireAndForget / Aimed | 60 | 215 | Undercity - Barnabas | Creates a molten stream as it passes near terrain, dealing 20 fire damage for 10 seconds. | DEAD-SCRIPT-PROP |
| [ ] | **Multivortex** | `player.addspell XX1A4A4A` | FireAndForget | 90 | 180 | Undercity - Barnabas | All nearby friendly characters within <50> feet get random elemental Cloak spells that damage enemies. |  |
| [ ] | **Scattershock** | `player.addspell XX024E49` | Concentration / Aimed | 34 | 175 | Undercity - Barnabas | A stream of charged bolts that deal 30 damage to Health and half of that to Magicka per second. |  |

### Expert (075) -- Sun Temple - Torius Flameling

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Bombardment** | `player.addspell XX0294D4` | Concentration / Aimed | 49 | 270 | Sun Temple - Torius Flameling | A steady stream of exploding projectiles that deal 50 points of damage per second. | DEAD-SCRIPT-PROP |
| [ ] | **Hot Potato** | `player.addspell XX15E72F` | FireAndForget / Aimed | 90 | 260 | Sun Temple - Torius Flameling | Chaotic fire deals 10 damage for 5 seconds, then jumps to a random target within <100> feet (including the caster) up to <5> times. | DEAD-SCRIPT-PROP |
| [ ] | **Ice Prism** | `player.addspell XX15E73E` | Concentration / Aimed | 49 | 255 | Sun Temple - Torius Flameling | A stream of slow exploding ice spheres that deal 50 damage to Health and Stamina per second. |  |
| [ ] | **Lightning Strike** | `player.addspell XX002878` | FireAndForget / TargetLocation | 110 | 295 | Sun Temple - Torius Flameling | Lightning strikes the target location, dealing 60 shock damage to Health and Magicka. | DEAD-PERK |
| [ ] | **Ravaging Storm** | `player.addspell XX15E728` | FireAndForget | 130 | 260 | Sun Temple - Torius Flameling | For 10 seconds, strikes a random target (including the caster) every second, dealing 20 shock damage. |  |
| [ ] | **Scorching Hands** | `player.addspell XX02388C` | Concentration / Aimed | 49 | 295 | Sun Temple - Torius Flameling | Blasts targets in melee range, dealing 80 points of fire damage per second. | DEAD-SCRIPT-PROP |
| [ ] | **Shattering Crystal** | `player.addspell XX108627` | FireAndForget | 190 | 250 | Sun Temple - Torius Flameling | Creates a crystal of ice. Cast again to detonate the crystal for up to 270 damage to Health and Stamina, decreasing with distance. |  |
| [ ] | **Shock Nova** | `player.addspell XX00186D` | FireAndForget | 110 | 270 | Sun Temple - Torius Flameling | Radial shockwave that deals 40 damage to Health and Magicka. Those along the edge take up to x<2> damage. | DEAD-PERK |
| [ ] | **Sleet Storm** | `player.addspell XX027F2E` | Concentration / Aimed | 49 | 250 | Sun Temple - Torius Flameling | A rapid stream of ice shards that deal 60 damage to Health and Stamina per second. |  |

### Master (100) -- Ark - Emberlord & Fireflash

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Apocalypse** | `player.addspell XX023316` | FireAndForget / Aimed | 150 | 425 | Ark - Emberlord & Fireflash | Target is assaulted by elemental entities that appear nearby and cast x<4> damage Flames, Frostbite and Sparks spells. Lasts 10 seconds. |  |
| [ ] | **Cyclonic Rift** | `player.addspell XX02D068` | FireAndForget / Aimed | 120 | 360 | Ark - Emberlord & Fireflash | Creates a storm portal for 20 seconds. If two portals are active, those approaching either get warped across and take 50 shock damage to Health and Magicka. |  |
| [ ] | **Fingers of the Mountain** | `player.addspell XX0137BE` | FireAndForget | 125 | 395 | Ark - Emberlord & Fireflash | Electrifies nearby opponents for 30 seconds. When hit by a shock spell, lightning strikes for 120 damage to Health and Magicka. Only works outdoors. |  |
| [ ] | **Flamestrike** | `player.addspell XX02E0C0` | FireAndForget | 125 | 300 | Ark - Emberlord & Fireflash | A storm of <24> meteoric fireballs rains down from the heavens in a line extending from the caster, each exploding for 160 fire damage. Only works outdoors. |  |
| [ ] | **Forbidden Sun** | `player.addspell XX044264` | FireAndForget / Aimed | 115 | 400 | Ark - Emberlord & Fireflash | Giant ball of elemental fire that deals 100 points of damage in a wide area on impact. |  |
| [ ] | **Frozen Orb** | `player.addspell XX020A58` | FireAndForget / TargetLocation | 130 | 380 | Ark - Emberlord & Fireflash | Spinning orb that slowly travels to the target location and hovers there for <3> seconds, spraying ice spikes for 180 frost damage to Health and Stamina. |  |
| [ ] | **Howling Blast** | `player.addspell XX083A2C` | Concentration / Aimed | 68 | 415 | Ark - Emberlord & Fireflash | Casts a jet of icy wind that deals 45 damage per second to Health and Stamina. |  |
| [ ] | **Static Dome** | `player.addspell XX083A22` | FireAndForget / Aimed | 130 | 365 | Ark - Emberlord & Fireflash | Shock globe that does 25 shock damage to Health and Magicka and causes <50>% weakness to shock. |  |
| [ ] | **Twister** | `player.addspell XX02D5DB` | FireAndForget / Aimed | 125 | 355 | Ark - Emberlord & Fireflash | Creates a tornado at the target location. A direct hit sucks up a target, dealing 40 frost damage for 10 seconds. Nearby targets take half damage. Only works outdoors. |  |
| [ ] | **Volcano** | `player.addspell XX04733C` | FireAndForget / TargetLocation | 120 | 420 | Ark - Emberlord & Fireflash | Creates a volcanic eruption at the target location that spits out <8> lava bombs per second for <10> seconds, each dealing 40 fire damage. |  |

## Entropy -- *Conjuration* (35 spells)

player.advskill conjuration 100000 first, so magnitudes read at full skill.

### Novice (000) -- Ark - Milbert Foxhand

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Azure Reconstruction** | `player.addspell XX088694` | Concentration / TargetActor | 14 | 40 | Ark - Milbert Foxhand | Heal a conjured minion 10 points per second. | DEAD-SCRIPT-PROP |
| [ ] | **Bag of Rats** | `player.addspell XX16162D` | FireAndForget | 45 | 30 | Ark - Milbert Foxhand | Summons a Skeever for 30 seconds. | DEAD-REF |
| [ ] | **Consuming Power** | `player.addspell XX016F92` | FireAndForget / Aimed | 80 | 45 | Ark - Milbert Foxhand | Allied summoned or reanimated minion gains 75% extra attack damage for 10 seconds, then dies. |  |

### Apprentice (025) -- NOT SOLD / Riverville - Tarhutie

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Conjure Cat Totem** | `player.addspell XX027144` | FireAndForget / TargetLocation | 115 | 85 | Riverville - Tarhutie | Summons a ancient totem spirit for 60 seconds. It changes between warrior and cat form to heal. (Max. <1>) |  |
| [ ] | **Conjure Deadeye Captain** | `player.addspell XX037E17` | FireAndForget / TargetLocation | 120 | 95 | Riverville - Tarhutie | Summons a Deadeye Captain for 60 seconds. Activate a corpse to store it. Activate the Captain to dredge it up. |  |
| [ ] | **Conjure Entropic Churl** | `player.addspell XX012359` | FireAndForget / TargetLocation | 110 | 145 | - | Summons an Entropic Churl for 60 seconds. When killed, an Entropic Churl is summoned under control of the killer. | NOT-SOLD |
| [ ] | **Elemental Mark** | `player.addspell XX02CD7E` | FireAndForget / Aimed | 50 | 90 | - | Marks a target for 10 seconds. The mark detonates when the target is struck by a summoned or reanimated minion, dealing <30> magic damage in a <15> foot area. | NOT-SOLD |
| [ ] | **Power of the Master** | `player.addspell XX01857E` | FireAndForget | 130 | 170 | Riverville - Tarhutie | Casts the (beneficial self-targeted) spell in your left hand on all nearby summoned or reanimated minions. |  |
| [ ] | **Soul Cloak** | `player.addspell XX140B03` | FireAndForget | 100 | 95 | Riverville - Tarhutie | For 60 seconds, nearby enemies within 15 feet fill a soul gem on death. |  |

### Adept (050) -- NOT SOLD / Undercity - Barnabas

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Conjure Entropic Pit Fighter** | `player.addspell XX012364` | FireAndForget / TargetLocation | 105 | 170 | - | Summons an Entropic Pit Fighter for 60 seconds. It gains <25>% extra damage for each nearby enemy. | NOT-SOLD |
| [ ] | **Conjure Lich** | `player.addspell XX01236A` | FireAndForget / TargetLocation | 110 | 185 | Undercity - Barnabas | Summons a Lich for 60 seconds. Costs <Global=WB_Conjuration_ConjureLich_Global_Cost> points of charge from an equipped enchanted weapon to cast. |  |
| [ ] | **Conjure Sinistran Sorcerer** | `player.addspell XX1228A8` | FireAndForget / TargetLocation | 105 | 170 | - | Summons a Sinistran Sorcerer for 60 seconds. The caster takes <50> points of fire damage. | NOT-SOLD |
| [ ] | **Corpse Explosion** | `player.addspell XX1212EB` | FireAndForget / Aimed | 80 | 170 | Undercity - Barnabas | Violently releases the soul of a corpse, disintegrating it with a magical explosion that deals damage equal to <40>% of the corpse's maximum Health. |  |
| [ ] | **Entropic Crescent** | `player.addspell XX01A0A4` | FireAndForget / TargetActor | 125 | 205 | Undercity - Barnabas | Binds an Entropic Crescent to a summoned or raised humanoid for 120 seconds. Until discharged, the weapon deals <50> magic damage and staggers targets. |  |
| [ ] | **Gank** | `player.addspell XX1A1B79` | FireAndForget / Aimed | 110 | 205 | Undercity - Barnabas | Summons all nearby allied minions within <100> feet to attack the target. |  |
| [ ] | **Summoning Rune** | `player.addspell XX124EC5` | FireAndForget / TargetLocation | 90 | 150 | Undercity - Barnabas | Cast on a nearby surface, summons an opponent in front of you when triggered. |  |

### Expert (075) -- NOT SOLD / Sun Temple - Torius Flameling

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Conjure Avenging Wraith** | `player.addspell XX017A8E` | FireAndForget / TargetLocation | 105 | 305 | Sun Temple - Torius Flameling | Summons an Avenging Wraith for 60 seconds. Its stats are equal to <Global=WB_Conjuration_ConjureAvengingWraith_Global_Mult>% of those of the opponent that last killed it (<Global=WB_Conjuration_ConjureAvengingWraith_Global_Health> Health, <Global=WB_Conjuration_ConjureAvengingWraith_Global_Magicka> Magicka, <Global=WB_Conjuration_ConjureAvengingWraith_Global_Stamina> Stamina). |  |
| [ ] | **Conjure Entropic Champion** | `player.addspell XX0128DF` | FireAndForget / TargetLocation | 110 | 285 | - | Summons an Entropic Champion for 60 seconds. Its power attacks deal bonus damage and knock targets airborne. | NOT-SOLD |
| [ ] | **Conjure Entropic Honor Guard** | `player.addspell XX0133D6` | FireAndForget / TargetLocation | 115 | 295 | - | Summons an Entropic Honor Guard for 60 seconds. It reduces enemy magic resistance within 15 feet by <25>%. | NOT-SOLD |
| [ ] | **Conjure Entropic Mentor** | `player.addspell XX0C64B1` | FireAndForget / TargetLocation | 120 | 275 | - | Choose a magic school and summon an Entropic Mentor for 90 seconds. It does not fight, but offers training in the chosen school and the school improves <20>% faster. | NOT-SOLD |
| [ ] | **Conjure Herne** | `player.addspell XX0128E8` | FireAndForget / TargetLocation | 120 | 305 | Sun Temple - Torius Flameling | Summons a Herne for 60 seconds. It is accompanied by <3> Spirit Wolves under its command. |  |
| [ ] | **Conjure Sinistran Lord** | `player.addspell XX012370` | FireAndForget / TargetLocation | 105 | 270 | - | Summons a Sinistran Lord for 60 seconds. When summoned, drains all Magicka and has <200>% of this amount. It casts a deadly bolt that costs <150> Magicka. | NOT-SOLD |
| [ ] | **Monarch Mark** | `player.addspell XX161621` | FireAndForget / Aimed | 90 | 245 | Sun Temple - Torius Flameling | Marks a target for 10 seconds. The mark detonates when the target is struck by a summoned or reanimated minion, dealing <60> magic damage in a <25> foot area. |  |
| [ ] | **Oathbound Guardian** | `player.addspell XX018AE7` | FireAndForget / TargetActor | 125 | 330 | Sun Temple - Torius Flameling | Living ally is protected by an Oathbound Guardian under his or her command for 60 seconds. |  |
| [ ] | **Six Demon Bag** | `player.addspell XX161619` | FireAndForget | 120 | 240 | - | Summons a Bound Churl for 60 seconds. | NOT-SOLD |

### Master (100) -- NOT SOLD / Ark - Emberlord & Fireflash

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Banish Living** | `player.addspell XX092B91` | FireAndForget / TargetActor | 300 | 440 | Ark - Emberlord & Fireflash | Banish a living creature into the Sea of Eventualities. Items (except quest items) are lost forever. (Creatures banished: <Global=WB_Conjuration_BanishLiving_Global_Counter>) | DEAD-SCRIPT-PROP |
| [ ] | **Conjure Battlemage** | `player.addspell XX08868C` | FireAndForget / TargetLocation | 230 | 390 | Ark - Emberlord & Fireflash | Call upon the services of a lower ranking Battlemage for 180 seconds. Activate to purchase permanent upgrades. |  |
| [ ] | **Conjure Bear Totem** | `player.addspell XX04734D` | FireAndForget / TargetLocation | 280 | 365 | Ark - Emberlord & Fireflash | Summons a ancient totem spirit for 240 seconds. It changes between hunter and bear form to heal. (Max. <1>) |  |
| [ ] | **Conjure Craftlord** | `player.addspell XX123E5B` | FireAndForget / TargetLocation | 250 | 370 | Ark - Emberlord & Fireflash | Calls a Starling sage to Vyn for 180 seconds. Modify its stats with the <Reconfigure Craftlord> spell. |  |
| [ ] | **Conjure Entropic Assassin** | `player.addspell XX0128F7` | FireAndForget / TargetLocation | 230 | 335 | Ark - Emberlord & Fireflash | Summons an Entropic Assassin for 180 seconds. Its arrows reduce targets below <Global=WB_Conjuration_ConjureDremoraAssassin_Global_Health> Health to <1> for <10> seconds. | SUMMON-GAP |
| [ ] | **Conjure Kyrkrim** | `player.addspell XX100032` | FireAndForget / TargetLocation | 135 | 425 | - | Summons the spirit wolf mount Kyrkrim for 180 seconds. When ridden, low level creatures and people flee in terror. | NOT-SOLD |
| [ ] | **Conjure Lord of Bindings** | `player.addspell XX019B2D` | FireAndForget / TargetLocation | 240 | 335 | - | Summons a Lord of Bindings for 180 seconds. It does not fight, but rapidly summons Churls in combat. | NOT-SOLD |
| [ ] | **Conjure Nether Lich** | `player.addspell XX0128FA` | FireAndForget / TargetLocation | 275 | 405 | Ark - Emberlord & Fireflash | Summons a Nether Lich for 180 seconds. It inflicts a damaging disease, lowers skill levels and raises the dead. |  |
| [ ] | **Conjure Weeping Shade** | `player.addspell XX08FDED` | FireAndForget / TargetLocation | 110 | 415 | - | Summons a Weeping Shade for 120 seconds. It steals large amounts of Health with its magical attacks, but turns to inert and brittle stone when an enemy looks at it. | SUMMON-GAP<br>DEAD-PERK<br>NOT-SOLD |
| [ ] | **Necrowitch** | `player.addspell XX016F95` | FireAndForget | 130 | 380 | Ark - Emberlord & Fireflash | Summons the corpse of an ancient sorceress to reanimate for 600 seconds and teaches her the (ranged, touch or cloak) elemental spell in your left hand. | DEAD-SCRIPT-PROP |

## Light Magic -- *Restoration* (35 spells)

player.advskill restoration 100000 first, so magnitudes read at full skill.

### Novice (000) -- Ark - Milbert Foxhand

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Bone Spirit** | `player.addspell XX03527C` | FireAndForget / Aimed | 40 | 50 | Ark - Milbert Foxhand | Casts a vengeful spirit that homes in on the target and explodes for 50 points of magic damage to undead. |  |
| [ ] | **Circle of Strength** | `player.addspell XX036A05` | FireAndForget | 50 | 50 | Ark - Milbert Foxhand | Steals 6 points of Stamina per second from hostiles inside the circle. |  |
| [ ] | **Wild Healing** | `player.addspell XX082483` | FireAndForget | 65 | 45 | Ark - Milbert Foxhand | Heals the caster 40 points, then heals a random target within range 40 points. |  |

### Apprentice (025) -- Riverville - Tarhutie

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Lamb of Irlanda** | `player.addspell XX036A03` | FireAndForget / Aimed | 60 | 90 | Riverville - Tarhutie | For 30 seconds, you gain <35>% of the Health the target loses. | RESPITE-INERT |
| [ ] | **Leech Seed** | `player.addspell XX13E4FD` | FireAndForget / Aimed | 40 | 120 | Riverville - Tarhutie | Infests a living target with a poison spore for 10 seconds. When the caster falls below full Health, the spore absorbs 5 points of Health per second. |  |
| [ ] | **Mystic Wind** | `player.addspell XX0E8B77` | FireAndForget | 68 | 90 | Riverville - Tarhutie | For 10 seconds, restores 5 points of Magicka per second while the caster is sprinting. |  |
| [ ] | **Necroplague** | `player.addspell XX034D12` | FireAndForget / Aimed | 70 | 160 | Riverville - Tarhutie | Infects a corpse with a spreading virus that deals 9 disease damage for 30 seconds to nonmechanical foes. |  |
| [ ] | **Slay Living** | `player.addspell XX003E0F` | FireAndForget / TargetActor | 65 | 85 | Riverville - Tarhutie | Kills a living target in melee range with <25>% or less remaining health. |  |
| [ ] | **Welling Blood** | `player.addspell XX01FCD9` | FireAndForget / Aimed | 50 | 95 | Riverville - Tarhutie | Curses a living target. If the target loses at least <Global=WB_Restoration_WellingBlood_Global_Threshold>% of its maximum Health within 8 seconds, it dies. |  |

### Adept (050) -- Ark - Ora Stonehand

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Channel Energies** | `player.addspell XX01FCCE` | FireAndForget / Aimed | 135 | 170 | Ark - Ora Stonehand | Casts the (beneficial self-targeted) spell in the caster's left hand on the target. | DEAD-SCRIPT-PROP |
| [ ] | **Circle of the Moons** | `player.addspell XX111CFB` | FireAndForget | 60 | 165 | Ark - Ora Stonehand | Steals 8 points of Magicka per second from hostiles inside the circle. |  |
| [ ] | **Dust in the Clockwork** | `player.addspell XX1A4A46` | FireAndForget / Aimed | 80 | 195 | Ark - Ora Stonehand | Induces fungal growth in mechanical targets, dealing 5 pure damage for 10 seconds. |  |
| [ ] | **Finger of Death** | `player.addspell XX035452` | FireAndForget / TargetActor | 70 | 190 | Ark - Ora Stonehand | Blast of death magic that damages a living target equal to its Health but the caster takes <Global=WB_Restoration_FingerOfDeath_Global_Percentage>% damage. If this would kill the caster, damage to the target is reduced. |  |
| [ ] | **Horrid Wilting** | `player.addspell XX012214` | FireAndForget / Aimed | 60 | 170 | Ark - Ora Stonehand | Desiccates living targets, inflicting 12 disease damage per second for 10 seconds. |  |
| [ ] | **Ruin** | `player.addspell XX0159D8` | FireAndForget / Aimed | 70 | 230 | Ark - Ora Stonehand | Weakens an enemy, reducing all skills by 15 points for 120 seconds. |  |
| [ ] | **Sealed Resolve** | `player.addspell XX01FCCA` | FireAndForget | 70 | 170 | Ark - Ora Stonehand | Places a seal upon the caster for 15 seconds. Losing <50>% of your current Health unlocks the seal, halving incoming damage for its remaining duration. |  |

### Expert (075) -- Sun Temple - Torius Flameling

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Blood Boil** | `player.addspell XX044D44` | Concentration | 49 | 300 | Sun Temple - Torius Flameling | Concentrate to summon whirling blood that harms foes within 15 feet and the caster. |  |
| [ ] | **Decompose** | `player.addspell XX01F1FB` | FireAndForget / Aimed | 95 | 280 | Sun Temple - Torius Flameling | Curses a nonmechanical target for 60 seconds, allowing allies within 10 feet of the target to absorb <15> points of Health per second from the target. |  |
| [ ] | **Healing Blossom** | `player.addspell XX05F74D` | FireAndForget | 110 | 280 | Sun Temple - Torius Flameling | Activates 10 seconds after casting and lasts 10 seconds. |  |
| [ ] | **Nature's Balance** | `player.addspell XX0012DC` | FireAndForget / Aimed | 225 | 315 | Sun Temple - Torius Flameling | Swaps the Health percentages of the caster and a living target. |  |
| [ ] | **Poisoned Chalice** | `player.addspell XX15E721` | FireAndForget / Aimed | 75 | 265 | Sun Temple - Torius Flameling | For 30 seconds, whenever the target gains Health, the gained Health is transferred to the caster instead. | RESPITE-INERT |
| [ ] | **Resurgence** | `player.addspell XX01E701` | FireAndForget | 125 | 280 | Sun Temple - Torius Flameling | For 15 seconds, heals 20 points per second when the caster falls below <50>% Health. |  |
| [ ] | **Serpent's Scale** | `player.addspell XX15E71A` | FireAndForget | 120 | 285 | Sun Temple - Torius Flameling | Take <10> disease damage per second for 15 seconds. Whenever the caster blocks a melee attack, the attacker takes 10 disease damage per second. |  |
| [ ] | **Tree Rings** | `player.addspell XX13DA15` | FireAndForget | 100 | 275 | Sun Temple - Torius Flameling | Caster receives <10> layers of tough plant skin, each increasing maximum Health by <15> points. Layers gradually fall off over the course of 30 seconds. |  |
| [ ] | **Willpower** | `player.addspell XX15E71D` | FireAndForget | 49 | 285 | Sun Temple - Torius Flameling | Transfers all Stamina to Magicka. |  |

### Master (100) -- Ark - Emberlord & Fireflash

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Bloodseeker** | `player.addspell XX048398` | FireAndForget / Aimed | 115 | 505 | Ark - Emberlord & Fireflash | Casts a homing flare at a target. When it reaches the target, it heals or deals magic damage equal to <Global=WB_Restoration_Bloodseeker_Global_Mult>% of the Health the target gained or lost while it was in flight. |  |
| [ ] | **Breath of Tyr** | `player.addspell XX12B063` | Concentration | 68 | 380 | Ark - Emberlord & Fireflash | Accumulate 50 points of divine energy per second while concentrating. After you stop concentrating, the energy is converted into healing. |  |
| [ ] | **Circle of Death** | `player.addspell XX01220F` | FireAndForget | 130 | 385 | Ark - Emberlord & Fireflash | Circle instantly kills living targets below <40>% Health. |  |
| [ ] | **Dust To Dust** | `player.addspell XX11122C` | FireAndForget | 240 | 350 | Ark - Emberlord & Fireflash | Destroys all undead below <40>% health. |  |
| [ ] | **Infinite Light** | `player.addspell XX02F66E` | Concentration / Aimed | 68 | 485 | Ark - Emberlord & Fireflash | Stream of healing energy that diffracts between targets, healing 150 points per second. | DEAD-SCRIPT-PROP |
| [ ] | **King's Heart** | `player.addspell XX033CCA` | FireAndForget | 120 | 325 | Ark - Emberlord & Fireflash | A holy spark slowly follows the caster for 60 seconds. When it is nearby, it fortifies most skills by <15>% and heals 15 points per second. |  |
| [ ] | **Life's Finale** | `player.addspell XX083FA8` | FireAndForget | 195 | 450 | Ark - Emberlord & Fireflash | Corrupts nearby living targets and the caster for 20 seconds. |  |
| [ ] | **Malphas' Wrath** | `player.addspell XX0362C7` | FireAndForget | 225 | 340 | Ark - Emberlord & Fireflash | Attunes the caster to light, equipping the Starstorm spell for up to 30 seconds. This spell deals 100 damage per second to undead while the caster concentrates. |  |
| [ ] | **Transcendence** | `player.addspell XX086B2E` | FireAndForget | 240 | 395 | Ark - Emberlord & Fireflash | Blaze with holy energy, replenishing 15 Magicka per second. |  |
| [ ] | **Worm Shroud** | `player.addspell XX12CB8D` | FireAndForget | 275 | 315 | Ark - Emberlord & Fireflash | For 120 seconds, destroys corpses within 20 feet, improving Restoration spells by <5>% for <30> seconds. This effect refreshes and stacks up to <10> times. |  |

## Mentalism -- *Alteration* (35 spells)

player.advskill alteration 100000 first, so magnitudes read at full skill.

### Novice (000) -- Ark - Milbert Foxhand

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Alarm** | `player.addspell XX0064A2` | FireAndForget | 60 | 35 | Ark - Milbert Foxhand | Alerts the caster whenever an enemy crosses the 150 foot perimeter for 120 seconds. |  |
| [ ] | **Longstride** | `player.addspell XX00541E` | Concentration | 14 | 35 | Ark - Milbert Foxhand | While concentrating, grants 20% movement speed and <25> carry weight, tripled when out of combat. |  |
| [ ] | **Prepare for Adventure** | `player.addspell XX007FFD` | FireAndForget | 40 | 40 | Ark - Milbert Foxhand | Creates a set of basic enchanted mage items (robes, circlet, boots, Destruction staff) in your inventory for 180 seconds. |  |

### Apprentice (025) -- Riverville - Tarhutie

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Baledor's Recital** | `player.addspell XX006FA6` | FireAndForget | 70 | 110 | Riverville - Tarhutie | Stores the (beneficial self-targeted non-concentration) spell in your left hand and casts it for no cost whenever you enter combat. Empty left hand to reset. |  |
| [ ] | **Drop Zone** | `player.addspell XX00B646` | FireAndForget / TargetLocation | 35 | 95 | Riverville - Tarhutie | Creates a ring of cushioning magic at the target location. The caster takes no damage when falling into the ring. |  |
| [ ] | **Fins of Kilé** | `player.addspell XX007A94` | FireAndForget | 80 | 130 | Riverville - Tarhutie | You swim 100% faster for 60 seconds. |  |
| [ ] | **Perilous Path** | `player.addspell XX0803F2` | FireAndForget / Aimed | 55 | 105 | Riverville - Tarhutie | Lay down a spike barrier that lasts 10 seconds and randomly staggers enemies moving through the spikes. |  |
| [ ] | **Raise Wall** | `player.addspell XX00CC14` | Concentration | 27 | 105 | Riverville - Tarhutie | Concentrate to summon a wall from the earth that blocks passage. |  |
| [ ] | **Wither** | `player.addspell XX12649C` | FireAndForget / Aimed | 45 | 80 | Riverville - Tarhutie | Reduces movement speed and attack damage by 5% per second, up to <50>%. Lasts 20 seconds. |  |

### Adept (050) -- Undercity - Barnabas

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Esara's Memory** | `player.addspell XX1A1B71` | FireAndForget | 135 | 160 | Undercity - Barnabas | Stores the (beneficial self-targeted non-concentration) spell in your left hand and casts it for no cost with x<2> duration whenever you enter combat. Empty left hand to reset. |  |
| [ ] | **Girathû's Prison** | `player.addspell XX002E25` | FireAndForget / Aimed | 85 | 150 | Undercity - Barnabas | Materializes a cage to trap target humanoid for 10 seconds. |  |
| [ ] | **Locate Object** | `player.addspell XX00C143` | FireAndForget | 95 | 175 | Undercity - Barnabas | Illuminates the nearest ore vein, gold, container, door, key, soul gem, written text, potion, gem, ingot or equipment of your choice for 20 seconds. | DEAD-SCRIPT-PROP |
| [ ] | **Spell Twine** | `player.addspell XX006A30` | FireAndForget | 49 | 200 | Undercity - Barnabas | Bind a chosen effect to the spell in your left hand. It is triggered whenever the spell is cast. Up to <3> spells. Empty left hand to reset. |  |
| [ ] | **Strength of Earth** | `player.addspell XX00D6F5` | Concentration | 34 | 180 | Undercity - Barnabas | Concentrate to deal <40>% more attack damage with your other hand. Release after attacking to stagger nearby foes. |  |
| [ ] | **Thundering Hooves** | `player.addspell XX007A8C` | FireAndForget | 70 | 220 | Undercity - Barnabas | For 180 seconds, your mount is 30% faster, regenerates Stamina and can swim upwards to run on water. Nearby allies riding a mount within 30 feet also benefit. |  |
| [ ] | **Undermine** | `player.addspell XX002E31` | FireAndForget / Aimed | 75 | 185 | Undercity - Barnabas | For 30 seconds, shifting earth causes the target to lose its balance when swinging a melee weapon, staggering the target and draining <30> points of Stamina. |  |

### Expert (075) -- Sun Temple - Torius Flameling

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Deep Storage** | `player.addspell XX003907` | FireAndForget | 100 | 300 | Sun Temple - Torius Flameling | Grants access to an infinite underground storage space. |  |
| [ ] | **Detonate Lock** | `player.addspell XX00AB69` | FireAndForget / Aimed | 180 | 350 | Sun Temple - Torius Flameling | Open a lock with a level <25> points or more below your Alteration skill with a shockwave that may alert others. |  |
| [ ] | **Entomb** | `player.addspell XX04581C` | FireAndForget / Aimed | 140 | 290 | Sun Temple - Torius Flameling | Buries a target permanently, or frees a buried target. Only one victim may be buried at a time. |  |
| [ ] | **Fabricate Object** | `player.addspell XX003902` | FireAndForget | 185 | 305 | Sun Temple - Torius Flameling | The caster creates a bridge, bed or crafting station of his or her choice. The object disappears after 120 seconds or when entering combat. |  |
| [ ] | **Grace of Water** | `player.addspell XX0AAF9E` | Concentration | 49 | 235 | Sun Temple - Torius Flameling | Concentrate to become ethereal. Release after attacking to briefly slow time. |  |
| [ ] | **Instant Forest** | `player.addspell XX0AE5B7` | Concentration / TargetLocation | 49 | 240 | Sun Temple - Torius Flameling | Concentrate to raise a row of trees where the caster points. They block passage, but the caster can destroy them. |  |
| [ ] | **Knowledge is Power** | `player.addspell XX00CC16` | FireAndForget | 140 | 280 | Sun Temple - Torius Flameling | Copies the (non-concentration) spell in your left hand, granting a power that casts this spell once a day for no cost. Empty left hand to reset. |  |
| [ ] | **Spell Sentinel** | `player.addspell XX161610` | FireAndForget | 120 | 240 | Sun Temple - Torius Flameling | Stores the (beneficial self-targeted non-concentration) spell in your left hand and casts it for no cost every <30> seconds in combat. Empty left hand to reset. |  |
| [ ] | **Tumble Magnet** | `player.addspell XX00A5EB` | FireAndForget / Aimed | 95 | 280 | Sun Temple - Torius Flameling | Magnetic artifact that exists for 20 seconds, randomly pulling nearby enemies to the center. |  |

### Master (100) -- Ark - Emberlord & Fireflash

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Acceleration Rune** | `player.addspell XX124EC9` | FireAndForget / TargetLocation | 240 | 350 | Ark - Emberlord & Fireflash | Cast on a nearby surface, launches enemies in the direction they are moving. |  |
| [ ] | **Battletide** | `player.addspell XX05ECEE` | FireAndForget | 135 | 395 | Ark - Emberlord & Fireflash | Steals 80 points of armor rating from each nearby target for 30 seconds. The caster gains the total amount stolen. |  |
| [ ] | **Control Weather** | `player.addspell XX084A9C` | FireAndForget | 240 | 395 | Ark - Emberlord & Fireflash | Temporarily summon the weather of your choice. | DEAD-SCRIPT-PROP |
| [ ] | **Eventuality Grimoire** | `player.addspell XX00C13D` | FireAndForget | 135 | 405 | Ark - Emberlord & Fireflash | Creates a hovering spell tome of the (projectile, non-concentration) spell in your left hand. It repeatedly casts the spell in the direction you are facing for 30 seconds. |  |
| [ ] | **Milestones** | `player.addspell XX0A59D5` | FireAndForget / TargetLocation | 265 | 405 | Ark - Emberlord & Fireflash | Place up to <5> teleportation anchors and teleport freely between them. |  |
| [ ] | **Talons of Vyn** | `player.addspell XX07FE79` | FireAndForget | 120 | 400 | Ark - Emberlord & Fireflash | Whenever an enemy in the area is staggered, a spike of rock erupts from the ground, tossing the target and dealing 150 Stamina damage. Lasts 60 seconds. |  |
| [ ] | **Telekinetic Gauntlet** | `player.addspell XX002E2A` | FireAndForget / Aimed | 110 | 370 | Ark - Emberlord & Fireflash | Telekinetically holds a target in front of the caster for 10 seconds. |  |
| [ ] | **Thaumaturgic Maelstrom** | `player.addspell XX086B60` | FireAndForget | 120 | 350 | Ark - Emberlord & Fireflash | Nearby foes within 20 feet get <5>% weakness to magic per second, up to <100>%. Lasts 120 seconds. |  |
| [ ] | **Thrumming Stone** | `player.addspell XX124EC7` | FireAndForget / TargetLocation | 120 | 300 | Ark - Emberlord & Fireflash | Magical vibrating rock that emits a tremor every <8> seconds, staggering enemies and inflicting 40% weakness to magic for 2 seconds. Emits <5> pulses. |  |
| [ ] | **Wind Running** | `player.addspell XX005F2B` | FireAndForget | 145 | 420 | Ark - Emberlord & Fireflash | Grants the ability to sprint across thin air and immunity to fall damage for 30 seconds. |  |

## Psionics -- *Illusion* (35 spells)

player.advskill illusion 100000 first, so magnitudes read at full skill.

### Novice (000) -- Ark - Milbert Foxhand

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Dispel Magic** | `player.addspell XX00BB25` | FireAndForget | 45 | 35 | Ark - Milbert Foxhand | Dispels all magical effects (except diseases) on friends and foes. |  |
| [ ] | **Pale Shadow** | `player.addspell XX08558A` | FireAndForget / Aimed | 30 | 55 | Ark - Milbert Foxhand | Target enemy is attacked by its own image for 10 seconds. It deals the same damage but has <1> Health. | DEAD-SCRIPT-PROP |
| [ ] | **Silvery Barbs** | `player.addspell XX15B843` | FireAndForget / Aimed | 35 | 40 | Ark - Milbert Foxhand | Curses a target for 20 seconds. When the target casts a spell, they get <10>% weakness to magic and you get <10>% magic resistance. This effect stacks. |  |

### Apprentice (025) -- Riverville - Tarhutie

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Backlash** | `player.addspell XX1132DA` | FireAndForget / Aimed | 27 | 95 | Riverville - Tarhutie | Interrupts target spellcaster. If a spell is interrupted, the target is hit by their own offensive spells, while non-offensive spells are cast on you. |  |
| [ ] | **Curse of the Silent** | `player.addspell XX017509` | FireAndForget / Aimed | 70 | 120 | Riverville - Tarhutie | Drains 8 points of Magicka per second for 30 seconds or until the target successfully casts a spell. |  |
| [ ] | **Illusory Flames** | `player.addspell XX03682F` | Concentration / Aimed | 27 | 75 | Riverville - Tarhutie | Concentrate to deal <30>% of their current Health as temporary damage that wears off after 2 seconds. |  |
| [ ] | **Mind Vision** | `player.addspell XX0378A9` | FireAndForget / TargetActor | 65 | 85 | Riverville - Tarhutie | See through the eyes of target creature or humanoid for 10 seconds. Sheathe to cancel. | DEAD-PERK |
| [ ] | **Shared Trauma** | `player.addspell XX00C0AC` | FireAndForget / Aimed | 45 | 100 | Riverville - Tarhutie | For 10 seconds, when target creature or humanoid loses Health, the previous target loses the same amount. | DEAD-PERK |
| [ ] | **Thoughtsteal** | `player.addspell XX00BB22` | FireAndForget / Aimed | 70 | 90 | Riverville - Tarhutie | Equip the spells the target has equipped. Lasts for 120 seconds or until unequipped. |  |

### Adept (050) -- Ark - Ora Stonehand

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Blood for Blood** | `player.addspell XX127FA7` | FireAndForget / TargetActor | 75 | 170 | Ark - Ora Stonehand | Cast on a corpse, summons the anguish of its death as an avenging force to reduce the Health of the killer to <1>. |  |
| [ ] | **Compelling Whispers** | `player.addspell XX058655` | Concentration / Aimed | 34 | 170 | Ark - Ora Stonehand | Concentrate for <5> seconds to force creatures or people to fight for the caster for <60> seconds. | DEAD-PERK |
| [ ] | **Evil Twin** | `player.addspell XX037332` | Concentration | 34 | 210 | Ark - Ora Stonehand | While concentrating, manifests illusions of nearby enemies to attack them. Illusions take extra damage from attacks. | DEAD-SCRIPT-PROP |
| [ ] | **Figment of Pain** | `player.addspell XX043CE1` | FireAndForget / TargetActor | 100 | 165 | Ark - Ora Stonehand | Creates an immobile illusion linked to the target for 20 seconds. Damage felt by either is felt by both. |  |
| [ ] | **Illusory Pyre** | `player.addspell XX032C8B` | FireAndForget / TargetActor | 65 | 165 | Ark - Ora Stonehand | Illusory explosion deals <25>% of their current Health as temporary damage that wears off after 15 seconds. |  |
| [ ] | **Shadowbond** | `player.addspell XX031C4D` | FireAndForget / TargetActor | 80 | 180 | Ark - Ora Stonehand | Caster and target gain invisibility for 20 seconds. When the invisibility is broken, the caster and target swap places. |  |
| [ ] | **Sleeping Dogs** | `player.addspell XX1A4A50` | FireAndForget / Aimed | 130 | 165 | Ark - Ora Stonehand | Curses a target for 20 seconds. Whenever the target shouts, spectral forces deal 120 pure damage. |  |

### Expert (075) -- Sun Temple - Torius Flameling

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Empathic Agony** | `player.addspell XX0A4EF7` | FireAndForget / Aimed | 110 | 285 | Sun Temple - Torius Flameling | For 45 seconds, when the caster loses Health, target creatures or people lose <40>% of this amount. | DEAD-PERK |
| [ ] | **Enslave the Weak** | `player.addspell XX0306AC` | FireAndForget / Aimed | 195 | 270 | Sun Temple - Torius Flameling | Forces a hostile humanoid below <20>% Health to serve your will permanently until slain. You can only have one slave at a time. Does not work on quest characters. | DEAD-PERK<br>DEAD-SCRIPT-PROP |
| [ ] | **Fold Into Ether** | `player.addspell XX15B849` | FireAndForget / Aimed | 80 | 280 | Sun Temple - Torius Flameling | Interrupts target spellcaster. If a spell is interrupted, manifests an illusion of the target for 40 seconds. | DEAD-SCRIPT-PROP |
| [ ] | **Ghostwalk** | `player.addspell XX00AAE8` | FireAndForget | 135 | 290 | Sun Temple - Torius Flameling | Caster is invisible for 10 seconds or until broken, then teleports back to where the spell was cast. |  |
| [ ] | **Mimic's Cloak** | `player.addspell XX1274CF` | FireAndForget | 130 | 255 | Sun Temple - Torius Flameling | For 60 seconds, the caster copies most (non-concentration) spells cast by others within 20 foot. |  |
| [ ] | **Mind Control** | `player.addspell XX0378AE` | FireAndForget / Aimed | 140 | 250 | Sun Temple - Torius Flameling | Take control of a humanoid for 30 seconds. In combat, the target will fight back when attacked. The caster cannot act, but can cast spells. Sheathe to cancel. |  |
| [ ] | **Seidstone** | `player.addspell XX03789F` | FireAndForget / Aimed | 105 | 290 | Sun Temple - Torius Flameling | The stone manifests illusions of nearby dead for 40 seconds. Illusions take extra damage from attacks. |  |
| [ ] | **Vanish** | `player.addspell XX037E24` | FireAndForget | 205 | 265 | Sun Temple - Torius Flameling | All nearby opponents targeting the caster or searching for the caster leave combat. |  |
| [ ] | **Veil of Misdirection** | `player.addspell XX15B847` | FireAndForget / TargetActor | 90 | 285 | Sun Temple - Torius Flameling | Curses a target for 30 seconds. Whenever the target casts an armor or cloak spell, it is transferred to the caster. |  |

### Master (100) -- Ark - Emberlord & Fireflash

| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |
|---|---|---|---|---:|---:|---|---|---|
| [ ] | **Harrowing Dirge** | `player.addspell XX0C74EA` | FireAndForget / Aimed | 120 | 405 | Ark - Emberlord & Fireflash | When a cursed creature or humanoid dies, all other cursed targets take unresistable damage equal to <Global=WB_Illusion_HarrowingDirge_Global_Percentage>% of their maximum Health. Lasts 40 seconds. | DEAD-PERK |
| [ ] | **Hidden Cobra** | `player.addspell XX046DC4` | FireAndForget / TargetActor | 130 | 385 | Ark - Emberlord & Fireflash | Curses a target for 60 seconds. The curse reduces Health to <1> if the target leaves combat for <5> seconds. |  |
| [ ] | **Last Word** | `player.addspell XX0416BF` | FireAndForget / Aimed | 68 | 375 | Ark - Emberlord & Fireflash | Interrupts target spellcaster. If a spell is interrupted, any other Illusion spells cast on the target within 10 seconds last four times longer and are twice as powerful. |  |
| [ ] | **Magicka Void** | `player.addspell XX00B5B7` | FireAndForget / Aimed | 140 | 405 | Ark - Emberlord & Fireflash | Reduces the Health percentage of all targets to match their Magicka percentage. |  |
| [ ] | **Mirror Entity** | `player.addspell XX037E1A` | FireAndForget / Aimed | 165 | 480 | Ark - Emberlord & Fireflash | Control an illusion of target humanoid for 20 seconds. In combat, the illusion will attack opponents in range. The caster cannot act, but can cast spells. Sheathe to cancel. |  |
| [ ] | **Pull From Eternity** | `player.addspell XX085B03` | FireAndForget / Aimed | 130 | 410 | Ark - Emberlord & Fireflash | Cast on a corpse to capture its ghost. Cast on a target to release the ghost to attack the target for 40 seconds. The ghost takes less damage from attacks. | DEAD-SCRIPT-PROP |
| [ ] | **Scream of Pain** | `player.addspell XX0321BA` | FireAndForget | 305 | 420 | Ark - Emberlord & Fireflash | Lowers the Health percentage of nearby creatures and humanoids to the caster's Health percentage. The lost Health is restored after 20 seconds. | DEAD-PERK |
| [ ] | **Shroudwalk** | `player.addspell XX0DD94B` | FireAndForget | 255 | 375 | Ark - Emberlord & Fireflash | You are invisible for 90 seconds. When performing an action that breaks invisibility, you immediately regain invisibility, up to <Global=WB_Illusion_Shroudwalk_Global_BreakCount> times. |  |
| [ ] | **Spectral Warband** | `player.addspell XX085579` | FireAndForget | 240 | 420 | Ark - Emberlord & Fireflash | Manifests illusions of all allies in combat for 60 seconds. Illusions take extra damage from attacks. | DEAD-SCRIPT-PROP |
| [ ] | **Wyrd** | `player.addspell XX05E21C` | FireAndForget | 210 | 410 | Ark - Emberlord & Fireflash | The hand of fate chooses a random nearby target. It takes <20>% of its current Health for each nearby target as temporary damage that wears off after 30 seconds. |  |

## Scrolls (144)

Scrolls carry the same magic effects as their tome spells, so a scroll row is a check that the
**item** works -- that it exists, is obtainable, and casts on use -- not a re-test of the effect.

All of them at once: `bat apoc-scrolls`, or one at a time with the `additem` below.

| OK | Scroll | `additem` | Gold | Loot list | Expected | Risk |
|---|---|---|---:|---|---|---|
| [ ] | **Scroll of Acceleration Rune** | `player.additem XX03A9C5 1` | 250 | ZP_Apoc_Scrolls | Cast on a nearby surface, launches enemies in the direction they are moving. |  |
| [ ] | **Scroll of Alarm** | `player.additem XX03A449 1` | 15 | ZP_Apoc_Scrolls | Alerts the caster whenever an enemy crosses the 150 foot perimeter for 120 seconds. |  |
| [ ] | **Scroll of Battletide** | `player.additem XX05F258 1` | 250 | ZP_Apoc_Scrolls | Steals 80 points of armor rating from each nearby target for 30 seconds. The caster gains the total amount stolen. |  |
| [ ] | **Scroll of Control Weather** | `player.additem XX085572 1` | 250 | ZP_Apoc_Scrolls | Temporarily summon the weather of your choice. | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Deep Storage** | `player.additem XX03A45D 1` | 125 | ZP_Apoc_Scrolls | Grants access to an infinite underground storage space. |  |
| [ ] | **Scroll of Detonate Lock** | `player.additem XX03A9C1 1` | 125 | ZP_Apoc_Scrolls | Open a lock with a level <25> points or more below your Alteration skill with a shockwave that may alert others. |  |
| [ ] | **Scroll of Drop Zone** | `player.additem XX03A44D 1` | 30 | ZP_Apoc_Scrolls | Creates a ring of cushioning magic at the target location. The caster takes no damage when falling into the ring. |  |
| [ ] | **Scroll of Entomb** | `player.additem XX03F659 1` | 125 | ZP_Apoc_Scrolls | Buries a target permanently, or frees a buried target. Only one victim may be buried at a time. |  |
| [ ] | **Scroll of Eventuality Grimoire** | `player.additem XX03A9CB 1` | 250 | ZP_Apoc_Scrolls | Creates a hovering spell tome of the (projectile, non-concentration) spell in your left hand. It repeatedly casts the spell in the direction you are facing for 30 seconds. |  |
| [ ] | **Scroll of Fabricate Object** | `player.additem XX03A9C3 1` | 125 | ZP_Apoc_Scrolls | The caster creates a bridge, bed or crafting station of his or her choice. The object disappears after 120 seconds or when entering combat. |  |
| [ ] | **Scroll of Fins of Kilé** | `player.additem XX03A451 1` | 30 | ZP_Apoc_Scrolls | You swim 100% faster for 60 seconds. |  |
| [ ] | **Scroll of Girathû's Prison** | `player.additem XX03A45B 1` | 60 | ZP_Apoc_Scrolls | Materializes a cage to trap target humanoid for 10 seconds. |  |
| [ ] | **Scroll of Knowledge is Power** | `player.additem XX0668E7 1` | 125 | ZP_Apoc_Scrolls | Copies the (non-concentration) spell in your left hand, granting a power that casts this spell once a day for no cost. Empty left hand to reset. |  |
| [ ] | **Scroll of Locate Object** | `player.additem XX03A459 1` | 60 | ZP_Apoc_Scrolls | Illuminates the nearest ore vein, gold, container, door, key, soul gem, written text, potion, gem, ingot or equipment of your choice for 20 seconds. | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Milestones** | `player.additem XX0AF0A6 1` | 250 | ZP_Apoc_Scrolls | Place up to <5> teleportation anchors and teleport freely between them. |  |
| [ ] | **Scroll of Perilous Path** | `player.additem XX03A44F 1` | 30 | ZP_Apoc_Scrolls | Lay down a spike barrier that lasts 10 seconds and randomly staggers enemies moving through the spikes. |  |
| [ ] | **Scroll of Prepare for Adventure** | `player.additem XX084A8C 1` | 15 | ZP_Apoc_Scrolls | Creates a set of basic enchanted mage items (robes, circlet, boots, Destruction staff) in your inventory for 180 seconds. |  |
| [ ] | **Scroll of Talons of Vyn** | `player.additem XX047E27 1` | 250 | ZP_Apoc_Scrolls | Whenever an enemy in the area is staggered, a spike of rock erupts from the ground, tossing the target and dealing 150 Stamina damage. Lasts 60 seconds. |  |
| [ ] | **Scroll of Telekinetic Gauntlet** | `player.additem XX03A9C7 1` | 250 | ZP_Apoc_Scrolls | Telekinetically holds a target in front of the caster for 10 seconds. |  |
| [ ] | **Scroll of Thrumming Stone** | `player.additem XX03A9CD 1` | 250 | ZP_Apoc_Scrolls | Magical vibrating rock that emits a tremor every <8> seconds, staggering enemies and inflicting 40% weakness to magic for 2 seconds. Emits <5> pulses. |  |
| [ ] | **Scroll of Undermine** | `player.additem XX03A457 1` | 60 | ZP_Apoc_Scrolls | For 30 seconds, shifting earth causes the target to lose its balance when swinging a melee weapon, staggering the target and draining <30> points of Stamina. |  |
| [ ] | **Scroll of Wither** | `player.additem XX03A453 1` | 30 | ZP_Apoc_Scrolls | Reduces movement speed and attack damage by 5% per second, up to <50>%. Lasts 20 seconds. |  |
| [ ] | **Scroll of Banish Living** | `player.additem XX03BFAB 1` | 250 | ZP_Apoc_Scrolls | Banish a living creature into the Sea of Eventualities. Items (except quest items) are lost forever. (Creatures banished: <Global=WB_Conjuration_BanishLiving_Global_Counter>) | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Conjure Avenging Wraith** | `player.additem XX03BA22 1` | 125 | ZP_Apoc_Scrolls | Summons an Avenging Wraith for 60 seconds. Its stats are equal to <Global=WB_Conjuration_ConjureAvengingWraith_Global_Mult>% of those of the opponent that last killed it (<Global=WB_Conjuration_ConjureAvengingWraith_Global_Health> Health, <Global=WB_Conjuration_ConjureAvengingWraith_Global_Magicka> Magicka, <Global=WB_Conjuration_ConjureAvengingWraith_Global_Stamina> Stamina). |  |
| [ ] | **Scroll of Conjure Battlemage** | `player.additem XX0896DC 1` | 250 | ZP_Apoc_Scrolls | Call upon the services of a lower ranking Battlemage for 180 seconds. Activate to purchase permanent upgrades. |  |
| [ ] | **Scroll of Conjure Bear Totem** | `player.additem XX047E29 1` | 250 | ZP_Apoc_Scrolls | Summons a ancient totem spirit for 240 seconds. It changes between hunter and bear form to heal. (Max. <1>) |  |
| [ ] | **Scroll of Conjure Cat Totem** | `player.additem XX03BA2E 1` | 30 | ZP_Apoc_Scrolls | Summons a ancient totem spirit for 60 seconds. It changes between warrior and cat form to heal. (Max. <1>) |  |
| [ ] | **Scroll of Conjure Craftlord** | `player.additem XX03BFB1 1` | 250 | ZP_Apoc_Scrolls | Calls a Starling sage to Vyn for 180 seconds. Modify its stats with the <Reconfigure Craftlord> spell. |  |
| [ ] | **Scroll of Conjure Deadeye Captain** | `player.additem XX03BA2D 1` | 30 | ZP_Apoc_Scrolls | Summons a Deadeye Captain for 60 seconds. Activate a corpse to store it. Activate the Captain to dredge it up. |  |
| [ ] | **Scroll of Conjure Entropic Assassin** | `player.additem XX03BFAC 1` | 250 | ZP_Apoc_Scrolls | Summons an Entropic Assassin for 180 seconds. Its arrows reduce targets below <Global=WB_Conjuration_ConjureDremoraAssassin_Global_Health> Health to <1> for <10> seconds. | SUMMON-GAP |
| [ ] | **Scroll of Conjure Entropic Champion** | `player.additem XX03BA3D 1` | 125 | - | Summons an Entropic Champion for 60 seconds. Its power attacks deal bonus damage and knock targets airborne. | NOT-SOLD |
| [ ] | **Scroll of Conjure Entropic Churl** | `player.additem XX03BA2B 1` | 30 | - | Summons an Entropic Churl for 60 seconds. When killed, an Entropic Churl is summoned under control of the killer. | NOT-SOLD |
| [ ] | **Scroll of Conjure Entropic Honor Guard** | `player.additem XX03BA3F 1` | 125 | - | Summons an Entropic Honor Guard for 60 seconds. It reduces enemy magic resistance within 15 feet by <25>%. | NOT-SOLD |
| [ ] | **Scroll of Conjure Entropic Mentor** | `player.additem XX03BA47 1` | 125 | - | Choose a magic school and summon an Entropic Mentor for 90 seconds. It does not fight, but offers training in the chosen school and the school improves <20>% faster. | NOT-SOLD |
| [ ] | **Scroll of Conjure Entropic Pit Fighter** | `player.additem XX03BA31 1` | 60 | - | Summons an Entropic Pit Fighter for 60 seconds. It gains <25>% extra damage for each nearby enemy. | NOT-SOLD |
| [ ] | **Scroll of Conjure Herne** | `player.additem XX03BA41 1` | 125 | ZP_Apoc_Scrolls | Summons a Herne for 60 seconds. It is accompanied by <3> Spirit Wolves under its command. |  |
| [ ] | **Scroll of Conjure Kyrkrim** | `player.additem XX088681 1` | 250 | - | Summons the spirit wolf mount Kyrkrim for 180 seconds. When ridden, low level creatures and people flee in terror. | NOT-SOLD |
| [ ] | **Scroll of Conjure Lich** | `player.additem XX03BA33 1` | 60 | ZP_Apoc_Scrolls | Summons a Lich for 60 seconds. Costs <Global=WB_Conjuration_ConjureLich_Global_Cost> points of charge from an equipped enchanted weapon to cast. |  |
| [ ] | **Scroll of Conjure Lord of Bindings** | `player.additem XX066E4F 1` | 250 | - | Summons a Lord of Bindings for 180 seconds. It does not fight, but rapidly summons Churls in combat. | NOT-SOLD |
| [ ] | **Scroll of Conjure Nether Lich** | `player.additem XX03BFAF 1` | 250 | ZP_Apoc_Scrolls | Summons a Nether Lich for 180 seconds. It inflicts a damaging disease, lowers skill levels and raises the dead. |  |
| [ ] | **Scroll of Conjure Sinistran Lord** | `player.additem XX03BA43 1` | 125 | - | Summons a Sinistran Lord for 60 seconds. When summoned, drains all Magicka and has <200>% of this amount. It casts a deadly bolt that costs <150> Magicka. | NOT-SOLD |
| [ ] | **Scroll of Conjure Sinistran Sorcerer** | `player.additem XX03BA35 1` | 60 | - | Summons a Sinistran Sorcerer for 60 seconds. The caster takes <50> points of fire damage. | NOT-SOLD |
| [ ] | **Scroll of Conjure Weeping Shade** | `player.additem XX05F25A 1` | 250 | - | Summons a Weeping Shade for 120 seconds. It steals large amounts of Health with its magical attacks, but turns to inert and brittle stone when an enemy looks at it. | SUMMON-GAP<br>DEAD-PERK<br>NOT-SOLD |
| [ ] | **Scroll of Consuming Power** | `player.additem XX03BA24 1` | 15 | ZP_Apoc_Scrolls | Allied summoned or reanimated minion gains 75% extra attack damage for 10 seconds, then dies. |  |
| [ ] | **Scroll of Corpse Explosion** | `player.additem XX03BA38 1` | 60 | ZP_Apoc_Scrolls | Violently releases the soul of a corpse, disintegrating it with a magical explosion that deals damage equal to <40>% of the corpse's maximum Health. |  |
| [ ] | **Scroll of Elemental Mark** | `player.additem XX03BA26 1` | 30 | - | Marks a target for 10 seconds. The mark detonates when the target is struck by a summoned or reanimated minion, dealing <30> magic damage in a <15> foot area. | NOT-SOLD |
| [ ] | **Scroll of Entropic Crescent** | `player.additem XX03BA37 1` | 60 | ZP_Apoc_Scrolls | Binds an Entropic Crescent to a summoned or raised humanoid for 120 seconds. Until discharged, the weapon deals <50> magic damage and staggers targets. |  |
| [ ] | **Scroll of Gank** | `player.additem XX1A791C 1` | 60 | ZP_Apoc_Scrolls | Summons all nearby allied minions within <100> feet to attack the target. |  |
| [ ] | **Scroll of Monarch Mark** | `player.additem XX1644FF 1` | 125 | ZP_Apoc_Scrolls | Marks a target for 10 seconds. The mark detonates when the target is struck by a summoned or reanimated minion, dealing <60> magic damage in a <25> foot area. |  |
| [ ] | **Scroll of Oathbound Guardian** | `player.additem XX03BA45 1` | 125 | ZP_Apoc_Scrolls | Living ally is protected by an Oathbound Guardian under his or her command for 60 seconds. |  |
| [ ] | **Scroll of Power of the Master** | `player.additem XX08811C 1` | 30 | ZP_Apoc_Scrolls | Casts the (beneficial self-targeted) spell in your left hand on all nearby summoned or reanimated minions. |  |
| [ ] | **Scroll of Soul Cloak** | `player.additem XX03BA27 1` | 30 | ZP_Apoc_Scrolls | For 60 seconds, nearby enemies within 15 feet fill a soul gem on death. |  |
| [ ] | **Scroll of Summoning Rune** | `player.additem XX03BA3B 1` | 60 | ZP_Apoc_Scrolls | Cast on a nearby surface, summons an opponent in front of you when triggered. |  |
| [ ] | **Scroll of Apocalypse** | `player.additem XX039ED9 1` | 250 | ZP_Apoc_Scrolls | Target is assaulted by elemental entities that appear nearby and cast x<4> damage Flames, Frostbite and Sparks spells. Lasts 10 seconds. |  |
| [ ] | **Scroll of Blaze** | `player.additem XX0896D6 1` | 15 | ZP_Apoc_Scrolls | Bolt of wildfire that deals 10 damage. | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Bolide** | `player.additem XX0393FE 1` | 60 | ZP_Apoc_Scrolls | Meteoric rock that deals 25 fire damage. It heats up as it travels, dealing up to x<5> damage based on distance. | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Crackle** | `player.additem XX038E8D 1` | 15 | ZP_Apoc_Scrolls | Does 10 damage to Health and Magicka. |  |
| [ ] | **Scroll of Cyclonic Rift** | `player.additem XX039EE1 1` | 250 | ZP_Apoc_Scrolls | Creates a storm portal for 20 seconds. If two portals are active, those approaching either get warped across and take 50 shock damage to Health and Magicka. |  |
| [ ] | **Scroll of Dragon's Teeth** | `player.additem XX0393F4 1` | 30 | ZP_Apoc_Scrolls | Ignites all targets, doing 5 damage for 4 seconds. | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Electrosphere** | `player.additem XX039400 1` | 60 | ZP_Apoc_Scrolls | Slow moving ball lightning that strikes for 55 damage to Health and Magicka. |  |
| [ ] | **Scroll of Fingers of the Mountain** | `player.additem XX039EDB 1` | 250 | ZP_Apoc_Scrolls | Electrifies nearby opponents for 30 seconds. When hit by a shock spell, lightning strikes for 120 damage to Health and Magicka. Only works outdoors. |  |
| [ ] | **Scroll of Flamestrike** | `player.additem XX039EDD 1` | 250 | ZP_Apoc_Scrolls | A storm of <24> meteoric fireballs rains down from the heavens in a line extending from the caster, each exploding for 160 fire damage. Only works outdoors. |  |
| [ ] | **Scroll of Forbidden Sun** | `player.additem XX0668E9 1` | 250 | ZP_Apoc_Scrolls | Giant ball of elemental fire that deals 100 points of damage in a wide area on impact. |  |
| [ ] | **Scroll of Fracture** | `player.additem XX0393F6 1` | 30 | ZP_Apoc_Scrolls | A layer of thin ice deals 5 damage to Health and Stamina for 3 seconds. |  |
| [ ] | **Scroll of Frost Nova** | `player.additem XX039402 1` | 60 | ZP_Apoc_Scrolls | Radial frost explosion that deals 30 damage to Health and Stamina. Closer targets take up to x<2> damage. |  |
| [ ] | **Scroll of Frozen Orb** | `player.additem XX039EDF 1` | 250 | ZP_Apoc_Scrolls | Spinning orb that slowly travels to the target location and hovers there for <3> seconds, spraying ice spikes for 180 frost damage to Health and Stamina. |  |
| [ ] | **Scroll of Hailstone** | `player.additem XX0393F2 1` | 15 | ZP_Apoc_Scrolls | An ice crystal that shatters for 15 frost damage to Health and Stamina. Direct hits bypass Frost Resist. |  |
| [ ] | **Scroll of Ice Shiv** | `player.additem XX039404 1` | 60 | ZP_Apoc_Scrolls | Jagged shard that deals 30 frost damage to Health and Stamina. Targets hit from behind take x<3> damage. |  |
| [ ] | **Scroll of Incendiary Flow** | `player.additem XX10C708 1` | 60 | ZP_Apoc_Scrolls | Creates a molten stream as it passes near terrain, dealing 20 fire damage for 10 seconds. | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Lightning Strike** | `player.additem XX03996D 1` | 125 | ZP_Apoc_Scrolls | Lightning strikes the target location, dealing 60 shock damage to Health and Magicka. |  |
| [ ] | **Scroll of Multivortex** | `player.additem XX1A791E 1` | 60 | ZP_Apoc_Scrolls | All nearby friendly characters within <50> feet get random elemental Cloak spells that damage enemies. |  |
| [ ] | **Scroll of Rift Bolt** | `player.additem XX0393FC 1` | 30 | ZP_Apoc_Scrolls | Deals 20 shock damage to Health and Magicka and teleports the target backwards. |  |
| [ ] | **Scroll of Shock Nova** | `player.additem XX039970 1` | 125 | ZP_Apoc_Scrolls | Radial shockwave that deals 40 damage to Health and Magicka. Those along the edge take up to x<2> damage. |  |
| [ ] | **Scroll of Static Dome** | `player.additem XX0896DA 1` | 250 | ZP_Apoc_Scrolls | Shock globe that does 25 shock damage to Health and Magicka and causes <50>% weakness to shock. |  |
| [ ] | **Scroll of Thundercrack** | `player.additem XX0393FA 1` | 30 | ZP_Apoc_Scrolls | Deafening close range blast that deals 40 points of shock damage to Health and Magicka. |  |
| [ ] | **Scroll of Twister** | `player.additem XX039EE3 1` | 250 | ZP_Apoc_Scrolls | Creates a tornado at the target location. A direct hit sucks up a target, dealing 40 frost damage for 10 seconds. Nearby targets take half damage. Only works outdoors. |  |
| [ ] | **Scroll of Volcano** | `player.additem XX0896D8 1` | 250 | ZP_Apoc_Scrolls | Creates a volcanic eruption at the target location that spits out <8> lava bombs per second for <10> seconds, each dealing 40 fire damage. |  |
| [ ] | **Scroll of Backlash** | `player.additem XX0388F8 1` | 30 | ZP_Apoc_Scrolls | Interrupts target spellcaster. If a spell is interrupted, the target is hit by their own offensive spells, while non-offensive spells are cast on you. |  |
| [ ] | **Scroll of Blood For Blood** | `player.additem XX038905 1` | 60 | ZP_Apoc_Scrolls | Cast on a corpse, summons the anguish of its death as an avenging force to reduce the Health of the killer to <1>. |  |
| [ ] | **Scroll of Curse of the Silent** | `player.additem XX0388F3 1` | 30 | ZP_Apoc_Scrolls | Drains 8 points of Magicka per second for 30 seconds or until the target successfully casts a spell. |  |
| [ ] | **Scroll of Dispel Magic** | `player.additem XX0388F0 1` | 15 | ZP_Apoc_Scrolls | Dispels all magical effects (except diseases) on friends and foes. |  |
| [ ] | **Scroll of Empathic Agony** | `player.additem XX03890D 1` | 125 | ZP_Apoc_Scrolls | For 45 seconds, when the caster loses Health, target creatures or people lose <40>% of this amount. | DEAD-PERK |
| [ ] | **Scroll of Enslave the Weak** | `player.additem XX038911 1` | 125 | ZP_Apoc_Scrolls | Forces a hostile humanoid below <20>% Health to serve your will permanently until slain. You can only have one slave at a time. Does not work on quest characters. | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Figment of Pain** | `player.additem XX038902 1` | 60 | ZP_Apoc_Scrolls | Creates an immobile illusion linked to the target for 20 seconds. Damage felt by either is felt by both. |  |
| [ ] | **Scroll of Ghostwalk** | `player.additem XX0388F2 1` | 10 | ZP_Apoc_Scrolls | Caster is invisible for 10 seconds or until broken, then teleports back to where the spell was cast. |  |
| [ ] | **Scroll of Harrowing Dirge** | `player.additem XX03891B 1` | 250 | ZP_Apoc_Scrolls | When a cursed creature or humanoid dies, all other cursed targets take unresistable damage equal to <Global=WB_Illusion_HarrowingDirge_Global_Percentage>% of their maximum Health. Lasts 40 seconds. | DEAD-PERK |
| [ ] | **Scroll of Hidden Cobra** | `player.additem XX047E2B 1` | 250 | ZP_Apoc_Scrolls | Curses a target for 60 seconds. The curse reduces Health to <1> if the target leaves combat for <5> seconds. |  |
| [ ] | **Scroll of Illusory Pyre** | `player.additem XX038907 1` | 60 | ZP_Apoc_Scrolls | Illusory explosion deals <25>% of their current Health as temporary damage that wears off after 15 seconds. |  |
| [ ] | **Scroll of Last Word** | `player.additem XX03E617 1` | 250 | ZP_Apoc_Scrolls | Interrupts target spellcaster. If a spell is interrupted, any other Illusion spells cast on the target within 10 seconds last four times longer and are twice as powerful. |  |
| [ ] | **Scroll of Magicka Void** | `player.additem XX038917 1` | 250 | ZP_Apoc_Scrolls | Reduces the Health percentage of all targets to match their Magicka percentage. |  |
| [ ] | **Scroll of Mimic's Cloak** | `player.additem XX03890B 1` | 125 | ZP_Apoc_Scrolls | For 60 seconds, the caster copies most (non-concentration) spells cast by others within 20 foot. |  |
| [ ] | **Scroll of Mind Control** | `player.additem XX03890F 1` | 125 | ZP_Apoc_Scrolls | Take control of a humanoid for 30 seconds. In combat, the target will fight back when attacked. The caster cannot act, but can cast spells. Sheathe to cancel. |  |
| [ ] | **Scroll of Mind Vision** | `player.additem XX0388FA 1` | 30 | ZP_Apoc_Scrolls | See through the eyes of target creature or humanoid for 10 seconds. Sheathe to cancel. |  |
| [ ] | **Scroll of Mirror Entity** | `player.additem XX038919 1` | 250 | ZP_Apoc_Scrolls | Control an illusion of target humanoid for 20 seconds. In combat, the illusion will attack opponents in range. The caster cannot act, but can cast spells. Sheathe to cancel. |  |
| [ ] | **Scroll of Pale Shadow** | `player.additem XX085B0F 1` | 15 | ZP_Apoc_Scrolls | Target enemy is attacked by its own image for 10 seconds. It deals the same damage but has <1> Health. | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Pull From Eternity** | `player.additem XX0896DE 1` | 250 | ZP_Apoc_Scrolls | Cast on a corpse to capture its ghost. Cast on a target to release the ghost to attack the target for 40 seconds. The ghost takes less damage from attacks. | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Scream of Pain** | `player.additem XX038E7F 1` | 250 | ZP_Apoc_Scrolls | Lowers the Health percentage of nearby creatures and humanoids to the caster's Health percentage. The lost Health is restored after 20 seconds. | DEAD-PERK |
| [ ] | **Scroll of Seidstone** | `player.additem XX038913 1` | 125 | ZP_Apoc_Scrolls | The stone manifests illusions of nearby dead for 40 seconds. Illusions take extra damage from attacks. |  |
| [ ] | **Scroll of Shadowbond** | `player.additem XX038909 1` | 60 | ZP_Apoc_Scrolls | Caster and target gain invisibility for 20 seconds. When the invisibility is broken, the caster and target swap places. |  |
| [ ] | **Scroll of Shared Trauma** | `player.additem XX0388F5 1` | 30 | ZP_Apoc_Scrolls | For 10 seconds, when target creature or humanoid loses Health, the previous target loses the same amount. |  |
| [ ] | **Scroll of Shroudwalk** | `player.additem XX038E81 1` | 250 | ZP_Apoc_Scrolls | You are invisible for 90 seconds. When performing an action that breaks invisibility, you immediately regain invisibility, up to <Global=WB_Illusion_Shroudwalk_Global_BreakCount> times. |  |
| [ ] | **Scroll of Silvery Barbs** | `player.additem XX1A792A 1` | 15 | ZP_Apoc_Scrolls | Curses a target for 20 seconds. When the target casts a spell, they get <10>% weakness to magic and you get <10>% magic resistance. This effect stacks. |  |
| [ ] | **Scroll of Sleeping Dogs** | `player.additem XX1A7920 1` | 60 | ZP_Apoc_Scrolls | Curses a target for 20 seconds. Whenever the target shouts, spectral forces deal 120 pure damage. |  |
| [ ] | **Scroll of Spectral Warband** | `player.additem XX0896E0 1` | 250 | ZP_Apoc_Scrolls | Manifests illusions of all allies in combat for 60 seconds. Illusions take extra damage from attacks. | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Thoughtsteal** | `player.additem XX0388FC 1` | 30 | ZP_Apoc_Scrolls | Equip the spells the target has equipped. Lasts for 120 seconds or until unequipped. |  |
| [ ] | **Scroll of Vanish** | `player.additem XX038915 1` | 125 | ZP_Apoc_Scrolls | All nearby opponents targeting the caster or searching for the caster leave combat. |  |
| [ ] | **Scroll of Veil of Misdirection** | `player.additem XX1A7928 1` | 10 | ZP_Apoc_Scrolls | Curses a target for 30 seconds. Whenever the target casts an armor or cloak spell, it is transferred to the caster. |  |
| [ ] | **Scroll of Wyrd** | `player.additem XX05F25C 1` | 250 | ZP_Apoc_Scrolls | The hand of fate chooses a random nearby target. It takes <20>% of its current Health for each nearby target as temporary damage that wears off after 30 seconds. |  |
| [ ] | **Scroll of Bloodseeker** | `player.additem XX04839A 1` | 250 | ZP_Apoc_Scrolls | Casts a homing flare at a target. When it reaches the target, it heals or deals magic damage equal to <Global=WB_Restoration_Bloodseeker_Global_Mult>% of the Health the target gained or lost while it was in flight. |  |
| [ ] | **Scroll of Bone Spirit** | `player.additem XX03AF31 1` | 15 | ZP_Apoc_Scrolls | Casts a vengeful spirit that homes in on the target and explodes for 50 points of magic damage to undead. |  |
| [ ] | **Scroll of Channel Energies** | `player.additem XX067915 1` | 60 | ZP_Apoc_Scrolls | Casts the (beneficial self-targeted) spell in the caster's left hand on the target. | DEAD-SCRIPT-PROP |
| [ ] | **Scroll of Circle of Death** | `player.additem XX03B4B8 1` | 250 | ZP_Apoc_Scrolls | Circle instantly kills living targets below <40>% Health. |  |
| [ ] | **Scroll of Circle of Strength** | `player.additem XX03AF33 1` | 15 | ZP_Apoc_Scrolls | Steals 6 points of Stamina per second from hostiles inside the circle. |  |
| [ ] | **Scroll of Circle of the Moons** | `player.additem XX03AF41 1` | 60 | ZP_Apoc_Scrolls | Steals 8 points of Magicka per second from hostiles inside the circle. |  |
| [ ] | **Scroll of Decompose** | `player.additem XX095F45 1` | 125 | ZP_Apoc_Scrolls | Curses a nonmechanical target for 60 seconds, allowing allies within 10 feet of the target to absorb <15> points of Health per second from the target. |  |
| [ ] | **Scroll of Dust in the Clockwork** | `player.additem XX1A7922 1` | 60 | ZP_Apoc_Scrolls | Induces fungal growth in mechanical targets, dealing 5 pure damage for 10 seconds. |  |
| [ ] | **Scroll of Dust To Dust** | `player.additem XX03B4BC 1` | 250 | ZP_Apoc_Scrolls | Destroys all undead below <40>% health. |  |
| [ ] | **Scroll of Finger of Death** | `player.additem XX03AF43 1` | 60 | ZP_Apoc_Scrolls | Blast of death magic that damages a living target equal to its Health but the caster takes <Global=WB_Restoration_FingerOfDeath_Global_Percentage>% damage. If this would kill the caster, damage to the target is reduced. |  |
| [ ] | **Scroll of Healing Blossom** | `player.additem XX03B4B4 1` | 125 | ZP_Apoc_Scrolls | Activates 10 seconds after casting and lasts 10 seconds. |  |
| [ ] | **Scroll of Horrid Wilting** | `player.additem XX03AF45 1` | 60 | ZP_Apoc_Scrolls | Desiccates living targets, inflicting 12 disease damage per second for 10 seconds. |  |
| [ ] | **Scroll of King's Heart** | `player.additem XX03B4BE 1` | 250 | ZP_Apoc_Scrolls | A holy spark slowly follows the caster for 60 seconds. When it is nearby, it fortifies most skills by <15>% and heals 15 points per second. |  |
| [ ] | **Scroll of Lamb of Irlanda** | `player.additem XX03AF37 1` | 30 | ZP_Apoc_Scrolls | For 30 seconds, you gain <35>% of the Health the target loses. | RESPITE-INERT |
| [ ] | **Scroll of Leech Seed** | `player.additem XX03AF39 1` | 30 | ZP_Apoc_Scrolls | Infests a living target with a poison spore for 10 seconds. When the caster falls below full Health, the spore absorbs 5 points of Health per second. |  |
| [ ] | **Scroll of Life's Finale** | `player.additem XX03B4B6 1` | 250 | ZP_Apoc_Scrolls | Corrupts nearby living targets and the caster for 20 seconds. |  |
| [ ] | **Scroll of Mystic Wind** | `player.additem XX03AF3B 1` | 30 | ZP_Apoc_Scrolls | For 10 seconds, restores 5 points of Magicka per second while the caster is sprinting. |  |
| [ ] | **Scroll of Nature's Balance** | `player.additem XX03B4B2 1` | 125 | ZP_Apoc_Scrolls | Swaps the Health percentages of the caster and a living target. |  |
| [ ] | **Scroll of Necroplague** | `player.additem XX03AF3D 1` | 30 | ZP_Apoc_Scrolls | Infects a corpse with a spreading virus that deals 9 disease damage for 30 seconds to nonmechanical foes. |  |
| [ ] | **Scroll of Poisoned Chalice** | `player.additem XX1A7924 1` | 125 | ZP_Apoc_Scrolls | For 30 seconds, whenever the target gains Health, the gained Health is transferred to the caster instead. | RESPITE-INERT |
| [ ] | **Scroll of Resurgence** | `player.additem XX03AF4B 1` | 125 | ZP_Apoc_Scrolls | For 15 seconds, heals 20 points per second when the caster falls below <50>% Health. |  |
| [ ] | **Scroll of Ruin** | `player.additem XX0B7DA0 1` | 60 | ZP_Apoc_Scrolls | Weakens an enemy, reducing all skills by 15 points for 120 seconds. |  |
| [ ] | **Scroll of Sealed Resolve** | `player.additem XX03AF49 1` | 60 | ZP_Apoc_Scrolls | Places a seal upon the caster for 15 seconds. Losing <50>% of your current Health unlocks the seal, halving incoming damage for its remaining duration. |  |
| [ ] | **Scroll of Slay Living** | `player.additem XX03AF3F 1` | 30 | ZP_Apoc_Scrolls | Kills a living target in melee range with <25>% or less remaining health. |  |
| [ ] | **Scroll of Transcendence** | `player.additem XX083FAB 1` | 250 | ZP_Apoc_Scrolls | Blaze with holy energy, replenishing 15 Magicka per second. |  |
| [ ] | **Scroll of Tree Rings** | `player.additem XX03AF47 1` | 125 | ZP_Apoc_Scrolls | Caster receives <10> layers of tough plant skin, each increasing maximum Health by <15> points. Layers gradually fall off over the course of 30 seconds. |  |
| [ ] | **Scroll of Welling Blood** | `player.additem XX03AF35 1` | 30 | ZP_Apoc_Scrolls | Curses a living target. If the target loses at least <Global=WB_Restoration_WellingBlood_Global_Threshold>% of its maximum Health within 6 seconds, it dies. |  |
| [ ] | **Scroll of Wild Healing** | `player.additem XX0896E2 1` | 15 | ZP_Apoc_Scrolls | Heals the caster 40 points, then heals a random target within range 40 points. |  |
| [ ] | **Scroll of Willpower** | `player.additem XX1A7926 1` | 125 | ZP_Apoc_Scrolls | Transfers all Stamina to Magicka. |  |
| [ ] | **Scroll of Worm Shroud** | `player.additem XX03B4BA 1` | 250 | ZP_Apoc_Scrolls | For 120 seconds, destroys corpses within 20 feet, improving Restoration spells by <5>% for <30> seconds. This effect refreshes and stacks up to <10> times. |  |
| [ ] | **Scroll of Erase Spell** | `player.additem XX11A04C 1` | 45 | ZP_Apoc_Scrolls | When you cast a spell within 10 seconds, the spell vanishes from your spellbook. Cannot remove starting spells. | VANILLA-LIST |
| [ ] | **Scroll of Erodan's Embrace** | `player.additem XX09957C 1` | 500 | ZP_Apoc_Scrolls | Fully heals the caster, then increases maximum Health by <25>% of the amount healed for 60 seconds. |  |
| [ ] | **Scroll of Gravisphere** | `player.additem XX03A44B 1` | 500 | ZP_Apoc_Scrolls | Target is pulled into the air by a floating sphere of high mass for 60 seconds. |  |
| [ ] | **Scroll of Mind Fog** | `player.additem XX099574 1` | 500 | ZP_Apoc_Scrolls | Prevents the target from casting spells or regenerating Magicka for 20 seconds. Bypasses spell absorption. |  |
| [ ] | **Scroll of Sinistra Unbound** | `player.additem XX09900A 1` | 500 | ZP_Apoc_Scrolls | Invokes an unholy rage in a summoned or raised creature, granting 200% attack and movement speed. |  |
| [ ] | **Scroll of Wizardfire** | `player.additem XX05D1E4 1` | 500 | ZP_Apoc_Scrolls | Devastating blast of raw magicka that deals 400 points of magic damage in a large area but can hit the caster. |  |

## Known-unobtainable by design

Fifteen Daedric and Dwemer summons are stocked by no merchant and in no leveled list, following the
`enderal-magic-porter` rule that Daedra and Dwemer have no place in Enderal's setting. Their
records still ship (removing them would break every FormList and script that indexes them), so
they are flagged `NOT-SOLD` above rather than deleted. Nothing to test -- but verify a player
cannot reach them:

- [ ] `WB_Con_Dremora4_Spell_ConjureDremoraChampion_NPC` -- **Conjure Entropic Champion** is not offered by any merchant and does not drop
- [ ] `WB_Con_Dremora2_Spell_ConjureDremoraChurl_NPC` -- **Conjure Entropic Churl** is not offered by any merchant and does not drop
- [ ] `WB_Con_Dremora4_Spell_ConjureDremoraHonorGuard_NPC` -- **Conjure Entropic Honor Guard** is not offered by any merchant and does not drop
- [ ] `WB_Con_Dremora4_Spell_ConjureDremoraMentor` -- **Conjure Entropic Mentor** is not offered by any merchant and does not drop
- [ ] `WB_Con_Dremora3_Spell_ConjureDremoraPitFighter_NPC` -- **Conjure Entropic Pit Fighter** is not offered by any merchant and does not drop
- [ ] `WB_Con_Daedric5_Spell_ConjureKyrkrim` -- **Conjure Kyrkrim** is not offered by any merchant and does not drop
- [ ] `WB_Con_Dremora5_Spell_ConjureLordOfBindings_NPC` -- **Conjure Lord of Bindings** is not offered by any merchant and does not drop
- [ ] `WB_Con_Xivilai4_Spell_ConjureXivilaiLord_NPC` -- **Conjure Sinistran Lord** is not offered by any merchant and does not drop
- [ ] `WB_Con_Xivilai3_Spell_ConjureXivilaiSorcerer_NPC` -- **Conjure Sinistran Sorcerer** is not offered by any merchant and does not drop
- [ ] `WB_Con_Dremora5_Spell_ConjureWeepingDaedra_NPC` -- **Conjure Weeping Shade** is not offered by any merchant and does not drop
- [ ] `WB_Con_Curse2_Spell_AtronachMark` -- **Elemental Mark** is not offered by any merchant and does not drop
- [ ] `WB_Con_Dremora4_Spell_SixDemonBag` -- **Six Demon Bag** is not offered by any merchant and does not drop

**Note the inconsistency:** 12 tomes are withheld but only 14 of the matching scrolls are. 
`WB_C075_SixDemonBag`'s scroll is still in `ZP_Apoc_Scrolls`, so that summon *is* reachable, once,
from a scroll. Either sell the tome or pull the scroll -- it should not be half-in.
