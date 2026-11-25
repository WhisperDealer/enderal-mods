# Triumvirate — distribution test checklist

In-game proof for the distribution built by `tools/15-distribution.ps1` and
`tools/17-tier-gating.ps1`: the **45 ungated tomes**, and **one merchant per archetype**, each selling
that archetype's whole line (all five tiers plus its staves). Everything below has been verified
statically. Only launching the game can settle the rest.

## First: find the plugin's load-order prefix

Every FormID here is the **6-digit record part**. In game it needs the plugin's two-digit load
order index in front. Open the console and run this once:

```
help "Chase the Horizon" 4
```

It prints something like `BOOK: (0341EC7F) 'Spell Tome: Chase the Horizon'`. The leading **`03`** is
your `XX` — the same prefix for every ID in this document. Substitute it below.

> If `help` finds nothing at all, stop: the plugin is not loading, and none of the rest of this
> checklist will mean anything.

---

## Test A — the gate fix (5 commands, any save, ~2 minutes)

**This is the test that matters most.** `player.additem` on a **LeveledItem** resolves the list on
the spot and honours its chance-none, so these commands are a direct A/B on the bug: before the fix
every one of them produced **nothing at all**; after it, each yields the named tome.

Adding the *tome* FormID directly would prove nothing — it bypasses the list. Use the bundle IDs.

| ☐ | Archetype | Console command | Should add |
|---|---|---|---|
| ☐ | **Druid** | `player.additem XX438212 1` | Spell Tome: Chase the Horizon |
| ☐ | **Shadow** | `player.additem XX4381EF 1` | Spell Tome: Nightfall |
| ☐ | **Warlock** | `player.additem XX4381FA 1` | Spell Tome: Hurl Into Sinistra |
| ☐ | **Cleric** | `player.additem XX43820D 1` | Spell Tome: Mass Immortality |
| ☐ | **Shaman** | `player.additem XX4381D3 1` | Spell Tome: Sacred Hearth |

All five are **Master** tier — the deepest part of what was gated. Read each tome and confirm the
spell is castable and does something.

If you would rather add a tome directly (to test the spell rather than the list), those five are
`XX41EC7F`, `XX419B29`, `XX419B57`, `XX41EC75`, `XX414A0E` in the same order.

---

## Test B — each archetype's one vendor sells its whole line

Vendor stock is **cached in the save**: `iDaysToRespawnVendor` is 2, so a merchant only re-rolls
every two in-game days. Use a **fresh save**, or `wait` 48+ hours before opening a shop, or the
inventory you see is the one from before this change.

| ☐ | Merchant | `coc` target | Expect |
|---|---|---|---|
| ☐ | Sister Envy | `coc FSNQR03RhalataTemple` | **Shadow**: 15 tomes, Novice → Master, + 4 Shadow staves |
| ☐ | Shrouded Mage, Undercity | `coc UndercityBarracks1` | **Warlock**: 15 tomes, Novice → Master, + 8 Warlock staves |
| ☐ | Torius Flameling | `coc SuntempleAlchemy` | **Druid** (9 tomes: Mentalism + Light Magic, no Force of Nature), **Shaman** (10: no totems or Fylgjas), **Cleric** (10: no Psionics), + 8 staves |
| ☐ | Halda Stronghand | `coc SuntempleArmory` | **No** Triumvirate tomes or staves |

Low tiers are priced **41–105 gold**, Adept about **130–170**, and Expert/Master **210+**. Every
merchant above should show all three price bands.

> **Sister Envy is in a Forgotten Stories quest location.** If `coc FSNQR03RhalataTemple` lands you
> somewhere she is not, note at what point in the story she becomes reachable. She is the
> **only** Shadow vendor now.

---

## Test C — the old vendors are empty of Triumvirate

| ☐ | Where | `coc` target | Expect |
|---|---|---|---|
| ☐ | Marius, Ark library | `coc CapitalCityBibliothek` | **No** Triumvirate tomes or staves |
| ☐ | Shrouded Mage, Frostcliff Tavern | `coc SchneefelstaverneInterior` | **No** Triumvirate tomes or staves |
| ☐ | Adreyo, Riverville | — | **No** Triumvirate tomes |
| ☐ | Any merchant | — | **No** Druid Call spells, Shaman totems/Fylgjas or Cleric Psionics (Suggestion, Exile, Spirit Guardian, Obedience, Exodus) |
| ☐ | House of the Apothecarii, Undercity | `coc UndercityBarracks2ApothekariUpper`, pick the **Expert** lock | The chest beside the *Old Ban Totem* blueprint holds **10 tomes** (five Druid Call spells, Shaman's three totems and two Fylgjas) and **3 totem staves**, one each, plus its own items. It does not restock |
| ☐ | Sun Temple, Secret Vault | `coc FSSuntempleYeroCave` (in play: the key from Yero's strongbox, quest "Secrets") | A **Chest** at the north end of Yero's unholy altar holds the **5 Cleric Psionics tomes** (Suggestion, Exile, Spirit Guardian, Obedience, Exodus) and **3 staves** (Suggestion, Exile, Obedience), one each. It does not restock. Check it sits on the floor and is not clipping into the altar, the divider or the rock |

---

## Test D — the shared hook with Apocalypse

Only relevant if Apocalypse (Enderal conversion) is installed: it also writes Torius Flameling's
`TuriousFlammentrunk_CustomMerchandise`.

| ☐ | Check |
|---|---|
| ☐ | With Triumvirate loading **after** Apocalypse, Torius sells the Druid/Shaman line (and Apocalypse's own additions to him are absent, which is expected) |

---

## Test E — no new script noise

| ☐ | Check |
|---|---|
| ☐ | Start a **new game** and confirm the Papyrus log has **zero** `TVR_` errors (`Cannot call … on a None object`) |

Papyrus logging: set `bEnableLogging=1` **and `bEnableTrace=1`** in `[Papyrus]` of the **profile**
INI (`<modlistRoot>\profiles\<profile>\Enderal.ini`, not the Documents copy), then read
`Documents\My Games\Skyrim Special Edition\Logs\Script\Papyrus.0.log` — Skyrim's folder, not
Enderal's. Turn both back to `0` afterwards.

---

## If Test A or B fails

The tome record exists (`help` found it), so a failure means the list still refuses to yield. Check
the built plugin actually has the change. The built `.esp` should be **737,067 bytes / SHA-256
`4D62DC89…3FC95ACB`**. A stale `.esp` in the deploy folder is the likeliest cause; see guardrail 7 —
rule out "never loaded" before debugging "loaded but broken".
