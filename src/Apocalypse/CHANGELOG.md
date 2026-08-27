# Changelog — Apocalypse: Enderal Patch

Paste each version block into the Nexus **Changelogs** tab. User-facing changes only; repo tooling
and documentation are not listed.

## 1.2.0

- Updated for **Apocalypse 10.3.0**. You must install that version — this release will not match 10.2.3.
- Spell tomes are now added through the spare shop slots Enderal itself provides, rather than by rewriting each merchant's inventory. This mod no longer edits a single container record.
- Because of that, it no longer conflicts with **Enderal Gameplay Overhaul**, **EGO Leveling Redone**, **KataPUMB Spell Package**, **Kata's Emberlord** or **Open Spells** — all of which edit the same shops. Load order between them no longer matters.
- Fixed: KataPUMB's 15 staves were being removed from Emberlord and Fireflash and from Torius Flameling. They are back.
- Apprentice tomes moved from Maxus Tabbakus in Duneville to **Tarhutie in Riverville**, the workaround that forced them to Duneville no longer being needed.
- Enai's own changes for 10.3.0 come with it.

## 1.1.0

- Fixed: Apocalypse's archive was replacing two scripts SureAI deliberately disabled, switching
  Skyrim's brawl and intimidation system back on in a game built without it. Enderal's own versions
  now ship with this mod and take priority.
- Fixed: script errors on every new game, and again each time the "Repopulate" button in Apocalypse's
  MCM was used. Apocalypse tries to stock 83 Skyrim vendor and loot lists that do not exist in
  Enderal. Nothing is lost — spell tomes and scrolls are placed by this mod instead.
- Fixed: the plugin carried Bethesda's entire navigation mesh map, built for Skyrim's worldspaces and
  meaningless here. Removed, keeping only the entries for Apocalypse's own two interior cells.
- Fixed: all 144 scrolls pointed at an inventory model Enderal does not have.
- Changed: this mod must now sit **below Apocalypse** in your mod manager's file order. It already
  had to in order to replace the plugin; it now also adds two loose script files that need to win.
- No changes to spells, prices, merchants or distribution.

## 1.0.0

- Initial public release.
