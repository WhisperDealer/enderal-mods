# 03 - Remove every bare DLC list entry from the surviving records.
#
# WD-9 verdict 7, second shape. These are sequence entries - "- HEX:Dragonborn.esm" - inside
# FormLists, race keyword lists and armour-addon race lists. Each points at a Hearthfires garden
# plant, a Dawnguard/Dragonborn ore or flora, or a DLC voice type. Enderal has none of them, so
# every entry is inert.
#
# Two things this deliberately does NOT do:
#
#   * It does not repopulate the lists from Enderal's own flora. The Druid's Mark Plant / Mark Ore
#     lists want Enderal targets and there ARE real ones - six of Triumvirate's Blackreach ore
#     entries already resolve to _00E_MineOreShadowsteel* by pure FormID coincidence - but deciding
#     what a tracking spell should find in Enderal is WD-11's call, not a strip's.
#   * It does not touch named fields. "Voice: HEX:Dawnguard.esm" is a field, not a list entry, and
#     is handled with a substitute in 04. The regex requires a bare "- " entry precisely so a
#     property line is never silently mangled.
#
# The empty-collection trap matters here: Spriggit omits a collection key entirely when the
# collection is empty, and Mutagen's reader throws "Expected 'SequenceStart', got 'Scalar'" on a
# bare "Items:" with nothing under it. Remove-YamlListEntries in 00-common.ps1 prunes the key too.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "03 - stripping DLC list entries"

$root = Get-EspRoot
$dlcEntry = '^\s*-\s+[0-9A-Fa-f]{6}:(Dawnguard|HearthFires|Dragonborn)\.esm\s*$'

$totalDropped = 0
$touched = 0

foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.yaml') {
    $lines = Get-YamlLines $file.FullName
    $keep = @()
    $dropped = 0
    foreach ($line in $lines) {
        if ($line -match $dlcEntry) { $dropped++ } else { $keep += $line }
    }
    if ($dropped -eq 0) { continue }

    $before = @($lines | Where-Object { $_ -match '^\s*-\s+[0-9A-Fa-f]{6}:' }).Count
    $keep = Remove-EmptyCollectionKeys -Lines $keep
    Set-YamlLines -Path $file.FullName -Lines $keep
    $after = @($keep | Where-Object { $_ -match '^\s*-\s+[0-9A-Fa-f]{6}:' }).Count

    Write-Host ("    {0,-58} -{1,-4} entries ({2} -> {3})" -f ($file.BaseName -split ' - ')[0], $dropped, $before, $after)
    $totalDropped += $dropped
    $touched++
}

if ($totalDropped -eq 0) {
    Write-Host "  nothing to do - already applied"
} else {
    Write-Host ("  removed {0} entries across {1} record(s)" -f $totalDropped, $touched)
}

# Whatever is left must be a named field, never a list entry.
$leftovers = @()
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.yaml') {
    foreach ($line in (Get-YamlLines $file.FullName)) {
        if ($line -match $dlcEntry) { $leftovers += ("{0}: {1}" -f $file.Name, $line.Trim()) }
    }
}
if ($leftovers.Count -gt 0) {
    $leftovers | ForEach-Object { Write-Host "    missed: $_" }
    throw "$($leftovers.Count) DLC list entr(ies) survived."
}

Write-Host "03 - done; only named DLC fields remain (04 handles those)"
