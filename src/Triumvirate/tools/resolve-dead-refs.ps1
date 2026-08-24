#requires -Version 5.1
<#
.SYNOPSIS
  Says what each of Triumvirate's dead references was MEANT to be, by resolving it against the
  real Bethesda masters instead of Enderal's replacements.

.DESCRIPTION
  `verify-missing-refs.ps1` answers "which references does Enderal not have?" and gives you 702
  bare FormKeys. That is not enough to choose a verdict: you cannot decide whether a dead
  reference needs an Enderal substitute, a deletion, or nothing at all without knowing what
  Bethesda's record at that FormID actually was.

  So this resolves every MISSING reference against the REAL vanilla masters, serialized into
  reference/base/*Real by /spriggit-decompile-reference:

    reference/base/SkyrimReal       real Skyrim.esm       (NOT Enderal's replacement)
    reference/base/UpdateReal       real Update.esm
    reference/base/DawnguardReal    real Dawnguard.esm    (NOT the 44 KB stub)
    reference/base/HearthFiresReal  real HearthFires.esm  (NOT the 80-byte stub)
    reference/base/DragonbornReal   real Dragonborn.esm   (NOT the 44 KB stub)

  Output is one row per distinct dead FormKey: what Bethesda had there, which Triumvirate records
  point at it, and through which field. That table is what the WD-9 verdicts get written against.

  Note the asymmetry this exposes. A reference into a DLC is dead because Enderal ships stubs, so
  the vanilla record always exists and always tells you what was intended. A reference into
  Skyrim.esm is dead because Enderal REPLACED that file, so the vanilla record tells you what Enai
  meant and Enderal's own tree has to supply the substitute - see verify-missing-refs.ps1 for the
  reverse direction, where a FormID survived as a DIFFERENT record.

.PARAMETER Csv
  The per-reference CSV from verify-missing-refs.ps1.
  Default: <repo>/build/dist/triumvirate-refs.csv

.PARAMETER Out
  Where to write the resolved CSV. Default: <repo>/build/dist/triumvirate-dead-refs.csv
#>
[CmdletBinding()]
param(
    [string]$Csv,
    [string]$Out
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$base = Join-Path $repo 'reference\base'
if (-not $Csv) { $Csv = Join-Path $repo 'build\dist\triumvirate-refs.csv' }
if (-not $Out) { $Out = Join-Path $repo 'build\dist\triumvirate-dead-refs.csv' }
if (-not (Test-Path $Csv)) { throw "Reference CSV not found: $Csv. Run verify-missing-refs.ps1 first." }

# Real master tree -> the master filename its records carry.
$realTrees = [ordered]@{
    'SkyrimReal'      = 'Skyrim.esm'
    'UpdateReal'      = 'Update.esm'
    'DawnguardReal'   = 'Dawnguard.esm'
    'HearthFiresReal' = 'HearthFires.esm'
    'DragonbornReal'  = 'Dragonborn.esm'
}

$identity = @{}

function Add-RealTree {
    param([string]$Root)
    if (-not (Test-Path $Root)) { return 0 }
    $n = 0
    Get-ChildItem -LiteralPath $Root -Recurse -File -Filter *.yaml | ForEach-Object {
        $rel   = $_.FullName.Substring($Root.Length + 1)
        $group = ($rel -split '\\')[0]
        $key = $null; $eid = ''
        if ($_.Name -eq 'RecordData.yaml') {
            $text = [IO.File]::ReadAllText($_.FullName)
            if ($text -match '(?m)^FormKey: ([0-9A-F]{6}):([^\r\n]+?)\s*(?=\r?$)') { $key = $Matches[1] + ':' + $Matches[2] }
            if ($text -match '(?m)^EditorID: (.+?)\s*(?=\r?$)') { $eid = $Matches[1] }
            # A cell/worldspace file also DEFINES its placed refs; index those too, without an EditorID.
            foreach ($m in [regex]::Matches($text, '(?m)^\s+-?\s*FormKey: ([0-9A-F]{6}):([^\r\n]+?)\s*(?=\r?$)')) {
                $nested = $m.Groups[1].Value + ':' + $m.Groups[2].Value
                if (-not $identity.ContainsKey($nested)) { $identity[$nested] = @{ Group = "$group (placed)"; EditorID = '' }; $n++ }
            }
        } elseif ($_.BaseName -match ' - ([0-9A-F]{6})_(.+)$') {
            $key = $Matches[1] + ':' + $Matches[2]
            $eid = ($_.BaseName -split ' - ')[0]
        } elseif ($_.BaseName -match '^([0-9A-F]{6})_(.+)$') {
            $key = $Matches[1] + ':' + $Matches[2]
        }
        if ($key) { $identity[$key] = @{ Group = $group; EditorID = $eid }; $n++ }
    }
    $n
}

Write-Host 'indexing REAL Bethesda masters...'
$havePlain = @()
foreach ($tree in $realTrees.Keys) {
    $root = Join-Path $base $tree
    if (-not (Test-Path $root)) {
        Write-Warning ("  {0,-18} ABSENT - serialize it with /spriggit-decompile-reference, or its references stay unresolved" -f $tree)
        continue
    }
    $added = Add-RealTree -Root $root
    $havePlain += $realTrees[$tree]
    Write-Host ("  {0,-18} +{1} records" -f $tree, $added)
}
if (-not $havePlain) { throw 'No real master trees found under reference/base/*Real.' }

# ---------------------------------------------------------------- resolve
$rows = Import-Csv -LiteralPath $Csv
$missing = @($rows | Where-Object State -eq 'MISSING')
Write-Host "dead references to resolve: $($missing.Count)"

$resolved = New-Object System.Collections.ArrayList
foreach ($g in ($missing | Group-Object Target | Sort-Object Name)) {
    $target = $g.Name
    $master = ($target -split ':')[1]
    $vanGroup = ''; $vanEid = ''; $verdictHint = ''

    if ($identity.ContainsKey($target)) {
        $vanGroup = $identity[$target].Group
        $vanEid   = $identity[$target].EditorID
    } elseif ($havePlain -notcontains $master) {
        $vanGroup = '<tree not serialized>'
    } else {
        $vanGroup = '<not in vanilla either>'
        $verdictHint = 'never existed - suspect a typo or a cut record'
    }

    $owners = @($g.Group | Select-Object -ExpandProperty Owner -Unique)
    $fields = @($g.Group | Select-Object -ExpandProperty Field -Unique)

    [void]$resolved.Add([pscustomobject]@{
        Target         = $target
        Master         = $master
        VanillaGroup   = $vanGroup
        VanillaEditorID= $vanEid
        Occurrences    = $g.Count
        OwnerCount     = $owners.Count
        Fields         = ($fields -join '; ')
        Owners         = (($owners | Select-Object -First 6) -join '; ')
        Hint           = $verdictHint
    })
}

$outDir = Split-Path -Parent $Out
if (-not (Test-Path $outDir)) { $null = New-Item -ItemType Directory -Force -Path $outDir }
$resolved | Export-Csv -LiteralPath $Out -NoTypeInformation -Encoding UTF8

''
"distinct dead FormKeys: $($resolved.Count)"
''
'--- resolved, by vanilla record type ---'
$resolved | Group-Object VanillaGroup | Sort-Object Count -Descending | ForEach-Object {
    "{0,-28} {1,-5} keys, {2} occurrences" -f $_.Name, $_.Count, (($_.Group | Measure-Object Occurrences -Sum).Sum)
}
''
'--- unresolved (nothing in vanilla either) ---'
$orphan = @($resolved | Where-Object VanillaGroup -eq '<not in vanilla either>')
if ($orphan.Count -eq 0) { '   none - every dead reference resolves in a real Bethesda master' }
else { $orphan | ForEach-Object { "   {0}  ({1} occ, {2})" -f $_.Target, $_.Occurrences, $_.Fields } }
''
Write-Host "resolved CSV: $Out"
