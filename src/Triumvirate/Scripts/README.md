# Why this release ships four Papyrus scripts

## TVR_Wildshape_Script (Enai's, patched — WD-37)

`TVR_Wildshape_Script.pex` is Enai's transformation script rebuilt with two changes, shipped loose so
it beats the copy in `Triumvirate - Mage Archetypes.bsa`.

Two magic effects bind it, and they are the mod's **only** two player transformations —
`TVR_Druid_Verdant_Effect_ForceOfNature` and `TVR_Druid_Verdant_Effect_Wildshape_MorphEffect`. Both
were reported broken in Enderal, which is what made this one subsystem rather than two bugs.

## What was actually wrong, and a wrong answer worth recording

The first fix shipped for this was the **armour strip**, on the theory that a race skin renders per
biped slot and the player's Enderal armour keeps slots 32/33/37 across the `SetRace`, drawing nothing
and suppressing the skin beneath. It is a tidy mechanism, both proven archetypes do unequip gear
immediately after `SetRace` (Bethesda's `PlayerWerewolfChangeScript`, SureAI's
`LycantropheTransformSC`), and **it did not fix the invisibility.**

What killed it was one observation from a player: **reloading a save while transformed shows the
Treewarden correctly** — with the armour still stripped, so the strip cannot be the variable. A fresh
actor build renders the model perfectly, which means the race, skin ARMO, armature, mesh and BSA are
all correct and the whole static search was the wrong tree. The real defect is that nothing rebuilds
the player's 3D at cast time.

The armour strip is **kept** anyway: it matches the host's archetype, Wildshape was verified working
with it in place, and removing it at the same time as adding the real fix would change two variables
at once. It is belt-and-braces, not the diagnosis. We record and remove exactly the worn armour
rather than calling `UnequipAll()`, because `UnequipAll` would also strip weapons — which upstream
deliberately keeps for Wildshape — with nothing to put them back.

## The fix that worked

The script forces the player's 3D to rebuild after the race change.

Upstream does try — `ForceFirstPerson()` early, `ForceThirdPerson()` late — and Wildshape survives on
that while Force of Nature does not. The difference is what each has to load: Wildshape reuses
`SkinReinDeer`, already resident, whereas Force of Nature needs a 7.2 MB mesh out of the BSA. The
camera toggle fires before it has streamed in. So the script now waits `TVR_RedrawDelay` (0.5 s) and
calls SKSE's `QueueNiNodeUpdate()`, the direct equivalent of what a reload does.

`GetWornForm` and `QueueNiNodeUpdate` are **SKSE** functions; they are in the SKSE tree, not the
vanilla one, so the SKSE tree must precede vanilla on `-i` or the compile fails to resolve them.
A correct build is **5712 bytes**.
`src/Triumvirate/tools/verify-druid-transformations.ps1` asserts the shipped `.pex` is ours by
looking for `QueueNiNodeUpdate` inside it — `build.ps1` fails on a *missing* `.pex` but cannot detect
a stale one, and a stale one here silently reintroduces the invisibility.

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
