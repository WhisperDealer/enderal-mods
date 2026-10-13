# Triumvirate — school review (deferred)

> **Status: NOT STARTED — a note for a future pass.** Written 2026-10-13 from the Zenderal
> modlist work in `zenderal-patches`. Nothing here has been applied to this port yet.

## The question

The port maps every spell mechanically: Destruction → Elementalism, Restoration → Light Magic,
Alteration → Mentalism, Conjuration → Entropy, Illusion → Psionics. That is the right default
(the school *is* the MGEF skill AV, and Enderal only renamed the five). But for some archetype
sets the mapping fights both Enderal's lore and Enderal's perks. The **rule** that came out of
reviewing six archetypes:

> **Re-school a set only when its effects lack the keywords its current tree's perks test, *and*
> the lore points to another discipline.** If the perks bite, leave it.

Lore source: Enderal's own *The Disciplines of Magic* (5 vols) and *Encyclopedia Arcana – Magic*
(4 vols), summarised in `zenderal-patches/arch-docs/enderal/magic-schools.md`. Perk evidence: EGO's
winning `_00E_Class_Elementalist_*` / `_Sinistrope_*` / `_Thaumaturge_*` perks. Every Elementalist
damage/duration perk keys `MagicDamageFire/Frost/Shock` or `MagicRune`. The cost discounts key the
spell's `HalfCostPerk` via `SpellHasCastingPerk` (Sinistrope tests `Conjuration*` + `Illusion*`,
Thaumaturge tests `Alteration*` + `Restoration*`).

## Verdicts so far

| Archetype set | Ported as | Verdict | Why |
|---|---|---|---|
| **Warlock — Destruction** | Elementalism | **→ Entropy** | raw/magic/poison damage + Bind Spirit, no element keywords; Entropy necromancy |
| Warlock — Conjuration / Illusion | Entropy / Psionics | keep | summons are Entropy anomalies; curses kept in Psionics (ladder + two-skill balance; Life Tap is the weak fit) |
| **Shadow Mage — Destruction** | Elementalism | **→ Entropy** | health/magicka drains + raw magic damage, no element keywords; EGO's Sinistrope perks call Entropy "*Schattenzauber*" |
| Shadow Mage — Alteration / Illusion | Mentalism / Psionics | keep | dashes, pulls, portals = Mentalism impulse; Possession, Darkness = Psionics |
| Druid — all three | Entropy / Mentalism / Light Magic | keep | **Force of Nature must stay Mentalism**: `TVR_Verdant_Perk_ForceOfNature` scales on the `Alteration` AV |
| Cleric — all three | Light Magic / Elementalism / Psionics | keep | Cleric Destruction **carries** `MagicDamageFire/Shock`, so Elementalist perks apply |
| **Shaman — Restoration** | Light Magic | **→ Entropy (proposed, not built anywhere)** | curses + drains, heals nothing; Skaragg bone readers are Enderal's Entropy shamans |
| Shaman — Conjuration / Alteration | Entropy / Mentalism | keep | totems/fylgjar carry `MagicSummonFamiliar`; Fissure is the only arguable one (earth) |
| Fifth archetype (not reviewed) | — | — | — |

## What Zenderal already ships (retire if this port adopts it)

The Zenderal list currently does the Warlock and Shadow Mage moves **as overrides** in
`zenderal-patches/src/MagicPatches/` (`tools/09-reschool-warlock-destruction.ps1`,
`tools/10-reschool-shadow-destruction.ps1`; doc `arch-docs/patches/MagicPatches.md`). If the moves
are made here at the source, delete those two generators and their MGEF/BOOK/WEAP overrides from
Magic Patches. Keep only its `HalfCostPerk` edits until its Spells folder is regenerated from the new
plugin. The Warlock move was tested in game on 2026-10-13.

Per moved set, the full record surface (the overrides above are the worked template):

- **SPEL:** `HalfCostPerk` Destruction&lt;tier&gt; → Conjuration&lt;tier&gt; (`0F2CA7` / `0C44BB` / `0C44BC` / `0C44BD` / `0C44BE`).
- **MGEF:** `MagicSkill` → `Conjuration`. Follow **hidden procs**: cloak spells, hazard spells, and
  script-cast `Spell` properties. The Shadow set had 15 MGEFs across 5 spells + 3 procs.
- **BOOK:** `SpellTomeConjurationLowPoly.nif` + inventory art `02FBB6`.
- **WEAP:** staff `Data.Skill`.
- **Check:** scrolls (none so far); whether distribution is per-school (so far all three schools of
  an archetype share the same merchants); scripts for skill reads.

## Found along the way — fix here regardless

- **Visions of Healing** (`TVR_Shaman_R050_Spell_RunesHealing`, Adept) carries the *Novice*
  half-cost perk `RestorationNovice00 0F2CAA`. Enai's record has it, not this port, so it gets the
  Novice/Apprentice discount instead of the Adept one. Should be `RestorationAdept50 0C44C8` (not `0C44C9`, which is Expert75), or
  `ConjurationAdept50 0C44BC` if the Shaman move happens.
