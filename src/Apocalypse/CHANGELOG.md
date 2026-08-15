# Changelog — Apocalypse: Enderal Patch

Paste each version block into the Nexus **Changelogs** tab. User-facing changes only; repo tooling
and documentation are not listed.

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
