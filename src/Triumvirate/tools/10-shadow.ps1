# 10 - The Shadow Mage line (WD-12).
#
# Record-level work for this archetype was done in 08 (MagicAllegianceFaction on Traitorous
# Shadow's script property, the Darkness staff template) - the Shadow Mage came through the
# gap audit nearly clean.
#
# Rename, per arch-docs/Triumvirate/naming-table.md (decision 3, option B): Azra Nightwielder is
# Elder Scrolls apocrypha with no Enderal counterpart, and we know no Enderal mage well enough to
# hang a destructive spell on, so the attribution is dropped: "Azra's Wrath" -> "Shadow's Wrath".
#
# Deliberately NOT touched:
#   MasterOfTheMind 059B76 on TVR_Shadow_Possess_Effect_TraitorousShadow. The condition group is
#   "not an automaton OR target has MasterOfTheMind"; with the perk dead the OR collapses to "not
#   an automaton", which is exactly vanilla's no-perk behaviour. Possession simply never affects
#   Dwarven-keyword constructs. Documented deviation.
#   The teleport/dash spells and darkness detection are runtime questions - WD-18 test matrix.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "10 - Shadow Mage (WD-12)"
$root = Get-EspRoot

$n = Update-TreeStrings -Old "Azra's Wrath" -New "Shadow's Wrath" -MustExistAfter
Write-Host "  'Azra's Wrath' -> 'Shadow's Wrath': $n"

$left = @()
foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
    foreach ($line in Get-YamlLines $file.FullName) {
        if ($line -match 'Azra' -and $line -notmatch 'EditorID|FormKey|File(Name)?:|Name: [A-Za-z_0-9]+\s*$') {
            $left += ("{0}: {1}" -f $file.Name, $line.Trim())
        }
    }
}
if ($left.Count -gt 0) {
    $left | ForEach-Object { Write-Host "    remaining: $_" }
    throw "$($left.Count) player-facing Azra string(s) survived."
}
Write-Host "10 - done"
