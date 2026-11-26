# Changelog — Apocalypse: Enderal Patch

Paste each version block into the Nexus **Changelogs** tab. User-facing changes only; repo tooling
and documentation are not listed.

## Unreleased

- **Updated for Enderal SE 2.1.4.4.** This version requires 2.1.4.4 or later.
- Fixed: **on Enderal 2.1.4.4, Mental Expert players paid no Arcane Fever for Apocalypse's heals.**
  2.1.4.4 moved the Fever charge into the engine and split it in two: the full charge now skips
  anyone with Mental Expert, and a second, reduced charge picks them up. Apocalypse's 19 heals only
  carried the first. They now carry both, at the same one-third discount Enderal's own heals give.
  Players without Mental Expert pay exactly what they did before.
- **Entropy and Psionics are now sold only by the Shrouded Mages**, Forgotten Stories'
  forbidden-magic dealers. Both are forbidden schools in Enderal, yet Ark's shops and the Sun Temple
  sold them openly. Milbert, Tarhutie, Ora Stonehand, Torius Flameling, Emberlord and Fireflash and
  Barnabas no longer carry them. Instead:
  - Novice and Apprentice: a new Shrouded Mage in Riverville (below)
  - Adept: the Shrouded Mage in the Undercity
  - Expert: the Shrouded Mage in Frostcliff Tavern
  - Master: the Shrouded Mage in Duneville
- **Eshra Mirâya now sells the Novice Light Magic and Elementalism tomes**, instead of Milbert
  Foxhand in Ark. She is one of the first merchants you can meet in the open world, and trades once
  her quest is done. Milbert keeps the Novice Mentalism tomes.
- **Works alongside Triumvirate (Enderal Conversion).** Both mods used to stock Tarhutie and Torius
  Flameling through the same lists, so whichever loaded later wiped the other's spells from those
  two shops. Apocalypse no longer uses either merchant:
  - Apprentice Elementalism and Light Magic: **Kurro's General Store**, Riverville
  - Apprentice Mentalism: **Ora Stonehand**, Ark, beside her Adept Light Magic
  - Expert Elementalism and Light Magic: **Emberlord and Fireflash**, Ark
- **Mirella Godshand sells the Master Mentalism tomes** at her alchemy shop in Ark, beside the
  top-tier spell books she already stocks.
- **Fitzai Galabagadananka sells the Expert Mentalism tomes** at Fitzai's Puzzle Box in Ark,
  instead of Torius Flameling. Mentalism is the Starlings' art, and with EGO his shop also sells
  Starling gear.
- **A new Shrouded Mage sits in The Drunken Bee in Riverville**, selling the Novice and Apprentice
  Entropy and Psionics tomes beside Forgotten Stories' own forbidden spell books. Like every Shrouded Mage, he
  will not trade with you until your Psionics or Entropy reaches 15.
- Removed the two loose brawl scripts (`dgintimidate*`) this mod used to ship. Enderal 2.1.4.4 no
  longer has scripts by those names, so they replaced nothing. The release is now the plugin alone;
  delete the two files from `Scripts\` if you update over an older version by hand.
- Brought the prologue worldspace this plugin carries up to date with Enderal 2.1.4.4's version,
  so it no longer reverts that update's changes (its Czech name, and a cell flag).

## 1.3.0

- Fixed: **the master-tier spells cost far too much mana to cast.** Apocalypse left every spell's
  cost to be calculated by the engine, and that calculation charges for a spell's *duration* rather
  than its power — so Conjure Battlemage came out at 1201 mana, more than twice what a fully
  invested Enderal mage's whole bar holds. Every spell now has a cost written against Enderal's own
  scale, where the most expensive spell in the game is 310. Conjure Battlemage is 230.
- Costs were rescaled per tier, so Enai's relative pricing inside each tier is unchanged — the
  cheapest novice spell is still the cheapest novice spell. Nothing else about the spells changed:
  no damage, duration, magnitude or effect was touched.
- Novice and apprentice spells barely move. The higher the tier, the larger the correction.
- Fixed: **Conjure Herne's summon never used his bow.** He was handed a quiver of Daedric Arrows,
  which do not exist in Enderal, so he spawned with a bow and nothing to fire from it and simply
  stood there. He now carries Aeterna Arrows, Enderal's own best arrow.
- Fixed: the same defect on **Conjure Entropic Assassin** (renamed below, and formerly Conjure
  Dremora Assassin), who also draws a bow. Unreported, found while checking Herne.
- Fixed: **the Craftlord summon arrived naked from the neck down.** Its outfit dressed it in
  Dwarven armour, which Enderal does not have, leaving only the hood and cloak. It now wears
  Endralean Plate.
- Fixed: two Elder Scrolls place names left in spell descriptions - the Craftlord was summoned
  "to Nirn", and the Sinistran Sorcerer threw a "Ball of Oblivion's flames".
- **Fifteen summons are renamed for Enderal.** Enderal has no Dremora, no Xivilai, no Daedra, no
  Dwemer and no Atronachs, so these spells used to carry names from a world it has never heard of.
  Dremora become **Entropic**, Xivilai become **Sinistran**, the Weeping Daedra becomes a **Weeping
  Shade**, Atronach Mark becomes **Elemental Mark**, and the Craftlord calls a **Starling** sage
  rather than a Dwemer one. Kyrkrim is a spirit wolf now, not a daedric one.
- **Three of them are now obtainable for the first time**, at their proper tiers: **Conjure Herne**
  from Torius Flameling, **Conjure Entropic Assassin** and **Conjure Craftlord** from Emberlord and
  Fireflash. All three were unbuyable and undroppable in every previous release. That is 163 spell
  tomes and 133 scrolls in circulation, up from 160 and 130.
- The remaining twelve renamed summons stay out of shops and loot **for now**. They have never been
  cast in Enderal, and of the first three that were examined, two were broken — see the Herne and
  Craftlord fixes above. They will be released as each is tested.
- The **Conjure Entropic Mentor** spell now offers Enderal's five disciplines by name -- Mentalism,
  Entropy, Elementalism, Psionics and Light Magic -- where it used to list Skyrim's schools.
- Note this renames the spells, not the models: the Entropic and Sinistran summons still look like
  Bethesda's Dremora and Xivilai.

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
