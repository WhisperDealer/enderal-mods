# Why this release ships three Papyrus scripts

## It used to ship a fourth, and that is worth recording

`TVR_Wildshape_Script` — Enai's player-transformation script — was patched three times during WD-37
and every version has been reverted. The script this release ships is **Enai's own, from his BSA,
untouched**. The history matters because the reasoning behind each attempt was sound and each one was
still wrong.

The bug: **Force of Nature** transforms the player into the Treewarden, who renders nothing — they
attack and cast normally with no body. **Wildshape**, on the same script, is fine.

| Attempt | Theory | Why it died |
|---|---|---|
| 1. Strip worn armour around the race change | A race skin renders per biped slot; armour left on keeps slots 32/33/37, draws nothing and suppresses the skin. Both Bethesda's `PlayerWerewolfChangeScript` and SureAI's `LycantropheTransformSC` do unequip gear right after `SetRace`. | Didn't fix it. Worse, it threw `Cannot cast from None to Form[]` on save-restored effects (so gear stayed off) and set off **45** `GetSlotMask()` errors per cast in another mod's unequip handler. |
| 2. `QueueNiNodeUpdate` + delay | Reloading a save mid-transform shows the Treewarden **correctly**, so every record is right and only the live 3D rebuild is missing. | Didn't fix it. |
| 3. Bethesda's full call order | `PlayerWerewolfChangeScript` sets beast form *before* `SetRace`, forces third person first, calls `ShowFirstPersonGeometry(false)`, and wraps the race change in `Game.SetInCharGen` — Enai does none of it, and SureAI independently agrees on `SetInCharGen`. | Overtaken: a bare `player.setrace` from the console, with no Triumvirate script involved at all, reproduces the invisibility. The fault is not in this script. |

**What is actually established.** The records are correct (the save reload proves it). The script is
irrelevant (the console `setrace` proves it). The fault is in the live race-switch path on the
reporting setup. A Papyrus log from that list shows RaceMenu broken at the bind level — `Unable to
bind script RaceMenuPluginXPMSE … because their base types do not match` ×12 — with all six plugin
aliases throwing `Cannot call OnChangeRace() on a None object` from
`RaceMenuLoad.OnRaceSwitchComplete` on **every** player race change (×36). RaceMenu/NiOverride owns
body rendering for *humanoid* actors, and that is exactly the line the two results fall on: Force of
Nature's race is humanoid (`DefaultMale.hkx`, head parts, tint masks); Wildshape's is a `Critter`
creature race NiOverride does not touch.

**Why the script override went away entirely.** With Force of Nature withheld from distribution
(`tools/20-withhold-force-of-nature.ps1`), every code path those three attempts touched had Force of
Nature as its only consumer — Wildshape sets `TVR_UnequipItems` to `False`, so it never enters the
block at all. Keeping a modified copy of a third-party script forever, to carry unproven changes
against the one transformation that works, is a maintenance burden with no upside.

**The lesson worth keeping:** two proven archetypes agreeing that a mechanism is real is good
evidence about the *mechanism*, and none at all that it is *this bug*. Don't keep a fix that failed
its test because the reasoning behind it was sound.

# TVR_PopulateSpellBooks_Script (ours - WD-16)

`TVR_PopulateSpellBooks_Script.pex` is a replacement for Enai's distribution script, shipped loose so it beats the copy in
`Triumvirate - Mage Archetypes.bsa`. The original makes 76 calls against Skyrim NPCs, merchant
chests and staff leveled lists - none of which exist in Enderal - and would log that many
`Cannot call ... on a None object` errors at game start. Distribution was rebuilt at the record
level (see `arch-docs/Triumvirate/vendor-mapping.md`), so the replacement keeps only the two
live pieces: starting `TVR_Conversion_Quest` and showing the mod-ready message. The quest
record's VMAD was stripped to the matching three properties by
`src/Triumvirate/tools/15-distribution.ps1`.

Recompile with the same Enderal-first import order as below; a correct build is **1657 bytes**.

# Why this release also ships two of SureAI's scripts

Nothing here is ours. Both files are **SureAI's own**, copied verbatim from `ScriptsEnderal.zip`
(`reference/base/EnderalScripts/source/scripts/`). They are shipped **loose** so they beat a BSA.

This is the same fix, for the same defect, that `src/Apocalypse/Scripts/` documents — **it is now
confirmed in two separate Enai Siaion mods**, both of which bundled the Brawl Bugs Patch.

## The problem

`Triumvirate - Mage Archetypes.bsa` contains 107 compiled scripts. Intersecting their names with
Enderal's own 5031 gives **exactly two collisions**, and they are the two CLAUDE.md already singles
out as Enderal's deliberate stubs:

| Script | In Enderal | In Triumvirate's BSA |
|---|---|---|
| `dgintimidateplayerscript` | 4 lines — `; DUMMY, DO NOTHING` | the full vanilla brawl script, 2425 bytes, **59 lines decompiled**, compiled 2016 by *Maximilian* (Brawl Bugs Patch) |
| `dgintimidatealiasscript` | 4 lines — `; DUMMY, DO NOTHING` | the full vanilla alias script, 1983 bytes, **47 lines decompiled**, same author |

Enderal ships compiled copies of both DUMMY stubs inside `E - Misc.bsa`, but **Triumvirate loads
after Enderal, so its BSA wins**, and Skyrim's brawl/intimidate system comes back on a game that
removed it. The restored `dgintimidatealiasscript` reaches for `DGIntimidateFaction`, which Enderal
does not have.

Triumvirate's BSA also carries seven more Bethesda scripts — `bladessparringscript`,
`c00jorrvaskrfightathisscript`, `c00jorrvaskrfightnjadascript`, `c00trainerscript`,
`c00vilkasscript`, `companionssinglecombatantscript`, `ms11calixtoscript`. All seven are vanilla
Skyrim scripts and **none of them collides with an Enderal script name**, so they are inert clutter
rather than an override: Enderal has no Companions and nothing attaches them. Left alone
deliberately — they are only reachable from records that do not exist.

## The fix

Loose files beat any BSA, so re-shipping Enderal's stubs restores Enderal's behaviour.

**This mod must therefore sit *after* Triumvirate in MO2's file priority** — which it already must,
in order to win the `.esp`.

## Recompiling

`compiled/` is committed (a `.gitignore` exception) because CI cannot run the Papyrus compiler.
Recompile with **Enderal's source tree first** on the import path — the compiler's `-i` is
first-wins, and getting the order wrong compiles *vanilla's* 59-line version, which is the very bug
this is fixing:

```powershell
. ".claude/config/tools.ps1"
$imports = @($Tools.papyrusSource.enderal, $Tools.papyrusSource.skse,
             $Tools.papyrusSource.vanilla, "src/Triumvirate/Scripts/source") -join ';'
& $Tools.papyrusCompiler "src/Triumvirate/Scripts/source" `
    -i="$imports" -o="src/Triumvirate/Scripts/compiled" `
    -f="TESV_Papyrus_Flags.flg" -all
```

A correct build is **480 and 482 bytes** — byte-identical to Apocalypse's, which is the cheapest
possible check. If either comes out near 2 KB you compiled the vanilla copy; fix the `-i` order.
