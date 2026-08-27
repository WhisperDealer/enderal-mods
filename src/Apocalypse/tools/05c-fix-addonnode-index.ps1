#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Move WB_IllusionNightmare_MPS_Seidsigil off an AddonNode index Enderal already uses.
#
# An `ADDN` record's NodeIndex is a GLOBAL slot, not a per-plugin one: two records sharing an index
# means whichever loads last owns the visual, and Apocalypse loads after Enderal. Enai's Nightmare
# ground sigil sits at **110**, which in Enderal is `_00E_MPSWildWaveFlames` - so shipping it as-is
# replaces one of Enderal's own effects with Apocalypse's mesh. We resolve it in ENDERAL's favour,
# which leaves Apocalypse's mesh looking for a node that has moved (a known, documented limitation)
# rather than breaking a base-game visual.
#
# For 10.2.3 this was a hand-edited committed record, called out in tools/README.md as "not a
# script". Regenerating against 10.3.0 silently reverted it to 110 - the edit was in the tree, and
# the tree is what gets wiped. `verify-addonnode-indices.ps1` still reported the collision
# afterwards, which is the only reason it was caught. It is a script now.

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$tree = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$enc  = New-Object System.Text.UTF8Encoding($false)

$target = 'WB_IllusionNightmare_MPS_Seidsigil'
$from   = 110
$to     = 746

$file = @(Get-ChildItem (Join-Path $tree 'AddonNodes') -Filter "$target - *.yaml" -File)
if ($file.Count -ne 1) { throw "expected exactly one $target record, found $($file.Count)" }

# Prove the destination is genuinely free, in Enderal and in our own tree, before moving into it.
$used = @{}
foreach ($src in @('reference\base\Skyrim\AddonNodes', 'reference\base\EnderalFS\AddonNodes',
                   'reference\base\Update\AddonNodes', 'src\Apocalypse\ApocalypseESP\AddonNodes')) {
    $dir = Join-Path $repo $src
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    foreach ($f in Get-ChildItem $dir -Filter '*.yaml' -File) {
        $m = [regex]::Match([IO.File]::ReadAllText($f.FullName), '(?m)^NodeIndex: (\d+)')
        if ($m.Success) {
            $idx = [int]$m.Groups[1].Value
            if (-not $used.ContainsKey($idx)) { $used[$idx] = @() }
            $used[$idx] += ($f.Name -replace ' - .*', '')
        }
    }
}

$text = [IO.File]::ReadAllText($file[0].FullName)
$cur  = [regex]::Match($text, '(?m)^NodeIndex: (\d+)')
if (-not $cur.Success) { throw "$target has no NodeIndex" }
$curIdx = [int]$cur.Groups[1].Value

if ($curIdx -eq $to) {
    "already at $to - nothing to do"
    return
}
if ($curIdx -ne $from) {
    throw "$target is at index $curIdx, expected $from - upstream moved it, re-check the collision before editing"
}
# ContainsKey first: piping a $null through Where-Object yields ONE element (because
# `$null -ne 'name'` is true), so an absent key reads as "occupied by an unnamed record".
$holders = @()
if ($used.ContainsKey($to)) { $holders = @($used[$to] | Where-Object { $_ -ne $target }) }
if ($holders.Count -gt 0) {
    throw "index $to is no longer free - held by $($holders -join ', '). Pick another and update this script"
}
if (-not $used.ContainsKey($from) -or @($used[$from] | Where-Object { $_ -ne $target }).Count -eq 0) {
    throw "index $from no longer collides with anything - the re-index may be unnecessary now, re-check before keeping it"
}

$collidesWith = @($used[$from] | Where-Object { $_ -ne $target })
[IO.File]::WriteAllText($file[0].FullName, ($text -replace '(?m)^NodeIndex: \d+', "NodeIndex: $to"), $enc)
"$target : NodeIndex $from -> $to  (freed for Enderal's $($collidesWith -join ', '))"
