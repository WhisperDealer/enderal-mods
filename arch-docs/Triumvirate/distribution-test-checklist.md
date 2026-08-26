# Triumvirate — distribution test checklist (WD-16b)

In-game proof for the two changes in `tools/17-tier-gating.ps1`: the **45 ungated tomes**, and
**Expert/Master confined to Ark and the Undercity**. Everything below is verified static — this is
the part only launching the game can settle.

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

## Test B — Expert/Master really are Ark + Undercity only

Vendor stock is **cached in the save**: `iDaysToRespawnVendor` is 2, so a merchant only re-rolls
every two in-game days. Use a **fresh save**, or `wait` 48+ hours before opening a shop, or the
inventory you see is the one from before this change.

### Should HAVE Expert/Master

| ☐ | Where | `coc` target | Expect high tiers for |
|---|---|---|---|
| ☐ | Marius, Ark library | `coc CapitalCityBibliothek` | Cleric, Shadow, **Druid, Shaman** |
| ☐ | Shrouded Mage, Undercity | `coc UndercityBarracks1` | Warlock, Shadow, **Druid, Shaman** |
| ☐ | The Bash Hole | `coc UndercityBarracks3BashHole` | Warlock |
| ☐ | The Fence, the False Dog | `coc UndercityBarracks0FalseDogTavern` | Shadow |

Marius is the single best check — he should carry high-tier tomes for **four of the five**
archetypes, including Druid and Shaman, which he sells at no other tier.

### Should NOT have Expert/Master

| ☐ | Where | `coc` target | Expect |
|---|---|---|---|
| ☐ | Shrouded Mage, Frostcliff Tavern | `coc SchneefelstaverneInterior` | Druid + Shaman tomes, but **nothing above Adept** |
| ☐ | Shrouded Mage / smith, Duneville | `coc DuenenhaimMain` | Shaman + Druid tomes, **nothing above Adept** |

This half is the actual gating test. A quick way to read it: the low tiers are priced **41–105
gold** and Adept sits around **130–170**; anything at **210+** is Expert or Master and should not be
in these two shops.

---

## Test C — the low tiers did not move

| ☐ | Check |
|---|---|
| ☐ | Frostcliff and Duneville still stock their Druid/Shaman lines up to Adept — the change should have taken **nothing** away below the top two tiers |
| ☐ | Marius still stocks Cleric and Shadow at the low tiers too, not only the high ones |

---

## Test D — no new script noise

| ☐ | Check |
|---|---|
| ☐ | Start a **new game** and confirm the Papyrus log has **zero** `TVR_` errors (`Cannot call … on a None object`) |

Papyrus logging: set `bEnableLogging=1` **and `bEnableTrace=1`** in `[Papyrus]` of the **profile**
INI (`<modlistRoot>\profiles\<profile>\Enderal.ini`, not the Documents copy), then read
`Documents\My Games\Skyrim Special Edition\Logs\Script\Papyrus.0.log` — Skyrim's folder, not
Enderal's. Turn both back to `0` afterwards.

---

## If Test A fails

The tome record exists (`help` found it), so a failure means the list still refuses to yield. Check
the built plugin actually has the fix — the `Global:` line should be gone from all 45 Adept/Expert/
Master tier bundles, and the built `.esp` should be **739,071 bytes / SHA-256 `43B8EF1E…161510`**.
A stale `.esp` in the deploy folder is the likeliest cause; see guardrail 7 — rule out "never
loaded" before debugging "loaded but broken".
