# Triumvirate for Enderal -- spell test matrix

> **Generated** by `src/Triumvirate/tools/14-gen-test-matrix.ps1` from the Spriggit YAML. Do not
> hand-edit -- re-run it. Tick the boxes in a working copy or a PR comment.

Covers the **75 tome-taught spells** (15 per archetype), enumerated from the Book records'
`Teaches` links so the list cannot drift from the plugin. Produced for **WD-11..WD-15**;
distribution rows are WD-16's and packaging is WD-18's.

## Before you start

1. **Find the plugin's load-order index**: `help "Spell Tome: Aid" 0` -- the leading two hex
   digits. **If this returns nothing, stop**: the plugin is not loading (on Enderal that almost
   always means `HEDR` 1.71; this tree builds 1.70, so suspect the deploy).
2. **Test character**: `tgm`, `player.setav magicka 100000`, `player.setlevel 50`.
3. **Papyrus log on** (see CLAUDE.md -- the PROFILE ini, and the log lands in the Skyrim SE
   Documents folder). Any `Cannot call ... on a None object` line naming a `TVR_` script during
   these tests is a regression -- the known-remaining None noise belongs to the populate quest
   (WD-16) only.
4. Teach a spell with `player.additem <XX offset of the tome> 1` then read it, or
   `player.addspell`.

## Druid (WD-11)

| OK | School | Rank | Spell | Verify |
|----|--------|------|-------|--------|
| [ ] | Mentalism | Novice | Druidcraft | corpse disintegrates AND an Enderal plant grows (list was repopulated - a None error here means the FormList regressed) |
| [ ] | Mentalism | Apprentice | Force of Nature | Horned Lord form: no Magicka regen, power attacks steal Magicka, help message says "Mark of the Wild" |
| [ ] | Mentalism | Adept | Wildshape | NAMED RISK: uses Game.SetBeastForm - check HUD/controls/equipment survive entering AND leaving deer form |
| [ ] | Mentalism | Expert | Impenetrable Grove | tree wall spawns on Enderal terrain and blocks pathing |
| [ ] | Mentalism | Master | Chase the Horizon | group teleport lands all actors on navmesh |
| [ ] | Entropy | Novice | Call Raven | NAMED RISK: raven rig/animation in flight; -40 weapon skill debuff on its target |
| [ ] | Entropy | Apprentice | Call Rattlesnakes | two snakes; poison dps ticks |
| [ ] | Entropy | Adept | Call Gray Wolf | bleed-out on targets under 20% Health; single summon only (Twin Souls is dead in Enderal - doubling absent is CORRECT) |
| [ ] | Entropy | Expert | Call Snow Leopard | stamina drain; speed boost in combat |
| [ ] | Entropy | Master | Call the Glacier Hound | name reads "Call the Glacier Hound"; armor shred procs; concentration drain cannot be enchanted away |
| [ ] | Light Magic | Novice | Spirit of the Oak | casts; visible effect; magnitude/duration as described |
| [ ] | Light Magic | Apprentice | Parasitic Growth | a Goodberry lands in the victim inventory on death and heals when eaten |
| [ ] | Light Magic | Adept | Spirit of Thornbriar | casts; visible effect; magnitude/duration as described |
| [ ] | Light Magic | Expert | Bramble Growth | casts; visible effect; magnitude/duration as described |
| [ ] | Light Magic | Master | Spirit of the Sun | heals ALLIES including summons (SummonableFaction substitution) |

## Shadow Mage (WD-12)

| OK | School | Rank | Spell | Verify |
|----|--------|------|-------|--------|
| [ ] | Mentalism | Novice | Shadow Stride | casts; visible effect; magnitude/duration as described |
| [ ] | Mentalism | Apprentice | Step Through Shadows | NAMED RISK: teleport - test in an Enderal interior, a city (Ark) and open terrain |
| [ ] | Mentalism | Adept | Shadow Dance | NAMED RISK: jump-dash needs a clear path check on Enderal navmesh |
| [ ] | Mentalism | Expert | Pull Through Shadows | NAMED RISK: pulls target through Enderal geometry without stranding it |
| [ ] | Mentalism | Master | Night Gate | NAMED RISK: both portals placeable on walkable Enderal terrain; round trip works |
| [ ] | Elementalism | Novice | Draining Touch | casts; visible effect; magnitude/duration as described |
| [ ] | Elementalism | Apprentice | Shadow's Wrath | name reads "Shadow's Wrath"; damage scales off current Magicka |
| [ ] | Elementalism | Adept | Nightblade | dash-attack from range; Magicka converts to bonus damage |
| [ ] | Elementalism | Expert | Draining Shroud | casts; visible effect; magnitude/duration as described |
| [ ] | Elementalism | Master | Draining Mist | casts; visible effect; magnitude/duration as described |
| [ ] | Psionics | Novice | Gather Shadows | NAMED RISK: darkness detection against Enderal's own lighting - test day/night/interior |
| [ ] | Psionics | Apprentice | Darkness | NAMED RISK: shadow-emitting light pools render under Enderal lighting |
| [ ] | Psionics | Adept | Reveal Secrets | containers/doors/keys highlighted; plant marking uses the pruned Mark lists |
| [ ] | Psionics | Expert | Possession | level-capped; works on Lost Ones? EXPECTED NO for Dwarven-keyword constructs (MasterOfTheMind is dead - vanilla no-perk behaviour) |
| [ ] | Psionics | Master | Nightfall | NAMED RISK: pool follows caster; grants known Shadow buffs; darkness scaling as above |

## Warlock (WD-13)

| OK | School | Rank | Spell | Verify |
|----|--------|------|-------|--------|
| [ ] | Entropy | Novice | Conjure Gremlin | with Spirit: disarm chance; base strength only (Elemental Potency is dead - Potent variants absent is CORRECT) |
| [ ] | Entropy | Apprentice | Conjure Temple Grim | casts; visible effect; magnitude/duration as described |
| [ ] | Entropy | Adept | Conjure Ravagor | casts; visible effect; magnitude/duration as described |
| [ ] | Entropy | Expert | Conjure Magister | Magister uses its staff (template repointed to Enderal's); escalating burst builds |
| [ ] | Entropy | Master | Conjure Leviathan | 180s duration; with Spirit: immobilize + bleed on attack |
| [ ] | Elementalism | Novice | Eldritch Blast | SPIRIT LOOP: kill -> "Spirit bound" -> summon within 30s -> upgraded minion. This is the archetype - test end to end |
| [ ] | Elementalism | Apprentice | Balefire | poisoned target takes 30% more from your minions |
| [ ] | Elementalism | Adept | Witch Bolt | casts; visible effect; magnitude/duration as described |
| [ ] | Elementalism | Expert | Cloudkill | casts; visible effect; magnitude/duration as described |
| [ ] | Elementalism | Master | Hurl Into Sinistra | name reads "Hurl Into Sinistra"; NAMED RISK: survivors vanish to the holding cell (TVR_Cell) and RETURN on recast - never test on a quest NPC |
| [ ] | Psionics | Novice | Weaken | casts; visible effect; magnitude/duration as described |
| [ ] | Psionics | Apprentice | Frailty | casts; visible effect; magnitude/duration as described |
| [ ] | Psionics | Adept | Iron Maiden | casts; visible effect; magnitude/duration as described |
| [ ] | Psionics | Expert | Life Tap | casts; visible effect; magnitude/duration as described |
| [ ] | Psionics | Master | Decrepify | casts; visible effect; magnitude/duration as described |

## Cleric (WD-14)

| OK | School | Rank | Spell | Verify |
|----|--------|------|-------|--------|
| [ ] | Elementalism | Novice | Solar Ray | fire beam; vs a Lost One the _VsUndead doubling fires (IsUndead condition) |
| [ ] | Elementalism | Apprentice | Holy Fire | casts; visible effect; magnitude/duration as described |
| [ ] | Elementalism | Adept | Consecrated Ground | ground patch persists 30s; doubled vs Lost Ones |
| [ ] | Elementalism | Expert | Holy Shock | casts; visible effect; magnitude/duration as described |
| [ ] | Elementalism | Master | Storm of Vengeance | casts; visible effect; magnitude/duration as described |
| [ ] | Psionics | Novice | Suggestion | casts; visible effect; magnitude/duration as described |
| [ ] | Psionics | Apprentice | Exile | casts; visible effect; magnitude/duration as described |
| [ ] | Psionics | Adept | Spirit Guardian | guardian spawns for EVERY Enderal race (script falls back to index 0); carries gear; returns it on death; joins SummonableFaction |
| [ ] | Psionics | Expert | Obedience | converted enemy fights for you AND barters out of combat; gets Enderal hunting bow if unarmed |
| [ ] | Psionics | Master | Exodus | NAMED RISK: hides all nearby actors except follower - never test near quest NPCs |
| [ ] | Light Magic | Novice | Aid | buff names read Enderal skills (Mentalism, Entropy, Light Magic, Handicraft, Rhetoric, Sleight of Hand...) |
| [ ] | Light Magic | Apprentice | Aura of Might | RELEASE HOOK: stop concentrating -> burst fires. Guards excluded from the proc (repointed IsGuardFaction) |
| [ ] | Light Magic | Adept | Aura of Vigor | RELEASE HOOK: 2s invulnerability on release |
| [ ] | Light Magic | Expert | Aura of Thorns | RELEASE HOOK: 100 heal on release; melee reflect while held |
| [ ] | Light Magic | Master | Mass Immortality | casts; visible effect; magnitude/duration as described |

## Shaman (WD-15)

| OK | School | Rank | Spell | Verify |
|----|--------|------|-------|--------|
| [ ] | Mentalism | Novice | Eye of the Ancestors | name reads "Eye of the Ancestors"; survey marks work; travel-marker beams DO NOT fire (orphaned Stone quest - expected) |
| [ ] | Mentalism | Apprentice | Stave of Ferocity | casts; visible effect; magnitude/duration as described |
| [ ] | Mentalism | Adept | Fissure | rock wall + knockdown on Enderal navmesh; staff reads "Staff of Fissures" |
| [ ] | Mentalism | Expert | Stave of Binding | casts; visible effect; magnitude/duration as described |
| [ ] | Mentalism | Master | Sacred Hearth | NAMED RISK: consecrate -> recall in spirit form -> return; marker must survive save/reload |
| [ ] | Entropy | Novice | Create Water Totem | totem places on Enderal navmesh; heals + cures in combat only |
| [ ] | Entropy | Apprentice | Create Tree Totem | casts; visible effect; magnitude/duration as described |
| [ ] | Entropy | Adept | Summon Wind Fylgja | NAMED RISK: body-swap possession - test save, load, fast travel and combat interruption while possessed; sheathe cancels |
| [ ] | Entropy | Expert | Create Earth Totem | tremor every 7s in combat |
| [ ] | Entropy | Master | Summon Sun Fylgja | NAMED RISK: as Wind Fylgja; its Grand Healing no longer carries the dead WI-say script - no Papyrus error on cast |
| [ ] | Light Magic | Novice | Visions of Opportunity | random foes in radius get cursed over 240s; effects expire cleanly |
| [ ] | Light Magic | Apprentice | Spirit Fire | casts; visible effect; magnitude/duration as described |
| [ ] | Light Magic | Adept | Visions of Healing | casts; visible effect; magnitude/duration as described |
| [ ] | Light Magic | Expert | Spirit Storm | casts; visible effect; magnitude/duration as described |
| [ ] | Light Magic | Master | Shield of Awe | release SOUND now plays (dead civil-war global gate removed); rune debuffs inside |

## Cross-cutting named risks

| OK | Risk | Why it cannot be proven from records |
|----|------|--------------------------------------|
| [ ] | **Wild Shape / `Game.SetBeastForm`** | Engine werewolf flag on a game with no werewolf system -- HUD, controls and equipment behaviour are unknowable until launch (WD-17 finding 4) |
| [ ] | **Raven summon rig** | The one summon with no close Enderal creature family; watch its skeleton/animation in flight |
| [ ] | **All four Shadow teleports indoors** | Navmesh and walkable-terrain checks differ per cell; Enderal's interiors were never the mod's test bed |
| [ ] | **Darkness detection under Enderal lighting** | Gather Shadows / Nightfall scale off ambient light; Enderal replaced all light settings (SureAI readme) |
| [ ] | **Fylgja possession lifecycle** | Save, load, fast travel, combat interruption while the body is left behind |
| [ ] | **Hurl Into Sinistra holding cell** | Survivors sit in TVR_Cell until recast; verify they return, and never cast it at a quest NPC |
| [ ] | **Aura release hooks** | Concentration-end triggers are runtime-only behaviour |
| [ ] | **Warlock Spirit-binding loop end to end** | Kill under Eldritch Blast -> summon within 30s -> upgraded minion (WD-13 done-when) |
| [ ] | **Totem placement on Enderal navmesh** | Placed activators with in-combat conditions |
| [ ] | **Sacred Hearth across sessions** | World marker must survive save/reload and not trap the player |

**Expected deviations (working as intended, do not file):** single summons only (Twin Souls
dead), base-strength Warlock minions (Elemental Potency dead), Possession never affects
Dwarven-keyword constructs (Master of the Mind dead), Farsight's travel-marker beams silent
(orphaned quest), Diviner/Farsight XP trickle absent (`AdvanceSkill` is inert in Enderal).
