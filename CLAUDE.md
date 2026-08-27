# Enderal Mods — Spriggit Workspace Guide

> **This file is the most valuable thing in the repo.** It is what a future session reads instead of
> re-deriving these conventions from scratch. When you learn something the hard way — a FormID
> allocation, a record shape that didn't work, a compile import you needed — write it here.
>
> Facts below marked **[verified]** were checked against this machine's actual Enderal install or
> toolchain on 2026-08-01. Facts marked **[upstream]** come from Mutagen/Spriggit/SureAI source or
> documentation. Anything unmarked is convention, not measurement — treat it as changeable.

## What this is

This is a workspace for authoring **mods for Enderal: Forgotten Stories (Special Edition)** — any
shape they come in: bugfix patches, compatibility patches, ports of Skyrim SE mods, and full
**replacement plugins** that rebuild a third-party mod for Enderal's engine. Each one is developed,
built and released from here, alongside the reference documentation that records how Enderal itself
works.

It is not a modlist and not tied to one. A mod here should be useful to anyone running Enderal SE.

Plugins are decompiled to YAML, edited as text, and re-packed to `.esp`.
**Never hand-edit binary plugins — edit the YAML.**

- Game: **Enderal: Forgotten Stories (Special Edition)**, running on the SkyrimSE engine.
- Spriggit game release: **`EnderalSE`** — *not* `SkyrimSE`. See "Why EnderalSE" below.
- Spriggit package/source: `Spriggit.Yaml.Skyrim`
- Spriggit CLI version: **`0.40.0` — deliberately pinned, do not upgrade** (see below).
- CLI path + all tool paths: `.claude/config/tools.json` (gitignored; see Tooling config below).

### Why `EnderalSE` and not `SkyrimSE`

`GameRelease.EnderalSE` is a real Mutagen release (value `6`), and `GameCategory.cs` maps
`GameRelease.EnderalSE => GameCategory.Skyrim`, which is why the **Skyrim** serializer package
still handles it. **[upstream]** What differs is the implicit **base-master set**:

```csharp
// Mutagen.Bethesda.Core/Plugins/Implicit/Implicits.cs
EnderalSE = SkyrimSE with { BaseMasters = new ImplicitModKeyCollection(SkyrimSE.Listings.And(enderal)) };
//   where enderal = ModKey.FromFileName("Enderal - Forgotten Stories.esm")
```

So under `EnderalSE`, `Enderal - Forgotten Stories.esm` is treated as an implicit base master
alongside the five Bethesda ones. Under `SkyrimSE` it is not, and a patch that overrides Enderal
records is handled as though it depended on an ordinary third-party mod. **Keep
`.spriggit`, `spriggit-meta.json` and `tools.json`'s `spriggit.gameRelease` all reading
`EnderalSE`.**

Mutagen also resolves the load order from `%LOCALAPPDATA%\Enderal Special Edition\plugins.txt` for
this release **[upstream]**, which is the correct file on this machine **[verified]**.

**`--GameRelease EnderalSE` is confirmed working end to end with Spriggit CLI 0.40.0. [verified]**
Every plugin in `reference/base/` was serialized with it; the CLI picks up the repo-root `.spriggit`
(`Release = EnderalSE`), resolves the `Spriggit.Yaml.Skyrim.0.40.0` entry point, and its built-in
correctness check round-trips the result back to a plugin. The three-tree import order is likewise
confirmed by compiling real Enderal scripts (`_00E_TalentLibrary`, `_00E_Game_TalentControlSC`,
`dgintimidateplayerscript`) clean against `reference/base`. **[verified]**

> **Why Spriggit 0.40.0 is pinned.** Spriggit **0.41.0 silently corrupts leveled-list entries that
> carry COED owner ExtraData**, verified 2026-07-31 and reverted. Its deserializer throws a
> `NullReferenceException` on the 0.40 shape (`MutagenObjectType: NoOwner` + `RawOwnerData`), and its
> serializer rewrites that as `UntypedOwner` + FormKeys while **dropping the next entry's `Data:`
> block** — an entry vanishes from the built plugin with no error. There is no YAML workaround: the
> `0xFFFFFFFF` "no variable" sentinel cannot survive FormKey encoding and returns as `0x04FFFFFF`, so
> even a hand-corrected record builds a different plugin.
>
> This bites this workspace specifically: **loot/vendor/distribution work is exactly the
> leveled-list-heavy records that trip it.** Before ever unpinning: confirm the bug is fixed upstream, grep the tracked YAML for
> `MutagenObjectType: (No|Untyped|Typed)Owner` and `RawOwnerData`, and prove the upgrade by
> rebuilding every `.esp` and comparing SHA-256 against the previous release's. A clean build on a
> repo with no such record proves nothing. 0.41.0 also requires the **.NET 10 SDK** (its serializer
> package ships `tools/net10.0` only), failing with a `DotnetToolSettings.xml was not found` error
> that never mentions .NET.

## Enderal ground truth

Everything in this section was read off the installed game, not recalled. Re-verify with the same
commands if the install moves or updates.

**Install** — Enderal SE is a *separate Steam app* with its own copy of the engine; it is not a mod
folder inside Skyrim SE. On this machine:
`C:/Gaming/steamapps/common/Enderal Special Edition` (version **2.0.12.4**). **[verified]**

**Engine / SKSE version.** The game folder ships `skse64_1_5_97.dll` — Enderal SE is pinned to
**SSE 1.5.97**, not 1.6.x. **[verified]** Every SKSE plugin (`.dll`) in the list must be a **1.5.97
(“Special Edition”, pre-AE)** build. A 1.6.640/AE build loads nothing and usually takes SKSE down
with it. This is the single most common source of "the list doesn't launch" reports.

**Masters.** `Enderal - Forgotten Stories.esm` declares exactly **two** masters — `Skyrim.esm` and
`Update.esm`. **[verified]** (Read from the TES4 header: two `MAST` subrecords, then `ONAM`. Author
`Niseam`, HEDR version 1.7, flags `0x81` = ESM + Localized.)

> **Do not master the DLC — they are empty stubs.** `Dawnguard.esm`, `HearthFires.esm` and
> `Dragonborn.esm` sit in Enderal's `Data/`, but they are **not** in `plugins.txt`, **not** mastered
> by Enderal, and **not the real DLC**: they are 44 KB, 80 bytes and 44 KB respectively, and
> serializing them yields **1–2 records each**. **[verified]** `HearthFires.esm` at 80 bytes is a
> bare TES4 header with no content at all. Enderal ships them only so the SSE engine finds the
> filenames it expects.
>
> Mutagen's *implicit* base-master list for `EnderalSE` does include them **[upstream]**, so Spriggit
> will not object if you add one. There is nothing in them to reference anyway, so don't. Compare
> `reference/base/Dawnguard-stub/` with `reference/base/EnderalFS/` if you ever doubt it.
>
> **But the engine DOES load all three stubs, always, whether or not `plugins.txt` lists them.**
> **[verified 2026-08-02]** — read straight out of a running game's plugin table via a Crash Logger
> dump on a profile that never enabled them:
>
> ```
> PLUGINS: Light: 13  Regular: 31  Total: 44
>   [ 0] Skyrim.esm   [ 1] Dawnguard.esm   [ 2] HearthFires.esm
>   [ 3] Dragonborn.esm   [ 4] Update.esm   [ 5] Enderal - Forgotten Stories.esm
> ```
>
> Corroborated independently by the plugin array inside a `.ess` save. So the older claim here — that
> a plugin mastering a DLC "fails to load" and that users must tick the stub — was **wrong**, and it
> shipped in a patch's FOMOD before anyone tested it. A third-party mod that masters `Dragonborn.esm`
> loads in Enderal with no user action at all; its references into the stub simply resolve to nothing.
> Note also that the engine's real order puts the DLC **before** `Update.esm`, which is not the order
> `loadorder.txt` shows.

**Stock load order** (`%LOCALAPPDATA%\Enderal Special Edition\plugins.txt`) **[verified]**:

```
*Enderal - Forgotten Stories.esm
*SkyUI_SE.esp
```

SkyUI is **built into Enderal**, not an add-on. Do not let the list install a second copy.

**Archives.** Enderal's own content is in `E - *.bsa`; voices in `L - Voices.bsa`; the vanilla
`Skyrim - *.bsa` are also present. **[verified]**

| Archive | Holds |
|---|---|
| `E - Meshes.bsa`, `E - Textures1.bsa`, `E - Textures2.bsa` | Enderal meshes/textures |
| `E - Misc.bsa` | interface, **scripts** and misc |
| `E - Sounds.bsa`, `L - Voices.bsa` | audio, voiced dialogue |
| `E - Update.bsa` | later-patch overrides — **loads last, so it wins** |
| `Skyrim - *.bsa` | untouched vanilla assets Enderal still uses |

**No Creation Kit and no Papyrus compiler ship with Enderal.** **[verified]** Both come from an
ordinary Skyrim SE install (`skyrimSeRoot` in `tools.json`). They are the correct tools — Enderal SE
*is* SSE — you just point them at Enderal's `Data`.

## Tooling config (no hardcoded paths)

All tool paths and per-machine settings live in **`.claude/config/tools.json`** (gitignored;
template at `tools.example.json`). Skills load it via `.claude/config/tools.ps1`, which exposes
`$Tools` (e.g. `$Tools.spriggitCli`, `$Tools.papyrusCompiler`, `$Tools.papyrusSource.enderal`,
`$Tools.xedit`) and an `Assert-Tool` guard. **Never reintroduce a hardcoded path into a skill —
change the config instead.**

Note that `gameRoot` is **Enderal's** folder while `skyrimSeRoot` is the **Skyrim SE** folder. They
are separate installs, and several steps need both.

- **An Enderal modlist** (a Wabbajack list, say) installs a full MO2 instance — Enderal copy, mods
  and tools — that can be hundreds of GB. If you keep one under the repo for testing, it is
  gitignored (`/modlist/`, `/downloads/`); point `tools.json` at it wherever it lives.
- With or without a modlist, fill `tools.json` by hand from `tools.example.json`.

## Workflow (round-trip)

```
.esp/.esm  ──serialize──►  YAML (committed)  ──deserialize──►  .esp/.esm
                 ▲                                                  │
                 └──────────── you edit the YAML ◄──────────────────┘
```

Serialize/deserialize commands: see `README.md`. After editing YAML, deserialize and load the plugin
in xEdit (**in `-EnderalSE` mode**) to verify before shipping.

## Folder map

```
src/                       # EVERY mod lives here — one folder per mod
  <PatchName>/
    <PatchName>ESP/        # Spriggit YAML — COMMITTED, source of truth
    Scripts/source/*.psc   # Papyrus source — COMMITTED
    Scripts/compiled/*.pex # COMMITTED via a .gitignore exception (CI can't compile Papyrus)
    tools/*.ps1            # only for REPLACEMENT releases — the generators that rebuild the tree
build/                     # build.ps1 + manifest.json (+ a committed FOMOD tree per release that has
                           #   one - none currently do; releases carry "fomod": false)
arch-docs/                 # Enderal reference docs, authoring guide
reference/base/            # gitignored — Enderal/vanilla decompiles + script source, LOOKUP ONLY
reference/mods/            # gitignored — third-party Enderal mods, serialized for lookup
reference/mods/EGO/        #   `-- EGO's .esp + its loose scripts; documented in arch-docs/EGO/
modlist/                   # gitignored — an installed MO2 instance for testing, hundreds of GB
papyrus-source/            # gitignored — spare slot for unpacked .psc trees (see reference/base)
```

> **Two shapes of release live here.** Most are **patches**: a small plugin of overrides that masters
> the mod it fixes. A few must be **replacements**: the third-party plugin itself, rebuilt with our
> changes and shipped under its *original filename* so its BSAs keep loading. `Apocalypse` is a
> replacement, forced by the form-version ceiling below — its `src/Apocalypse/ApocalypseESP/` holds
> **all ~3,890 of Enai's records**, not just our edits, because that is what the build deserializes.
> A replacement is only legitimate when the author's permissions allow modification and re-upload,
> and it must ship credit in the plugin header, the FOMOD and the mod page. Its `tools/` folder holds
> the scripts that regenerate the tree against a new upstream version — without those, an update
> means redoing the analysis from scratch.

`src/` is the only place mod content goes, and it holds as many mods as you like. Each gets its own
`src/<PatchName>/` folder and its own `build/manifest.json` release entry; the `/mod-new-plugin`
skill sets both up.

### What's in `reference/base/` (built 2026-08-01, ~0.9 GB, gitignored)

Regenerate any of these with `/spriggit-decompile-reference`; the script trees are plain unzips.
**Grep these instead of guessing a FormKey or a script signature.**

| Folder | Source | Contents |
|---|---|---|
| `Skyrim/` | `Skyrim.esm` | **87322 records — this is BASE ENDERAL, not vanilla Skyrim.** Start here for base-game content |
| `EnderalFS/` | `Enderal - Forgotten Stories.esm` | 14061 records across 86 types — the FS expansion, overriding the above |
| `Update/` | `Update.esm` | 404 records |
| `SkyUI_SE/` | `SkyUI_SE.esp` | 8 records (SkyUI is built into Enderal) |
| `Dawnguard-stub/`, `Dragonborn-stub/`, `HearthFires-stub/` | the DLC ESMs | **1–2 records each — they are empty stubs** (see below) |
| `SkyrimReal/`, `UpdateReal/`, `DawnguardReal/`, `HearthFiresReal/`, `DragonbornReal/` | the **real** Bethesda masters from `skyrimSeRoot` | 853721 / 14032 / 93218 / 17480 / 176956 records. **What Bethesda actually had at a FormID** — the other half of every port audit (see below) |
| `EnderalScripts/source/scripts/` | `ScriptsEnderal.zip` | **5029 real `.psc`** from SureAI — not decompiles |
| `SKSEScripts/` | `Data/Source/Scripts` | 74 SKSE-extended vanilla types |
| `VanillaScripts/Source/Scripts/` | Skyrim SE `Scripts.zip` | 14301 `.psc` **plus `TESV_Papyrus_Flags.flg`** |

`tools.json`'s `papyrusSource` points at the three script trees here, so the compiler and the
lookup copies are the same files — there is no second copy to drift.

> **Serialize the REAL Bethesda masters too — a dead FormID is an opaque hex string without them.**
> **[verified 2026-08-24]** `reference/base/Skyrim/` tells you what Enderal has; `SkyrimReal/` tells
> you what the ported mod's author *meant*. You need both to pick a substitute, and the pair is what
> separates the three states a ported reference can be in: **dead** (nothing at that FormID),
> **renamed** (Enderal kept the record under its own name — `MineOreBlackreach01` is
> `_00E_MineOreShadowsteel`), and **drifted** (a completely different record — the live-bug class).
> On Triumvirate this turned 311 anonymous dead FormKeys into 311 named records with **zero**
> unresolved, and isolated 15 drifted references out of 1462 survivors. Serialize them with
> `/spriggit-decompile-reference` from `skyrimSeRoot`; `Dawnguard.esm` fails Spriggit's round-trip
> check on one LZ4-compressed NPC record but its tree is complete and correct for lookup.
>
> **`reference/base/Skyrim/` is lookup-only and cannot be rebuilt.** Spriggit 0.40.0 serializes it
> fine but **fails its own round-trip check**: `Skyrim.esm`'s NavigationMeshInfoMap (NAVI) record has
> a **null FormKey**, so Spriggit writes it as `NavigationMeshInfoMaps/Null.yaml` with no `FormKey:`
> line, then on read-back parses the next line as the FormKey and throws
> `Malformed FormKey string: 89103`. **[verified]** The serialized tree is complete and correct for
> grepping — we never deserialize a reference tree — so this is a caveat, not a problem.
>
> **Enderal's own NAVI record is unaffected**: it has a real FormKey
> (`000802:Enderal - Forgotten Stories.esm`) and `EnderalFS/` passed its round-trip check. **[verified]**
> That matters because it means navmesh-adjacent bugfix patches on Enderal *are* buildable. Only the
> null-FormKey case breaks, and only in `Skyrim.esm`.

**An empty `build/manifest.json` is legal.** With `"releases": []` the build reports "nothing to
build" and exits 0 rather than failing, so the repo stays green even with nothing to ship. Today it
carries four releases — `Apocalypse - Enderal Patch`, `Relentless Sword - Enderal Conversion`,
`Biggie Traits - Enderal Conversion` and `Triumvirate - Enderal Conversion`.

## Guardrails — how to work in this repo

These are distilled from real failures in this workspace's lineage. They cost test cycles to learn.

1. **Ground-truth before claiming.** Do not conclude a patch is or isn't needed, or that a record
   does what its name suggests, from the name alone. Read the serialized record, trace the
   FormKeys, and **show the evidence alongside the verdict**. If a mechanic depends on a third-party
   mod's compiled script, read that script's decompiled source — data-driven parts extend to your
   records, hardcoded index checks do not.
2. **Assume nothing transfers from Skyrim.** Enderal reuses the engine and almost none of the
   design. Progression, crafting, lighting, economy and the perk UI are all Enderal's own (see
   "How Enderal differs" below). A pattern that is correct for Skyrim modding is a *hypothesis* here
   until you have read Enderal's record or script.
3. **Prefer a proven archetype to an invented mechanism.** Read
   `arch-docs/enderal-record-patterns.md` first. The engine fails silently: an inert record produces
   no error, so an invented mechanism costs a full build-deploy-launch-test cycle to disprove.
4. **Copy records verbatim; never retype hex.** When basing a record on an existing one, copy the
   file and edit the fields that differ. Hand-transcribing `Data:` blobs has produced odd-length hex
   that fails the build, and dropped array entries that fail silently. Prefer a script over
   retyping. Re-check array lengths after any edit.
5. **A patch's job is to forward, not to author.** The commonest patch bug is not a wrong value —
   it is an override that carries *your* change and silently reverts someone else's. Before
   overriding a record, look at every plugin in the list that already touches it and confirm the
   winning version of every field you are not deliberately changing.
6. **Ask for paths; don't hunt for them.** Install locations, modlist names, MO2 folders and mod
   names live in `tools.json` or in the user's head. Read the config or ask — filesystem-searching
   for them wastes time and lands on the wrong candidate.
7. **Verify the deploy target before blaming the records.** A mod in a wrongly-named MO2 folder is
   invisible; the game runs fine and the change simply isn't there. The `mod-deploy` skill checks
   this. Rule out "never loaded" before debugging "loaded but broken".
8. **A clean build is not a working patch.** Deserialize, xEdit and the Papyrus compiler all passing
   proves it *builds*. Only launching Enderal proves it *runs*. Say which of the two you have
   actually established.
9. **Recompile and re-commit `.pex` whenever a `.psc` changes.** CI cannot run the Papyrus
   compiler. `build/build.ps1` fails on a *missing* `.pex` but cannot detect a *stale* one.
10. **PowerShell 5.1 is the target** for build scripts and skills: `Set-StrictMode` is on, there is
    no `&&`/`||`, no ternary, no null-coalescing, and no built-in YAML parser. Write `-Encoding utf8`
    explicitly when a file will be read by other tools. Two further traps when bulk-editing YAML:
    - **The Spriggit YAML is CRLF, so `$` in a multiline regex does not match.** `'(?m)^Foo: bar$'`
      silently fails on `Foo: bar\r\n` because `$` anchors before `\n` and the `\r` is in the way.
      Use `(?=\r?$)` or drop the anchor. **[verified]** — this cost a full pass on the Apocalypse
      recipes and it fails *silently*, so always assert the replacement count and throw on zero.
    - `Join-Path` takes **two** arguments in 5.1; `Join-Path $a $b $c` is a parameter-binding error.
      Nest the calls.
11. **Bulk record edits should be scripted, verified by count, and re-validated after.** When a patch
    touches dozens of records, generate them from `reference/` with a script that *asserts* what it
    changed (entry counts before/after, every intended replacement matched at least once) and fails
    loudly otherwise. Then re-resolve every FormKey the patch emits against the serialized masters —
    that catches the dangling references xEdit would, without needing the mod installed. Note
    `000014:Skyrim.esm` (PlayerRef) is **absent from `reference/base/Skyrim/`** despite being valid
    and used by 77 of Enderal's own recipes, so allow-list it rather than chasing it. **[verified]**

12. **A replacement plugin's tree must be reproducible from its `tools/` alone — and the only
    way to know is to WIPE IT AND RE-RUN.** **[verified 2026-08-27]** `src/<Mod>/<Mod>ESP/` is
    committed in full but is *derived*; every conversion decision that lives only in the tree is
    invisible until an upstream version bump deletes it. Bumping Apocalypse 10.2.3 → 10.3.0
    found **four** such decisions, none of them recorded as a step:

    | Hand edit | How it presented |
    |---|---|
    | the `Enderal - Forgotten Stories.esm` master, added to the header by hand | **build failure** — Spriggit cannot map an FS FormKey without it |
    | three `Dragonborn.esm` references, deleted by hand | build failure, same reason |
    | an `ADDN` NodeIndex moved off an Enderal collision | **builds clean, ships wrong** — only its verifier caught it |
    | ~32 Elder Scrolls nouns in record groups the rename script never scanned | builds clean, ships wrong |

    The two that fail loudly are the lucky ones. The other two are the reason to re-run the
    verifiers after a regeneration and to diff the result against what you last shipped, record
    by record: a hand edit and an upstream change look identical in that diff, and only the
    generators tell you which is which. **When you fix a ported record by hand, the fix is not
    done until it is a script that asserts what it changed.**

    Two traps inside the re-run itself. A merge step with an "our edit wins" rule does almost
    nothing when run over an existing tree, so a regeneration means **deleting the tree first**.
    And a rename pass that scans a hand-picked list of record groups will report *"all renames
    matched"* while leaving every string in the groups it never opened — scan them all, and let
    the per-rename assertion prove each one landed.

## FormKey discipline

- **New** records use the patch plugin's own name as the FormKey suffix: `<hex>:<PatchName>.esp`.
- **Overrides keep the defining master's suffix** — that is how you tell at a glance which records
  you invented and which you are modifying:

  | Suffix | Means |
  |---|---|
  | `:Enderal - Forgotten Stories.esm` | a record Enderal itself created — **71%** of its records |
  | `:Skyrim.esm` / `:Update.esm` | a vanilla FormID. May be untouched vanilla, **or Enderal content sitting on an overridden vanilla record** — see below |
  | `:<SomeMod>.esp` | overriding a third-party list mod — check *its* load position |
  | `:<PatchName>.esp` | a record this patch invented |

> **`Skyrim.esm` in Enderal's Data folder is not Skyrim — it *is* base Enderal.** **[verified]**
> Enderal ships a wholesale replacement: **191,827,554 bytes** (vs 249,753,412 for the real SSE
> file), author `mcarofano` in the TES4 `CNAM` (not Bethesda), **12,223 `_00E_`-prefixed records**,
> **no Tamriel worldspace** — Enderal's overworld is `Vyn`. All nine base memory-tree perk FormLists
> (`BastionPerks` `06686B:Skyrim.esm`, …) live in it.
>
> So the two plugins are: **`Skyrim.esm` = base Enderal** (author `mcarofano`) and
> **`Enderal - Forgotten Stories.esm` = the FS expansion** (author `Niseam`). Of the FS plugin's
> 9566 records, **28.7% (2749) carry `:Skyrim.esm` FormKeys — that is FS overriding base Enderal**,
> not touching anything of Bethesda's.
>
> Consequences: `reference/base/Skyrim/` is **Enderal content, not vanilla lookup material**; a
> `:Skyrim.esm` suffix means "base Enderal"; and a FormID copied from a Skyrim wiki will not resolve
> to the same record. The engine-hardcoded IDs (`000014` PlayerRef, `000039` GameDaysPassed,
> `000010` MapMarker) are still safe. Full detail in
> [`arch-docs/enderal/plugin-architecture.md`](arch-docs/enderal/plugin-architecture.md).

- **Master order in `RecordData.yaml`** is load order:
  `Skyrim.esm`, `Update.esm`, `Enderal - Forgotten Stories.esm`, then any third-party plugin you
  override, in list order.
- **ESL (`Small`) plugins are constrained to FormIDs `0x800–0xFFF`.** Patches should almost always
  be ESL-flagged — a list carries a lot of them and the 254-plugin limit is real. Note that
  *overrides consume no new FormID*, so an ESL patch can override thousands of records and still
  only need a handful of the 2048 new-record slots.
- Allocate a **contiguous block per feature** for readable diffs.
- ALWAYS grep the whole workspace (your patch folders + `reference/`) for a hex FormID before
  assigning it — use the `formkey-check` skill.

### Allocations in use

Each mod's own ESL block. Overrides are not listed — they consume nothing. `Apocalypse` is a
*replacement plugin* rather than a patch and allocates in its host's space instead; the row says so.
An ordinary ESL-flagged patch takes `0x800–0xFFF`, as `RelentlessSword` does.

| Mod / plugin | Block | Contents |
|---|---|---|
| `Apocalypse` → **`Apocalypse - Magic of Skyrim.esp`** | `0x1C1E71–0x1C1E76` | **Not an ESL block.** This release *replaces* Enai's plugin rather than patching it (see the form-version ceiling above), so new records are allocated in **Apocalypse's own FormID space**, just past its highest own ID `1C1E70`. `1C1E71–75` `ZP_Apoc_Tomes_R000/R025/R050/R075/R100` — one LeveledItem per spell rank; `1C1E76` `ZP_Apoc_Scrolls`. ~3,890 records, full ESP, no ESL flag |
| `RelentlessSword` → **`Relentless Sword - Enderal.esp`** | `0x800–0x827` | `800–806` statics (1st-person models), `809–80F` weapons, `811–81F` forge + temper recipes (**johnskyrim's original offsets, preserved for traceability** — that is why the block has gaps and is not densely packed), `820–825` dismantle recipes (new here), `826` the crafting blueprint MiscItem, `827` its placed reference in Riverville Temple. 44 records, ESL-flagged. Overrides only `FlusshaimTemple 015282:Skyrim.esm` and `_00ETraderCraftingPlansC 148ABE:Skyrim.esm`, both forwarded from the **Forgotten Stories** versions |

> **`Enderal - Forgotten Stories.esm` survives as a declared master.** It is an *implicit* base
> master under `GameRelease.EnderalSE`, so there was reason to fear Mutagen would drop it from the
> written master list and leave `:Enderal - Forgotten Stories.esm` FormKeys dangling. It does not:
> `src/RelentlessSword/`'s small ESL plugin builds with `MAST Skyrim.esm` + `MAST Enderal - Forgotten
> Stories.esm`, and its `02F336` references resolve at master index **1**. **[verified]** So a patch
> may reference FS records freely — just declare the master and confirm it in the built header.

## Papyrus toolchain

Scripts go through extract → decompile → edit → compile → package. Use the matching skills; the
`papyrus-script-engineer` subagent handles decompiled-source cleanup and compile-error fixing.

**Tool paths:** all resolved from `.claude/config/tools.json` — do not hardcode.

| Step | Tool | Config key |
|------|------|------------|
| Extract `.bsa` | `bsab.exe`, or `BSArch64.exe` (see below) | `$Tools.bsab` / `$Tools.bsarch` |
| Decompile `.pex`→`.psc` | `Champollion.exe` | `$Tools.champollion` |
| Compile `.psc`→`.pex` | `PapyrusCompiler.exe` (from Skyrim SE) | `$Tools.papyrusCompiler` |
| Open Creation Kit | `CreationKit.exe` (from Skyrim SE) | `$Tools.creationKit` |

> **`bae.exe` has no usable CLI — do not reach for it.** **[verified]** It rejects `-e`,
> `--extract` and even `--help` ("Unknown option"); the `extract` string in the binary is a Qt slot
> name, not a command-line option. It is GUI/drag-and-drop only. When `bsab` is not installed, use
> **`BSArch64.exe unpack "<archive.bsa>" "<outdir>" -mt`** (bundled in xEdit's folder,
> `$Tools.bsarch`) — it is the reliable headless extractor here. Note it **requires the output
> directory to already exist** and fails with "Folder does not exist" otherwise.

### The import path is first-wins, and Enderal must be first

There are **three** Papyrus source trees in an Enderal setup, and **55 script names exist in both
Enderal's and Skyrim's** — `critter.psc`, `dgintimidateplayerscript.psc`, `dragonactorscript.psc`,
the `default*` handlers, and so on. Compile against the wrong copy and you get code built on vanilla
signatures that fails at runtime, not at compile time.

**All 55 differ from vanilla — not one is an accidental identical duplicate.** **[verified]** by
byte-comparing `reference/base/EnderalScripts` against `reference/base/VanillaScripts`. Two of them
are explicit `; DUMMY, DO NOTHING` stubs: `dgintimidateplayerscript.psc` and
`dgintimidatealiasscript.psc`, where Enderal has gutted the vanilla brawl/intimidate system down to
4 lines from 59. **[verified]** That is the concrete cost of getting the order wrong: compile
against vanilla's copy and you link in brawl logic Enderal deliberately deleted.

**The Papyrus compiler's `-i` path is FIRST-WINS. [verified]** — tested directly on this machine's
`PapyrusCompiler.exe` by putting a deliberately broken copy of a script in the first import dir and
a good copy in the second: with `-i="broken;good"` the compile **failed** on the broken copy; with
`-i="good;broken"` it **succeeded**. So the correct order is:

```
-i="<papyrusSource.enderal>;<papyrusSource.skse>;<papyrusSource.vanilla>;<importDirs...>"
```

> SureAI's own `How to modify Enderal scripts.txt` (inside `ScriptsEnderal.zip`) states the sources
> "must be loaded in the following order: Creation Kit scripts (Scripts.zip), SKSE scripts, Enderal
> scripts (ScriptsEnderal.zip)". That is **precedence** order — last one wins — describing the CK's
> source-folder list. It is the **reverse** of the `-i` order above. Both say the same thing:
> *Enderal's copy is the one that must be used.* Don't paste that readme's order into `-i`.

**Where the three trees come from** (unpack once; `papyrus-source/` is gitignored):

| Tree | Source | `tools.json` key |
|---|---|---|
| Enderal (~5000 `.psc`) | `<gameDataDir>/ScriptsEnderal.zip` → its `source/scripts/` | `papyrusSource.enderal` |
| SKSE (74 `.psc`) | `<gameDataDir>/Source/Scripts` — already loose in an Enderal install | `papyrusSource.skse` |
| Vanilla (~14300 `.psc`) | `<skyrimSeRoot>/Data/Scripts.zip` → its `Source/Scripts/` | `papyrusSource.vanilla` |

**Flags file.** `TESV_Papyrus_Flags.flg` ships only in the **vanilla** `Scripts.zip` — neither
Enderal tree contains one. **[verified]** It resolves off the `-i` path, so having vanilla on the
path is what makes `-f=TESV_Papyrus_Flags.flg` work.

**Enderal's own scripts are prefixed `_00E_`** (1257 of them). **[verified]** A script name starting
`_00E_` is Enderal's; treat it as third-party source you read but do not edit in place — patch by
adding your own script, not by shipping a modified `_00E_` file, unless overriding it *is* the fix
and you have said so in the patch's notes.

**Per-project import dirs** — persist in `tools.json`'s `importDirs` array (the `papyrus-compile`
skill appends them to `-i` after the three trees). Record each one here as you discover it:

| API / framework | Source `.psc` dir |
|-----------------|-------------------|
| _(none yet)_ | Add SkyUI/MCM, PapyrusUtil, etc. here when a patch's script needs them. |

### Creation Kit against Enderal

The CK is only needed for asset work and for the compiler binary — **all record editing here happens
in the Spriggit YAML**, so most sessions never open it. If you do:

- Use the **Skyrim SE** CK (`$Tools.creationKit`), pointed at Enderal's `Data`.
- `bAllowMultipleMasterLoads=1` must be set in `CreationKit.ini` (already set on this machine
  **[verified]**) — without it the CK refuses to load an ESP on top of an ESM chain.
- The CK's `sResourceArchiveList` lists the *Skyrim* BSAs; it does not know about `E - *.bsa`, so
  Enderal assets will be missing in the render window unless you add them.

## Testing

MO2 instances under `$Tools.modlistsRoot`, or a single instance at `$Tools.modlistRoot`.
Use the `mod-deploy` skill rather than copying by hand.

**xEdit must run in Enderal mode:** use a copy named `EnderalSEEdit.exe` or pass **`-EnderalSE`**.
**[upstream]** Plain SSEEdit mode reads the Skyrim game folder and INI and will not see Enderal's
plugins at all. Pass the switch yourself — there is no skill that does it for you.

> **A quest flag does not gate a quest script.** **[verified in-game 2026-08-07]** Clearing
> `Start Game Enabled` on a quest looks like the way to stop its script running, and it is not: the
> script's `OnInit` — and any `RegisterForSingleUpdate` inside it — still fires. Apocalypse's
> `WB_PopulateLists_Quest` was rebuilt with `DNAM` flags `0x0110` (`RunOnce` set, `StartGameEnabled`
> clear, read straight out of the binary), and a **brand-new game** still logged 685 ×
> `Cannot call AddForm() on a None object` from its `OnUpdate`.
>
> To stop a ported mod's script doing work, **make the work empty** — clear the FormLists it
> iterates, so `GetSize()` returns 0 — rather than trying to stop the script from running. And
> **find every entry point first**: 2 of Apocalypse's 206 compiled scripts mention `PopulateLists`,
> and the second was the MCM's "Repopulate" button driving the same loop over a *duplicate* set of
> six FormLists. Fixing only the obvious one leaves a button that reproduces the bug on demand.
> `grep` the mod's whole script set for the symbol before choosing where to cut.

### Papyrus logging: the INI that counts is MO2's, and the log lands in SKYRIM's folder

**[verified 2026-08-07]** Two separate traps, and together they make it look like Papyrus logging is
broken.

1. **MO2 profiles set `LocalSettings=true`**, so the game reads
   `<modlistRoot>\profiles\<profile>\Enderal.ini` — **not** the copy in
   `Documents\My Games\Enderal Special Edition\`. Enabling logging in the Documents copy does
   nothing. Set `bEnableLogging=1` **and `bEnableTrace=1`** in the profile INI's `[Papyrus]` section;
   without trace, `Debug.Trace` output — which is most of what a mod prints — is suppressed. Leave
   `bEnableProfiling=0`; it is a heavy frame cost.
2. **The log is written to `Documents\My Games\Skyrim Special Edition\Logs\Script\Papyrus.0.log`** —
   Skyrim's folder, the same place the SKSE and crash logs go, even though the INIs and saves live
   under Enderal's.

Turn both settings back to `0` afterwards; a long session produces a very large file.

### Crash logs are written to the SKYRIM SE folder, not Enderal's

**[verified]** Crash Logger SSE (and the other SKSE plugin logs — `skse64.log`, `EnderalSE.log`,
`po3_*.log`) land in:

```
C:\Users\<you>\Documents\My Games\Skyrim Special Edition\SKSE\crash-<timestamp>.log
```

**not** `…\My Games\Enderal Special Edition\SKSE\`, which holds only the INIs and saves. Looking in
the Enderal folder and finding nothing is what makes a crash look like it produced no log at all —
it did. Read the newest `crash-*.log` by mtime and check `Working Directory:` says Enderal before
trusting it.

Two fields to read first, before the call stack:

| Field | Means |
|---|---|
| `PLUGINS: Total: 0` | crashed **during** file loading — the data handler never populated. Suspect the plugin header/masters, not records |
| `PLUGINS: Total: <n>` with a full list | plugins loaded fine; it is a content or runtime problem |

The plugin list in a `.ess` save is a second, independent source for what the engine actually
loaded — useful when the game will not start at all.

---

# This repo

## What ships here

Enderal SE mods of any shape, each in its own `src/<ModName>/` folder with its own
`build/manifest.json` release entry. Three shapes recur:

| Shape | When | Example |
|---|---|---|
| **Patch** | A small plugin of overrides that masters the mod it fixes, or Enderal's own ESM. The default. | a bugfix or compatibility patch |
| **Replacement plugin** | The third-party plugin itself, rebuilt with our changes and shipped under its *original filename* so its BSAs keep loading. Only legitimate when the author's permissions allow modification and re-upload, and it must credit them in the plugin header and on the mod page. | `Apocalypse - Magic of Skyrim.esp` |
| **New content** | A plugin that adds rather than fixes — gear, a quest shortcut, a system. Held to the same bar: it should read as something Enderal could have shipped. | — |

Currently released:

| Mod | Plugin | What it is |
|---|---|---|
| `Apocalypse` | `Apocalypse - Magic of Skyrim.esp` | Enai Siaion's spell pack, converted for Enderal — form version lowered to 1.70, Elder Scrolls proper nouns renamed, and distribution rebuilt onto Enderal's own vendor and loot lists. A **replacement plugin**; see the form-version ceiling below for why it cannot be a patch |
| `RelentlessSword` | `Relentless Sword - Enderal.esp` | johnskyrim's *Relentless Sword SE* rebuilt for Enderal: clean masters (his plugin masters the three DLC stubs), shadowsteel-tier stats, blueprint + Handicraft-50 gating instead of a Skyforge recipe that could never fire, and FS-style dismantle recipes. **New content shipped as a standalone plugin, carrying no assets** — the player installs his mod for the meshes and disables his ESP |
| `BiggieTraits` | `Biggie Traits.esp` | Shazdeh's Fallout-style trait system, converted for Enderal — form version lowered to 1.70, DLC masters dropped, and the traits with no Enderal target removed (the five Skyrim city houses, standing stones, Divine shrines, shouts, vanilla perk points). 30 of 38 traits survive. A **replacement plugin**; its generators live in `src/BiggieTraits/tools/` |
| `Triumvirate` | `Triumvirate - Mage Archetypes.esp` | Enai Siaion's five mage archetypes (75 spells), converted for Enderal — DLC masters dropped, Elder Scrolls nouns renamed, and distribution rebuilt from a script that made 76 calls against absent Skyrim receivers onto ten Enderal merchant chests, with Expert/Master confined to Ark and the Undercity. A **replacement plugin** (its two BSAs are named after the plugin); generators in `src/Triumvirate/tools/`, still on `feat/triumvirate-conversion` |

> **B612 is deliberately NOT shipped here.** It is a dependency of Biggie Traits and its `b612.esp`
> is form version 1.71, so a conversion was written — and then dropped, because **BEES** loads the
> stock plugin unchanged (see the form-version ceiling below). Requiring an SKSE plugin the user
> already has beats maintaining a rebuild of someone else's mod forever. Use B612 as its author
> ships it.

### Where the documentation is

| Read this | For |
|---|---|
| **[`arch-docs/enderal/`](arch-docs/enderal/)** | **How Enderal actually works** — nine documents mined from the serialized plugins and SureAI's own source. Start with [`plugin-architecture.md`](arch-docs/enderal/plugin-architecture.md); [its README](arch-docs/enderal/README.md) indexes the rest |
| **[`arch-docs/EGO/`](arch-docs/EGO/)** | **How EGO works and how to patch around it** — the community's Enderal gameplay overhaul, 6203 overridden records. Start with [`patching-ego.md`](arch-docs/EGO/patching-ego.md) before any combat/loot/crafting patch |
| **[`arch-docs/Apocalypse/`](arch-docs/Apocalypse/)** | **What a real port broke and how it was found.** [`enderal-gap-audit.md`](arch-docs/Apocalypse/enderal-gap-audit.md) is the worked example of auditing a ported mod against Enderal's stripped `Skyrim.esm`; [`spell-test-matrix.md`](arch-docs/Apocalypse/spell-test-matrix.md) is what a generated per-item test checklist looks like |
| `arch-docs/enderal-record-patterns.md` | Record shapes that build clean and do nothing in-game |

By subject: combat patches start at [`arch-docs/enderal/combat.md`](arch-docs/enderal/combat.md),
visuals at [`visuals-and-world.md`](arch-docs/enderal/visuals-and-world.md), and anything touching
progression, potions or scripts at
[`progression-and-classes.md`](arch-docs/enderal/progression-and-classes.md) /
[`crafting-alchemy-economy.md`](arch-docs/enderal/crafting-alchemy-economy.md) /
[`scripting-and-actorvalues.md`](arch-docs/enderal/scripting-and-actorvalues.md). Three more cover
the content a patch places things *into*:
[`factions.md`](arch-docs/enderal/factions.md) (the 335+96 faction records, and why the lore
factions mostly do not exist as records — plus the German↔English glossary Enderal's EditorIDs
need), [`bestiary.md`](arch-docs/enderal/bestiary.md) (enemy families, the `_NNE_` tier system,
per-actor XP, and the fact that **nothing scales to the player**) and
[`world-and-dungeons.md`](arch-docs/enderal/world-and-dungeons.md) (the 22 real regions, the
abandoned Location/EncounterZone systems, interior-cell conventions, the map-marker dungeon census).

### EGO is the dominant conflict source in Enderal lists

`Enderal SE - Gameplay Overhaul.esp` (v1.93.1.0, author *Ixion XVII*) overrides **6203** records and
adds **974**. **[verified 2026-08-04]** It is in most Enderal load orders, and a patch from this repo
loads **after** it. Four facts that change how you write a patch, all documented in
[`arch-docs/EGO/`](arch-docs/EGO/):

1. **EGO is not `Localized`.** Every string on every record it overrides collapses from a
   multi-language `Values:` list to a single English `Value:`. So `['Name', 'Description',
   'Version2']` is the **null diff** — filter it out — and copying the FS/Skyrim version of a record
   EGO also overrides re-adds the `Values:` block, which is the tell that you copied the wrong source.
2. **`Player 000007:Skyrim.esm` carries 42 EGO perks.** That record *is* EGO's player ruleset.
   Overriding it without forwarding them deletes the mod's combat, economy, alchemy and mana rules
   while everything else still looks installed.
3. **61 records are injected**, not overridden — FormIDs in `Skyrim.esm`'s space that `Skyrim.esm`
   does not define (`ChaurusChitin 03AD57`, `DeflectArrows 058F68`, the Dragon Priest masks, six
   `DeathItem*` lists…). Referencing one means declaring EGO as a master.
4. **EGO rewrites all three blueprint vendor lists** (`_00ETraderCraftingPlansA/B/C`) — the exact
   records a new craftable-weapon patch needs — plus 123 other leveled lists, 99 GMSTs and 18 GMSTs
   it creates outright.

Before touching a record, `grep` its FormKey in
[`arch-docs/EGO/conflict-index.md`](arch-docs/EGO/conflict-index.md); if it is listed, build your
version from **EGO's** YAML file, not the master's.

## How Enderal differs (and what that breaks)

This is the section to read before assuming a Skyrim mod "just works". Each entry is a verified
mechanism plus the class of patch it invalidates.

> **Porting a Skyrim mod? Use the `skyrim-to-enderal-porter` subagent first**, before planning or
> authoring anything. It runs the kill-checks in order — form version, load-proof, SKSE build,
> masters, distribution, override collisions — and decides whether the mod is portable at all and
> whether it needs a *patch* or a *replacement plugin*. The first two checks take minutes and both
> have already cost this repo a full build-and-debug cycle when skipped.
>
> **For a spell or magic mod, follow it with `enderal-magic-porter`.** That one carries everything the
> Apocalypse port cost: the five renamed schools (Alteration is *Mentalism*, Illusion is *Psionics* —
> the intuitive pairing is wrong), rebuilding distribution when Enderal has no spell tomes at all,
> repricing onto a 20–350 range, making self-heals pay Arcane Fever, renaming the Elder Scrolls gods
> out of every string, and cutting the Daedra and Dwemer summons.

**Progression is not Skyrim's.** There is no learn-by-doing and no vanilla perk tree UI. Enderal's
*talents* are three-tier **Perks** paired with **WordOfPower** unlocks, read back via
`_00E_TalentLibrary.GetPlayerTalentLevel(Perk01, Perk02, Perk03)` and
`GetTalentLevel(Word01, Word02, Word03)`. **[verified]** The character sheet is a **custom menu** —
`_00E_Game_SkillmenuSC`, a script on a ReferenceAlias that registers for `"Journal Menu"` and draws
Enderal's own UI. **[verified]**

> **Consequence.** A combat mod that adds perks to vanilla perk trees puts them somewhere the player
> can never see or buy. Combat patches must hang new behaviour off Enderal's own perks/talents, or
> off keywords and combat styles, not off the vanilla progression UI.

**Lighting is wholly replaced.** SureAI's own readme: *"since Enderal changes all light settings, no
ENB preset made for Skyrim would produce adequate lighting in Enderal. Furthermore, ENB mods may
deactivate fadeouts in cutscenes, leading to visual bugs."* **[verified — quoted from
`enderal readme.txt`]**

> **Consequence.** For the visuals pillar, a Skyrim ENB/weather/lighting mod is a starting point, not
> a drop-in. Budget for an Enderal-specific reconciliation pass, and watch cutscene fades — they are
> a known ENB casualty and they are everywhere in Enderal's story.

**Skyrim mods need conversion, by the author's own statement.** *"Enderal uses its own master file
(ESM). Mods that were developed for Skyrim must be adjusted to it before they can safely be used in
Enderal."* **[verified — `enderal readme.txt`]** In practice a Skyrim mod that only edits
`Skyrim.esm` records may load, but Enderal has usually already overridden the record you care about,
and Enderal's copy wins or loses purely on load order.

**The five magic schools are renamed, not replaced.** Enderal keeps all five vanilla magic
ActorValues and only changes what they are *called*. **[verified]** — read off the `AlchFortify*`
magic effects' display strings in `reference/base/Skyrim/MagicEffects/`, and corroborated by
`_00E_BookMagicDisciplines*` and the `_00E_MagicSchool*` load screens:

| Vanilla `MagicSkill` | Enderal discipline | Higher school |
|---|---|---|
| Destruction | **Elementalism** | (an art of its own) |
| Conjuration | **Entropy** | Sinistra |
| Restoration | **Light Magic** | Thaumaturgy |
| Alteration | **Mentalism** | Thaumaturgy |
| Illusion | **Psionics** | Sinistra |

> Note the last two: **Alteration is Mentalism and Illusion is Psionics.** The intuitive pairing
> (Illusion→Mentalism) is wrong, and getting it backwards mis-files every spell in a magic patch.

> **Keep a ported spell's `HalfCostPerk` — it is the hook Enderal's talents already read.**
> **[verified 2026-08-24]** Enderal reuses **all 25 vanilla school perks** (`AlterationNovice00` …
> `RestorationMaster100`) as tier tags, and **14 of its own talent perks** — the Elementalist,
> Sinistrope, Thaumaturge and Affinity lines — key off them with
> `SpellHasCastingPerkConditionData`, the condition that asks *"is this spell's `HalfCostPerk` X?"*.
> `_00E_Class_Thaumaturge_P02_MentalNovice` is the worked example: `ModSpellCost × 0.7` for any
> spell tagged `AlterationNovice00`/`Apprentice25` or `RestorationNovice00`/`Apprentice25`.
>
> So the vanilla field a porter is most tempted to strip as "Skyrim progression cruft" is in fact
> what makes an Enderal mage's talent discounts apply to the ported spell. Set it to the right tier
> and leave it. All 126 of Triumvirate's `HalfCostPerk` references resolve untouched.

The consequence is good news for ported spell mods: a Skyrim spell's `MagicSkill`, magicka cost and
skill scaling all work unchanged in Enderal. What does *not* carry over is anything user-visible
that names a school — spell tomes, load screens, descriptions — because the player has never heard
of "the School of Conjuration". Enderal's own magic metaphysics vocabulary, for rewriting those
strings, is the **Sea of Eventualities** (mages "manifest an eventuality"), **Lost Ones** (its
undead), and the two higher schools above. All from `_00E_BookMagicDisciplines*`.

**Enderal-only systems to look for** before touching anything nearby (script names verified in
`ScriptsEnderal.zip`): Arcane Fever (`_00E_FS_AlchAddArcaneFever`), Phasmalism/Apparitions
(`_fs_phasmalist_controlquest`, `_00E_Phasmalist_*`), the affinity system inside
`_00E_Game_SkillmenuSC`, memory/learning points (`_00E_Lehrbuch_Plus1MemoryPointSC`,
`_00E_Lehrbuch_Plus2SkillPointsScript`), crafting books (`_00E_Handwerksbuch*`), and the
talent cooldown/control quests (`_00E_Game_TalentControlSC`, `_00E_Game_TalentCooldownSC`).

> **Enderal taxes healing MAGIC, not healing — so a ported healing spell is free money unless you tax
> it.** **[verified 2026-08-03]** Only 11 of base Enderal's 837 spells raise Arcane Fever and every
> one is a self-heal (the `_NNE_SpellBoon` and `_NNE_SpellFlashHeal` lines), plus FS's Mystical
> Panacea and two Boon scrolls. Nothing else in the game raises it — a master-tier damage spell costs
> zero, so a ported one costing zero is *correct*.
>
> **Enderal DOES have healing potions**, and none of them costs Fever: five tiers of
> `_NNE_Genesungstrank` (`01E` `0028C8` → `05E` `0028C9`, 36 → 160 HP over 4 s, 25 → 190 gold) plus
> `_00E_Medicine` `07071F`. **[verified]** So the design is a trade — potions are the finite,
> gold-priced heal and magic is the renewable one that costs Fever instead. This repo asserted the
> opposite ("Enderal has no healing potions") for a while, from an English-only name search;
> Enderal's EditorIDs are German and `Genesungstrank` displays as *"Health Potion (Cheap)"*. **Search
> `reference/base/Skyrim/Ingestibles/` by effect FormKey, not by English name.**
> Attach `11A4B6:Skyrim.esm` (`_00E_IncreaseArcaneFeverFFSelf`, FireAndForget/**Self**) as an extra
> effect item with `Magnitude` + `Duration: 1`; its script applies the Mental Expert reduction for
> you. Concentration casts need `106EA4` paired with FS's `02F42E` instead. Price against Enderal's
> own ceilings — **26 HP per fever point burst, 78 over-time** — and note that Enderal charges a
> *flat* cost per line, so HP-per-point improves with tier. **`11A4B6` is Self-delivery and has zero
> precedent on an Aimed spell across 370 non-Self spells**, so leech/drain heals cannot be taxed this
> way. Full mechanism and the worked example in
> [`crafting-alchemy-economy.md`](arch-docs/enderal/crafting-alchemy-economy.md#arcane-fever) and
> `src/Apocalypse/tools/09-arcane-fever-heals.ps1`.

**A ported Skyrim gear mod's recipes are the part most likely to be silently inert.** Enderal keeps
the crafting *plumbing* (bench keywords are vanilla — see
[`crafting-alchemy-economy.md`](arch-docs/enderal/crafting-alchemy-economy.md)) but not everything
around it. Two concrete traps, both found in Relentless Sword **[verified]**:

| Vanilla FormID | In Enderal | Consequence |
|---|---|---|
| `0F46CE` `CraftingSmithingSkyforge`, `0F46D1` (Companions global) | **Do not exist** — no record at either ID in `Skyrim.esm`, `Update.esm` or the FS ESM | A Skyforge recipe can never appear. Repoint to `CraftingSmithingForge` `088105`. |
| `05218E` — vanilla's Arcane Blacksmith | `_00E_Class_Phasmalist_P04_B_ArcaneSmith`, *"You can improve enchanted armors and weapons"* | A **false friend that happens to be correct**: the standard temper condition means in Enderal exactly what it meant in Skyrim. Leave it alone. |

Enderal's own forge recipes gate on **`GetActorValue Smithing >= N`** (`RunOnType: Reference`,
`Reference: 000014:Skyrim.esm`) plus, usually, owning a `_00E_CraftingPlan_*` blueprint — **not** on
smithing perks. The vanilla smithing perks `0CB40D–0CB414` all still exist, but Enderal's `Player`
NPC record **grants every one of them at rank 1 from the start** **[verified]**, so `HasPerk
EbonySmithing` is a condition that is always true and gates nothing. Copy **both** conditions from
`_03E_RecipeWeapon_27_SwordOfTheRighteousPathForged` (`148A89:Skyrim.esm`) instead — the AV check and
the `GetItemCount <blueprint> >= 1` that follows it. Shipping only the first is the easy mistake:
the recipe works, but the item unlocks on level alone, unlike every one of its tier peers.

**Blueprints are `MiscItem`s, not Books** **[verified]** — `_00E_CraftingPlan_*`, model
`Enderal\books\Craftingplans\Craftingplan.nif` with an `AlternateTextures` entry selecting a
per-weapon-type TextureSet (`_00E_CraftingPlan_OneHandedSword` `09D079`, `…TwoHandedSword` `09D07A`,
and 22 more). Keywords `VendorItemClutter` + `VendorItemTool` + `Blueprint` (`0493B5`), `Value: 150`,
`Weight: 0.1`. Their in-game names read **`Blueprint: <item> (Handicraft <N>)`** — note **Enderal
displays the `Smithing` AV as "Handicraft"** (`_00E_Levelsystem_sSkillNameSmithing`), so a blueprint
naming the vanilla skill will look wrong to a player. Vendors stock them through three level-tiered
leveled lists — `_00ETraderCraftingPlans` `137A06` (level 1), `…PlansB` `148ABD` (10+), `…PlansC`
`148ABE` (19–30). A Handicraft-50 blueprint belongs in **C at Level 30**, where the Righteous Path
and Aeterna plans sit.

For weapon balance, Enderal's scale runs ~1.6× Skyrim's: its shadowsteel (ebony) tier sword is
**23 damage / crit 6** and its greatsword **37 / crit 11** **[verified]**. Note also that
`05AD9D:Skyrim.esm` is **`IngotShadowsteel`** here, Enderal's rename of ebony — so an ebony-tier
Skyrim recipe's *materials* usually port across unchanged even when its gating does not.

**A ported mod's DISTRIBUTION is the most likely thing to be silently dead — check it first.**
**[verified]** on Apocalypse — Magic of Skyrim, whose entire loot/vendor system is inert in Enderal.
It runs a `StartGameEnabled` quest (`WB_PopulateLists_Quest`) that copies three FormLists into **54
vanilla Skyrim vendor and loot leveled lists** — and **not one of those 54 exists in Enderal**.
Neither do the five College-of-Winterhold ritual globals it gates on (`0FDE72`–`0FDE76`), nor the
`Tamriel` worldspace it places its containers in. The mod loads, its 373 spells are all present and
mechanically fine, and the player can never obtain a single one.

This generalises: **Enderal's `Skyrim.esm` is Enderal**, so a vanilla FormID is only present if
Enderal happened to keep it. Bethesda's leveled-list IDs largely did *not* survive. So for any mod
that distributes items, the port checklist is: resolve its leveled-list targets against
`reference/base/Skyrim/` **before** assuming anything else about it — a dead distribution makes every
other consideration moot. The same applies to `MenuDisplayObject`, `LoadingScreenNif`,
`FirstPersonModel` and script `Object` properties, all of which are commonly vanilla FormIDs that
Enderal lacks.

> **Audit the WHOLE tree against Enderal, not just your diff — and key the index by
> `<hex>:<master>`.** **[verified 2026-08-07]** A check that only reports what *you* newly broke
> relative to upstream will read zero forever while the mod ships thousands of inherited dead
> references. `src/Apocalypse/tools/verify-missing-refs.ps1` is the absolute version; on the shipped
> Apocalypse tree it found **4,077 missing-reference occurrences across 617 FormKeys in 261 records**
> where the diff-based check read 0. Two things it has to do:
>
> 1. **Key by `<hex>:<master>`, never by hex alone.** Hex-only keying lets any hex that appears
>    anywhere in `reference/base/Skyrim` count as "defined by `Skyrim.esm`" — it inflates that index
>    from ~87k real records to **786k** and silently resolves references that are in fact dead.
> 2. **Resolve the survivors to their Enderal group + EditorID.** "Present" is not "correct"; the
>    interesting failures are the FormIDs Enderal kept as something else.
>
> And **do not read the count as a severity ranking**: 3,498 of those 4,077 were one deletable NAVI
> record that probably cost the player nothing, while *Locate Potion* is broken by **seven**. Full
> worked example in [`arch-docs/Apocalypse/enderal-gap-audit.md`](arch-docs/Apocalypse/enderal-gap-audit.md).

> **Never ship a `NAVI` record built against a different `Skyrim.esm`.** **[verified 2026-08-07]**
> Add one navmesh — even in your own interior cell — and the Creation Kit regenerates the plugin's
> whole NavigationMeshInfoMap, stamping Bethesda's navigation map into it. Apocalypse's was 6,633
> lines: 10 vanilla exterior `MapInfos` entries with thousands of merge FormIDs, plus a
> `PreferredPathing` block of 6,312 references, **none** of them the mod's own. Its entries even name
> `ParentWorldspace: 00003C:Skyrim.esm` — Tamriel in Skyrim, **`MQP01Home`** in Enderal. Note
> Enderal's `Skyrim.esm` NAVI has a **null FormKey** (Spriggit writes `Null.yaml`) and the real map is
> `000802:Enderal - Forgotten Stories.esm`, so a plugin NAVI at a vanilla ID is injecting, not
> overriding. Keep only the entries whose `NavigationMesh` FormKey is your own plugin's and delete the
> rest — `src/Apocalypse/tools/10-strip-vanilla-navi.ps1` does exactly that.

> **A ported mod's BSA can silently overwrite Enderal's own scripts — check it.** **[verified
> 2026-08-07]** Enderal replaces 55 vanilla script names, and a mod's archive loads *after* Enderal's
> because its plugin does. Apocalypse's BSA ships `dgintimidateplayerscript.pex` and
> `dgintimidatealiasscript.pex` — the full vanilla brawl scripts, from Brawl Bugs Patch — over
> Enderal's deliberate 4-line `; DUMMY, DO NOTHING` stubs, which are in `E - Misc.bsa`. So Skyrim's
> brawl system comes back on a game that removed it, reaching for `dgintimidatequestscript`,
> `DGIntimidateFaction` and `CR04Running`, none of which exist.
>
> The check is one command — list the mod's archive and intersect the script names with
> `reference/base/EnderalScripts/source/scripts/`. The fix is to **ship Enderal's stubs loose**, since
> loose files beat any BSA, and to say on the mod page that your mod must sit below the ported one in
> MO2's file order. Compile with **Enderal's tree first** on `-i`, or you rebuild the very script you
> are trying to suppress.
>
> **Assume every Enairim port does this.** **[verified 2026-08-24]** Triumvirate ships the identical
> pair — 2425 and 1983 bytes, decompiling to 59 and 47 lines, with a Champollion header reading
> `User: Maximilian` and a 2016 date. That is the Brawl Bugs Patch in both mods. Two for two, so run
> the intersection on any Enai mod before anything else. A correct rebuild of Enderal's stubs is
> **480 and 482 bytes** in both releases — byte-identical output is the cheapest proof the `-i` order
> was right, because vanilla's copy compiles to ~2 KB. Note `bsab`'s list output ends in a blank
> line: count with `grep -c .`, not `wc -l`, or every archive reports one phantom hit.

> **A vanilla FormID that survived may be a completely different record — check what a ported mod
> OVERRIDES, not just what it references.** **[verified]** Apocalypse overrides exactly one Enderal
> record, and it is worldspace **`00003C`**. In Skyrim that is `Tamriel`; **in Enderal it is
> `MQP01Home`**, the prologue house. Its override stamps Tamriel's `MaxHeight` grid and map bounds
> over a `SmallWorld` interior-ish worldspace, drops `Parent: Vyn`, `Location` and the
> `SmallWorld`/`CannotFastTravel` flags, and gives the persistent cell a `Regions` list of five
> FormIDs — **four absent from Enderal, and the fifth (`041449`) is `_00E_Ark_1024WallRound01`, a
> Static.** Our rebuilt `Apocalypse - Magic of Skyrim.esp` forwards Enderal's own record back (from
> **Forgotten Stories**, which also overrides it — guardrail 5).
>
> Generalise the *check*, not the fix: for any ported mod, list every record it overrides whose
> FormKey suffix is `:Skyrim.esm` / `:Update.esm` and confirm the Enderal record at that ID is the
> same record type **and the same thing**. A script that maps FormID → record group for both trees
> does this in seconds. **Run it on every port — it has now caught two.** Triumvirate ships the
> identical `Tamriel` override at `00003C` **[verified 2026-08-24]**, found in the first minutes of
> its ingest by listing 36 override FormKeys rather than by debugging anything. Note this override was **not** the crash it looked like — it is a real
> defect, found while chasing an unrelated bug, and worth fixing on its own merits.
>
> **And check what it REFERENCES, not only what it overrides — a surviving ID inside a condition is
> the nastier case.** **[verified 2026-08-05]** Biggie Traits gates two traits on an OR-group of the
> nine Amulets of the Divines. Eight of the nine FormIDs resolve to nothing in Enderal, but
> `0C891B` is `_04E_30_Unique_SongOfTheWinter` — an unrelated Enderal unique weapon. Left alone, the
> group is not merely dead: equipping that one weapon fires effects meant for a Divine amulet. A
> dangling reference is inert and safe to ignore; a reference that *resolves to the wrong record* is
> a live bug, and only resolving every external FormKey against `reference/base/` tells them apart.
>
> **`0C891B` has now caught three mods.** **[verified 2026-08-24]** Triumvirate stocks it as an
> `Item` in its own Maramal merchant chest — vanilla's Amulet of Mara, Enderal's unique weapon,
> again. Check it by name on any port that touches the Divines. And note the ratio that makes this
> worth automating: of Triumvirate's **1462** surviving `:Skyrim.esm` references, **1402 are exact
> matches** and only **15** drifted — the signal is rare, uniform-looking, and invisible to every
> check except a vanilla-vs-Enderal comparison.

**Enderal's own distribution slots**, for re-homing a ported mod's items **[verified]**
(`reference/base/Skyrim/LeveledItems/`). Note Enderal has **no spell tomes at all** — it teaches
spells from `_01E_SpellBook*` Books:

| Purpose | Lists | Level bands |
|---|---|---|
| Spell books, vendor | `_00ETraderSpellBooksLevelA/B/C/D` = `118209` / `11820A` / `1376C8` / `14479B` | 1–12 / 1–18 / 14–40 / 30–55 |
| Spell books, loot | `_00E_SpellBooksLootA/B/C/D` = `13798C` / `13798D` / `1447A2` / `1447A3` | 1–7 / 10–18 / 18–33 / 30–55 |
| Scrolls, loot | `00E_ScrollsLowChance` = `0905A5` | 1+, `ChanceNone: 0.5` |
| Crafting blueprints, vendor | `_00ETraderCraftingPlans` / `…PlansB` / `…PlansC` = `137A06` / `148ABD` / `148ABE` | 1 / 10+ / 19–30 |

> **`(Rank N)` on an Enderal spell tome is an upgrade chain, not a power tier — do not add it to a
> ported mod's tomes.** **[verified]** Enderal ships the *same spell* at six strengths, and the record
> prefix is the **player level** each unlocks at: `_01E_SpellBookFireBolt` = *Spell Tome: Firebolt
> (Rank I)* at level 1, then `_10E_` (II), `_18E_` (III), `_28E_` (IV), `_38E_` (V), `_48E_` (VI) at
> levels 10/18/28/38/48. So "(Rank I)" promises the player a Rank II of that exact spell exists.
>
> Enderal follows its own rule: **13 of its 201 spell tomes carry no suffix** — Clairvoyance, Mark,
> Return, Telekinesis, Detect Life, Detect Dead, the three Wall spells, the ghostly summons, Death
> Storm — precisely the spells that exist at one strength only. A ported spell with a single version
> therefore belongs in that group, unsuffixed. Apocalypse's tomes ship as `Spell Tome: <name>` for
> this reason; it looks inconsistent next to Enderal's and is in fact the consistent choice.

> **A ported spell mod's high-tier tomes are gated on globals Enderal never sets — grep the
> leveled lists for `Global:` before trusting distribution.** **[verified 2026-08-26]** Vanilla
> gates spell-tome availability by player skill: the Adept/Expert/Master `LeveledItem`s carry
> `Global: PC<School><Tier>`, and **when a leveled list names a Global that global's value IS the
> chance-none percentage** — the `ChanceNone` byte beside it is ignored. All 15 of those globals
> exist in Enderal at `Data: 100` (100% chance of nothing) and **nothing ever lowers them**:
> vanilla zeroes them from `WISkillIncrease02`, a quest present in `reference/base/SkyrimReal/`
> and in **neither** `reference/base/Skyrim/` nor FS; no Enderal script mentions them; and the
> only file in Enderal's whole tree matching `0F2584:Skyrim.esm` is the global's own record.
>
> On Triumvirate this left **45 of 75 tomes unobtainable after the distribution rebuild had already
> shipped**. The fix is one line per record — delete `Global:` and let the authored `ChanceNone`
> stand (`src/Triumvirate/tools/17-tier-gating.ps1`).
>
> Two lessons beyond the fix. **This is invisible to a missing-reference audit** — `PCAlterationAdept`
> resolves perfectly well, it just never changes; it is the "present but inert" class, a cousin of
> the drifted-FormID bug above. And **a structural reachability proof is not a reachability proof**:
> `15-distribution.ps1` walked chest → bundle → tome reading only `Reference:`, and reported a
> confident *"75/75 tomes at >=3 vendors"* on a mod that could sell 30. If a check asserts an item
> is obtainable, it must read the fields that decide whether the list yields at all.

**Inject, don't rewrite.** Add entries to the host list pointing at your own sublist, and carry
every existing entry through untouched (guardrail 5). One new LeveledItem per tier keeps the diff
readable and leaves Enderal's own list contents byte-identical.

> **But one entry is not enough — weight it, or your items are statistically invisible.**
> **[verified in-game 2026-08-02]** A host list picks **one entry per draw**, so a single injected
> entry gives your entire sublist the same odds as one of Enderal's individual books, no matter how
> many items are behind it. Apocalypse's 160 tomes sat behind one slot in `_00ETraderSpellBooksLevelA`
> (15 entries): even Tarhutie, the richest spell vendor at 8+10+10 draws, worked out to **~1 Apocalypse
> tome out of ~28 books**, and Milbert at 3+4 draws expected **0.3** — i.e. usually none. The
> distribution was correct and looked completely broken.
>
> Do the arithmetic before shipping: `draws x (your entries / entries at or below player level)`.
> Duplicating the injected entry — same `Level`, same `Reference` — is the lever, because it still
> touches none of Enderal's own entries. `src/Apocalypse/tools/06-weight-distribution.ps1` tops each
> injection up to a target multiplicity and is idempotent.
>
> Two traps when picking that multiplicity, both found by measuring rather than reasoning:
> **`ChanceNone` does not dilute your share** — it gates whether the list yields anything at all, so
> a loot list does *not* need a higher weight to compensate. And **a list whose band takes only one
> of your sublists ends up on half the share of its neighbours**, so weight per *list*, not per
> injection: Enderal's `…LevelB` / `…LootB` bands admit one Apocalypse rank where A/C/D admit two.
>
> Two things that make this look like a bug when it is not: vendor stock is **cached in the save**
> (`iDaysToRespawnVendor: 2`, so a merchant only re-rolls every 2 in-game days), and
> `player.additem <LVLI FormID> 1` **resolves a leveled list on the spot** — that command is the way
> to prove distribution works without waiting or starting a new game.

> **Weighting has a ceiling: a leveled list makes an item AVAILABLE, never FINDABLE.** **[verified
> in-game 2026-08-02]** A list is rolled per draw, so *which* of your items a shop has is random
> every restock. With 160 tomes behind one sublist, even at a healthy 38% share of a big vendor's
> spell stock, most of the 160 were purchasable **nowhere**, and a player hunting one named spell had
> no route to it at all. Two rounds of weighting did not fix that, because it is not a weighting
> problem.
>
> ### Place it directly — but write into `<Merchant>_CustomMerchandise`, NOT the chest
>
> **[verified 2026-08-26]** Enderal ships **67 LeveledItems named `<Merchant>_CustomMerchandise`**,
> one per merchant, and **every single one is empty** — `UseAll`, no entries, no `ChanceNone`, no
> `Global`. Each merchant's chest already contains its own. They are an extension point SureAI
> built and never filled, and they are the correct place to add vendor stock:
>
> - **`UseAll` with no `ChanceNone`** means everything you put in is yielded, in full, every
>   restock — the same determinism as writing into the chest.
> - **You override a `LeveledItem` instead of a `CONT`**, so you do not touch the merchant's
>   record at all.
>
> That second point is the whole prize, because the chests are heavily contested and the hooks
> are not. **No third-party plugin in `reference/mods/` overrides any of the 67** — EGO,
> `EGO SE - Leveling Redone`, KataPUMB, KataEmberlord and xxOpenSpells included. Compare with the
> chests: EGO owns essentially all of Ark's commerce (of the capital's **55** merchant chests only
> **six** are EGO-clear, and all six are 250–405 gold; every Ark chest at 900+ is EGO's), and
> **`EGO SE - Leveling Redone` overrides 50 containers**, among them every one of Apocalypse's six.
>
> **The critical property is that every one of those mods KEEPS the hook in the chests it
> rewrites** **[verified 2026-08-27]**, so a hook stays reachable whoever wins the container. That
> is what makes the technique safe rather than merely tidy, and it is worth re-checking per mod
> rather than assuming — a chest override that dropped the hook would silence your stock with
> no error, the "present but inert" class again.
>
> Both releases here have now moved. Triumvirate originally overrode ten chests and collided with
> EGO on three; Apocalypse overrode six and collided with all five of the mods above. Each is now
> at **zero container overrides** — ten `LeveledItem`s and six respectively — and both sets of
> vendor picks stopped having to dodge anybody. Apocalypse's Apprentice tier moved **back** to
> Tarhutie (630 gold) from the Maxus Tabbakus stand-in as a direct result. Note Maxus is one of the
> merchants SureAI left **without** a hook, so not every chest has this escape route.
>
> Two practical notes. The empty records have **no `Entries:` key at all** — Spriggit omits an
> empty collection — so you create the key rather than append to it. And **map hook → merchant by
> reading the chest's own `Items:` list, never by the name**: Adreyo's hook is `Vexin_`, the Ark
> guard smith's is `ArkHofSchmied_`.
>
> Writing into the `Container` still works, and it is what both releases here did first; **prefer
> the hook** and migrate anything that does not. Enderal's spell merchants, ranked by the gold in
> their chest (the natural wealth ladder for tiering what each one sells), with the hook that
> stocks each one **[verified]**:
>
> | Chest | Gold | Shop | Hook (write HERE) |
> |---|---|---|---|
> | `_00E_Merchant_CCFunkentanz` `102AD5` | 1800 | Ark, Emberlord and Fireflash (`coc CapitalCityMagierkram`) | `GabrielleFunkenfrst_` `0302D5` |
> | `_00E_Merchant_STTurious` `118050` | 1430 | Sun Temple, Torius Flameling (`coc SuntempleAlchemy`) | `TuriousFlammentrunk_` `0302FE` |
> | `_00E_Merchant_UC_Barnabas` `13824A` | 1050 | Undercity, Barnabas (`coc UndercityBarracks2Barnabas`) | `Barnabas_` `030302` |
> | `_00E_Merchant_CCSteinschlag` `0F9320` | 980 | Ark, Ora Stonehand | `OraSteinschlag_` `0302E3` |
> | `_00E_Merchant_FlusshaimTarhutieContainer` `05BCD6` | 630 | Riverville, Tarhutie | `Tarhutie_` `0302F7` |
> | `_00E_Merchant_MaxusTabbakus02` `022BF2` | 620 | Duneville, Maxus Tabbakus | **none** |
> | `_00E_Merchant_CCMilbert` `127928` | 530 | Ark, Milbert Foxhand | `MilbertFuchshand_` `0302DE` |
>
> Richer merchants exist (`Nordwind_Traveller_01` 3700, `Rhalata_SisterEnvy` 2700, `DunenhaimKarymea`
> 2700) but draw from only 1–2 spell lists, so they read as incidental rather than as mage shops.
>
> **Reprice what you distribute — Enderal's gold scale is much flatter than Skyrim's.** **[verified]**
> Enderal's *entire* spell-tome range is **20–350**, with two outliers (Paralyze Rank II 400, the
> unique Death Storm 600); scrolls run **10–100** with two at 500. Vanilla Skyrim's tome ladder is
> ~50/175/330/700/1300, and a ported mod carries it in silently — Apocalypse's masters sat at a 1407
> median, 5.6x Enderal's dearest tome, and its X-school scrolls at 2500. For scale, Enderal's
> *unique weapons and armour* run 1100–4000, so a Skyrim-priced master tome costs about what a unique
> greataxe does. Rescale by a **per-tier ratio** rather than a flat value so the author's ordering
> inside each tier survives, and let tiers overlap at the edges — Enderal's own do.
> **Forgotten Stories overrides all of these**, so copy the FS record, not base Enderal's (guardrail 5).
>
> **If you do claim a chest, check what else overrides it first.** `KataPUMBSpellPack.esp` adds the
> same 15 staves to `CCFunkentanz`, `STTurious` and `FlusshaimTarhutieContainer`, and those three
> shops are their only vendor. **[verified]** A plugin loading after it that overrides one of those
> chests without mastering it silently deletes them. Where a mod repeats an identical set across
> several chests, **sparing one chest preserves the whole set** — which is how `Apocalypse` used to
> protect them, leaving Tarhutie alone and hosting its Apprentice tier at Maxus Tabbakus (620 gold
> vs Tarhutie's 630) instead. **That workaround is now history**: on the hooks it claims no chest at
> all, KataPUMB's staves are safe everywhere, and the Apprentice tier is back with Tarhutie. Keep
> the reasoning for the cases the hooks cannot reach — a merchant without one, or a non-merchant
> container.

## Useful FormKey constants

These are **engine-hardcoded** FormIDs — Bethesda's own code depends on them, so Enderal's replacement
`Skyrim.esm` keeps them. They are safe to reference.

> **This table is deliberately short.** Because Enderal's `Skyrim.esm` *is* Enderal (see "Masters"
> above), an ordinary-looking vanilla FormID usually resolves to an Enderal record. Do not extend this
> table from Skyrim documentation — look the record up in `reference/base/Skyrim/` and cite the
> EditorID you actually found. Enderal's own worldspace, keyword, bench and talent FormKeys are
> documented in [`arch-docs/enderal/`](arch-docs/enderal/).

| FormKey | Meaning |
|---|---|
| `000014:Skyrim.esm` | PlayerRef |
| `000038:Skyrim.esm` | GameHour global |
| `000039:Skyrim.esm` | GameDaysPassed global |
| `000010:Skyrim.esm` | MapMarker base |
| `000034:Skyrim.esm` | XMarker base |
| `10F63C:Skyrim.esm` | MapMarkerRef LocationRefType (required for discoverability) |
| `013F42:Skyrim.esm` | `RightHand` EquipType |

> Enderal's own worldspace, keywords, crafting benches and talent perks are **not** listed here on
> purpose. Look them up in a serialized copy of `Enderal - Forgotten Stories.esm` with the
> `spriggit-decompile-reference` skill and add the ones you actually use, with the EditorID you
> found them under. A constants table copied out of Skyrim documentation is worse than no table.

## Gotchas

- **Enderal's cell EditorIDs are German; the display names are English.** Riverville is
  **`Flusshaim*`**, Ark is **`CapitalCity*`**, and the Sun Temple is `Suntemple*`. **[verified]**
  Searching `reference/base/*/Cells/` by the English town name returns **nothing** — grep the
  localized `String:` values instead, then read the EditorID off the match. This is also what a `coc`
  command needs: `coc FlusshaimShopSura` lands in "Riverville, Sura's Sharp Steel".
  - **This applies to NPCs too, and it will put the wrong name in your mod page and your docs.**
    **[verified 2026-08-26]** `_00E_FS_Wildmage_*` display as **"Shrouded Mage"** — all three of
    them, and they are the only three NPCs in the game that do. `_00E_UndercityHehler02` is
    **"Fence"** (*Hehler* = fence). Triumvirate's vendor docs called them "Wild Mage" and "Hehler"
    for a whole release because the EditorID was never checked against the `Name` block. When you
    name an NPC anywhere a player will read it, grep the record's English `String:` first.
- **Placed references live inside the cell's single `RecordData.yaml`, not in per-ref files.**
  Interior cells serialize to one file (`Cells/<block>/<sub>/<EditorID> - <hex>_<master>/RecordData.yaml`)
  holding the cell record, its `NavigationMeshes:`, then `Persistent:` and `Temporary:` lists.
  Exterior refs are under `Worldspaces/`. **[verified]** A `find` that turns up only `RecordData.yaml`
  does not mean the refs are missing.
- **To add one object to an existing cell, copy the winning cell record and give it a one-entry
  child group.** **[verified]** — this is exactly what FS does to `FlusshaimTemple`, and what a
  blueprint-placing patch built in this workspace did. Three rules learned building it:
  1. Copy the cell from the **winning** plugin, not from `Skyrim/`. FS overrides many cells and
     changes their data (for `FlusshaimTemple` it rewrites the `Name` from 3 localisations to 10) —
     copying base Enderal's version silently reverts that. Guardrail 5 applies to cells too.
  2. **Delete the `NavigationMeshes:` block.** Those are full NAVM record overrides carrying vertex
     and grid data; carrying them means overriding Enderal's navmesh for no reason.
  3. List **only** your new ref under `Temporary:`. Refs are independent records — omitting the
     hundreds you aren't touching does not remove them, and re-listing them invites conflicts.

  Spriggit 0.40.0 round-trips this correctly, emitting the canonical
  `GRUP CELL → block → sub-block → CELL → GRUP cellchildren → GRUP celltemp → REFR` nesting, and a
  new `REFR` in an ESL-flagged plugin keeps the flag. **[verified]**
- **Placing a ref in an EXTERIOR cell needs three scaffolding files, or Spriggit silently drops the
  whole tree.** **[verified 2026-08-03]** An interior cell is one `RecordData.yaml` (see above), but
  a worldspace cell will not build from the cell file alone — the plugin comes out with **zero**
  `WRLD`/`CELL`/`REFR` records, no error, no warning. The build succeeds and the ref simply is not
  there. Four files are required:

  ```
  Worldspaces/<WS EditorID> - <hex>_<master>/RecordData.yaml   # the WRLD record itself
  Worldspaces/<WS…>/<blockX, blockY>/GroupRecordData.yaml      # GroupType: ExteriorCellBlock
  Worldspaces/<WS…>/<blockX, blockY>/<subX, subY>/GroupRecordData.yaml  # ExteriorCellSubBlock
  Worldspaces/<WS…>/<blockX, blockY>/<subX, subY>/<cell>/RecordData.yaml
  ```

  Folder names are `<X>, <Y>`; block = `floor(coord/32)`, sub-block = `floor(coord/8)`. Inside the
  `GroupRecordData.yaml` the fields are `BlockNumberY` **then** `BlockNumberX` plus `GroupType`, and
  a zero is **omitted** (Spriggit drops defaults) — so folder `0, -1` yields only `BlockNumberY: -1`.
  A cell with no EditorID gets a folder of just `<hex>_<master>` with no `" - "` prefix.

  **Truncate the WRLD record before its `TopCell:` block** unless you actually mean to override the
  worldspace's persistent cell. Copying the master's record whole drags in every persistent ref
  (Ark's market is ~40 of them) as an override you then have to be right about. Header-only builds
  fine and keeps the conflict surface to the WRLD fields. Copy the file and cut it with a script —
  do not retype it (guardrail 4).
- **Never rewrite a UTF-8 doc with PowerShell 5.1's `Set-Content -Encoding utf8`.** **[verified
  2026-08-03]** It reads the file as the system ANSI codepage and writes it back as UTF-8 **with a
  BOM**, double-encoding every non-ASCII character — every `—` in this file became `â€"` in one
  pass, and `git diff` then reports the whole file as changed. It happened here while resolving a
  rebase conflict in `CLAUDE.md`. Use the Edit tool for surgical text changes, or `git checkout` the
  file and redo them; if you must script it, read and write with an explicit
  `[System.Text.UTF8Encoding]::new($false)` rather than the `-Encoding utf8` shorthand.
- **`E - Update.bsa` loads last and wins.** When a record or asset doesn't look like the one you
  found in `E - Meshes.bsa`, check `E - Update.bsa` before concluding your patch is wrong.
- **Don't give a patch you author a DLC master** — there is nothing in the stubs to reference. But
  the stubs *do* load (see "Masters" above), so a third-party plugin that masters one is fine and
  needs no user action. What you get is *loading*, not *working*: every FormID into a stub resolves
  to null, because the stubs hold 1–2 records between them. `Dragonborn.esm`'s single record is
  `DLC2MiraakRace` `03CA97`. **[verified]** Adding the DLC to your own master list does **not** help a
  dependent patch either — tested directly, it changes nothing. **[verified]**
  - A patch may override each record carrying a DLC reference and repoint or drop it, but weigh that
    against doing nothing: a dangling FormID is **proven harmless** here (Apocalypse ships 67 recipes
    and 144 scrolls full of them and the game runs), whereas a *null* is not automatically better.
    **Null `BNAM` on a `COBJ` has zero precedent in Enderal** — all 1,859 of its recipes carry a real
    bench keyword, none null, none absent. **[verified]** We shipped 67 null ones on the reasoning
    that null "is a real engine sentinel"; that reasoning was never tested and the overrides were
    later dropped entirely. If a dangling reference already makes the record unreachable, **leave it
    alone** — that is the proven archetype (guardrail 3), and an override that achieves nothing is
    still a record you have to be right about.

> ### THE FORM-VERSION CEILING: Enderal will not load a plugin whose `HEDR` version is 1.71
>
> **[verified in-game 2026-08-02. Read this before porting any Skyrim mod.]**
>
> Enderal SE runs SSE **1.5.97**, and that engine **silently refuses any plugin written at `HEDR`
> form version 1.71**. No warning, no log entry, no missing-master dialog — the plugin is simply
> absent from the game. `HEDR` 1.70 is the ceiling; 1.71 is what the 1.6/AE-era Creation Kit and
> newer tools emit.
>
> **Proof:** `Apocalypse - Magic of Skyrim.esp` is 1.71. With it enabled, `help wither 4` in the
> console finds nothing, though the mod defines a spell whose EditorID and name both contain
> "Wither". Change **four bytes** — the `HEDR` version float at file offset 30 — from 1.71 to 1.70,
> leave every other byte identical, and the spell appears. Single variable, both directions.
>
> **How this presents, and why it is so hard to spot:**
>
> - The mod appears installed and enabled. MO2 is happy. The game launches.
> - Nothing it adds exists. `help <anything> 4` finds none of its records.
> - **A patch that masters it crashes the game**, because the patch loads, tries to bind to a master
>   the engine skipped, and dereferences null during data load:
>   ```
>   EXCEPTION_ACCESS_VIOLATION  SkyrimSE.exe+05E1F22   mov rdx, [rax+0x158]   rax = 0
>   PROBABLE CALL STACK: ... InitTESThread
>   PLUGINS: Light: 0  Regular: 0  Total: 0      <-- data handler never finished
>   ```
> - Setting the *patch* to 1.71 makes the crash disappear — because the patch is now skipped too.
>   **That is a false fix and it was shipped once.** A crash that vanishes because both plugins
>   became invisible looks exactly like a crash that was fixed.
>
> **Check `HEDR` before you plan anything.** Read the float at offset 30 of the `.esp`
> (`src/Apocalypse/tools/verify-plugin-structure.ps1` prints it). If it is 1.71:
>
> - a patch plugin **cannot** work — the only route is to rebuild the mod's own plugin at 1.70,
>   which means shipping a modified copy under the same filename (keeps its BSAs loading). Check the
>   author's permissions first.
> - when authoring with Spriggit, set `ModHeader.Stats.Version: 1.7` **explicitly**. Mutagen's
>   default is **1.71**, so a plugin that never mentions the field builds itself invisible.
>
> **This is not rare.** Five other plugins in the `thepath` modlist are 1.71 and therefore inert:
> `CS Light.esp`, `DynDOLOD.esp`, `Enderal Weather - HDR.esp`, `standard_lighting_templates.esp`,
> `TerrainHelper.esp` — most of a visuals layer, loading nothing, with no error anywhere. Audit any
> Enderal list for this.
>
> **Check the mod's DEPENDENCIES for 1.71 too, not just the mod.** **[verified 2026-08-05]** Porting
> Biggie Traits turned up `Biggie Traits.esp` at 1.71 *and* `b612.esp` — the UI library that supplies
> its trait-selection menu — also at 1.71. Rebuilding only the mod would have produced a plugin that
> loads and a menu that never opens, which reads like a scripting bug and is not one. Any required
> mod that ships an `.esp` is subject to the same ceiling, so run the offset-30 check over the whole
> dependency chain before concluding a port is one plugin's worth of work.
>
> ### BEES LIFTS THE CEILING — check for it before rebuilding anything
>
> **[verified in-game 2026-08-05 — this corrects the section above, which describes the STOCK
> engine.]** **Backported Extended ESL Support (BEES)** by Nukem
> (`BackportedESLSupport.dll`, Nexus 106441) makes 1.5.97 load 1.71 plugins. Its export table
> carries `SKSEPlugin_Query`, so it loads on Enderal, and the mechanism is visible in the binary:
>
> ```
> LoaderHooks::ReadFormVersionHook::Thunk(RE::TESFile*, void*, unsigned int)
> ```
>
> — it hooks the form-version read itself. It also resolves the address library through
> `version-{}.bin`, which is the name Enderal ships.
>
> Proven by direct A/B in `thepath`: with BEES enabled, the **stock** `b612.esp` (1.71) loads and
> Biggie Traits' trait menu works; with BEES disabled and the same stock plugin, the menu cannot be
> used at all. That second half is `b612.psc` doing
> `Game.GetFormFromFile(0x800, "b612.esp")` — when the engine skips the plugin the lookup returns
> `None` and every B612 menu silently fails.
>
> **So the first question about a 1.71 mod is no longer "how do we rebuild it" but "is BEES in this
> list?"** With BEES, a 1.71 dependency needs no conversion at all — which is why this repo ships
> **no** B612 conversion despite having written one. Rebuilding a third-party plugin carries a
> permissions burden and an update burden forever; requiring BEES carries neither.
>
> Two things this does **not** change:
>
> - **Author your own plugins at 1.70 regardless.** It costs nothing and keeps them working in lists
>   without BEES. `Biggie Traits.esp` here is 1.70 for exactly that reason, so only its *dependency*
>   needs BEES.
> - **A conversion is still worth it when the mod's CONTENT is wrong for Enderal.** BEES would have
>   let stock Biggie Traits load, and it would still have overridden five nonexistent Skyrim house
>   cells and offered 14 traits with no target. Form version is one reason to rebuild, not the only
>   one.
>
> Worth revisiting: `Apocalypse` is a **replacement plugin** partly because of this ceiling. With
> BEES it could in principle have been a patch. Its other changes (renames, distribution rebuild)
> are extensive enough that this was probably still the right call — but the reasoning recorded in
> `src/Apocalypse/tools/README.md` now overstates the case.

> ### Proving an SKSE plugin is 1.5.97-capable WITHOUT launching the game
>
> **[verified 2026-08-05]** SE-era SKSE (1.5.97) calls a DLL's **`SKSEPlugin_Query`** export. The
> AE-era entry point is **`SKSEPlugin_Version`**. So reading the PE export table decides
> SE compatibility statically:
>
> | Exports | Means |
> |---|---|
> | `Query` only | SE-only build — fine for Enderal |
> | `Query` **and** `Version` | CommonLibSSE-NG build — runtime-agnostic, fine for Enderal |
> | `Version` only | **AE-only — will not load on 1.5.97** |
>
> Validated against Keyword Item Distributor's own FOMOD, which ships `SE/` and `AE/` folders: the
> `SE/` DLL exports `Query`, the `AE/` DLL exports only `Version`. This turns "is this whole SKSE
> stack usable?" from a build-deploy-launch cycle into a minute of reading headers. Note it proves
> the *entry point* matches, not that the plugin behaves — still launch before claiming it works.
>
> Two related facts from the same session: CommonLibSSE-NG DLLs look for the address library under
> **both** `Data/SKSE/Plugins/versionlib-{}.bin` and `version-{}.bin`, so Enderal's stock
> `version-1-5-97-0.bin` satisfies them with no rename. And a dependency's **Papyrus** side needs
> checking separately — po3's Papyrus Extender ships different script signatures per era, so confirm
> the functions a ported script imports exist in the SE build's `.psc`.

> ### Debugging a load crash: bisect the PLUGIN, not the records
>
> **[verified — learned the expensive way on the Apocalypse patch.]** When a patch crashes the game
> at load, the instinct is to suspect the records. Six record-level hypotheses were tested and all
> six were wrong, because the cause was in the 24-byte header. **Run the cheap controls first, in
> this order** — each is one launch and each halves the search space:
>
> 1. **Empty plugin.** Hand-write a valid TES4 with no masters and no records under the same
>    filename. If that crashes, nothing you authored is involved.
> 2. **Masters only, no records.** Add the real master list, still zero records. This separates
>    "header/masters" from "content" in one launch.
> 3. **Bisect the master list**, then the header fields (`HEDR` version, flags), then records.
>
> `scratchpad/make-masters.ps1`-style hand-built plugins are better than toolchain output here
> precisely because they remove the toolchain as a variable. Also: **isolate one variable per
> launch** — an early run changed the ESL flag and the record set together and proved nothing.
- **Compiling against vanilla signatures.** If a script compiles clean and then misbehaves on an
  Enderal type, check the `-i` order — Enderal's tree must be first. 55 names collide.
- **FOMOD images that actually render in MO2** — a config can build clean, pass
  `build.ps1 -CheckFomod`, open its wizard normally, and still show *no image at all*. Nothing
  warns you. This recipe is confirmed working in MO2; copy its shape rather than re-deriving:
  1. `path=` is relative to the **archive root**, so an image at `fomod/images/foo.jpg` is
     referenced as `path="fomod\images\foo.jpg"` — *including* the `fomod` prefix.
  2. Use **backslashes** in `path=`.
  3. Declare an `<installSteps>` block, even for a patch with no real choices (one
     `SelectExactlyOne` group holding a single `Recommended` plugin). A config with only
     `<requiredInstallFiles>` gives MO2 no wizard page to draw the banner on.
  4. Use a **baseline** JPEG or a PNG, not a progressive JPEG. Check with
     `od -A d -t x1 -v img.jpg | grep -oE 'ff c[0-9a-f]'`: `ff c0` is baseline (fine), `ff c2` is
     progressive. Re-encode progressive files via `System.Drawing` before shipping.

  These four were fixed **together** after several one-at-a-time attempts each failed, so which is
  individually decisive is unverified — treat the set as the known-good recipe, and do not drop one
  on the assumption it does not matter.

  `build/build.ps1 -CheckFomod` enforces points 1, 2 and 4: an unresolvable `path=` or a
  progressive JPEG **fails** the check (with a "did you mean `fomod\…`?" hint for the missing
  prefix), and forward slashes warn. It cannot check point 3 — whether an `<installSteps>` block
  exists at all — because a config legitimately may not want one.
- **Enderal's Scrolls carry no `MenuDisplayObject`** — 0 of its 34 (32 in `Skyrim.esm`, 2 in FS).
  **[verified 2026-08-07]** A ported mod's scrolls usually do, pointing at a vanilla static Enderal
  dropped (Apocalypse's 144 all named `076E8F:Skyrim.esm`). **Delete the field rather than picking a
  substitute** — matching the host's archetype beats inventing one (guardrail 3).
- **Decompiled `.psc` is a reconstruction** (Champollion): auto-named vars, reconstructed control
  flow, lost comments/flags. Enderal ships real source for its own scripts in `ScriptsEnderal.zip` —
  **read that instead of decompiling** whenever the script is Enderal's. Invocation is
  `Champollion.exe -p <outdir> <input.pex>` — `-p` is the output **directory** and the input comes
  last. Any other arrangement just prints the usage banner.
- **Missing-type compile errors** → the referenced API's source isn't on the import path; add its
  `Source\Scripts` dir to `importDirs` in `tools.json` and record it in the imports table above.
- **Emptying a collection in the YAML means DELETING its key, not leaving it bare.** **[verified
  2026-08-05]** Spriggit omits a collection key entirely when the collection is empty — a FormList
  with no entries serializes to just `FormKey:` + `EditorID:`, with no `Items:` line. Remove the
  last entry and leave `Items:` behind, and deserialize dies with
  `Expected 'SequenceStart', got 'Scalar'`. The build fails loudly, so this one is cheap.

  The related trap is **not** cheap: when scripting that key removal, remember a YAML block sequence
  sits at the **same indentation** as the key that owns it —

  ```yaml
  Flags:
  - IgnoreResistance
  ```

  so an "is anything indented under this key?" test deletes live keys (`Flags:`, `Effects:`,
  `Conditions:`) across the whole tree. A key is empty only when the next non-blank line is neither
  more indented **nor** a `- ` item at the same indent. This corrupted several records here before
  it was caught; the fix is in `src/BiggieTraits/tools/00-common.ps1`.
- **`build/manifest.json` supports an `assets` array** for releases that ship more than a plugin and
  its `.pex` — `Interface/`, `MCM/`, `SKSE/`, KID/SPID `.ini`. Entries are `{from, to}`, both
  repo-relative; `to` is the path inside the archive (`""` = root). For a **folder** source the
  folder's *contents* are copied into `to`, so `to` names the destination exactly — that is what lets
  `src/<Mod>/Scripts/source` land at `Source/Scripts`.
- **YAML comments do not survive a re-serialize.** Spriggit rewrites the folder from the binary
  plugin, so any `#` comment you add to a record file is lost the next time anyone runs
  `/spriggit-serialize`. Put durable explanation in this file, not in the record YAML.
- Edit `.psc`/YAML, never the binary `.pex`/`.esp`. Commit source, not build artifacts.
- See `arch-docs/enderal-record-patterns.md` for the in-game failure modes that produce no build
  error — that list is the single highest-value read before authoring a new patch.
