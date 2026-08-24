# Triumvirate — lore and naming table

The agreed mapping from Triumvirate's Elder Scrolls proper nouns to Enderal's own vocabulary, so
every archetype ticket uses the same names. Produced for **WD-10**.

**Decide here, apply last.** This document is the deciding half. The mechanical rename runs *after*
the archetype ports (WD-11…WD-15) and the distribution rebuild (WD-16), because those tickets add
and delete player-facing strings, and WD-10's done-when — "no leftover Skyrim proper nouns" — is only
meaningful when asserted over the finished tree.

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

### Needs your decision

Four calls where the evidence does not choose for us. Each shapes what the archetype tickets build,
which is why they are worth settling before WD-11.

#### 1. Hircine — the Druid's patron

Appears in *Call Hound of Hircine*, *Mark of Hircine*, and the Druid's whole framing.

| Option | Reads as | Cost |
|---|---|---|
| **A — The High Ones** | The closest structural match Enderal has: a power that *manifests as beasts*, with Bear/Wolf/Spider/Sabre Cat avatars already in the game | They are the **antagonists** — behind the Cleansing, the Cycle and the Red Madness. A Druid who serves them is a villain, which is a bigger statement than a spell pack should make by accident |
| **B — no patron at all** *(my recommendation)* | The Druid is simply attuned to the wild. *Call Hound of Hircine* → **Call the Glacier Hound**; *Mark of Hircine* → **Mark of the Wild** | Loses a little colour. But Enderal genuinely has no nature god, and inventing one is a bigger liberty than dropping the framing |
| **C — the Pyreans** | Ancient precursors with a spiritual "Highest Being" | Archaeological rather than natural; the association is a stretch |

#### 2. Daedra and Oblivion — the Warlock's identity

Includes *Hurl Into Oblivion*. Apocalypse already settled **Oblivion-as-a-place → Sinistra / the Sea
of Eventualities**, so the open question is only what the Warlock *summons*.

| Option | Reads as |
|---|---|
| **A — Oorbâya and kin** *(my recommendation)* | Enderal's own summoned otherworldly entities. The Warlock binds Oorbâya rather than daedra; *Hurl Into Oblivion* → **Hurl Into Sinistra** |
| **B — the Black Guardian** | Leans on Enderal's existing dark-oath figure. More sinister, less established — it appears as an exclamation, never as a described power |

Note Triumvirate's demons keep their own invented names — Gremlin, Temple Grim, Ravagor, Leviathan,
Oathbreaker — and **none is an Elder Scrolls term**, so they stay whatever this decision is.

#### 3. Azra — *Azra's Wrath*

Azra Nightwielder is Elder Scrolls apocrypha. Enderal has no equivalent famous mage in the material
I read.

| Option | |
|---|---|
| **A — reattribute to an Enderal figure** | **Baledor** is already used this way in Apocalypse (*Ocato's Recital* → *Baledor's Recital*), so *Azra's Wrath* → **Baledor's Wrath** is consistent and free |
| **B — drop the attribution** *(my recommendation)* | *Azra's Wrath* → **Nightwielder's Wrath** or simply **Shadow's Wrath**. Avoids attaching a destructive spell to a figure whose character we have not read |

#### 4. The All-Maker, Earth Bones and the Old Ways — the Shaman

Skaal and Nordic religion, and the densest Elder Scrolls layer in the mod (*Eye of the All-Maker*).

| Option | Reads as |
|---|---|
| **A — the ancestors** *(my recommendation)* | Enderal ships an `AncestralSpiritFaction` and Triumvirate's own line is already called **Ancestors**. *Eye of the All-Maker* → **Eye of the Ancestors**; the Old Ways → **the old rites**, which is Erodan's own domain wording |
| **B — the Pyreans** | The precursor civilisation and its Highest Being. Gives the Shaman an archaeological identity distinct from the Druid's |
| **C — Malphas / the Light-Born** | Makes the Shaman devotional. Probably wrong — Enderal's Order is institutional, not shamanic |

---

## Part 3 — How this gets applied

Not yet. The rename runs after WD-11…WD-16 as **WD-10b**, and two constraints come from the
Apocalypse precedent:

1. **It must edit in place.** `src/Apocalypse/tools/01-gen-renames.ps1` regenerates the working tree
   *from the pristine reference copy* (`reference/mods/Apocalypse/esp` → `src/…`). That is only safe
   because it runs first in its chain. Triumvirate's tree already carries seven in-place steps;
   copying that script's shape would wipe them.
2. **It must be idempotent.** Apocalypse's version `throw`s if a rename matches nothing — correct on
   a single pass, fatal on a re-run. Triumvirate's needs to tolerate already-applied renames and
   still fail loudly on a rename that never matched *anything*, in any run.

Fields in scope: spell and magic-effect `Name`, tome titles, `Description`, `Message` text and
dialogue. **Gameplay text — damage numbers, durations — is out of scope**; this is a naming pass, not
a balance pass.

The final check is the one that makes the ticket true: a grep over every player-facing string in the
finished tree for the Elder Scrolls terms above, asserting zero.
