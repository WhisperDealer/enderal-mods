# Why this release ships two Papyrus scripts

Nothing here is ours. Both files are **SureAI's own**, copied verbatim from
`ScriptsEnderal.zip` (`reference/base/EnderalScripts/source/scripts/`). They are shipped **loose**
so they beat a BSA.

## The problem

`Apocalypse - Magic of Skyrim.bsa` contains 206 compiled scripts, and two of them share a name with
a script Enderal deliberately gutted:

| Script | In Enderal | In Apocalypse's BSA |
|---|---|---|
| `dgintimidateplayerscript` | 4 lines — `; DUMMY, DO NOTHING` | the full vanilla brawl script, 2425 bytes, compiled by *Maximilian* (Brawl Bugs Patch) |
| `dgintimidatealiasscript` | 4 lines — `; DUMMY, DO NOTHING` | the full vanilla alias script, 1983 bytes, same author |

Enderal ships compiled copies of both DUMMY stubs inside `E - Misc.bsa` — confirmed by reading that
archive's file-name table. But **Apocalypse loads after Enderal, so its BSA wins**, and Skyrim's
brawl/intimidate system comes back on a game that removed it. The restored scripts reach for
`dgintimidatequestscript`, `DGIntimidateFaction` and `CR04Running`, none of which Enderal has.

These are 2 of the **55 script names that exist in both Enderal's and Skyrim's source trees**
(CLAUDE.md, "The import path is first-wins"). They are also the two that CLAUDE.md already singled
out as explicit `; DUMMY, DO NOTHING` stubs — which is exactly why this was findable.

## The fix

Loose files beat any BSA, so re-shipping Enderal's stubs restores Enderal's behaviour.

**This mod must therefore sit *after* Apocalypse in MO2's file priority** — which it already must, in
order to win the `.esp`.

## Recompiling

`compiled/` is committed (a `.gitignore` exception) because CI cannot run the Papyrus compiler.
Recompile with **Enderal's source tree first** on the import path — the compiler's `-i` is
first-wins, and getting the order wrong here compiles *vanilla's* 59-line version, which is the very
bug this is fixing:

```
PapyrusCompiler.exe src/Apocalypse/Scripts/source `
  -i="<papyrusSource.enderal>;<papyrusSource.skse>;<papyrusSource.vanilla>;src/Apocalypse/Scripts/source" `
  -o="src/Apocalypse/Scripts/compiled" -f="TESV_Papyrus_Flags.flg" -all
```

A correct build is **~480 bytes per `.pex`**. If either comes out near 2 KB you compiled the vanilla
copy — check the `-i` order.
