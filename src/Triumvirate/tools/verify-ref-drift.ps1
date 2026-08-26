#requires -Version 5.1
<#
.SYNOPSIS
  Finds Triumvirate references whose FormID SURVIVED into Enderal but now points at a DIFFERENT
  record than Bethesda had there.

.DESCRIPTION
  This is the nastier half of the WD-9 sweep, and the half no dangling-reference check can see.

  A dead reference is inert: the engine resolves nothing and the effect simply does not happen.
  A reference that resolves to the WRONG record is a live bug - the effect fires on something
  unrelated. CLAUDE.md's worked example is Biggie Traits, whose Amulet-of-the-Divines OR-group had
  eight dead FormIDs and one, 0C891B, that resolved to an Enderal unique weapon; equipping that
  weapon fired effects meant for a Divine amulet.

  Enderal's Skyrim.esm is base Enderal wearing Bethesda's filename, so EVERY :Skyrim.esm reference
  in a ported mod is a candidate. This script compares, per FormID:

      what Bethesda had        reference/base/SkyrimReal, UpdateReal
      what Enderal has         reference/base/Skyrim,     Update

  and classifies the difference:

    MATCH        same EditorID           - Enderal kept Bethesda's record. Safe.
    RENAMED      same record type, EditorID differs only by an Enderal prefix/suffix
                 (_00E_, _NNE_, _0nE_, a Skyrim suffix) - almost always the same thing, renamed.
    DRIFTED      same record type, unrelated EditorID - READ IT. This is the Biggie Traits class.
    RETYPED      different record type entirely - certainly wrong, and the loudest signal.

  Only MATCH is safe without reading the record. Everything else is a verdict for the audit.

.PARAMETER Csv
  The per-reference CSV from verify-missing-refs.ps1.
  Default: <repo>/build/dist/triumvirate-refs.csv

.PARAMETER Out
  Where to write the drift CSV. Default: <repo>/build/dist/triumvirate-ref-drift.csv
#>
[CmdletBinding()]
param(
    [string]$Csv,
    [string]$OutCsv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$base = Join-Path $repo 'reference\base'
if (-not $Csv)    { $Csv    = Join-Path $repo 'build\dist\triumvirate-refs.csv' }
if (-not $OutCsv) { $OutCsv = Join-Path $repo 'build\dist\triumvirate-ref-drift.csv' }
if (-not (Test-Path $Csv)) { throw "Reference CSV not found: $Csv. Run verify-missing-refs.ps1 first." }

# vanilla tree -> Enderal tree, for the masters Enderal actually replaced.
$pairs = @(
    @{ Master = 'Skyrim.esm'; Vanilla = 'SkyrimReal'; Enderal = 'Skyrim' },
    @{ Master = 'Update.esm'; Vanilla = 'UpdateReal'; Enderal = 'Update' }
)

function Get-Identities {
    param([string]$Root)
    $map = @{}
    if (-not (Test-Path $Root)) { throw "tree not found: $Root" }
    Get-ChildItem -LiteralPath $Root -Recurse -File -Filter *.yaml | ForEach-Object {
        $rel   = $_.FullName.Substring($Root.Length + 1)
        $group = ($rel -split '\\')[0]
        if ($_.Name -eq 'RecordData.yaml') {
            $text = [IO.File]::ReadAllText($_.FullName)
            if ($text -match '(?m)^FormKey: ([0-9A-F]{6}):([^\r\n]+?)\s*(?=\r?$)') {
                $k = $Matches[1] + ':' + $Matches[2]
                $eid = ''
                if ($text -match '(?m)^EditorID: (.+?)\s*(?=\r?$)') { $eid = $Matches[1] }
                $map[$k] = @{ Group = $group; EditorID = $eid }
            }
        } elseif ($_.BaseName -match ' - ([0-9A-F]{6})_(.+)$') {
            $map[($Matches[1] + ':' + $Matches[2])] = @{ Group = $group; EditorID = ($_.BaseName -split ' - ')[0] }
        } elseif ($_.BaseName -match '^([0-9A-F]{6})_(.+)$') {
            $map[($Matches[1] + ':' + $Matches[2])] = @{ Group = $group; EditorID = '' }
        }
    }
    $map
}

# Strip the affixes Enderal uses when it keeps a vanilla record but renames it.
function Get-Core([string]$s) {
    if (-not $s) { return '' }
    $t = $s -replace '^_[0-9A-Za-z]{2,3}E_', ''      # _00E_, _NNE_, _03E_, _10E_ ...
    $t = $t -replace 'Skyrim$', ''                    # NordRaceSkyrim -> NordRace
    $t.ToLowerInvariant()
}

$rows = Import-Csv -LiteralPath $Csv
$present = @($rows | Where-Object { $_.State -eq 'PRESENT' })

$results = New-Object System.Collections.ArrayList
foreach ($pair in $pairs) {
    $targets = @($present | Where-Object { $_.Target -like ('*:' + $pair.Master) } |
                 Select-Object -ExpandProperty Target -Unique)
    if (-not $targets) { continue }

    Write-Host ("indexing {0} vs {1} ..." -f $pair.Vanilla, $pair.Enderal)
    $van = Get-Identities (Join-Path $base $pair.Vanilla)
    $end = Get-Identities (Join-Path $base $pair.Enderal)
    Write-Host ("  vanilla={0} enderal={1}  targets to compare={2}" -f $van.Count, $end.Count, $targets.Count)

    foreach ($t in $targets) {
        # Only top-level records carry an EditorID we can compare; placed refs are handled by
        # verify-missing-refs.ps1's <nested> bucket and are reported separately below.
        $hasV = $van.ContainsKey($t); $hasE = $end.ContainsKey($t)
        if (-not $hasV -and -not $hasE) { continue }

        $vg = if ($hasV) { $van[$t].Group }    else { '<absent>' }
        $ve = if ($hasV) { $van[$t].EditorID } else { '' }
        $eg = if ($hasE) { $end[$t].Group }    else { '<placed-or-nested>' }
        $ee = if ($hasE) { $end[$t].EditorID } else { '' }

        $state =
            if (-not $hasV)                     { 'INJECTED' }       # Enderal has it, Bethesda never did
            elseif (-not $hasE)                 { 'NESTED' }          # resolves only as a placed ref
            elseif ($ve -and $ee -and $ve -eq $ee)          { 'MATCH' }
            elseif ($vg -ne $eg)                            { 'RETYPED' }
            elseif ((Get-Core $ve) -eq (Get-Core $ee))      { 'RENAMED' }
            else                                            { 'DRIFTED' }

        $users = @($present | Where-Object Target -eq $t)
        [void]$results.Add([pscustomobject]@{
            State           = $state
            Target          = $t
            VanillaGroup    = $vg
            VanillaEditorID = $ve
            EnderalGroup    = $eg
            EnderalEditorID = $ee
            Occurrences     = $users.Count
            Fields          = ((@($users | Select-Object -ExpandProperty Field -Unique) | Select-Object -First 4) -join '; ')
            Owners          = ((@($users | Select-Object -ExpandProperty Owner -Unique) | Select-Object -First 4) -join '; ')
        })
    }
}

$dir = Split-Path -Parent $OutCsv
if (-not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Force -Path $dir }
$results | Export-Csv -LiteralPath $OutCsv -NoTypeInformation -Encoding UTF8

''
'--- reference drift ---'
foreach ($s in 'RETYPED', 'DRIFTED', 'RENAMED', 'INJECTED', 'NESTED', 'MATCH') {
    $n = @($results | Where-Object State -eq $s)
    $occ = 0
    if ($n.Count -gt 0) { $occ = ($n | Measure-Object Occurrences -Sum).Sum }
    "{0,-10} {1,-5} FormKeys, {2} occurrences" -f $s, $n.Count, $occ
}
''
'--- RETYPED: a different record TYPE than Bethesda had. Certainly wrong. ---'
$bad = @($results | Where-Object State -eq 'RETYPED' | Sort-Object { [int]$_.Occurrences } -Descending)
if (-not $bad) { '   none' }
$bad | ForEach-Object {
    "  {0}  {1}/{2}  ->  {3}/{4}   ({5} occ; {6})" -f $_.Target, $_.VanillaGroup, $_.VanillaEditorID, $_.EnderalGroup, $_.EnderalEditorID, $_.Occurrences, $_.Fields
}
''
'--- DRIFTED: same type, unrelated record. READ EACH ONE. ---'
$drift = @($results | Where-Object State -eq 'DRIFTED' | Sort-Object { [int]$_.Occurrences } -Descending)
if (-not $drift) { '   none' }
$drift | ForEach-Object {
    "  {0}  {1}  ->  {2}   ({3} occ; {4})" -f $_.Target, $_.VanillaEditorID, $_.EnderalEditorID, $_.Occurrences, $_.Fields
}
''
Write-Host "drift CSV: $OutCsv"
