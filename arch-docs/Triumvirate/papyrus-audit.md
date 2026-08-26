# Triumvirate — Papyrus and dependency audit

What Triumvirate's mechanics actually do in script, what they need from the engine, and what
survives the move to Enderal. Produced for **WD-17**.

All 106 compiled scripts were extracted from `Triumvirate - Mage Archetypes.bsa` and decompiled
(4,398 lines of reconstructed source). Everything below was read off that output, not inferred from
script names.

> Decompiled `.psc` is a **reconstruction** — Champollion invents variable names, rebuilds control
> flow and loses comments. It is reliable for *what a script reads and calls*, which is all this
> audit claims. The sources live in gitignored `reference/mods/Triumvirate/scripts-source/`;
> regenerate with the commands at the bottom.

## Headline: there is nothing to port

| Question | Answer |
|---|---|
| Hardcoded FormIDs (`GetFormFromFile`, `Game.GetForm`) | **none — 0 of 106 scripts** |
| Hex literals of any kind (`0x…`) | **none** |
| `import` statements | **none** |
| SKSE dependency | **none** |
| PapyrusUtil / StorageUtil / JContainers / MiscUtil | **none** |
| MCM / SkyUI (`SKI_ModConfigBase`, `ModEvent`) | **none** |
| Property types used | **all vanilla Papyrus** |

**Every one of Triumvirate's mechanics is driven by properties filled from the plugin records.** That
is the best possible answer to WD-17's central question — CLAUDE.md's rule is that *data-driven parts
of a script extend to new records while hardcoded checks do not*, and here there are no hardcoded
checks at all. Fixing a mechanic means fixing the record it points at, never recompiling a script.

It also settles the two dependency questions the ticket raised, both negative:

* **No SKSE plugin**, so the 1.5.97 / pre-AE build question never arises. There is no `.dll`.
* **No MCM**, so no SkyUI-equivalent is needed.

Base types, for a sense of the shape: 60 `ActiveMagicEffect`, 16 `Quest`, 10 `ReferenceAlias`,
9 `ObjectReference`, 6 `Actor`, 5 `TopicInfo`.

## Every string literal resolves in Enderal

With no FormIDs to check, the remaining hardcoding risk is string-keyed lookups. There are 23
distinct string literals across all 106 scripts, and they fall into three groups — all safe:

| Group | Literals | Verdict |
|---|---|---|
| ActorValues | `Health` `Magicka` `Alteration` `Conjuration` `CarryWeight` `SpeedMult` `WeaponSpeedMult` `AttackDamageMult` `BrainCondition` `Lockpicking` `EnchantingPowerMod` `AlterationPowerMod` `AlterationSkillAdvance` `Variable04` `WaitingForPlayer` | **All exist in Enderal.** CLAUDE.md establishes that Enderal keeps all five magic ActorValues and only renames them for display |
| Animation events | `PowerAttack_Start_End` `HitFrame` `GetUpBegin` | Engine-level, unchanged |
| Triumvirate's own | three `TRIUMVIRATE ERROR: …` strings, `SacredHearth` | Its own |

One is a neat trick worth recognising rather than "fixing": `tvr_totem_script` does

```papyrus
self.SetActorValue("AlterationSkillAdvance", game.GetPlayer().GetActorValue("Conjuration"))
```

— storing the player's Conjuration level in an unused ActorValue on the totem so other effects can
scale off it. Both AVs exist in Enderal, so it works untouched.

## Findings

### 1. `tvr_populatespellbooks_script` — dead, noisy, and carrying one live line — **WD-16**

The distribution script. `OnInit` calls `RegisterForSingleUpdate`, and `OnUpdate` then makes **76
calls on properties that are mostly dead**: 18 `AddToFaction` on named Skyrim NPCs, 36 `AddItem` on
merchant chests, 22 `AddForm` on `LItemStaff*` leveled lists. Of the quest record's 85 remaining
references, **34 are dead**. Each dead receiver produces a `Cannot call <X> on a None object` line in
the Papyrus log, once, at game start.

> **CLAUDE.md's rule applies exactly.** Clearing `StartGameEnabled` will not stop this — `OnInit`
> and its `RegisterForSingleUpdate` fire regardless. Make the work empty instead.

Two things WD-16 needs to know before touching it:

* **Its first line is `TVR_Conversion_Quest.Start()`**, and that quest exists and does real work.
  Neutralising the populate quest wholesale would silently break the Conversion mechanic.
* **There is only ONE entry point.** Grepping all 106 scripts for `populate` returns exactly one
  file. Apocalypse had a second — an MCM "Repopulate" button driving the same loop over duplicate
  lists — and fixing only the obvious one left a button that reproduced the bug on demand.
  Triumvirate has no MCM, so this really is the whole surface.

### 2. `tvr_manager_quest` — degrades gracefully, but carried a debug alias — **FIXED**

This is the quest that grants the player `TVR_Primal_Perk`. Its script:

```papyrus
if PlayerRef.HasPerk(TwinSouls)
    PlayerRef.RemovePerk(TwinSouls) ; remove/re-add to force perk-entry re-evaluation order
    PlayerRef.AddPerk(TVR_Primal_Perk)
    PlayerRef.AddPerk(TwinSouls)
else
    PlayerRef.AddPerk(TVR_Primal_Perk)
endIf
```

`TwinSouls` is `0D5F1C:Skyrim.esm`, dead in Enderal, so the property is `None`, `HasPerk(None)` is
false, and the `else` branch runs. **The perk is still granted; only minion doubling is lost** — which
WD-9 already recorded. No error, no crash. Leave it.

What did need fixing was the quest's single alias, **`TVR_CheatChicken`**:

```yaml
- Name: TVR_CheatChicken
  ForcedReference: 1066DF:Skyrim.esm
  Items: [ TVR_Tomes_Litem_All ]        # a UseAll list holding EVERY Triumvirate spell tome
```

In vanilla Skyrim `1066DF` is a placed chicken in Riverwood — Enai's developer cheat: loot the
chicken, get all 75 tomes. **In Enderal the same FormID is a placed
`_00E_PaintingSquarePortrait_04` in `MQ07aManor`**, so the alias binds to a painting in an Enderal
manor and tries to stuff the mod's entire spell list into it.

Removed rather than repointed — it is a debug leftover with no player-facing purpose, and leaving it
cost something concrete: a non-optional alias that fails to fill stops a quest starting, and this is
the quest that grants the player's core perk. With no alias the quest starts unconditionally.

> **This is the drift class again, and it is one `verify-ref-drift.ps1` could not see.** That script
> compares top-level records carrying an EditorID; a placed reference has neither, so `1066DF` sat in
> its `NESTED` bucket. Worth remembering as a limit of the tool rather than a gap in the data — the
> nested bucket is 19 FormKeys and deserves a manual pass on any port.

### 3. `DLC2AshShellScript` does not exist anywhere — **FIXED**

`TVR_Shaman_Violence_Effect_Worldshatter_Hazard_AshShell` bound a script named `DLC2AshShellScript`.
That is **Bethesda's Dragonborn script, not one of Triumvirate's**, and it is **not among the BSA's
106 scripts** — checked, not assumed. Enderal ships no Dragonborn scripts either, so the binding
could never resolve and logged a missing-script warning on every load. WD-9 had already removed its
dead `DLC2AshShellDmgPerk` property; the binding itself is now gone too.

### 4. Wild Shape uses Skyrim's werewolf flag — **TEST IN GAME** — WD-11

`tvr_wildshape_script` calls `Game.SetBeastForm(true)` on start and `Game.SetBeastForm(false)` on
end. That is the engine's **werewolf** beast-form state, and Enderal has no werewolf system — no
beast race, no feeding, no beast-form HUD.

The call itself is engine-level and will not error. What it *does* to an Enderal player is not
something the records can tell us: beast form affects equipment, controls and the HUD. **This is the
one script-level unknown that only a launch can settle**, so it belongs on WD-18's test matrix as a
named risk rather than being guessed at now.

### 5. Two spells reward XP through a system Enderal does not have — WD-11 / WD-12

`game.AdvanceSkill("Alteration", …)` appears twice — in `qf_tvr_diviner_quest_mark_go` (a flat 10)
and `tvr_farsight_quest_script` (a variable `TVR_XP`). `AdvanceSkill` drives Skyrim's
**learn-by-doing**, and CLAUDE.md establishes that Enderal has none: skills advance through learning
points and skill books, and the character sheet is Enderal's own `_00E_Game_SkillmenuSC` menu.

So the call raises a counter Enderal's progression never reads. **Inert, not harmful** — the Diviner
and Farsight spells simply stop paying their small XP reward. Worth a line in the mod description
rather than a rewrite; converting it would mean granting Enderal learning points, which is a design
decision for the archetype tickets, not a script fix.

## What this release ships

**None of Enai's scripts.** All 106 stay in his BSA, unmodified — every fix above is a record edit,
which is possible precisely because no script hardcodes anything.

The only Papyrus in the release is the pair from the WD-9 asset sweep: **Enderal's own
`dgintimidateplayerscript` and `dgintimidatealiasscript` stubs**, re-shipped loose so they beat
Triumvirate's BSA, which carries the full vanilla brawl scripts. See
[`../../src/Triumvirate/Scripts/README.md`](../../src/Triumvirate/Scripts/README.md). They compile to
480 and 482 bytes — byte-identical to Apocalypse's, which is the cheapest check that the `-i` order
put Enderal's tree first.

## Reproduce

```bash
bsab -e:N -o "reference/mods/Triumvirate/Triumvirate - Mage Archetypes.bsa" \
     -f "scripts\*" reference/mods/Triumvirate/scripts-pex
Champollion.exe -p reference/mods/Triumvirate/scripts-source \
     reference/mods/Triumvirate/scripts-pex/*.pex

cd reference/mods/Triumvirate/scripts-source
grep -il "GetFormFromFile\|Game.GetForm(" *.psc        # hardcoded FormIDs   -> expect none
grep -il "0x[0-9A-Fa-f]\{4,\}" *.psc                   # hex literals        -> expect none
grep -ih "^import " *.psc                              # frameworks          -> expect none
grep -oh '"[^"]\{2,\}"' *.psc | sort -u                # string-keyed lookups
```

`Champollion.exe -p <outdir> <input.pex>` — `-p` is the output **directory** and the input comes
last; any other arrangement just prints the usage banner.
