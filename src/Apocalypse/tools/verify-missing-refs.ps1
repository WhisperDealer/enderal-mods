#requires -Version 5.1
<#
.SYNOPSIS
  ABSOLUTE audit of every reference the Apocalypse tree makes into Enderal's masters.

.DESCRIPTION
  `verify-dangling-diff.ps1` answers "did WE break anything new?" (expected: 0). This one answers
  the different, larger question: "what does this plugin point at that Enderal does not have?"

  Enderal's Skyrim.esm is base Enderal wearing Bethesda's filename, so a ported Skyrim mod's
  references land in one of three states, and only the audit tells them apart:

    MISSING    the FormID is not in Enderal at all         -> the reference is dead
    PRESENT    the FormID resolves to a record             -> may still be the WRONG record,
                                                              which is why we print its group+EditorID
    ALLOWED    engine-hardcoded (000014 PlayerRef)         -> absent from the tree but valid

  Two things this does that the diff script does not:

    1. Keys the index by "<hex>:<master>", not by hex alone. Keying on hex lets ANY hex that
       appears anywhere in reference/base/Skyrim count as "defined by Skyrim.esm" - which inflates
       that index from ~87k real records to ~786k and silently resolves references that are in
       fact dead.
    2. Resolves surviving references to their Enderal record group and EditorID, so a
       FormID-survived-but-is-a-different-record case is visible rather than invisible.

.PARAMETER Csv
  Where to write the per-reference CSV. Default: <repo>/build/dist/apocalypse-refs.csv

.PARAMETER Baseline
  Expected MISSING-reference count. Non-zero is normal and expected - Enai's plugin was written
  against Bethesda's Skyrim.esm. Fails if the actual count EXCEEDS this, so CI holds the line
  without demanding a number nobody can reach.
#>
[CmdletBinding()]
param(
    [string]$Csv,
    [int]$Baseline = -1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# <repo>/src/Apocalypse/tools/this.ps1 -> four levels up
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$ours = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$base = Join-Path $repo 'reference\base'

if (-not (Test-Path $ours))  { throw "Apocalypse YAML tree not found: $ours" }
if (-not (Test-Path $base))  { throw "reference/base not found: $base. Run /spriggit-decompile-reference first." }

# Masters we can adjudicate. A reference to anything else is out of scope, not a failure.
$knownMasters = @(
    'Skyrim.esm', 'Update.esm', 'Enderal - Forgotten Stories.esm',
    'Dawnguard.esm', 'HearthFires.esm', 'Dragonborn.esm',
    'Apocalypse - Magic of Skyrim.esp'
)

# Engine-hardcoded FormIDs that are valid but absent from the serialized trees (CLAUDE.md guardrail 11).
$allowList = @('000014')

# A record's OWN identity line. Never a reference.
$identityLine = '^\s*-?\s*FormKey: '
# Spriggit writes a link as "<Field>: <hex>:<master>" or, in a list, "- <hex>:<master>".
$refPattern = '\b([0-9A-F]{6}):([^\r\n''"]+?\.(?:esm|esp))\b'

# ---------------------------------------------------------------- index of DEFINED records
# Every "FormKey: <hex>:<master>" line, including the nested ones (cell children, navmeshes,
# perk sections) - those are real records too, and a reference to one must resolve.
$defined = New-Object 'System.Collections.Generic.HashSet[string]'
# Group + EditorID, from the per-record filename or the top of a RecordData.yaml.
$identity = @{}

function Add-Tree {
    param([string]$Root, [switch]$Identify)
    if (-not (Test-Path $Root)) { return 0 }
    $n = 0
    Get-ChildItem -LiteralPath $Root -Recurse -File -Filter *.yaml | ForEach-Object {
        $text = [IO.File]::ReadAllText($_.FullName)
        foreach ($m in [regex]::Matches($text, '(?m)^\s*-?\s*FormKey: ([0-9A-F]{6}):([^\r\n]+?)\s*(?=\r?$)')) {
            if ($defined.Add($m.Groups[1].Value + ':' + $m.Groups[2].Value)) { $n++ }
        }
        if ($Identify) {
            $rel = $_.FullName.Substring($Root.Length + 1)
            $group = ($rel -split '\\')[0]
            $key = $null; $eid = ''
            if ($_.Name -eq 'RecordData.yaml') {
                if ($text -match '(?m)^FormKey: ([0-9A-F]{6}):([^\r\n]+?)\s*(?=\r?$)') { $key = $Matches[1] + ':' + $Matches[2] }
                if ($text -match '(?m)^EditorID: (.+?)\s*(?=\r?$)') { $eid = $Matches[1] }
            } elseif ($_.BaseName -match ' - ([0-9A-F]{6})_(.+)$') {
                $key = $Matches[1] + ':' + $Matches[2]
                $eid = ($_.BaseName -split ' - ')[0]
            } elseif ($_.BaseName -match '^([0-9A-F]{6})_(.+)$') {
                $key = $Matches[1] + ':' + $Matches[2]
            }
            if ($key -and -not $identity.ContainsKey($key)) { $identity[$key] = @{ Group = $group; EditorID = $eid } }
        }
    }
    $n
}

Write-Host 'indexing Enderal masters...'
foreach ($tree in 'Skyrim', 'Update', 'EnderalFS', 'Dawnguard-stub', 'HearthFires-stub', 'Dragonborn-stub') {
    $added = Add-Tree -Root (Join-Path $base $tree) -Identify
    Write-Host ("  {0,-18} +{1} FormKeys" -f $tree, $added)
}
Write-Host 'indexing our own tree...'
$null = Add-Tree -Root $ours -Identify
Write-Host "  defined FormKeys total: $($defined.Count)"

# ---------------------------------------------------------------- scan our references
Write-Host 'scanning references...'
$rows = New-Object System.Collections.ArrayList
Get-ChildItem -LiteralPath $ours -Recurse -File -Filter *.yaml | ForEach-Object {
    $rel   = $_.FullName.Substring($ours.Length + 1)
    $group = ($rel -split '\\')[0]
    $owner = if ($_.Name -eq 'RecordData.yaml') { Split-Path -Leaf (Split-Path -Parent $_.FullName) } else { $_.BaseName }

    foreach ($line in ([IO.File]::ReadAllText($_.FullName) -split "`r?`n")) {
        if ($line -match $identityLine) { continue }
        foreach ($m in [regex]::Matches($line, $refPattern)) {
            $hex    = $m.Groups[1].Value
            $master = $m.Groups[2].Value.Trim()
            if ($knownMasters -notcontains $master) { continue }
            if ($allowList -contains $hex) { continue }

            $key = "${hex}:$master"
            $state = 'PRESENT'
            $tgtGroup = ''; $tgtEid = ''
            if (-not $defined.Contains($key)) {
                $state = 'MISSING'
            } elseif ($identity.ContainsKey($key)) {
                $tgtGroup = $identity[$key].Group; $tgtEid = $identity[$key].EditorID
            } else {
                $tgtGroup = '<nested>'   # a REFR / NAVM inside a parent record's file
            }

            # "Field: <hex>:<master>" -> Field. A bare list entry has no field name.
            $field = ($line -replace '^\s*-?\s*', '') -replace ':\s*[0-9A-F]{6}:.*$', ''
            if ($field -match '^[0-9A-F]{6}:') { $field = '<list entry>' }

            [void]$rows.Add([pscustomobject]@{
                State = $state; OwnerGroup = $group; Owner = $owner
                Field = $field; Target = $key
                TargetGroup = $tgtGroup; TargetEditorID = $tgtEid
            })
        }
    }
}

$missing = @($rows | Where-Object State -eq 'MISSING')
$distinct = @($missing | Select-Object -ExpandProperty Target -Unique)
$records  = @($missing | Select-Object -ExpandProperty Owner  -Unique)

''
Write-Host "references examined : $($rows.Count)"
Write-Host "MISSING occurrences : $($missing.Count)  across $($distinct.Count) distinct FormKeys in $($records.Count) records"
''
'--- MISSING, by owning record type ---'
$missing | Group-Object OwnerGroup | Sort-Object Count -Descending | ForEach-Object {
    "{0,-24} occ={1,-6} records={2}" -f $_.Name, $_.Count, (@($_.Group | Select-Object -ExpandProperty Owner -Unique).Count)
}
''
'--- MISSING, by field ---'
$missing | Group-Object Field | Sort-Object Count -Descending | Select-Object -First 15 | ForEach-Object {
    "{0,-30} {1}" -f $_.Name, $_.Count
}

if (-not $Csv) { $Csv = Join-Path $repo 'build\dist\apocalypse-refs.csv' }
$csvDir = Split-Path -Parent $Csv
if (-not (Test-Path $csvDir)) { $null = New-Item -ItemType Directory -Force -Path $csvDir }
$rows | Export-Csv -LiteralPath $Csv -NoTypeInformation -Encoding UTF8
''
Write-Host "per-reference CSV: $Csv"

if ($Baseline -ge 0) {
    if ($missing.Count -gt $Baseline) {
        throw "MISSING references rose to $($missing.Count), above the baseline of $Baseline. Something new points at a record Enderal does not have."
    }
    Write-Host "baseline OK: $($missing.Count) <= $Baseline"
}
