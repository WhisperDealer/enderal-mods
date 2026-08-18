# 04 - Clear the last three references into Dawnguard.esm, so 05 can drop the DLC masters.
#
# After 01 and 02 the only surviving DLC references are cosmetic, and they are NOT in FormLists
# that get deleted (an assumption in the original plan that turned out to be wrong - 05's guard
# caught it):
#
#   Traits_CrabDietList              one entry of eleven, a Dawnguard ingredient
#   Traits_AnglerExplosion           Sound1 / Sound2, two Dawnguard sound descriptors
#   Traits_BadNaturedNeg1DamageEffect  HitShader, a Dawnguard effect shader
#
# The fix is to REMOVE the fields, not to null them. Absence is well-precedented in Enderal -
# 476 of its 1008 magic effects carry no HitShader and 90 of its 227 explosions carry no Sound1
# (measured 2026-08-05) - whereas a null FormKey is the pattern CLAUDE.md records as untested and
# later reverted on the Apocalypse recipes. An absent optional field is the proven archetype.
#
# Note the Angler explosion's Model still points at a Creation Club Fishing mesh
# (CreationClub\BGSSSE001\Effects\WaterImpactExplosion.nif) that Enderal does not ship. That is a
# file path rather than a FormID, so it does not block the master drop; it means the splash has no
# mesh, which is cosmetic. Left alone deliberately.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "04 - clearing residual Dawnguard references"

$root = Get-EspRoot

function Remove-FieldLines {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Label
    )
    $lines = Get-YamlLines $Path
    $keep  = @()
    $dropped = 0
    foreach ($line in $lines) {
        if ($line -match $Pattern) { $dropped++ } else { $keep += $line }
    }
    if ($dropped -gt 0) { Set-YamlLines -Path $Path -Lines $keep }
    Write-Host ("  {0}: removed {1} line(s)" -f $Label, $dropped)
    return $dropped
}

$total = 0

# --- the Dawnguard ingredient in the mudcrab diet -----------------------------------------------
$crab = Get-ChildItem -Path (Join-Path $root 'FormLists') -Filter 'Traits_CrabDietList - *.yaml' | Select-Object -First 1
if ($crab) {
    $before = (Get-YamlLines $crab.FullName | Where-Object { $_ -match '^\s*-\s+[0-9A-Fa-f]{6}:' }).Count
    $total += Remove-FieldLines -Path $crab.FullName `
                                -Pattern '^\s*-\s+[0-9A-Fa-f]{6}:Dawnguard\.esm\s*$' `
                                -Label 'Traits_CrabDietList'
    $after = (Get-YamlLines $crab.FullName | Where-Object { $_ -match '^\s*-\s+[0-9A-Fa-f]{6}:' }).Count
    Write-Host ("    diet entries: {0} -> {1}" -f $before, $after)
    if ($after -lt 10) { throw "Crab diet list dropped below the 10 entries that resolve in Enderal." }
}

# --- the Angler explosion's Dawnguard sounds ----------------------------------------------------
$expl = Get-ChildItem -Path (Join-Path $root 'Explosions') -Filter 'Traits_AnglerExplosion - *.yaml' | Select-Object -First 1
if ($expl) {
    $total += Remove-FieldLines -Path $expl.FullName `
                                -Pattern '^\s*Sound[12]: [0-9A-Fa-f]{6}:Dawnguard\.esm\s*$' `
                                -Label 'Traits_AnglerExplosion (Sound1/Sound2)'
}

# --- the Bad Natured damage effect's Dawnguard hit shader ---------------------------------------
$bad = Get-ChildItem -Path (Join-Path $root 'MagicEffects') -Filter 'Traits_BadNaturedNeg1DamageEffect - *.yaml' | Select-Object -First 1
if ($bad) {
    $total += Remove-FieldLines -Path $bad.FullName `
                                -Pattern '^\s*HitShader: [0-9A-Fa-f]{6}:Dawnguard\.esm\s*$' `
                                -Label 'Traits_BadNaturedNeg1DamageEffect (HitShader)'
}

if ($total -eq 0) {
    Write-Host "  nothing to do - already applied"
}

# Prove the job is finished rather than trusting the counts above.
$remaining = @()
foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
    $text = Read-YamlText $file.FullName
    foreach ($dlc in @('Dawnguard.esm', 'HearthFires.esm', 'Dragonborn.esm')) {
        if ($text -match ('[0-9A-Fa-f]{6}:' + [regex]::Escape($dlc))) { $remaining += $file.Name }
    }
}
if ($remaining.Count -gt 0) {
    throw "DLC references still present in: $(($remaining | Select-Object -Unique) -join ', ')"
}

Write-Host "04 - done; no DLC FormID references remain"
