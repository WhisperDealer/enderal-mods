# Why this release ships four Papyrus scripts

## TVR_Wildshape_Script (Enai's, patched — WD-37)

`TVR_Wildshape_Script.pex` is Enai's transformation script rebuilt with one change, shipped loose so
it beats the copy in `Triumvirate - Mage Archetypes.bsa`.

Two magic effects bind it, and they are the mod's **only** two player transformations —
`TVR_Druid_Verdant_Effect_ForceOfNature` and `TVR_Druid_Verdant_Effect_Wildshape_MorphEffect`. Both
were reported broken in Enderal, which is what made this one subsystem rather than two bugs.

## The change: Bethesda's call order

`PlayerWerewolfChangeScript.psc` is the shipped, proven recipe for "the player becomes a beast race
and renders". Read end to end, Enai's script does almost none of it:

| Step | Bethesda | Enai |
|---|---|---|
| `Game.SetBeastForm(True)` | **before** `SetRace` | after everything |
| `DisablePlayerControls` `aiDisablePOVType` | `1` | `0` |
| `Game.ForceThirdPerson()` | before `SetRace` | after the unequips |
| `Game.ForceFirstPerson()` | never called | before `SetRace` |
| `Game.ShowFirstPersonGeometry(false)` | yes | never |
| `Game.SetInCharGen(true, …)` | around `SetRace` | never |

SureAI's `LycantropheTransformSC` agrees with Bethesda on the one easiest to dismiss: it also wraps
its race change in `Game.SetInCharGen`. Two independent proven implementations calling it is the
reason to make the call, rather than reasoning about what it "should" do — chargen mode is the state
the engine itself uses when a race change has to rebuild the player, which is exactly the missing
step.

The script now follows that order on both transitions, and keeps the `QueueNiNodeUpdate` redraw from
the previous attempt after it. Two smaller repairs came along: `ForceFirstPerson()` is gone, and the
weapon unequips are guarded, which removes two `Cannot unequip a None item` errors per cast for an
unarmed caster.

**This ships instrumented.** `TVR_Trace` (default on) writes the player's race before and after every
transition to the Papyrus log. This is the third attempt at this bug; the first two were each
defensible and each failed, so if this one fails the log should say where instead of costing another
round of hypotheses.

## Two wrong answers worth recording

**Attempt 1 — an armour strip.** The theory: a race skin renders per biped slot, so armour left on
across the `SetRace` keeps slots 32/33/37, draws nothing, and suppresses the skin. Both proven
archetypes *do* unequip gear right after `SetRace`, so it looked well founded. It was wrong three
ways, and only a Papyrus log showed the last two:

1. It never fixed the invisibility — the save reload that displayed the Treewarden happened *with the
   armour already stripped*, so the strip was never the variable.
2. It threw on that path: an `ActiveMagicEffect` restored from a save comes back detached (`[None]`),
   and reading its `Form[]` variable errors with `Cannot cast from None to Form[]` before any guard
   helps, so the restore aborted and the player's gear stayed off.
3. It fired up to 31 unequip events per cast, setting off **45** `Cannot call GetSlotMask() on a None
   object` errors in an unrelated mod's `OnObjectUnequipped` handler.

The lesson: two proven archetypes agreeing that a mechanism is real is good evidence about the
*mechanism* and none at all that it is *this bug*. Don't keep a fix that failed its test because the
reasoning behind it was sound.

**Attempt 2 — `QueueNiNodeUpdate` alone.** Motivated by the anchor fact that reloading a save while
transformed shows the Treewarden correctly, so every record is right and only the live transition is
wrong. It did not fix it either, and is kept only as a cheap belt-and-braces step *after* the
corrected order.

## Still open

A Papyrus log from the reporting modlist also shows RaceMenu broken at the bind level — `Unable to
bind script RaceMenuPluginXPMSE … because their base types do not match` ×12 — with all six plugin
aliases throwing `Cannot call OnChangeRace() on a None object` from `RaceMenuLoad.OnRaceSwitchComplete`
on **every** player race change (×36). RaceMenu/NiOverride owns body rendering for *humanoid* actors,
which is exactly what separates the two transformations: Force of Nature's race is humanoid
(`DefaultMale.hkx`, head parts, tint masks), Wildshape's is a `Critter` creature race NiOverride does
not touch — and Wildshape renders.

`player.setrace TVR_Verdant_Race_ForceOfNature` from the console (an **EditorID**, not a FormID —
`SetRace` rejects FormIDs) takes this script out of the equation entirely and settles whether the
fault is ours or the list's.

`QueueNiNodeUpdate` is an **SKSE** function; it lives in the SKSE tree, not the vanilla one, so the
SKSE tree must precede vanilla on `-i` or the compile fails to resolve it. A correct build is
**5724 bytes**. `src/Triumvirate/tools/verify-druid-transformations.ps1` asserts the shipped `.pex`
contains `QueueNiNodeUpdate` and does **not** contain `StripArmor` — `build.ps1` fails on a *missing*
`.pex` but cannot detect a stale one.

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
