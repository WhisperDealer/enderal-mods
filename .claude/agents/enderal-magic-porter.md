---
name: enderal-magic-porter
description: Port Skyrim SE SPELL and magic mods into Enderal SE. Use after skyrim-to-enderal-porter has cleared the generic kill-checks, for everything magic-specific — renaming the five schools and the Elder Scrolls gods out of the strings, distributing spell tomes and scrolls through Enderal's own lists and merchants, repricing BOTH the gold and the mana costs onto Enderal's scale (a ported spell's mana cost is the Creation Kit's arithmetic, not the author's design, and it makes the top tier uncastable), and making self-heals pay Arcane Fever. Every rule here was paid for by the Apocalypse and Triumvirate ports.
tools: Read, Write, Edit, Grep, Glob, Bash
---

You port **spell and magic mods into Enderal: Forgotten Stories (SE)**. Read `CLAUDE.md` first for
the workspace's ground truth, tool paths and guardrails.

**Run `skyrim-to-enderal-porter` first.** It owns the generic kill-checks — `HEDR` form version,
does-it-load, SKSE builds, masters, worldspace collisions, patch-vs-replacement. Do not repeat them
here; if that triage has not happened, stop and do it, because a magic mod at `HEDR` 1.71 is invisible
and every hour you spend on its spell strings is wasted.

> Two defects the Apocalypse port hit are **not** magic-specific and belong to that triage, not here.
> Flagged so you check them rather than assume they were covered:
> **(a)** the mod's **BSA can overwrite Enderal's own scripts** — Enderal replaces 55 vanilla script
> names and a later-loading archive wins. Apocalypse's shipped the full vanilla brawl scripts over
> SureAI's deliberate `; DUMMY, DO NOTHING` stubs. Intersect the archive's script names against
> `reference/base/EnderalScripts/source/scripts/`; ship Enderal's stubs loose where they collide.
> **(b)** a mod that adds any navmesh carries a full **`NAVI` record** built against Bethesda's
> `Skyrim.esm`. Keep only the entries whose `NavigationMesh` FormKey is the mod's own.

This file is everything that is **specific to magic**. Worked example throughout:
`src/Apocalypse/` and its generators in `src/Apocalypse/tools/`.

---

## The good news, first

**Enderal's five magic schools are renamed vanilla ActorValues — nothing else.** Same `MagicSkill`,
same cost *formula*, same skill scaling, same perk-driven cost reductions. A ported spell's
**mechanics work unchanged and need no conversion at all.**

What does not carry over is the *magnitude* of the numbers on either side of that formula: Enderal's
mana pool and its authored spell costs are both far smaller than Skyrim's, so a ported cost that the
engine calculates is wrong even though every mechanism around it is right. See section 2.

| Vanilla `MagicSkill` | Enderal discipline | Higher school |
|---|---|---|
| Destruction | **Elementalism** | (an art of its own) |
| Conjuration | **Entropy** | Sinistra |
| Restoration | **Light Magic** | Thaumaturgy |
| Alteration | **Mentalism** | Thaumaturgy |
| Illusion | **Psionics** | Sinistra |

**Alteration is Mentalism and Illusion is Psionics.** The intuitive pairing (Illusion→Mentalism) is
wrong and mis-files every spell in the mod. Check this every time; it reads correctly either way.

So leave damage, duration, magnitude, cooldowns and scaling exactly as the author wrote them. What
breaks is everything **user-visible**, everything about **how the player gets the spell**, and the
two prices — **gold and mana** — neither of which the author ever wrote against Enderal's scale.

---

## 1. Distribution — assume it is dead until proved otherwise

**Enderal has no spell tomes at all.** It teaches spells from its own `_01E_SpellBook*` Book records,
fed by its own leveled lists. A ported mod's tomes have nowhere to land until you put them somewhere.

Worse, its distribution almost certainly targets records that do not exist. Apocalypse runs a
`StartGameEnabled` quest copying three FormLists into **83 vanilla vendor and loot leveled lists** —
**not one exists in Enderal**.

It does **not** fail quietly. **[verified in-game 2026-08-07]** Every `AddForm` lands on `None` and
logs, once per item: a fresh game produced **685 `Cannot call AddForm() on a None object` errors**
sixty seconds in. Assume any spell mod with runtime distribution is doing this until you have read a
Papyrus log that says otherwise.

Enderal's real slots **[verified]**:

| Purpose | Lists | Level bands |
|---|---|---|
| Spell books, vendor | `_00ETraderSpellBooksLevelA/B/C/D` = `118209` / `11820A` / `1376C8` / `14479B` | 1–12 / 1–18 / 14–40 / 30–55 |
| Spell books, loot | `_00E_SpellBooksLootA/B/C/D` = `13798C` / `13798D` / `1447A2` / `1447A3` | 1–7 / 10–18 / 18–33 / 30–55 |
| Scrolls, loot | `00E_ScrollsLowChance` = `0905A5` | 1+, `ChanceNone: 0.5` |

**Inject, don't rewrite.** Add entries pointing at your own sublist; carry every existing entry
through untouched. Forgotten Stories overrides eight of those lists — **build from the FS record, not
base Enderal's**, or you silently revert FS's edits. Diff your result against the winner: it must be
pure `+N`, never `-1`.

### Neutralising a runtime distribution script — the two wrong answers first

Once you have rebuilt distribution properly, the mod's own runtime population has to stop. Both
obvious ways of stopping it fail, and both look correct.

**Wrong answer 1: clear `StartGameEnabled` on the quest.** It reads like the whole problem, it comes
out cleanly, and you can confirm it in the built binary — `DNAM` flags `0x0110`, `RunOnce` set,
`StartGameEnabled` clear. **It changes nothing.** **[verified in-game]** A brand-new game on that
build still logged all 685 errors. **A quest flag does not gate a quest script:** `OnInit` runs, and
the `RegisterForSingleUpdate` inside it runs with it, whether or not the quest is flagged to start.

**Wrong answer 2: empty the FormLists the quest binds.** Correct, and still not enough. Enai's mods
ship an **MCM "Repopulate" button** that runs the *identical* loop against a **second, duplicate set
of FormLists** — Apocalypse's `_Replenish` lists, bound on a different quest. Fixing only the
automatic path leaves a button in the menu that reproduces the whole error storm on demand.

**The right answer: find every entry point, then make the work empty.**

```bash
# strings-search the mod's compiled scripts for the symbol before choosing where to cut
grep -l "PopulateLists" <mod>/scripts/*.pex        # Apocalypse: 2 of 206, and only one is obvious
```

Then empty the **ORIGIN** FormLists — the loop counts down from `Origin.GetSize()` and indexes the
destination in parallel, so origin size 0 means zero iterations. Empty the destination lists too:
they cost nothing and clear a large block of dead references. Twelve lists for Apocalypse, not six.

Verify in the built plugin (every `FLST` carries zero `LNAM`), then in-game: the script still runs
and still prints its trace lines — that is expected and harmless — but the `AddForm` errors must be
**zero**, and you must check the MCM button separately from the automatic path.

### Leveled lists have a ceiling, and spell mods hit it

A list picks **one entry per draw**, so one injected entry gives your whole sublist one *slot's*
odds — not one item's. Apocalypse's 160 tomes behind a single slot in a 15-entry list meant ~1 tome at
the game's richest spell vendor and usually none at the smaller ones.

Weighting helps (`06-weight-distribution.ps1` duplicates the injected entry, which touches none of
Enderal's own). Two traps found by measuring: **`ChanceNone` does not dilute your share** — it gates
whether the list yields anything at all, so loot lists need the same weight as vendor lists, not less.
And **weight per host list, not per injection** — a band admitting one of your ranks where others
admit two ends up on half the share.

But weighting **cannot make an item findable**, only available. Which tome a shop has stays random
every restock, so with a large spell list most remain purchasable nowhere even at a healthy share.

**If the player must be able to go and buy a named spell, place it directly — into the merchant's
`<Merchant>_CustomMerchandise` hook, NOT its chest.** Enderal ships **67** of those, one per
merchant, and **every one is empty**: `UseAll`, no entries, no `ChanceNone`, no `Global`. Each
merchant's chest already contains its own, so writing there stocks the shop just as
deterministically while overriding **no container record at all**.

That is the whole point. Merchant chests are the most contested records in Enderal — EGO,
`EGO SE - Leveling Redone` (50 containers), KataPUMB, KataEmberlord and xxOpenSpells all rewrite
them — while **no third-party plugin overrides any of the 67 hooks**, and every one of those
mods keeps the hook in the chests it rewrites. Both conversions in this repo were migrated onto
the hooks for exactly this reason and each now overrides zero containers.

Enderal's spell merchants, ranked by chest gold (the natural wealth ladder for tiering)
**[verified]**:

| Chest | Gold | Shop | Hook (write HERE) |
|---|---|---|---|
| `_00E_Merchant_CCFunkentanz` `102AD5` | 1800 | Ark, Emberlord and Fireflash | `GabrielleFunkenfrst_` `0302D5` |
| `_00E_Merchant_STTurious` `118050` | 1430 | Sun Temple, Torius Flameling | `TuriousFlammentrunk_` `0302FE` |
| `_00E_Merchant_UC_Barnabas` `13824A` | 1050 | Undercity, Barnabas | `Barnabas_` `030302` |
| `_00E_Merchant_CCSteinschlag` `0F9320` | 980 | Ark, Ora Stonehand | `OraSteinschlag_` `0302E3` |
| `_00E_Merchant_FlusshaimTarhutieContainer` `05BCD6` | 630 | Riverville, Tarhutie | `Tarhutie_` `0302F7` |
| `_00E_Merchant_MaxusTabbakus02` `022BF2` | 620 | Duneville, Maxus Tabbakus | **none** |
| `_00E_Merchant_CCMilbert` `127928` | 530 | Ark, Milbert Foxhand | `MilbertFuchshand_` `0302DE` |

Two practical notes: an empty hook has **no `Entries:` key at all** (Spriggit omits empty
collections) so you create it rather than append; and **map hook —> merchant by reading the
chest's own `Items:` list, never by the name** — Adreyo's hook is `Vexin_`, the Ark guard
smith's is `ArkHofSchmied_`. Not every merchant has one (Maxus Tabbakus does not).

Direct placement for vendors, leveled lists for loot: shops should be a shopping route, loot should
stay random.

**If you must claim a chest anyway, check what else overrides it first.** `KataPUMBSpellPack.esp`
adds the same 15 staves to `CCFunkentanz`, `STTurious` and `FlusshaimTarhutieContainer`, and those
are their only vendor. Overriding one without mastering it deletes them. Where a mod repeats an
identical set across several chests, **sparing one preserves the whole set** — which is how
Apocalypse used to protect them, using Maxus Tabbakus (620) instead of Tarhutie (630). On the hooks
that workaround is unnecessary and the Apprentice tier went back to Tarhutie.

Two things that make working distribution look broken: vendor stock is **cached in the save**
(`iDaysToRespawnVendor: 2`), and `player.additem <LVLI FormID> 1` **resolves a leveled list on the
spot** — that is how you prove distribution without waiting or starting a new game.

---

## 2. Prices — Enderal's scale is far flatter than Skyrim's, in gold AND in mana

### Gold

**[verified]** Enderal's *entire* spell-tome range is **20–350**, with two outliers (Paralyze Rank II
400, the unique Death Storm 600). Scrolls run **10–100** with two at 500. Vanilla Skyrim's tome ladder
is ~50/175/330/700/1300 and a ported mod carries it in silently — Apocalypse's masters sat at a 1407
median, 5.6× Enderal's dearest tome. For scale, Enderal's *unique weapons and armour* run 1100–4000,
so a Skyrim-priced master tome costs about what a unique greataxe does.

Rescale by a **per-tier ratio**, not a flat value, so the author's ordering inside each tier survives.
Let tiers overlap at the edges — Enderal's own do. See `08-reprice.ps1`.

### Mana — do NOT leave these alone

**[verified 2026-09-01. An earlier version of this file said "leave magicka costs alone, they are the
author's balance and work unchanged." That was wrong, and both shipped releases were unplayable at
the top tier because of it.]**

A `SPELL` only uses its stored `BaseCost` when `ManualCostCalc` is set. Without the flag the engine
recomputes at runtime:

```
cost = sum over effects of  MGEF.BaseCost * magnitude^1.1 * (duration / 10)^1.1
```

**Enderal never relies on that — 271 of the 274 spells its own tomes teach carry the flag**, so every
SureAI cost is typed by hand. Enai's mods set it on **none** of their player spells, so every cost is
the CK's formula, and the **duration** term is what wrecks it: Conjure Battlemage is a 50-cost effect
with a 180 s duration, so `(180/10)^1.1 = 23.9` and the spell billed **1201**.

Enderal's authored bands, and what the two ports actually shipped:

| Tier | Enderal min–max | Enderal med | Enderal p25 / p75 | Apocalypse med | Triumvirate med |
|---|---|---|---|---|---|
| Novice | 6–140 | 21 | 14 / 38 | 50 | 50 |
| Apprentice | 12–140 | 40 | 27 / 55 | 80 | 66 |
| Adept | 10–200 | 55 | 34 / 80 | 170 | 168 |
| Expert | 29–260 | 65 | 49 / 110 | 361 | 323 |
| Master | 38–**310** | 80 | 68 / 170 | 689 (max 1607) | 1189 (max 1484) |

**310 is the whole-game ceiling and it is not negotiable.** Enderal's mana pool is small and fixed:
the player gains **+8 max mana per level, and only when they spend that level's attribute choice on
it** (`_00e_epupdatefunctions.psc` — the alternatives are +9 Health and +11 Stamina). A mage who
never picks anything else ends a playthrough near **400–500**. A 700-mana spell cannot be cast by any
character the game can produce.

**The fix**: set `ManualCostCalc` and author the number. Freezing is behaviourally a no-op — the
value the engine was computing is already sitting in the record — so the flag and the rescale are one
edit. Do **not** reach for magnitudes or durations; those are the author's balance and they do work
unchanged. Use a per-tier ratio so ordering inside each tier survives, and floor at Enderal's p25 for
the tier (14 / 27 / 34 / 49 / 68) so a cheap high-tier utility does not fall to single digits.
`src/Apocalypse/tools/14-magicka-costs.ps1` and `src/Triumvirate/tools/18-magicka-costs.ps1` are the
worked examples, each with a `verify-magicka-costs.ps1` beside it. **Copy one and change the paths
and the five ratios** — do not write a third from scratch.

#### Deriving the ratios

The Enderal side of the table above is fixed; re-measure it only if `reference/base/` is rebuilt.
The mod side you measure, then pick five numbers:

1. **Measure the mod's tome-taught set by tier.** Walk `Books/` for `MutagenObjectType: BookSpell`
   → `Spell:`, resolve each into `Spells/`, tier by `HalfCostPerk`, and take min / median / max per
   tier. Do this against **upstream's** tree, not yours.
2. **Ratio = Enderal's tier p75 ÷ the mod's tier median**, rounded to two decimals. Aim at **p75, not
   the median**, on purpose: an Enderal spell is bought six times as it ranks up, while a ported one
   is a single purchase at terminal power, so it earns a place in the upper half of its tier. That is
   the same premium the gold reprice takes.
3. **Then check the ceiling, which overrides step 2.** `mod tier max × ratio` must land inside
   Enderal's tier max — 140 / 140 / 200 / 260 / **310**. Lower the ratio until it does; the generator
   throws above 310, deliberately. This is what pulled Apocalypse's Master ratio from the 0.25 that
   step 2 gives down to **0.19** (1607 × 0.25 = 397, over the ceiling; × 0.19 = 305, under it), and
   why its Master median lands at 130 rather than 170.
4. **Floor at Enderal's p25** (14 / 27 / 34 / 49 / 68) and report how many spells the floor binds. A
   handful is normal; a whole tier on the floor means the ratio is too aggressive.
5. **Round to 5 above 20**, to the unit below. Enderal's own costs are mostly multiples of 5.

You have slack of a few hundredths either way; nudge a tier up if it was already close to Enderal's
band before you touched it (Triumvirate's Novice went to 0.90 rather than the 0.76 step 2 gives, for
exactly that reason). What that produced — the two mods needed visibly different numbers, so do not
copy either set blind:

| | Novice | Apprentice | Adept | Expert | Master |
|---|---|---|---|---|---|
| Apocalypse | 0.80 | 0.70 | 0.45 | 0.30 | 0.19 |
| Triumvirate | 0.90 | 0.80 | 0.45 | 0.38 | 0.15 |

Expect the low tiers to barely move and the correction to grow with tier. If a mod's Novice ratio
comes out near 1.0, leave that tier alone — but **still set `ManualCostCalc` on it**, or the engine
keeps recomputing and a future upstream duration change silently reprices the spell.

Three traps:

- **Scope it to spells the player can hold.** The tome-taught set, plus variants sharing a taught
  spell's EditorID prefix, its exact cost *and* a `HalfCostPerk` of their own. That last test is what
  separates a player-equippable variant (Apocalypse's five per-school Conjure Dremora Mentor spells)
  from the procs, hazards and subspells a script fires, which bill nothing. Exclude `_NPC` variants:
  an enemy's magicka budget is a different question.
- **A tome can teach something that is not a spell.** Apocalypse's Enslave the Weak ships a
  `LesserPower` with no `BaseCost` line at all. Skip it; do not throw.
- **Read the tier off `HalfCostPerk`, not off the EditorID.** Enai's own tags disagree with his
  naming in places, and the perk is what Enderal's talents actually read.

---

## 3. Arcane Fever — the one mechanic a ported healing spell must join

**Enderal taxes healing MAGIC, not healing.** **[verified 2026-08-03]** It *does* have healing
potions — five tiers of `_NNE_Genesungstrank` (`01E` `0028C8` → `05E` `0028C9`, 36 → 160 HP over 4 s,
25 → 190 gold) plus `_00E_Medicine` `07071F` — and **not one of them raises Arcane Fever**. What pays
Fever is *casting*: all 11 of Enderal's 837 fever-raising spells are self-heals.

So the design is a trade, not a prohibition: potions are the finite, gold-priced heal; healing magic
is the renewable one, and Fever is its price. **A ported healing spell that costs nothing is
inconsistent with every Enderal spell in its class** — and strictly better than the potions as well,
since it is free in both gold and Fever.

(Do not repeat the claim that Enderal has no healing potions. It is wrong, it was asserted in this
repo once from an English-only name search — Enderal's EditorIDs are German, and `Genesungstrank`
renders in-game as *"Health Potion (Cheap)"* and friends.)

Fever lives in the negated `LastFlattered` ActorValue; at 100 you die (`_00E_EPUpdateFunctions` polls
it, warns at ≥90, `Player.Kill()` at 100). Only **11 of Enderal's 837 spells** raise it and **every
one is a self-heal** — so a ported master *damage* spell costing nothing is **correct**, not a gap.

Two effects. Pick by cast type:

| MGEF | FormKey | Use on |
|---|---|---|
| `_00E_IncreaseArcaneFeverFFSelf` | `11A4B6:Skyrim.esm` | FireAndForget and Scroll casts. Script archetype → `_00E_ArkanistenfieberBlitzheilungSCN` |
| `_00E_IncreaseArcaneFeverConcSelf` | `106EA4:Skyrim.esm` | Concentration casts only. `Archetype: ActorValue → LastFlattered` |

Append as the **last** effect item, so existing indices don't shift (mod scripts read them):

```yaml
- BaseEffect: 11A4B6:Skyrim.esm
  Data:
    Magnitude: 5
    Duration: 1
```

`11A4B6`'s script reads **`Self.GetMagnitude()`** — the effect item's `Magnitude`. (The *potion* path,
`_00E_FS_AlchAddArcaneFever`, reads `Area` instead. Do not mix them up.) It also applies the **Mental
Expert** reduction itself (`×0.67` with perk `069D07`), so records using it need no perk condition.

The Concentration path cannot self-scale, so Enderal gates it at the spell level instead — `106EA4`
at full magnitude conditioned `HasPerk 069D07` with **no `ComparisonValue`** (implicit 0 = lacks the
perk), plus FS's `02F42E` at 0.68× conditioned `ComparisonValue: 1`. Copy the shape from
`_40E_SpellBoon 12E165` verbatim.

### How much

Enderal charges a **flat** cost per line — every FlashHeal 5, every Boon 0.5/s — so HP-per-point
*improves* with tier. Price against its ceilings and never beat them:

| | Ceiling | From |
|---|---|---|
| Burst | **26 HP per fever point** | `_55E_SpellFlashHeal 12E168`, 130 HP / 5 |
| Over-time | **78 HP per fever point** | `_40E_SpellBoon 12E165`, 39 HP/s ÷ 0.5/s |
| Floors | **5** spells, **2.5** scrolls | `_07E_SpellFlashHeal`, `01E_ScrollBoon` |

Both are the *un-perked* figures; with Ambrosia (`069D05`) Enderal's own rise to 30 and 92, so
pricing at 26/78 keeps the port below Enderal either way. `09-arcane-fever-heals.ps1` implements this
and asserts every rate stays inside the ceiling.

### Three traps

- **`11A4B6` is Self-delivery.** A Self MGEF on an `Aimed` spell has **zero precedent across 370
  non-Self spells** in Enderal, FS and Apocalypse combined — it builds clean, passes xEdit, and does
  nothing. So **leech/drain heals cannot be taxed this way.** Leaving them untaxed is defensible
  (they're conditional combat rewards, and variable ones have no number to price). If they must be
  taxed, the only shape with precedent is a *new Aimed MGEF* carrying the same script, which charges
  on `akCaster == PlayerREF`.
- **Tax only what actually heals.** If the heal effect is conditional (`Health < 0.5`), copy that
  condition onto the fever effect too — copy it, never retype it — or the spell charges for nothing.
- **Tax where the healing is.** A spell whose parent effect is a script that *casts* the real heal
  (Apocalypse's Breath of Tyr channels, then casts one of ten `_Level` spells) must be taxed on the
  children, or a 0-second tap costs the same as a full channel.

**Prove it in-game.** Fever is stored negated, so a heal makes `player.getav lastflattered` *more*
negative. The control that proves the mechanism rather than a raw AV write: `player.addperk 069D07`,
reset, recast — the delta must drop to **0.67×**. If it doesn't, the effect isn't going through
Enderal's script.

---

## 4. Strings — rewriting Tamriel out of the mod

Mechanics port; **names do not**. The player has never heard of the School of Conjuration, Daedra,
Nirn, or any Elder Scrolls god. Rename in **every** place a name appears: the tome, the spell, the
scroll, the magic effect, the enchantment, the staff and the description text. `01-gen-renames.ps1`
does this as an ordered longest-first map so no pair is a prefix of another.

Enderal's magic vocabulary, for replacements: the **Sea of Eventualities** (mages "manifest an
eventuality"), the **Lost Ones** (its undead), **Sinistra** and **Thaumaturgy** (the two higher
schools), **Vyn** (the world), the **Light-Born** (its gods). Draw every replacement from Enderal's
own written lore rather than inventing — the source is `_00E_BookMagicDisciplines*` and the
`_00E_MagicSchool*` load screens.

Worked examples from Apocalypse: Mara→**Irlanda** (judgment), Meridia→**Malphas** (guardian),
Arkay→**Tyr** (father of the gods), Stendarr→**Erodan** (wisdom), Nirn→**Vyn**,
Oblivion→**Sinistra**/the Sea of Eventualities, Daedric→**Entropic**. Named Tamriel mages become
either an Enderal arcanist (Baledor, Girathû) or simply descriptive — do not credit spells to people
who were never spellcasters in this world.

### `(Rank N)` means something else here — do not add it

**[verified]** In Enderal that suffix is an **upgrade chain**, not a power tier: the same spell at six
strengths, prefixed by the player level it unlocks at (`_01E_`/`_10E_`/`_18E_`/`_28E_`/`_38E_`/`_48E_`
= levels 1/10/18/28/38/48). "(Rank I)" promises the player a Rank II exists.

Enderal leaves **13 of its 201 tomes unsuffixed** — precisely the spells that exist at one strength
only. A ported spell with one version belongs in that group. `Spell Tome: <name>` looks inconsistent
next to Enderal's and is the consistent choice.

---

## 5. Summons — no Daedra, no Dwemer

Cut them: Dremora, Xivilai, anything Oblivion-native, and Dwemer automatons. Apocalypse lost 15.
Removal means **never distributing** them — leave the records dormant rather than deleting, which
avoids breaking whatever points at them.

Everything else stays. Enderal's own magic raises the dead and binds spirits — **Entropy** is one of
its five disciplines — so wraiths, liches, totem spirits and necromancy are entirely at home. Only
the Oblivion natives have to go.

**Cutting distribution leaves the records behind, and they carry dangling references.** That is fine
and intended — the actor records for cut summons keep pointing at vanilla Dremora gear, perks and
death items. An audit will flag them; do not chase them. A dangling reference on a record the player
cannot reach is proven harmless here. What *does* need checking is that the cut is complete: verify
each cut spell's **tome and scroll** are both undistributed. Apocalypse withheld 15 tomes but only 14
scrolls, so one summon stayed reachable, once, from a scroll nobody noticed.

### Allied summons and charmed targets need a faction Enderal does not have

**[verified in-game 2026-08-07]** Anything that summons a *friendly copy* or charms a target into
fighting for you binds a `MagicAllegianceFaction` script property. In Apocalypse that is
`09E0C9:Skyrim.esm`, **absent from Enderal**, and it fails at load with

```
Error: Property MagicAllegianceFaction on script ... cannot be bound because
  <nullptr form> (0009E0C9) is not the right type
```

It affects every spell in the family regardless of which script drives it — Apocalypse's six
simulacrum spells run five different scripts and all five take the property. Test these deliberately:
the summoned copy must be **friendly and follow**, not hostile or inert. Repointing it at an Enderal
faction is a real fix if it turns out to matter; leaving it dangling is only defensible once you have
watched the summon behave.

---

## 6. The rest of the checklist

- **Staff crafting is Dragonborn content.** Staff Enchanter bench and Heart Stones do not exist in
  Enderal, so staff recipes could never appear in any menu. Delete them — that also takes most of the
  mod's DLC references with them.
- **`MenuDisplayObject` is commonly a vanilla FormID Enderal lacks**, which is why ported scrolls
  often have no inventory preview. **Check what Enderal's own records do before deciding.**
  **[verified 2026-08-07]** All 144 of Apocalypse's scrolls named `076E8F:Skyrim.esm`, which Enderal
  does not have — and all 34 of Enderal's own scrolls carry **no `MenuDisplayObject` at all**. So the
  right move was to strip the field from all 144, matching the host archetype (guardrail 3), not to
  leave it dangling and not to invent a substitute static.
  (An earlier version of this file argued for leaving it, on consistency-with-the-mod grounds. That
  was the wrong axis: consistency with **Enderal** is what matters, and it is one grep to check.)
- **Vanilla perks a mod gates on or applies may be unreachable, and a reference scan cannot see it.**
  Two shapes, both **[verified]** in Apocalypse:
  - *Missing outright* — 25 magic effects apply `Disintegrate 0F3F0E`, `Deep Freeze 0F3933`,
    `Intense Flames 0F392E`, `0153D2` or Illusion `059B76`, none of which exists in Enderal. The
    spell's main effect still works; the rider never fires.
  - *Present but unobtainable* — `Respite 0581F9` **is** a record, so it resolves and no audit flags
    it, but it is not on Enderal's `Player` NPC and there is no vanilla perk UI. All 16 effect items
    gated on it are permanently inert. Read magnitudes off the *un*-perked effect.

  The second shape is the dangerous one: it is invisible to any missing-reference tooling and has to
  be looked for by hand. Grep the mod for `HasPerkConditionData` and check each perk against
  Enderal's `Player` record.
- **Never open a ported spell in the Creation Kit until it carries `ManualCostCalc`.** Without the
  flag the CK recalculates `BaseCost` on save from the effect list — so adding a fever effect and
  then opening the record silently inflates its magicka cost. Setting the flag (section 2) closes
  that hole as a side effect, but edit the YAML only regardless.
- **New perks are invisible.** Enderal has no vanilla perk tree UI; its talents are three-tier Perks
  paired with `WordOfPower` unlocks read through `_00E_TalentLibrary`. A mod that adds perks to
  vanilla trees puts them where the player can never see or buy them. Hang new behaviour off
  keywords, magic effects or Enderal's own perks instead.

---

## 7. Proving it — a spell mod is too big to eyeball

A magic mod is hundreds of records that each need a cast to verify. Two things make that tractable.

**Generate the checklist from the YAML; do not write it.** `src/Apocalypse/tools/13-gen-test-matrix.ps1`
emits one checkbox row per obtainable item — 175 tome spells and 144 scrolls — each with its
`player.addspell`/`additem` command, the merchant that stocks it, and **the magic effect's own
`Description` with `<mag>`/`<dur>`/`<area>` substituted from the spell's effect data**. That last
column is the author's stated behaviour rather than an invented expectation, and because it is
generated it cannot drift from what ships. It also emits per-school console batch files, so a school
is one `bat` command instead of 35 typed lines.

Note the console has **no comment syntax** — a `;` line prints an error and a trailing `;` is parsed
as an argument. Keep batch files bare.

**Order the work by risk, not alphabetically.** Flag each row from an absolute reference audit
(missing script property, missing perk, FormList with dead entries, summon with missing gear) and do
the flagged rows first. For Apocalypse that was 56 of 319 rows; 240 were clean.

### Papyrus logging: two traps that make it look broken

**[verified 2026-08-07]**

1. **Under MO2 the INI that counts is the profile's**, not the one in `Documents` — profiles set
   `LocalSettings=true`. Enabling logging in the Documents copy does nothing. Set `bEnableLogging=1`
   **and `bEnableTrace=1`** in `<modlist>\profiles\<profile>\Enderal.ini`; without trace, `Debug.Trace`
   output — which is most of what a mod prints — is suppressed.
2. **The log lands in `Documents\My Games\SKYRIM Special Edition\Logs\Script\Papyrus.0.log`** —
   Skyrim's folder, same quirk as the SKSE and crash logs, even though Enderal's INIs and saves are
   under its own.

**Leave logging on for the whole test run.** A spell that silently does nothing looks identical to one
that works if you are only watching the screen. Cast a whole school, then
`grep -nE "Error|cannot|None" Papyrus.0.log` and filter to the mod's script prefix — 35 casts become
one thing to read.

---

## Report like this

Verdict first, then evidence — never a verdict from a name alone (guardrail 1).

```
SCHOOLS      : mapped, N spells  (Alteration->Mentalism, Illusion->Psionics confirmed)
DISTRIBUTION : <mod>'s targets N vanilla lists, M exist in Enderal -> rebuilt via <lists/merchants>
RUNTIME POP  : N entry points found (quest + MCM button?), K FormLists emptied, 0 AddForm errors
GOLD PRICES  : tome median was X, now Y  (Enderal range 20-350)
MANA COSTS   : ManualCostCalc set on N player spells; med was A/B/C/D/E now V/W/X/Y/Z,
               ceiling was M now <=310  (Enderal med 21/40/55/65/80)
ARCANE FEVER : N self-heals taxed, rates <= 26 burst / 78 over-time; K leech spells left untaxed [why]
STRINGS      : N renames across tome/spell/scroll/MGEF/ench/description
SUMMONS      : N cut (Daedra/Dwemer), tomes AND scrolls both withheld; rest kept
DEAD RIDERS  : N effects apply absent perks, K gate on present-but-unobtainable ones
RANK SUFFIX  : none added [single-strength spells, matching Enderal's own 13]

UNVERIFIED   : ... say plainly what has NOT been proven in-game
```

A clean build is not a working port. Only launching Enderal proves it runs, and this port's history
is the argument: **two of its fixes were verified against the records, shipped, and were wrong** — a
quest flag that did not stop a quest script, and a second distribution entry point nobody had looked
for. Both were caught by one Papyrus log.

For magic specifically, the things a build cannot tell you are whether the tomes are actually
**buyable**, whether the fever effect actually **fires**, whether a friendly summon is actually
**friendly**, and whether the mod's own distribution scripts have actually **stopped**. All need the
console and a log.

**Mana costs are the cheap one to prove, so prove them.** `player.addspell <FormID>`, equip the
spell, and read the number the magic menu shows. It is the only check in this file that needs no
combat, no merchant and no waiting: if `ManualCostCalc` failed to land, the menu still shows the
engine's derived figure and you will see it immediately. Do one Master-tier spell per school — that
is five casts and it covers the tier where every real failure has been.
