# Zen Traits — imported, not yet converted

Shazdeh's **Zen Traits**, an Enderal-native add-on for *Biggie Traits* that adds nine Arcane
Fever / Light Magic traits. Imported here verbatim so the plugin can be edited as YAML; **no
conversion changes have been applied yet** and there is deliberately no `build/manifest.json`
release entry, so nothing here is built or published until someone decides to ship it.

| | |
|---|---|
| Upstream | <https://github.com/shazdeh/Zen-Traits> |
| Commit | `1ae67a8` — *"Update Zen Traits.esp"*, 2026-08-22. Resolves [issue #1](https://github.com/shazdeh/Zen-Traits/issues/1); the only change from `648332e` is `ZenTraits_TwilightDiscipleAb 00081F`'s `Name`, *Lightborn* → *Twilight Disciple*. Everything else in the package — scripts, `.psc`, the FLM ini, LICENCE — is byte-identical across the two commits |
| Licence | **MIT**, © 2026 Shazdeh — see `LICENSE`. Redistribution and modification are permitted provided the notice travels with it, which is why the whole package is committed here rather than the changed-parts-only shape the Biggie Traits release uses |

## What is here

```
ZenTraitsESP/            # Spriggit YAML, 41 records, FormIDs 000801-000828
Scripts/source/*.psc     # 15 Papyrus sources
Scripts/compiled/*.pex   # 15 compiled, opted back into git via .gitignore
Zen Traits_FLM.ini       # the entire integration with Biggie Traits
LICENSE
```

The stock repo root is already a valid MO2 data folder, so the only things not copied across are
`.gitattributes` and the git metadata.

## How it hooks into Biggie Traits

Nothing in the plugin references `Biggie Traits.esp` — the master is declared and unused. The
integration is entirely `Zen Traits_FLM.ini`, which asks **FormList Manipulator** to inject the nine
trait abilities into the FormList `Traits_AbilityList` by EditorID at runtime.

Our conversion keeps that FormList at `000002` under the same EditorID, so the injection lands
unchanged. It appends to Biggie's own 30 entries, so none of the eight traits our conversion cut can
dangle against it.

## What must change before this can ship

Nothing below has been done — the tree is stock.

| # | Issue | Detail |
|---|---|---|
| 1 | **`HEDR` is 1.71** | Invisible on stock 1.5.97. Worse than merely absent: `ArcaneFever.psc` resolves everything through `Game.GetFormFromFile(0x802, "Zen Traits.esp")`, so on an engine that skipped the plugin every fever hook returns `None` — the b612 failure mode. Set `ModHeader.Stats.Version: 1.7`; Mutagen defaults to 1.71 and the serialized header carries no `Stats` block at all |
| 2 | **Not ESL-flagged** | Every record sits in `000801-000828`, inside the ESL window, so the flag is free |
| 3 | **`_00e_phasmalist_newapparitionalias.pex` is contested** | EGO and *Enderal SE - Bug Fixes* both ship this script; Zen's copy is a third lineage, 325 diff lines from the Bug Fixes version, and it drops the `ForgottenStoriesMiscDialogue` property. Either drop it here or reconcile it against Bug Fixes. The other six `_00E_` overrides only beat Enderal's own copies in `E - Misc.bsa` and are uncontested |
| 4 | **Two orphaned scripts** | `_00E_AlchArcaneFever` and `_00E_IncreaseArcaneFeverFFTarget` have no Enderal original and no record binds either name, so both are inert. `02F112`'s script is `_00E_ArkanistenfieberBlitzheilungSCN` |
| 5 | **`Traits_EffectsList` gets no parallel injection** | Biggie's `Traits_ResetManager 000065` binds both `Traits_AbilityList` and `Traits_EffectsList`; the FLM ini only injects the former, so a trait reset may not clean up Zen's nine. Unverifiable without Biggie's `.pex`, which neither repo ships |

Undeclared dependencies, both required at runtime: **FormList Manipulator** (nothing injects
without it) and **powerofthree's Papyrus Extender** (`ZenTraits_AeternaVeinsScript` imports
`PO3_Events_AME`).

## Verified clean

All 19 external FormKeys resolve against `reference/base/` — zero dangling. They are Enderal
content throughout: `_00E_ArkanistenfieberIMOD`, `_00E_Class_Thaumaturge_P07_MentalExpert`, the
five Restoration (= Light Magic) perks, the FS fever messages and IMODs. `000014` PlayerRef is
absent from `reference/base/Skyrim/` as CLAUDE.md documents, and is allow-listed.

The perks use real `PerkEntryPointModifyValue` entries keyed on
`EPMagic_SpellHasSkillConditionData ActorValue: Restoration`, which is the Enderal-native way to
scale a school — no invented mechanism to disprove.
