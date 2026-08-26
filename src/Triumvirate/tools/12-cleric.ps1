# 12 - The Cleric line (WD-14).
#
# Record-level work for this archetype was done in 08 (SpiritGuardian factions, the guard
# exclusion on the aura cloak-procs, the Suggestion/Obedience WI-say scripts, three staff
# templates). Two ticket questions resolved by reading rather than editing:
#
#   SUN DAMAGE: already solved. The "fire and sun" spells are plain fire (ResistValue:
#   ResistFire) plus a _VsUndead doubling effect gated on "HasKeyword ActorTypeUndead == 1 OR
#   IsUndead == 1". ActorTypeUndead 013796 EXISTS in Enderal, and IsUndead reads race flags -
#   Enderal's Lost Ones sit on DraugrRace shells, so the doubling fires. No Dawnguard machinery
#   survives in these records at all (WD-9 stripped it). Nothing to do.
#
#   SPIRIT GUARDIAN RACES: TVR_ProjectedSpirit_Script does TVR_Races.find(GetRace()) and FALLS
#   BACK TO INDEX 0 when the caster's race is not in the array - so every Enderal race gets a
#   guardian, and the Argonian/Khajiit/Orc guardian actors are simply unreachable (no Enderal
#   player has those races). Kept as vestigial rather than deleted: harmless, and deleting
#   records again would churn the census for nothing.
#
# Renames: the Aid buff names the vanilla skills ("Fortify Skills - Alteration"), which is
# player-visible in active-effects UI. Remapped to Enderal's own display names, read off the
# _00E_Levelsystem_sSkillName* messages [verified]. Note Alteration is Mentalism and Illusion is
# Psionics - the intuitive pairing is wrong (CLAUDE.md).

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "12 - Cleric (WD-14)"
$root = Get-EspRoot

# vanilla string in the Aid effect Name -> Enderal display name (_00E_Levelsystem_sSkillName*)
$renames = @(
    @('Fortify Skills - Alteration',  'Fortify Skills - Mentalism'),
    @('Fortify Skills - Conjuration', 'Fortify Skills - Entropy'),
    @('Fortify Skills - Destruction', 'Fortify Skills - Elementalism'),
    @('Fortify Skills - Illusion',    'Fortify Skills - Psionics'),
    @('Fortify Skills - Restoration', 'Fortify Skills - Light Magic'),
    @('Fortify Skills - Smithing',    'Fortify Skills - Handicraft'),
    @('Fortify Skills - Speech',      'Fortify Skills - Rhetoric'),
    @('Fortify Skills - Pickpocket',  'Fortify Skills - Sleight of Hand'),
    # Note the "\n" anchor: 'Fortify Skills - Block' is a PREFIX of its own replacement, and an
    # unanchored replace re-matches inside 'Blocking' on every rerun ("Blockinging..."). The Name
    # value ends the line, so anchoring on the CRLF makes the rename idempotent.
    @("Fortify Skills - Block`r`n",    "Fortify Skills - Blocking`r`n"),
    @('Fortify Skills - HeavyArmor',  'Fortify Skills - Heavy Armor'),
    @('Fortify Skills - LightArmor',  'Fortify Skills - Light Armor'),
    @('Fortify Skills - OneHanded',   'Fortify Skills - One-handed'),
    @('Fortify Skills - TwoHanded',   'Fortify Skills - Two-handed')
)
# Archery, Enchanting, Lockpicking and Sneak match Enderal's display names already.
$total = 0
foreach ($r in $renames) {
    $n = Update-TreeStrings -Old $r[0] -New $r[1] -MustExistAfter
    Write-Host ("  '{0}' -> '{1}': {2}" -f $r[0], $r[1], $n)
    $total += $n
}
Write-Host "12 - done ($total renames)"
