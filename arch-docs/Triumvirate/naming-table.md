# Triumvirate — lore and naming table

The agreed mapping from Triumvirate's Elder Scrolls proper nouns to Enderal's own vocabulary, so
every archetype ticket uses the same names. Produced for **WD-10**.

**Applied.** The renames landed with the archetype ports (WD-11–WD-15, generators `09`–`13` in
`src/Triumvirate/tools/`), and `16-verify-naming.ps1` closes the ticket: it scans every
player-facing string in the finished tree against the full Elder Scrolls lexicon and **asserts
zero**, which it does. Re-run it after any later string edit — WD-18's build should treat it as
a gate.

---

## Part 1 — Enderal's vocabulary, verified

Everything here was read out of `reference/base/`, not recalled. Counts are files containing the term
across Enderal's books, spells and magic effects.

### The pantheon: seven Light-Born

Enumerated verbatim from Enderal's own scripture (`There is X, the …`):

| Light-Born | Domain | Notes |
|---|---|---|
| **Tyr** | father of the gods, the highest | Allotted no land; rules **Inodan**, the land of the gods at the edge of the world |
| **Malphas** | guardian of the gods | Enderal's patron and by far the most-cited (127 files); the Order's god |
| **Irlanda** | judgment | Allotted Arazeal; worshipped by the Arazealeans |
| **Erodan** | wisdom and old rites | Allotted Nehrim; **renowned for prowess in Light Magic** |
| **Esara** | memories | Tends the halls of knowledge on Inodan |
| **Saldrin** | knowledge and progress | |
| **Morala** | language and commerce | |

> **The decisive fact for this conversion: there is no nature, beast, hunt or death god among them.**
> The Light-Born are a civic, order-facing pantheon. Anything in Triumvirate that invokes a god *of
> the wild* has no one to be reassigned to, which is why the Druid's Hircine question below is a real
> decision rather than a lookup.

Mortal figures who recur: **Selna** the *Truchessa* (first high priestess of the Order) and
**Ketaron**, the two to whom Malphas first appeared; **Melros**; **Asĥtoron**, the mad god who
reigned before the Light-Born.

### Cosmology and powers

| Term | What it is |
|---|---|
| **Sea of Eventualities** | Enderal's metaphysics of magic. *"Every state of reality that is not ours is termed an 'eventuality', and the sum of these the Sea of Eventualities."* A mage pulls an eventuality into our reality — an elementalist "looks into the Sea for a reality in which the tree has burst into flame" |
| **The High Ones** | Cosmic entities *"responsible for the Cleansing and the Cycle"*, who reach mortals through dreams and the **Red Madness**. They manifest as **beast avatars** — the game ships `Bear (The High Ones)`, `Wolf (The High Ones)`, `Spider (The High Ones)` and `SabreCatHoheRace`. **They are Enderal's antagonists.** |
| **The Black Guardian** | A dark power used as an oath — *"By the Black Guardian!"*, *"What by the Black Guardian's name are you? A demon?"* |
| **Rhalâta** | A murder-cult; its cultists are a whole bandit sub-family |
| **Lost Ones** | Enderal's undead (42 files); the `UndeadFaction` ladder, on `DraugrRace` shells |
| **Vyn** | The world. **Not Nirn.** Enderal's overworld worldspace is `Vyn 001D3C` |
| **Inodan** | The divine land at the rim of the world |
| **Oorbâya** | A summoned otherworldly entity — Enderal's nearest thing to a conjured daedra. Family also holds `Rynéus` and `Avatar of the Black Stone` |
| **Pyreans** | The ancient precursor civilisation, ruled by a chosen child called the **Highest Being** |

### The five magic schools

From CLAUDE.md, and the reason to get this right is that the intuitive pairing is wrong:

| Vanilla | Enderal | Higher school |
|---|---|---|
| Destruction | **Elementalism** | (an art of its own) |
| Conjuration | **Entropy** | Sinistra |
| Restoration | **Light Magic** | Thaumaturgy |
| Alteration | **Mentalism** | Thaumaturgy |
| Illusion | **Psionics** | Sinistra |

A practitioner of Entropy is an **entropist**. **Sinistra** is the dark higher school — Apocalypse
already renamed *Oblivion Unbound* to *Sinistra Unbound* on that basis.

### Playable races — for the Shaman's Spirit Guardian

Enderal's races sit on vanilla slots with renamed display names:

| Vanilla slot | Enderal |
|---|---|
| Imperial | **Endralean** |
| Nord | **Half Arazealean** (pure `_00E_` = Arazealean) |
| Redguard | **Qyranian** |
| Breton | **Kiléan** |
| HighElf | **Half Aeterna** |
| DarkElf | **Aeterna** |
| WoodElf | **Starling** |
| — | **Leoran** (`_00E_LeorRace`) |

**`ArgonianRace`, `KhajiitRace` and `OrcRace` are vestigial leftovers no Enderal NPC uses.**
Triumvirate ships 25 `TVR_Ancestors_Actor_SpiritGuardian_*` actors, one per race and sex, including
Argonian, Khajiit and Orc — three of those have no Enderal people to be the spirit of.

### Creatures Enderal actually has — for the Druid and Warlock summons

| Triumvirate wants | Enderal has | Family |
|---|---|---|
| Raven | ambient birds (`Creature_BirdWildFaction`, 17 actors, level 1) | thin — see WD-11 |
| Rattlesnakes | **Gareasnake** | `Creature_FishPredatorFaction` |
| Gray Wolf | **Wolf, Snow Wolf, Starving Wolf** | `Creature_WolfFaction` |
| Snow Leopard | **Leopard, Panther** | `Creature_LeopardFaction` |
| Hound of Hircine | **Glacier Hound** (level 55) | `Creature_GlacierHoundFaction` |
| Deer | **Deer** (ambient) | livestock |
| Spirit Guardian | **Ancestral Spirit**, Yogosh, Ash Widow | `Creature_AncestralSpiritFaction` |
| Demons | **Oorbâya**, Rynéus | `Creature_OorbayaFaction` |
| any summon | 60 actors already in `Creature__SummonableFaction 046E6B` | the archetype WD-9 identified |

---

## Part 2 — The mapping

### Settled: inherited from the Apocalypse conversion

These are already shipped in this repo, in a spell pack the same player will have installed. **Use
them verbatim** — two Enai spell packs disagreeing about who the god of mercy is would be worse than
either choice alone. Every target is attested Enderal vocabulary, not invented.

| Elder Scrolls | Enderal | Attested in |
|---|---|---|
| Stendarr | **Erodan** | 11 files |
| Mara | **Irlanda** | 14 |
| Arkay | **Tyr** | 11 |
| Meridia | **Malphas** | 127 |
| Medora | **Esara** | 4 |
| Ocato | **Baledor** | 18 |
| Nirn | **Vyn** | — |
| Oblivion (as a place) | **Sinistra** / **the Sea of Eventualities** | 6 / 9 |

### Settled: mechanical

| Triumvirate | Becomes | Why |
|---|---|---|
| Skyrim hold and city names in flavour text | Enderal locations | `arch-docs/enderal/world-and-dungeons.md` has the 22 real regions. Note **cell EditorIDs are German** — Riverville is `Flusshaim*`, Ark is `CapitalCity*` |
| "the School of Conjuration" etc. | Entropy / Elementalism / Light Magic / Mentalism / Psionics | Per the table above. **Alteration is Mentalism and Illusion is Psionics** — the intuitive pairing is wrong and mis-files every spell |
| Draugr, undead references | **Lost Ones** | |
| Argonian / Khajiit / Orc Spirit Guardians | drop, or re-cut to Enderal's eight peoples | Those races exist as unused shells; a spirit of a people Enderal does not have is not a spirit of anything |
| **Fylgja**, **Goodberry** | **keep** | Norse and D&D loans, not Elder Scrolls. Neither collides with Enderal vocabulary and both read as generic. WD-10 asked for this to be decided explicitly — decided: keep |
| **Horned Lord** | **keep** | Generic; no Elder Scrolls referent |

### The four contested calls — settled and applied

All four went with the recommendation (confirmed by starting the ports on that basis):

| Decision | Applied as |
|---|---|
| 1. Hircine (Druid's patron) | **B — no patron.** *Call Hound of Hircine* → **Call the Glacier Hound** (a real Enderal creature); *Mark of Hircine* → **Mark of the Wild** |
| 2. Daedra / Oblivion (Warlock) | **A.** Oblivion-as-a-place → Sinistra: *Hurl Into Oblivion* → **Hurl Into Sinistra**, descriptions follow. The demons keep Enai's own invented names, and the internal "Daedric*" labels became "Demon*" |
| 3. Azra's Wrath | **B — attribution dropped.** → **Shadow's Wrath** |
| 4. All-Maker / Earth Bones / Old Ways (Shaman) | **A — the ancestors.** *Eye of the All-Maker* → **Eye of the Ancestors**; *Staff of Earth Bones* → **Staff of Fissures** (named for its spell, per both Enai's and Enderal's staff conventions) |

Also applied: the Cleric's Aid buff names now read Enderal's skill display names (Mentalism,
Entropy, Elementalism, Psionics, Light Magic, Handicraft, Rhetoric, Sleight of Hand…).

---

## Part 3 — How it was applied

Both constraints from the Apocalypse precedent held: every rename **edits in place** (the tree
already carried the WD-9/WD-17 fixes) and every generator is **idempotent** — a re-run replaces
nothing and still asserts the target strings exist, so a typo'd pattern throws rather than
silently matching nothing.

Fields renamed: spell/effect/actor/race/armor `Name`, tome titles, `Description`, `Message`
text. EditorIDs and asset paths are identifiers, not prose, and were left alone. Gameplay text
(damage numbers, durations) untouched — this was a naming pass, not a balance pass.

The final check lives in `src/Triumvirate/tools/16-verify-naming.ps1`: zero Elder Scrolls
proper nouns across every player-facing string line, over a lexicon deliberately wider than
what the mod ever contained (gods, princes, races, holds, factions), so a future edit that
reintroduces one fails loudly.
