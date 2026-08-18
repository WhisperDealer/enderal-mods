# 02 - Remove the traits whose mechanics have no target in Enderal.
#
# Each entry below was decided by resolving the trait's FormList targets against reference/base/
# on 2026-08-05, not by reading the trait's name. The counts are the measurements.
#
#   Master of Destiny   0/13 standing stones and 0/15 stone effects exist in Enderal
#   Disbeliever         1/12 Divine shrines exist (only ShrineOfKynareth 0D987F)
#   Way of the Voice    3/18 non-hostile shouts exist; and 013F3A is VoiceUnrelentingForce2 in
#                       Skyrim but _00E_A2_PrimalForceSP in Enderal - a different record
#   Dovah Tinvaak       dragon-language flavour built on the same shout set
#   Addict              0/5 skooma items exist
#   Skilled             drives Game.ModPerkPoints; Enderal uses its own TalentPoints (05BCFA)
#                       and a custom skill menu, and no Enderal script touches vanilla perk points
#   Master of One       same perk-point problem, plus it injects into StatsMenu, which Enderal
#                       replaced with _00E_Game_SkillmenuSC
#   Autodidact          hangs off RegisterForSkillIncrease; Enderal has no learn-by-doing
#
# Nosferatu is deliberately NOT cut: its food items resolve 3/3 in Enderal. It is flagged for
# in-game testing instead.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "02 - cutting traits with no Enderal target"

# EditorID substrings, grouped by the trait they belong to.
$families = [ordered]@{
    'Master of Destiny' = @('MasterofDestiny', 'StandingStones')
    'Master of One'     = @('MasterofOne')
    'Disbeliever'       = @('Disbeliever', 'ReligiousShrine', 'ShrineTouch')
    'Way of the Voice'  = @('WayoftheVoice')
    'Dovah Tinvaak'     = @('DovahTinvaak')
    'Addict'            = @('Addict', 'Skooma')
    'Skilled'           = @('Skilled')
    'Autodidact'        = @('Autodidact')
}

$index = Get-RecordIndex
$total = 0
foreach ($name in $families.Keys) {
    $records = Get-RecordsMatching -Patterns $families[$name] -Index $index
    if ($records.Count -eq 0) {
        Write-Host ("  {0}: already removed" -f $name)
        continue
    }
    Write-Host ("  {0}:" -f $name)
    $total += Remove-RecordFiles -Records $records -Label $name
}

if ($total -eq 0) {
    Write-Host "  nothing to do - already applied"
} else {
    Write-Host ("02 - removed {0} record(s) across {1} trait(s)" -f $total, $families.Count)
}

Write-Host "02 - done"
