# Triumvirate — Enderal conversion

Enai Siaion's **Triumvirate — Mage Archetypes** (75 spells across druid, shadow mage, warlock,
cleric and shaman), converted for Enderal SE. Tracked as epic **WD-7**.

**Status: ingested only (WD-8).** `TriumvirateESP/` is currently Enai's plugin, unchanged, as YAML.
No conversion work has been done to it yet.

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
```

`Scripts/`, `tools/` and a `build/manifest.json` entry arrive with WD-17 and WD-18.
