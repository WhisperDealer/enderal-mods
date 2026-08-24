# Why this release ships two Papyrus scripts

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
