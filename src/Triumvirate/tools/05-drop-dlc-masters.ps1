# 05 - Drop the three DLC masters from the plugin header.
#
# Run this LAST. It refuses to touch the header while any DLC-suffixed FormID survives anywhere in
# the tree, so 01-04 must all have run first.
#
# This is hygiene, not a fix. CLAUDE.md records - verified in-game 2026-08-02, off a Crash Logger
# plugin table on a profile that never enabled them - that Enderal's engine loads all three DLC
# stubs unconditionally, whether or not plugins.txt lists them. So a DLC-mastered plugin loads with
# no user action, and WD-8's original claim that it "fails to load in game" was wrong. What dropping
# them buys is an honest header and WD-18's release gate.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "05 - dropping DLC masters"

$root   = Get-EspRoot
$header = Join-Path $root 'RecordData.yaml'
if (-not (Test-Path $header)) { throw "Header not found: $header" }

# Fail loudly rather than leaving a dangling master reference behind.
$stillReferenced = @()
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.yaml') {
    $text = Read-YamlText $file.FullName
    foreach ($dlc in @('Dawnguard.esm', 'HearthFires.esm', 'Dragonborn.esm')) {
        if ($text -match ('[0-9A-Fa-f]{6}:' + [regex]::Escape($dlc))) {
            $stillReferenced += ("{0} -> {1}" -f $file.Name, $dlc)
        }
    }
}
if ($stillReferenced.Count -gt 0) {
    Write-Host "  records still referencing a DLC master:" -ForegroundColor Red
    $stillReferenced | Select-Object -Unique | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
    throw "Cannot drop DLC masters while $($stillReferenced.Count) reference(s) remain. Run 01-04 first."
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

# The header must still declare exactly the two masters Triumvirate genuinely needs.
$masters = @(Get-YamlLines $header | Where-Object { $_ -match '^\s*-\s+Master: ' } | ForEach-Object { ($_ -replace '^\s*-\s+Master:\s*', '').Trim() })
Write-Host ("  masters now: {0}" -f ($masters -join ', '))
if ($masters -join ',' -ne 'Skyrim.esm,Update.esm') {
    throw "Unexpected master list after the drop: $($masters -join ', ')"
}

# And the form version must still be 1.70 - Mutagen's default is 1.71, which Enderal skips silently.
#
# The header carries TWO "Version:" lines: SpriggitSource.Version (the serializer, 0.40) comes
# first, and ModHeader.Stats.Version (the form version) second. Match the one under Stats, not the
# first one - reading $ver[0] finds the serializer version and asserts on the wrong number.
$headerText = Read-YamlText $header
if ($headerText -notmatch '(?m)^ModHeader:\r?\n\s+Stats:\r?\n\s+Version: 1\.7\s*(?=\r?$)') {
    $seen = @(Get-YamlLines $header | Where-Object { $_ -match '^\s*Version: ' })
    throw "Header form version is not 1.7 under ModHeader.Stats. Version lines seen: $($seen -join '; ')"
}
Write-Host "  form version still 1.7"

Write-Host "05 - done"
