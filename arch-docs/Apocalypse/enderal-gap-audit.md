# What Apocalypse needs that Enderal does not have

**[verified 2026-08-07]** against `reference/base/` and the shipped `src/Apocalypse/ApocalypseESP/`.

Enderal's `Skyrim.esm` is not Bethesda's — it is base Enderal wearing the same filename (see
[`../enderal/plugin-architecture.md`](../enderal/plugin-architecture.md)). So a ported Skyrim mod's
references land in one of three states, and only an audit tells them apart:

| State | Meaning |
|---|---|
| **missing** | the FormID is not in Enderal at all — the reference is dead |
| **present** | the FormID resolves — but it may be a *different record*, which is worse than dead because nothing warns you |
| **present but unreachable** | the record exists and is correct, and the player can never get it (vanilla perks) |

## The blind spot this closes

`verify-dangling-diff.ps1` has always reported **0 new** unresolved references, and it is right to.
It answers "did *we* break anything relative to Enai's plugin?" — a different question from "does
this plugin point at things Enderal has?", which nothing was asking.

`verify-missing-refs.ps1` asks the second one. Two differences make it able to:

1. **It keys the index by `<hex>:<master>`, not by hex alone.** Keying on hex lets any hex that
   appears anywhere in `reference/base/Skyrim` count as "defined by `Skyrim.esm`", which inflates
   that index from ~87k real records to **786k** and silently resolves references that are in fact
   dead.
2. **It resolves surviving references to their Enderal record group and EditorID**, so the
   present-but-different case is visible.

## What it found, and what happened to it

Before this audit: **4,077 missing-reference occurrences, 617 distinct FormKeys, 261 records.**
After the fixes: **267 / 201 / 109.**

> **A dangling-reference count is not a severity ranking.** 3,498 of the 4,077 were one deletable
> record that probably cost the player nothing. `Locate Potion` is broken by **seven**.

### Fixed

| # | Finding | Fix |
|---|---|---|
| 1 | **A full vanilla NAVI record.** `012FB4:Skyrim.esm`, 6,633 lines, **3,498 of the 4,077** missing refs. Apocalypse adds two interior cells, so the CK regenerated the whole record and it carried Bethesda's navigation map: 10 vanilla exterior `MapInfos` entries with thousands of merge FormIDs, plus a `PreferredPathing` block of 6,312 references, **zero** of them Apocalypse's. Its entries name `ParentWorldspace: 00003C:Skyrim.esm` — Tamriel in Skyrim, **`MQP01Home`** in Enderal. Enderal's own `Skyrim.esm` NAVI has a **null FormKey** (Spriggit writes `Null.yaml`); the real map is `000802:Enderal - Forgotten Stories.esm` | `10-strip-vanilla-navi.ps1` keeps only the three Apocalypse-owned entries (`0A0252`, `0A0253` in `WB_Dreamscape_Cell`; `0ABFDE` in `WB_Entomb_Cell`), which carry no foreign references. 6,633 lines → 34 |
| 2 | **Apocalypse's BSA overrides two scripts Enderal deliberately gutted.** Its archive holds 206 compiled scripts and 2 collide with Enderal's 5,029: `dgintimidateplayerscript` (2,425 bytes, the full vanilla brawl script, compiled by *Maximilian* of Brawl Bugs Patch) and `dgintimidatealiasscript` (1,983 bytes). Enderal's source for both is **4 lines: `; DUMMY, DO NOTHING`**, and its compiled copies are in `E - Misc.bsa` (confirmed by reading that archive's name table). Apocalypse loads after Enderal, so **its BSA wins**. The restored scripts reach for `dgintimidatequestscript`, `DGIntimidateFaction`, `CR04Running` — none of which Enderal has | Ship SureAI's stubs **loose** under `Scripts/`. Loose beats BSA. See [`../../src/Apocalypse/Scripts/README.md`](../../src/Apocalypse/Scripts/README.md) |
| 3 | **All 144 scrolls carried a dangling `MenuDisplayObject: 076E8F:Skyrim.esm`.** All 34 of Enderal's own scrolls carry **none** | `12-strip-scroll-menudisplay.ps1` removes the field, matching Enderal's archetype rather than inventing a substitute static |
| 4 | **Apocalypse's runtime list-population ran and failed 685 times, 60 s into a new game.** Decompiling `WB_PopulateLists_Script` shows `OnUpdate` counts down from the **origin** list's size and indexes the **destination** list in parallel, then calls `CurrentDestinationLitem.AddForm(...)`. The origin lists are Apocalypse's own and full; the destination lists are 54 vanilla book lists, 24 staff and 5 scroll — **83 leveled lists, none of which exists in Enderal**. So every `AddForm` landed on `None`. **[verified in-game — see below]** | `11-neutralise-populate-lists.ps1` empties **twelve** FormLists so every loop iterates zero times |
| 5 | **The two archer summons had no arrows.** `WB_Con_Dremora_Actor_ConjureHerne` carried `0139C0:Skyrim.esm` ×100 (`DaedricArrow`) and `WB_Con_Dremora_Actor_ConjureDremoraAssassin` carried `037C14:Skyrim.esm` ×250 (`BaseArrowDaedric75`, a leveled list of the same arrow). **Neither FormID exists in Enderal** — both are in `reference/base/SkyrimReal`, neither is in `Skyrim`, `Update` or `EnderalFS`. So each summon spawned holding a bow with an empty quiver and just stood there. Reported from a real playthrough against Herne; the Assassin was found by checking the class rather than the report | `15-summon-ammo.ps1` repoints both onto `13E219:Skyrim.esm` `_30E_AeternaArrow` — Enderal's own best arrow, 10 damage against vanilla Daedric's 24. `verify-summon-ammo.ps1` then asserts the *invariant*: every NPC with a bow has resolvable ammo |

#### Finding 4 in detail — two wrong fixes before the right one

Worth writing down, because both wrong answers looked correct and one of them shipped.

**Wrong fix 1: drop `StartGameEnabled` from the quest.** It reads like the whole problem — a
start-game-enabled quest that should not start. The flag came out cleanly, the plugin built, and
reading `DNAM` straight out of the binary confirmed it: flags `0x0110`, `RunOnce` set,
`StartGameEnabled` clear.

**It changed nothing.** **[verified in-game 2026-08-07]** A brand-new game on the rebuilt plugin
still logged:

```
[06:26:32PM] APOCALYPSE DEBUG: Initialising Populate Lists script...
[06:26:32PM] APOCALYPSE DEBUG: Populating leveled lists... Books...
[06:26:32PM] Error: Cannot call AddForm() on a None object, aborting function call
  stack: [WB_PopulateLists_Quest (1E03F65D)].WB_PopulateLists_Script.OnUpdate()
                                                                          ... x685
```

The quest script's `OnInit` — and the `RegisterForSingleUpdate` inside it — runs whether or not the
quest is flagged to start. **A quest flag does not gate a quest script.** The only thing that stops
the work is making the loops have nothing to do.

**Wrong fix 2: empty the six FormLists the quest binds.** Correct as far as it goes, and it drops
the automatic path to zero iterations. But `WB_MCMQuest_Script.RepopulateLists()` — the
**Repopulate** toggle in Apocalypse's MCM — runs the *identical* loop against a **second set of six
lists**, the `_Replenish` ones (`08F880`–`08F885`), bound on `WB_SkyUI_Quest`. Fixing only the first
set leaves a button in the menu that reproduces the entire error storm on demand.

**The fix is all twelve.** Emptying the ORIGIN lists is what makes `GetSize()` return 0; emptying
the DESTINATION lists as well removes 166 dead references and costs nothing, since
`WB_PopulateLists_Quest` and `WB_SkyUI_Quest` are the only records in the plugin that reference any
of them. `StartGameEnabled` stays cleared as belt-and-braces, but it is not the fix.

> **Generalise this.** When a ported mod misbehaves through a script, find **every** entry point
> before choosing where to cut. `grep` the mod's whole script set for the symbol — two of
> Apocalypse's 206 compiled scripts mention `PopulateLists`, and only one of them is the obvious one.

#### Finding 1 in detail — how much did that NAVI actually matter?

Deleting it was right regardless, but "3,498 dangling references" says nothing about impact. Resolving
the removed content against Enderal's **6,854 real navmesh records** gives the honest answer:

| Removed | Distinct `:Skyrim.esm` FormIDs | …that are a real Enderal navmesh |
|---|---:|---:|
| 10 vanilla `MapInfos` entries | 71 | **0** |
| `PreferredPathing` | 650 | **1** (`075393`) |

**720 of 721 named nothing that exists**, so the engine had nothing to apply them to. On top of that,
every one of the 10 `MapInfos` entries parents to worldspace `00003C` — Tamriel in Skyrim,
**`MQP01Home`** in Enderal — so even the entries that were structurally valid pointed at the prologue
house rather than anywhere a player spends time.

The one real collision, `075393`, is the navmesh of an unnamed exterior cell in **Vyn** at grid
`(-8, -3)`.

So the record was very nearly inert, and the in-game check for this fix is a **regression** check,
not a fix confirmation — the expected result is "no difference anywhere". An earlier draft of the
test matrix said to walk around Ark and Riverville watching NPCs; that was a guess, and it was wrong.
Neither city's navmeshes are named anywhere in the record. The places worth visiting are Apocalypse's
own two interior cells (whose entries we **kept** — the only regression surface), `cow Vyn -8 -3`, and
`cow MQP01Home 0 0`.

#### Finding 5 in detail — the class of bug that reads as an AI bug

This one arrived as a player report ("the conjured NPC has no arrow ammunition so he doesn't use his
bow"), and it is worth recording because of how it presents rather than how it was fixed.

An archer NPC whose quiver FormID does not resolve is **not** visibly a data bug. The summon appears,
is correctly equipped, is correctly levelled, has 65 Archery — and then stands there. Every instinct
says combat style, package, or a missing perk. The actual cause is one line of inventory pointing at
a record Bethesda had and Enderal does not.

It was in the audit CSV the whole time:

```
"MISSING","Npcs","WB_Con_Dremora_Actor_ConjureHerne …","Item","0139C0:Skyrim.esm","",""
"MISSING","Npcs","WB_Con_Dremora_Actor_ConjureDremoraAssassin …","Item","037C14:Skyrim.esm","",""
```

Two of 269 lines, indistinguishable from the 267 that genuinely cost nothing. **A missing-reference
audit tells you what is dead; it cannot tell you what dying costs.** That is the whole argument for
writing an invariant check per subsystem rather than watching one aggregate number:
`verify-summon-ammo.ps1` does not care how many references are missing, only that no NPC ends up
holding a bow it cannot fire.

**Why a substitution and not a new record.** Enai already solved this once inside the same plugin —
`WB_Con_Spirit_Actor_ConjureBearTotem` carries his own `WB_ConjureBearTotem_Ammo`, and that record
happens to resolve cleanly in Enderal (its projectile `0EAFE0`, keyword `0917E7` and NordHero mesh
all survive). Minting a second one would have meant a mesh, a projectile, a keyword, a FormID and a
damage number to keep in step with Enderal forever, and it would have resolved to an Elven arrow's
projectile and mesh anyway. Enai handed Herne an ordinary playable arrow out of the host game; so do
we.

**Why `_30E_AeternaArrow` specifically.** Enderal's arrow ladder tops out at **10 damage**
(`_30E_AeternaArrow` `13E219`) where vanilla's Daedric Arrow is 24, so "best arrow" maps to "best
arrow" and the numbers land where SureAI put them. Herne's Bow is 25 damage against Enderal's best
bow at 23, so 25 + 10 puts a master-tier summon a shade above the best archer a player can build
(23 + 10). Carrying vanilla's 24 across, or minting a 30 like the Bear Totem's, would have put it
half again over that.

Counts are left as authored. The Assassin's 250 was 250 draws at `ChanceNone: 0.25` (~187 arrows) and
is now a flat 250; for a summon on a despawn timer that is not a real distinction.

**Triumvirate was checked for the same defect and has none** — it ships no bow at all.

#### The `WB_MGRitual*Books` leveled lists — the errors are real and cost nothing

Asked by the same reporter, and the answer is worth keeping because the reasoning generalises.

Each of the five lists shows two classes of xEdit error, and both are genuinely dead:

| Field | Value | In Enderal |
|---|---|---|
| `Global:` on all five | `0FDE72`–`0FDE76` (`MGRitualDestBook`, `…Alt…`, `…Conj…`, `…Ill…`, `…Rest…`) | **absent** |
| one entry each | `0D2B4E` Dragonhide, `0A26FA` Flame Thrall, `0A270C` Fire Storm, `0A271C` Hysteria | **absent** |
| Restoration has **two** | `0DD647` Bane of the Undead **and** `0FDE7B` Guardian Circle | **absent** |

But nothing reads them. The five lists are referenced by exactly one record — the
`WB_MGRitualBooks` script property on `WB_NewManager_Quest` `08095C` — and that quest is Apocalypse's
hook into the **College of Winterhold ritual spell quests**. Its other properties are `MGRitual04`
`0CD987`, `MGRitual05` `0D0755` and five vanilla vendor chests, none of which exist here either. The
quest binds its dead forms once at load, logs the `WB_VendorChest` line already documented in
[`spell-test-matrix.md`](spell-test-matrix.md#log-lines-that-are-expected-not-bugs), and then has no
stage to advance and no chest to stock.

So the lists are unreachable, the Global that would gate them is unreachable, and the vanilla tome
inside each is unreachable. **They were left alone deliberately.** Cleaning them would silence ten of
xEdit's red lines while leaving the quest that owns them just as full of dead bindings — a tidier
diff, an unchanged game, and one more record to be right about (CLAUDE.md, "Gotchas": an override
that achieves nothing is still a record you have to be right about).

Note what separates this from finding 5, since both are "a vanilla FormID Enderal does not have".
Herne's dead arrow sat on a **reachable** record — a spell the player can buy, cast and watch fail.
These sit on an unreachable one. The audit scores them identically; only tracing what reaches the
record tells them apart.

### Left alone, on purpose

Recorded here so the next session does not re-derive them. All are in
[`spell-test-matrix.md`](spell-test-matrix.md) as risk flags.

| Finding | Why it stays |
|---|---|
| **15 Daedric/Dwemer summon tomes and 14 matching scrolls are in no chest and no leveled list** (160 of 175 tomes placed, 130 of 144 scrolls) | Deliberate — the `enderal-magic-porter` rule that Daedra and Dwemer have no place in Enderal's setting. The records still ship because removing them would break every FormList and script that indexes them. **But `WB_C075_SixDemonBag`'s scroll ships while its tome does not**, so that one summon is reachable once, from a scroll. That inconsistency is real and unresolved |
| **25 magic effects apply vanilla perks Enderal lacks** — `Disintegrate 0F3F0E`, `Deep Freeze 0F3933`, `Intense Flames 0F392E`, `0153D2`, Illusion `059B76` | These are riders on effects that otherwise work. Repointing them at Enderal perks is a design change, not a port fix, and needs its own analysis |
| **16 effect items gate on `Respite 0581F9`** — present in Enderal, but on no perk tree and not on the `Player` record, so permanently inert | Same. Note it is **invisible to a missing-reference scan** because the record exists; it has to be looked for by hand. The base magnitudes are the real numbers |
| **`WB_AlterationAlt_FormList_LocatePotion_Inclusion` is 7 entries, 7 missing** → *Locate Object*'s potion mode can never match | A fix means choosing Enderal equivalents and proving them in-game. Flagged for testing rather than guessed at |
| **`LocateContainer_Exclusion` is 68-for-68 missing** | It is an *exclusion* list, so the failure mode is over-matching, not silence. Lower stakes, same reasoning |
| **39 dangling script `Object:` properties** — mostly `SayOnHitByMagicEffectScript.TopicToSay` (an NPC voice line) and `MG01FireEffectScript.MG01` on 14 fire effects (the College-of-Winterhold brazier quest) | Cosmetic or log noise. Removing a property from a vanilla helper script's binding is a bigger change than the defect |
| **`Kyrgar`, `Dreamscape` and the College ritual quests** — a merchant NPC, a container and five globals from vanilla content Enderal does not have. The `WB_MGRitual*Books` leveled lists live here too; [see above](#the-wb_mgritualbooks-leveled-lists--the-errors-are-real-and-cost-nothing) for why their errors are harmless | Apocalypse's own optional side content, already unreachable. A dangling reference on an unreachable record is proven harmless here (CLAUDE.md, "Gotchas") |

### Not broken, and worth knowing

`LocateOreVein_Inclusion` resolves to **561 live Activators**, including Enderal's own
`_00E_MineOreShadowsteel`. `LocatePlant_TreeInclusion` resolves to live records like
`TreeFloraVatyrsTongue01` — Enderal's rename of a vanilla flora.

**Enderal kept and renamed a great many vanilla records.** That is why a bare count of dangling
references is the wrong instrument, and why the audit resolves survivors to their EditorID: the
question is never "how many are dead" but "which behaviours died".

## Running it

```powershell
# absolute audit -> summary + build/dist/apocalypse-refs.csv
src\Apocalypse\tools\verify-missing-refs.ps1

# hold the line in CI
src\Apocalypse\tools\verify-missing-refs.ps1 -Baseline 267
```

`-Baseline` fails when the count *rises*. A non-zero baseline is correct and permanent here: Enai
wrote against Bethesda's `Skyrim.esm` and most of what is left is unreachable content that costs
nothing to leave in place.
