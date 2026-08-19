# Regenerating the Biggie Traits conversion

`src/BiggieTraits/BiggieTraitsESP/` is **Shazdeh's** plugin with our changes applied. It is
**committed in full** so CI can build it, but it is *derived* — these scripts are how it was
produced, and how it gets reproduced against a new Biggie Traits version.

> "Biggie Traits" is the mod's name, not the author's. The package itself carries no author string —
> `Traits.dll` still has the unfilled CommonLibSSE template placeholder `AUTHOR_NAME` — so do not try
> to infer the credit from the filename, as an earlier pass here did. The author is **Shazdeh**, who
> also wrote B612, which is why this mod depends on that otherwise-niche UI library.

## Reproducing it

Re-serialize the stock plugin, then **run `set-header.ps1` first** — it stamps form version 1.70 and
the credit. Spriggit writes `Author: DEFAULT` and no `Stats` block, and Mutagen's default form
version is **1.71**, so skipping that step rebuilds the plugin invisible to Enderal with no error
anywhere. Then run the numbered scripts in the order below.

Every one asserts what it changed and throws on zero matches (CLAUDE.md guardrail 11), and every one
is idempotent, so a re-run on an already-converted tree reports "already applied" rather than
corrupting it.

## Why this is a replacement plugin

Two independent reasons, and only the second one still stands on its own:

**1. Form version.** Stock `Biggie Traits.esp` is `HEDR` 1.71, which Enderal's 1.5.97 engine
silently refuses. This build is **1.70**, so it loads with or without BEES.

**2. Content.** Far more of the mod than the header is wrong for Enderal — see the tables below.
This is the reason that would still justify a rebuild even if form version were free.

### BEES, and why there is no B612 conversion here

`b612.esp` — the UI library supplying the trait-selection menu — is **also 1.71**, and
`b612.psc` resolves everything through `Game.GetFormFromFile(0x800, "b612.esp")`. When the engine
skips that plugin the lookup returns `None` and every B612 menu fails silently, so Biggie Traits
would load and be unusable.

A B612 conversion was written for that reason and then **deleted**, because
**Backported Extended ESL Support (BEES)** by Nukem hooks the form-version read and loads 1.71
plugins on 1.5.97. Verified by direct A/B in `thepath` on 2026-08-05: BEES on, stock B612, traits
selectable and the Witcher potion UI working; BEES off, same stock B612, menu unusable.

Requiring BEES beats shipping a rebuild of someone else's mod — no permissions burden, and no
obligation to re-convert on every B612 update. **Use B612 exactly as its author ships it.**

Note the asymmetry: this plugin stays at 1.70 anyway, because that costs nothing and means only the
*dependency* needs BEES rather than the mod itself.

## Order — 06 must run BEFORE 03

| # | Script | Does |
|---|---|---|
| 1 | `01-cut-homeowner.ps1` | Removes the Homeowner trait, including the whole `Cells/` tree. That tree is **all 11 of the plugin's overrides of a master**, so after this the plugin overrides nothing at all |
| 2 | `02-cut-homeless-traits.ps1` | Removes the 8 traits whose mechanics have no target in Enderal — Master of Destiny, Master of One, Disbeliever, Way of the Voice, Dovah Tinvaak, Addict, Skilled, Autodidact |
| 3 | `06-repair-kept-traits.ps1` | Repoints the Angler's summoned crabs to Enderal's own, cuts Good Natured, and strips Bad Natured's Divine-amulet effect. **Run before 03**, because it deletes records that 03 then has to prune out of the driver lists |
| 4 | `03-prune-references.ps1` | Repairs every reference left pointing at a deleted record, then **fails if any dangling internal reference survives**. This is the step that decides whether the cut was safe |
| 5 | `07-enderal-flavour.ps1` | Rewrites the four strings that are factually wrong in Enderal, and drops Pacifist's now-always-true Atronach condition |
| 6 | `04-clear-dlc-references.ps1` | Clears the last three references into `Dawnguard.esm` — a diet-list entry, two explosion sounds, one hit shader |
| 7 | `05-drop-dlc-masters.ps1` | Drops the three DLC masters from the header. Guards first: it refuses to run while any DLC reference remains |
| 8 | `08-assemble-package.ps1` | Copies the surviving scripts and assets into `src/BiggieTraits/`. Which scripts survive is **derived** from the record set, not listed by hand |
| 9 | `09-rewrite-configs.ps1` | Rewrites the KID and SPID inis to only what exists in Enderal, deletes the FLM ini, trims the MCM |
| 10 | `10-riverville-trigger.ps1` | Adds the conditioned ability that opens the trait menu on entering Riverville. Order-independent; run it any time after 03 |

## How the trait menu opens

**Stock Biggie Traits never opens the menu by itself.** `Traits_Quest` grants
`Traits_SelectionSpell`, a **Power** on the Voice equip type, which the player casts by hand. That
is a poor fit for Enderal — the Voice slot carries Meditate and the talent powers from the first
minutes — and a worse one with **Skip Intro SE**, which skips the prologue and drops a fresh
character at `SonnenkuesteTempelausgang` with no prompt at all.

`10` adds `ZP_Traits_RivervilleTriggerAb` (`000DA9`) to the same alias: a constant-effect ability
whose single script effect is gated on `GetInCurrentLoc FlusshaimLocation`. Walk into Riverville and
the effect starts, `Traits_PickTraitScript.OnEffectStart` opens the menu, and that script's existing
`Traits_Quest.Stop()` tears the alias down — removing the new ability *and* the old power. **No new
Papyrus**; it reuses the mod's own script and copies the archetype from the mod's own
`Traits_AnglerAb` + `Traits_Angler`.

The manual power is deliberately kept as a fallback until the automatic trigger is confirmed in
game. The end of `10-riverville-trigger.ps1` says exactly what to delete to drop it.

Two facts that make the condition right, and are easy to get wrong:

- Riverville is **`FlusshaimLocation 032706`** — Enderal's EditorIDs are German, so searching for the
  English town name returns nothing. 13 exterior cells in `Vyn` carry that Location, including
  `FlusshaimEingang` (the town entrance), plus every interior.
- The condition type is **`GetInCurrentLocConditionData`**, which Enderal uses **221 times**.
  `GetInCurrentLocation` — the name that looks right — appears **zero** times and is not what Mutagen
  emits.

`00-common.ps1` holds the shared helpers; `set-header.ps1` is unnumbered because it runs before the
sequence rather than inside it. Every script asserts what it changed and is safe to re-run.

## What the conversion decided, and on what evidence

Everything below was measured against `reference/base/`, not inferred from a name.

| Cut | Measurement |
|---|---|
| Homeowner | The five Skyrim city house cells are **absent entirely**, as are all 31 placed refs its enable/disable lists drive |
| Master of Destiny | **0/13** standing stones, **0/15** stone effects |
| Disbeliever | **1/12** Divine shrines survive |
| Way of the Voice / Dovah Tinvaak | **3/18** non-hostile shouts survive |
| Addict | **0/5** skooma items |
| Skilled / Master of One | Drive `Game.ModPerkPoints`. Enderal uses its own `TalentPoints` (`05BCFA`) and a custom skill menu; **no Enderal script touches vanilla perk points**. Master of One also injects into `StatsMenu`, which Enderal replaced |
| Autodidact | Hangs off `RegisterForSkillIncrease`; Enderal has no learn-by-doing |
| Good Natured | All three of its **benefits** are gated on wearing an Amulet of the Divines. Only its ungated `ModSpellMagnitude x0.75` penalty survived — a purely negative trait |

Kept, with evidence they work:

| Kept | Measurement |
|---|---|
| Angler | Salmon activators **4/4**. Crabs repointed to `_03E_Crab` `0164C4` and `_05E_KingscrabNormal` `01722B`, both on `MudcrabRace` `0BA545`, which 5 Enderal NPCs use |
| Druid | `SprigganRace` (7 NPCs) and `SprigganMatronRace` (1) are live |
| Bane of the Wicked | Keys on `ActorTypeUndead` and `ActorTypeDaedra`. **Both fire** — 19 Enderal races carry the undead keyword (`DraugrRace` alone is on 94 NPCs) and 8 carry the daedra keyword, including Enderal's own `_00E_OorbayaRace` and `_00E_StoneGolemRace` |
| Pacifist | Its Atronach clause compares equal to 0 — "does *not* have the Atronach Stone" — so in Enderal it is always true and the trait works |
| Bad Natured | Its perk is entirely sneak-based and needs nothing from Skyrim |

## The trap worth remembering

Good Natured and Bad Natured gate on an OR-group of the nine Amulets of the Divines. Eight resolve
to nothing in Enderal — but **`0C891B` resolves to `_04E_30_Unique_SongOfTheWinter`**, an unrelated
Enderal unique weapon. Left alone that is not a dead condition, it is a live bug: equipping that one
weapon would fire effects meant for a Divine amulet. Resolve every external FormKey, not just the
overridden ones.

## What the release ships

**Only what the conversion changed** — the rebuilt `Biggie Traits.esp`, the two rewritten
distribution inis and the trimmed MCM config. Five files. Install Shazdeh's original mod first, then
this over it, exactly the way the Apocalypse release works.

Everything third-party and unmodified is deliberately left out of both the archive and this public
repo: `Traits.dll` (915 KB), the SWF menus, the translations and the `.pex` set. We do not have the
author's permission on file to redistribute them, and nothing about the conversion needs us to.

`08-assemble-package.ps1` still builds a **complete** Data-layout folder under `src/BiggieTraits/`
for local testing and `mod-deploy` — that part is gitignored. So there are two shapes: the full one
you test with, and the overlay one you publish. If permission is ever confirmed and a self-contained
archive is wanted, re-add the `Interface`/`SKSE`/`Scripts` entries to the release's `assets` in
`build/manifest.json` and drop the matching `.gitignore` lines.

The 28 `.pex` for cut traits are simply left in place from the original install. Nothing references
them, so orphaned scripts are inert. The stock `Biggie Traits_FLM.ini` also survives an overlay
install; every line in it is dead in Enderal, which is harmless — delete it if you want the log
quiet.

## Dependencies

All checked with the export-table test on 2026-08-05: an SE-era 1.5.97 SKSE calls
`SKSEPlugin_Query`; an AE-only build exports just `SKSEPlugin_Version`.

| Requirement | Note |
|---|---|
| **BEES** (Backported Extended ESL Support) | **Required** — for B612, not for this plugin. Without it B612's menus silently do nothing |
| **B612** | Stock, unmodified. Do not convert it |
| **KID** | **Install the FOMOD's `SE/` folder.** Its `AE/` DLL exports only `SKSEPlugin_Version` and will not load on 1.5.97 |
| MCM Helper | 1.3.0 works with this mod's trimmed config. If updating, go to **1.6.2** — **1.5.0 is AE-only** and would take every MCM in the list down with it |
| powerofthree's Papyrus Extender | SE build; `RegisterForSkillIncrease` / `RegisterForLevelIncrease` signatures confirmed against what the scripts call |
| PapyrusUtil, SPID | SE builds |

**FormList Manipulator is NOT required.** Every line of the stock FLM ini was dead in Enderal, so
`09` deletes the file rather than shipping it.

### MCM config: two gates that both reject the whole file

MCM Helper validates the config before looking at its contents, and the stock file trips two checks
on older builds. `09` removes both, and neither is needed by the trimmed config:

| Key | Symptom |
|---|---|
| `$schema` | `Invalid key: $schema` → `Failed to parse config for Biggie Traits` |
| `minMcmVersion: 13` | `Config requires MCMHelper plugin version: 13` → same failure |

`$schema` is an editor-only hint. The `13` was there for the Homeowner and Autodidact pages this
conversion removed — every key and control type the remaining six entries use (`slider`, `toggle`,
`input`, `header`, `valueOptions`, `sourceType`, `ModSettingInt/Float/String`, `cursorFillMode`) is
present in MCM Helper 1.3.0's own binary. Note this never affected the trait menu: settings values
come from `settings.ini` through a separate store that loads fine either way.
