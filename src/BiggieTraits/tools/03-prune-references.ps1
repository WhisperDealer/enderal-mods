# 03 - Repair every reference left pointing at a record that 01 and 02 deleted.
#
# This is the step that decides whether the cut is safe. Four surviving records reference the cut
# set (measured before any deletion, so the list is exhaustive):
#
#   Traits_AbilityList          the 38 selectable traits - what the B612 menu draws
#   Traits_EffectsList          the matching magic effects
#   Traits_MCM                  a script property pointing at the Homeowner mortgage multiplier
#   Traits_PlayerLoadGameQuest  alias scripts for Addict and Skilled
#
# A stale entry in the first two is the dangerous case: the menu still shows the row and granting
# it does nothing. The script finishes with a full sweep that fails if ANY dangling internal
# reference survives.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "03 - pruning references to removed records"

$root  = Get-EspRoot
$index = Get-RecordIndex

# Every FormKey this plugin still references but no longer defines.
function Get-DanglingRefs {
    param([hashtable]$Index)
    $dangling = @{}
    foreach ($file in Get-ChildItem -Path (Get-EspRoot) -Recurse -Filter '*.yaml') {
        $text = Read-YamlText $file.FullName
        foreach ($m in [regex]::Matches($text, '([0-9A-Fa-f]{6}:Biggie Traits\.esp)')) {
            $fk = $m.Groups[1].Value
            if (-not $Index.ContainsKey($fk)) {
                if (-not $dangling.ContainsKey($fk)) { $dangling[$fk] = @() }
                if ($dangling[$fk] -notcontains $file.Name) { $dangling[$fk] += $file.Name }
            }
        }
    }
    return $dangling
}

$dangling = Get-DanglingRefs -Index $index
Write-Host ("  found {0} dangling FormKey(s) to clear" -f $dangling.Keys.Count)

# --- 1/2: the two driver FormLists --------------------------------------------------------------
$listsPruned = 0
foreach ($listName in @('Traits_AbilityList', 'Traits_EffectsList')) {
    $file = Get-ChildItem -Path (Join-Path $root 'FormLists') -Filter "$listName - *.yaml" | Select-Object -First 1
    if (-not $file) { throw "Driver list '$listName' not found - it must survive the cut." }
    $n = Remove-YamlListEntries -Path $file.FullName -FormKeys @($dangling.Keys)
    Write-Host ("  {0}: removed {1} stale entry/entries" -f $listName, $n)
    $listsPruned += $n
}

# --- 3: the MCM's Homeowner property ------------------------------------------------------------
$mcm = Get-ChildItem -Path (Join-Path $root 'Quests') -Filter 'Traits_MCM - *.yaml' | Select-Object -First 1
$mcmPruned = 0
if ($mcm) {
    # A ScriptObjectProperty block opens with '- MutagenObjectType:' and is identified by the
    # 'Name:' line inside it, so find the Name and walk back to the opening line.
    $lines = Get-YamlLines $mcm.FullName
    $nameIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*Name: Traits_HomeownerMortgageMult\s*$') { $nameIdx = $i; break }
    }
    if ($nameIdx -ge 0) {
        $startIdx = $nameIdx
        while ($startIdx -ge 0 -and $lines[$startIdx] -notmatch '^\s*-\s+MutagenObjectType:') { $startIdx-- }
        if ($startIdx -lt 0) { throw "Could not find the opening line of the Homeowner MCM property." }

        $startIndent = ($lines[$startIdx] -replace '^(\s*).*$', '$1').Length
        $endIdx = $lines.Count
        for ($i = $startIdx + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq '') { continue }
            $indent = ($lines[$i] -replace '^(\s*).*$', '$1').Length
            if ($indent -le $startIndent) { $endIdx = $i; break }
        }

        $keep = @()
        if ($startIdx -gt 0) { $keep += $lines[0..($startIdx - 1)] }
        if ($endIdx -lt $lines.Count) { $keep += $lines[$endIdx..($lines.Count - 1)] }
        Set-YamlLines -Path $mcm.FullName -Lines $keep
        $mcmPruned = $endIdx - $startIdx
    }
    Write-Host ("  Traits_MCM: removed {0} line(s) for the Homeowner property" -f $mcmPruned)
}

# --- 4: the PlayerLoadGameQuest alias scripts ---------------------------------------------------
$plg = Get-ChildItem -Path (Join-Path $root 'Quests') -Filter 'Traits_PlayerLoadGameQuest - *.yaml' | Select-Object -First 1
$plgPruned = 0
if ($plg) {
    foreach ($script in @('Traits_AddictPlayerScript', 'Traits_SkilledPlayerScript')) {
        $n = Remove-YamlBlock -Path $plg.FullName -StartPattern ('^\s*-\s+Name: ' + [regex]::Escape($script) + '\s*$')
        Write-Host ("  Traits_PlayerLoadGameQuest: removed {0} line(s) for {1}" -f $n, $script)
        $plgPruned += $n
    }
}

$totalPruned = $listsPruned + $mcmPruned + $plgPruned
if ($totalPruned -eq 0 -and $dangling.Keys.Count -gt 0) {
    throw "There were dangling references but nothing was pruned - a pattern has stopped matching."
}

# --- final sweep: no internal reference may point at a record that no longer exists --------------
$index    = Get-RecordIndex
$leftover = Get-DanglingRefs -Index $index
if ($leftover.Keys.Count -gt 0) {
    Write-Host ""
    Write-Host "STILL DANGLING - these must be handled before building:" -ForegroundColor Red
    foreach ($fk in ($leftover.Keys | Sort-Object)) {
        Write-Host ("  {0}  referenced by: {1}" -f $fk, ($leftover[$fk] -join ', '))
    }
    throw "$($leftover.Keys.Count) dangling internal reference(s) remain."
}

Write-Host ("03 - done; pruned {0} line(s), no dangling internal references remain" -f $totalPruned)
