# 14 - Generate arch-docs/Triumvirate/spell-test-matrix.md from the Spriggit YAML.
#
# Same contract as src/Apocalypse/tools/13-gen-test-matrix.ps1: the doc is GENERATED - do not
# hand-edit it, re-run this. The canonical spell list is the 75 tome-taught spells (every Book
# whose Teaches.Spell resolves to a TVR spell), 15 per archetype, so the matrix cannot drift
# from the records.
#
# Per-spell "verify" notes live in the table below, keyed by the BOOK EditorID. Spells without a
# note get the default check. The named-risk rows at the bottom are the mechanics WD-11..WD-15
# identified as unprovable from records alone.

. (Join-Path $PSScriptRoot '00-common.ps1')

$root = Get-EspRoot
$out  = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) 'arch-docs\Triumvirate\spell-test-matrix.md'

# --- collect: Book -> taught spell ---------------------------------------------------------------
$spellsByKey = @{}
foreach ($f in Get-ChildItem (Join-Path $root 'Spells') -Filter '*.yaml') {
    $t = Read-YamlText $f.FullName
    $fk = [regex]::Match($t, '(?m)^FormKey: (.+?)(?=\r?$)').Groups[1].Value
    $nm = [regex]::Match($t, "(?m)^Name:\r?\n  TargetLanguage: English\r?\n  Value: (.+?)(?=\r?$)")
    $spellsByKey[$fk] = if ($nm.Success) { $nm.Groups[1].Value.Trim().Trim("'").Trim('"') } else { '' }
}
$rows = @()
foreach ($f in Get-ChildItem (Join-Path $root 'Books') -Filter 'TVR_*.yaml') {
    $t = Read-YamlText $f.FullName
    $sp = [regex]::Match($t, '(?m)^  Spell: (.+?)(?=\r?$)')
    if (-not $sp.Success -or -not $spellsByKey.ContainsKey($sp.Groups[1].Value)) { continue }
    $eid = ($f.Name -split ' - ')[0]
    $m = [regex]::Match($eid, '^TVR_(Druid|Shadow|Warlock|Cleric|Shaman)_([ACDIR])(\d{3})_Book_')
    if (-not $m.Success) { continue }
    $rows += [pscustomobject]@{
        Arch   = $m.Groups[1].Value
        School = @{A='Mentalism'; C='Entropy'; D='Elementalism'; I='Psionics'; R='Light Magic'}[$m.Groups[2].Value]
        Rank   = @{'000'='Novice'; '025'='Apprentice'; '050'='Adept'; '075'='Expert'; '100'='Master'}[$m.Groups[3].Value]
        Order  = [int]$m.Groups[3].Value
        SchoolOrder = 'ACDIR'.IndexOf($m.Groups[2].Value)
        Book   = $eid
        Spell  = $spellsByKey[$sp.Groups[1].Value]
    }
}
if ($rows.Count -ne 75) { throw "expected 75 tome-taught spells, found $($rows.Count)" }

# --- per-spell verification notes, keyed by Book EditorID ----------------------------------------
$notes = @{
    # Druid
    'TVR_Druid_A000_Book_Druidcraft'          = 'corpse disintegrates AND an Enderal plant grows (list was repopulated - a None error here means the FormList regressed)'
    'TVR_Druid_A025_Book_ForceOfNature'       = 'Horned Lord form: no Magicka regen, power attacks steal Magicka, help message says "Mark of the Wild"'
    'TVR_Druid_A050_Book_Wildshape'           = 'NAMED RISK: uses Game.SetBeastForm - check HUD/controls/equipment survive entering AND leaving deer form'
    'TVR_Druid_A075_Book_ImpenetrableGrove'   = 'tree wall spawns on Enderal terrain and blocks pathing'
    'TVR_Druid_A100_Book_ChaseTheHorizon'     = 'group teleport lands all actors on navmesh'
    'TVR_Druid_C000_Book_CallRaven'           = 'NAMED RISK: raven rig/animation in flight; -40 weapon skill debuff on its target'
    'TVR_Druid_C025_Book_CallSnakes'          = 'two snakes; poison dps ticks'
    'TVR_Druid_C050_Book_CallWolf'            = 'bleed-out on targets under 20% Health; single summon only (Twin Souls is dead in Enderal - doubling absent is CORRECT)'
    'TVR_Druid_C075_Book_CallSnowLeopard'     = 'stamina drain; speed boost in combat'
    'TVR_Druid_C100_Book_CallHoundOfHircine'  = 'name reads "Call the Glacier Hound"; armor shred procs; concentration drain cannot be enchanted away'
    'TVR_Druid_R025_Book_ParasiticGrowth'     = 'a Goodberry lands in the victim inventory on death and heals when eaten'
    'TVR_Druid_R100_Book_SpiritOfTheSun'      = 'heals ALLIES including summons (SummonableFaction substitution)'
    # Shadow Mage
    'TVR_Shadow_A025_Book_StepThroughShadows' = 'NAMED RISK: teleport - test in an Enderal interior, a city (Ark) and open terrain'
    'TVR_Shadow_A050_Book_ShadowDance'        = 'NAMED RISK: jump-dash needs a clear path check on Enderal navmesh'
    'TVR_Shadow_A075_Book_PullThroughShadow' = 'NAMED RISK: pulls target through Enderal geometry without stranding it'
    'TVR_Shadow_A100_Book_NightGate'          = 'NAMED RISK: both portals placeable on walkable Enderal terrain; round trip works'
    'TVR_Shadow_D025_Book_AzrasWrath'         = 'name reads "Shadow''s Wrath"; damage scales off current Magicka'
    'TVR_Shadow_D050_Book_Nightblade'         = 'dash-attack from range; Magicka converts to bonus damage'
    'TVR_Shadow_I000_Book_GatherShadows'      = 'NAMED RISK: darkness detection against Enderal''s own lighting - test day/night/interior'
    'TVR_Shadow_I025_Book_Darkness'           = 'NAMED RISK: shadow-emitting light pools render under Enderal lighting'
    'TVR_Shadow_I050_Book_RevealSecrets'      = 'containers/doors/keys highlighted; plant marking uses the pruned Mark lists'
    'TVR_Shadow_I075_Book_Possession'         = 'level-capped; works on Lost Ones? EXPECTED NO for Dwarven-keyword constructs (MasterOfTheMind is dead - vanilla no-perk behaviour)'
    'TVR_Shadow_I100_Book_Nightfall'          = 'NAMED RISK: pool follows caster; grants known Shadow buffs; darkness scaling as above'
    # Warlock
    'TVR_Warlock_D000_Book_EldritchBlast'     = 'SPIRIT LOOP: kill -> "Spirit bound" -> summon within 30s -> upgraded minion. This is the archetype - test end to end'
    'TVR_Warlock_D025_Book_Balefire'          = 'poisoned target takes 30% more from your minions'
    'TVR_Warlock_D100_Book_HurlIntoOblivion'  = 'name reads "Hurl Into Sinistra"; NAMED RISK: survivors vanish to the holding cell (TVR_Cell) and RETURN on recast - never test on a quest NPC'
    'TVR_Warlock_C000_Book_ConjureGremlin'    = 'with Spirit: disarm chance; base strength only (Elemental Potency is dead - Potent variants absent is CORRECT)'
    'TVR_Warlock_C075_Book_ConjureOathbreaker'= 'Magister uses its staff (template repointed to Enderal''s); escalating burst builds'
    'TVR_Warlock_C100_Book_ConjureLeviathan'  = '180s duration; with Spirit: immobilize + bleed on attack'
    # Cleric
    'TVR_Cleric_D000_Book_SolarRay'           = 'fire beam; vs a Lost One the _VsUndead doubling fires (IsUndead condition)'
    'TVR_Cleric_D050_Book_ConsecratedGround'  = 'ground patch persists 30s; doubled vs Lost Ones'
    'TVR_Cleric_R000_Book_Aid'                = 'buff names read Enderal skills (Mentalism, Entropy, Light Magic, Handicraft, Rhetoric, Sleight of Hand...)'
    'TVR_Cleric_R025_Book_Aura_1'        = 'RELEASE HOOK: stop concentrating -> burst fires. Guards excluded from the proc (repointed IsGuardFaction)'
    'TVR_Cleric_R050_Book_Aura_2'        = 'RELEASE HOOK: 2s invulnerability on release'
    'TVR_Cleric_R075_Book_Aura_3'       = 'RELEASE HOOK: 100 heal on release; melee reflect while held'
    'TVR_Cleric_I050_Book_SpiritGuardian'     = 'guardian spawns for EVERY Enderal race (script falls back to index 0); carries gear; returns it on death; joins SummonableFaction'
    'TVR_Cleric_I075_Book_Obedience'          = 'converted enemy fights for you AND barters out of combat; gets Enderal hunting bow if unarmed'
    'TVR_Cleric_I100_Book_Exodus'             = 'NAMED RISK: hides all nearby actors except follower - never test near quest NPCs'
    # Shaman
    'TVR_Shaman_A000_Book_Farsight'           = 'name reads "Eye of the Ancestors"; survey marks work; travel-marker beams DO NOT fire (orphaned Stone quest - expected)'
    'TVR_Shaman_A050_Book_Fissure'            = 'rock wall + knockdown on Enderal navmesh; staff reads "Staff of Fissures"'
    'TVR_Shaman_A100_Book_SacredHearth'       = 'NAMED RISK: consecrate -> recall in spirit form -> return; marker must survive save/reload'
    'TVR_Shaman_C000_Book_CreateWaterTotem'   = 'totem places on Enderal navmesh; heals + cures in combat only'
    'TVR_Shaman_C050_Book_SummonWindFylgja'   = 'NAMED RISK: body-swap possession - test save, load, fast travel and combat interruption while possessed; sheathe cancels'
    'TVR_Shaman_C075_Book_CreateEarthTotem'   = 'tremor every 7s in combat'
    'TVR_Shaman_C100_Book_SummonSunFylgja'    = 'NAMED RISK: as Wind Fylgja; its Grand Healing no longer carries the dead WI-say script - no Papyrus error on cast'
    'TVR_Shaman_R000_Book_RunesOpportunity' = 'random foes in radius get cursed over 240s; effects expire cleanly'
    'TVR_Shaman_R100_Book_ShieldOfAwe'        = 'release SOUND now plays (dead civil-war global gate removed); rune debuffs inside'
}
$default = 'casts; visible effect; magnitude/duration as described'

# --- emit ----------------------------------------------------------------------------------------
$L = New-Object System.Collections.Generic.List[string]
$L.Add('# Triumvirate for Enderal -- spell test matrix')
$L.Add('')
$L.Add('> **Generated** by `src/Triumvirate/tools/14-gen-test-matrix.ps1` from the Spriggit YAML. Do not')
$L.Add('> hand-edit -- re-run it. Tick the boxes in a working copy or a PR comment.')
$L.Add('')
$L.Add('Covers the **75 tome-taught spells** (15 per archetype), enumerated from the Book records''')
$L.Add('`Teaches` links so the list cannot drift from the plugin. Produced for **WD-11..WD-15**;')
$L.Add('distribution rows are WD-16''s and packaging is WD-18''s.')
$L.Add('')
$L.Add('## Before you start')
$L.Add('')
$L.Add('1. **Find the plugin''s load-order index**: `help "Spell Tome: Aid" 0` -- the leading two hex')
$L.Add('   digits. **If this returns nothing, stop**: the plugin is not loading (on Enderal that almost')
$L.Add('   always means `HEDR` 1.71; this tree builds 1.70, so suspect the deploy).')
$L.Add('2. **Test character**: `tgm`, `player.setav magicka 100000`, `player.setlevel 50`.')
$L.Add('3. **Papyrus log on** (see CLAUDE.md -- the PROFILE ini, and the log lands in the Skyrim SE')
$L.Add('   Documents folder). Any `Cannot call ... on a None object` line naming a `TVR_` script during')
$L.Add('   these tests is a regression -- after WD-16 there is NO expected TVR Papyrus noise at all:')
$L.Add('   the populate script was replaced and its dead calls removed.')
$L.Add('4. Teach a spell with `player.additem <XX offset of the tome> 1` then read it, or')
$L.Add('   `player.addspell`.')
$L.Add('')

foreach ($arch in 'Druid', 'Shadow', 'Warlock', 'Cleric', 'Shaman') {
    $archRows = $rows | Where-Object Arch -eq $arch | Sort-Object SchoolOrder, Order
    $title = @{Druid='Druid (WD-11)'; Shadow='Shadow Mage (WD-12)'; Warlock='Warlock (WD-13)'; Cleric='Cleric (WD-14)'; Shaman='Shaman (WD-15)'}[$arch]
    $L.Add("## $title")
    $L.Add('')
    $L.Add('| OK | School | Rank | Spell | Verify |')
    $L.Add('|----|--------|------|-------|--------|')
    foreach ($r in $archRows) {
        $note = if ($notes.ContainsKey($r.Book)) { $notes[$r.Book] } else { $default }
        $L.Add(('| [ ] | {0} | {1} | {2} | {3} |' -f $r.School, $r.Rank, $r.Spell, $note))
    }
    $L.Add('')
}

$L.Add('## Cross-cutting named risks')
$L.Add('')
$L.Add('| OK | Risk | Why it cannot be proven from records |')
$L.Add('|----|------|--------------------------------------|')
$L.Add('| [ ] | **Wild Shape / `Game.SetBeastForm`** | Engine werewolf flag on a game with no werewolf system -- HUD, controls and equipment behaviour are unknowable until launch (WD-17 finding 4) |')
$L.Add('| [ ] | **Raven summon rig** | The one summon with no close Enderal creature family; watch its skeleton/animation in flight |')
$L.Add('| [ ] | **All four Shadow teleports indoors** | Navmesh and walkable-terrain checks differ per cell; Enderal''s interiors were never the mod''s test bed |')
$L.Add('| [ ] | **Darkness detection under Enderal lighting** | Gather Shadows / Nightfall scale off ambient light; Enderal replaced all light settings (SureAI readme) |')
$L.Add('| [ ] | **Fylgja possession lifecycle** | Save, load, fast travel, combat interruption while the body is left behind |')
$L.Add('| [ ] | **Hurl Into Sinistra holding cell** | Survivors sit in TVR_Cell until recast; verify they return, and never cast it at a quest NPC |')
$L.Add('| [ ] | **Aura release hooks** | Concentration-end triggers are runtime-only behaviour |')
$L.Add('| [ ] | **Warlock Spirit-binding loop end to end** | Kill under Eldritch Blast -> summon within 30s -> upgraded minion (WD-13 done-when) |')
$L.Add('| [ ] | **Totem placement on Enderal navmesh** | Placed activators with in-combat conditions |')
$L.Add('| [ ] | **Sacred Hearth across sessions** | World marker must survive save/reload and not trap the player |')
$L.Add('')
$L.Add('**Expected deviations (working as intended, do not file):** single summons only (Twin Souls')
$L.Add('dead), base-strength Warlock minions (Elemental Potency dead), Possession never affects')
$L.Add('Dwarven-keyword constructs (Master of the Mind dead), Farsight''s travel-marker beams silent')
$L.Add('(orphaned quest), Diviner/Farsight XP trickle absent (`AdvanceSkill` is inert in Enderal).')
$L.Add('')

[System.IO.File]::WriteAllText($out, ($L -join "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "14 - wrote $out ($($rows.Count) spells)"
