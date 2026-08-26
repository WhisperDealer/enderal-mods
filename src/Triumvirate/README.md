# Triumvirate — Enderal conversion

Enai Siaion's **Triumvirate — Mage Archetypes** (75 spells across druid, shadow mage, warlock,
cleric and shaman), converted for Enderal SE. Tracked as epic **WD-7**.

**Status: converted and building.** The DLC masters are off, the five archetype passes are done,
the naming close-out holds at zero Elder Scrolls nouns, and distribution has been rebuilt onto
Enderal merchants (WD-16) and tier-gated (WD-16b). `build/manifest.json` carries the release, so
CI builds it on every push and attaches the archive to the PR.

**Not yet proven in game** — see
[`arch-docs/Triumvirate/distribution-test-checklist.md`](../../arch-docs/Triumvirate/distribution-test-checklist.md).

## Shape

A **replacement plugin**, the same shape as `src/Apocalypse/`. It ships under the original filename
`Triumvirate - Mage Archetypes.esp` because the mod's two BSAs are named after the plugin and only
load while that name is intact — so the tree here holds *all* of Enai's records, not just our edits.
The player installs Enai's mod for its assets and this release replaces the plugin.

That makes the author's permissions and on-page credit a release requirement, not a nicety. Settle
both before WD-18 packages anything.

## What is already known

Read **[`arch-docs/Triumvirate/ingest-census.md`](../../arch-docs/Triumvirate/ingest-census.md)**
first — the baseline census, the kill-check results, and the three things already flagged for the
gap audit. The headlines:

* Form version is **already 1.70**. The ceiling that forced Apocalypse into a rebuild does not bite
  here; the BSA filename coupling is what forces it instead.
* The override surface is **36 records of 1882**, nearly all Skyrim vendor chests and Services
  factions — inert in Enderal, and WD-16's problem.
* It overrides worldspace **`00003C`**, which is `Tamriel` in Skyrim and **`MQP01Home`** in Enderal.
  Same defect Apocalypse shipped.
* It masters all three DLC stubs, with 260 references into them. Those come off in WD-9, not before
  — see the census doc for why.

## Layout

```
TriumvirateESP/        Spriggit YAML — the source of truth, committed
Scripts/source/*.psc   Papyrus source, committed
Scripts/compiled/*.pex committed via a .gitignore exception — CI cannot compile Papyrus
tools/*.ps1            the numbered generators that rebuild the tree against a new upstream
```

`Scripts/` ships three loose `.pex`: our replacement distribution script, and verbatim copies of
Enderal's two `dgintimidate*` DUMMY stubs that Triumvirate's BSA would otherwise overwrite with the
Brawl Bugs Patch versions. **This mod must sit after Triumvirate in MO2's file priority** — which it
must anyway, to win the `.esp`. See [`Scripts/README.md`](Scripts/README.md).

The release is `Triumvirate - Enderal Conversion` in `build/manifest.json` (`"fomod": false` — a
plain archive, since a single `.esp` plus loose scripts has nothing to ask the installer).
