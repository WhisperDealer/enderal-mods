# 05 - Drop the three DLC masters from the plugin header.
#
# The stock plugin masters Skyrim.esm, Update.esm, Dawnguard.esm, HearthFires.esm and
# Dragonborn.esm. In Enderal the three DLC files are empty stubs holding 1-2 records between them,
# and every DLC-suffixed FormID this mod referenced lived in a FormList that steps 01 and 02
# delete (Way of the Voice shouts, Disbeliever blessings, the skooma list, the Giantkin exclusion).
#
# Note this is hygiene, not a fix: the stubs DO load in Enderal whether or not they are listed,
# so mastering one is harmless. Dropping them just keeps the header honest about what the plugin
# actually needs. Run this AFTER 02, so no reference is left behind.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "05 - dropping DLC masters"

$root   = Get-EspRoot
$header = Join-Path $root 'RecordData.yaml'
if (-not (Test-Path $header)) { throw "Header not found: $header" }

# Fail loudly rather than leaving a dangling master reference behind.
$stillReferenced = @()
foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
    $text = Read-YamlText $file.FullName
    foreach ($dlc in @('Dawnguard.esm', 'HearthFires.esm', 'Dragonborn.esm')) {
        if ($text -match ('[0-9A-Fa-f]{6}:' + [regex]::Escape($dlc))) {
            $stillReferenced += ("{0} -> {1}" -f $file.Name, $dlc)
        }
    }
}
if ($stillReferenced.Count -gt 0) {
    Write-Host "  records still referencing a DLC master:" -ForegroundColor Red
    $stillReferenced | Select-Object -Unique | ForEach-Object { Write-Host "    $_" }
    throw "Cannot drop DLC masters while $($stillReferenced.Count) reference(s) remain. Run 01 and 02 first."
}

$lines   = Get-YamlLines $header
$keep    = @()
$dropped = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*-\s+Master: (Dawnguard|HearthFires|Dragonborn)\.esm\s*$') {
        # Each master is a two-line entry: '- Master: X' then '  FileSize: 0'.
        Write-Host ("    - {0}" -f $lines[$i].Trim())
        $dropped++
        if ($i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^\s*FileSize:') { $i++ }
        continue
    }
    $keep += $lines[$i]
}

if ($dropped -eq 0) {
    Write-Host "  nothing to do - already applied"
} else {
    Set-YamlLines -Path $header -Lines $keep
    Assert-Changed -Count $dropped -What 'DLC master removal'
    Write-Host ("  removed {0} master reference(s)" -f $dropped)
}

Write-Host "05 - done"
