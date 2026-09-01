#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Prove every tome is actually BUYABLE, by reading the fields that decide whether a list yields -
# not merely by walking Reference: links.
#
# WHY THIS EXISTS. Triumvirate shipped a distribution whose structural walk reported a confident
# "75/75 tomes at >=3 vendors" on a mod that could sell 30: 45 of its tier bundles carried a
# `Global:`, and **when a leveled list names a Global, that global's value IS the chance-none
# percentage** - the ChanceNone byte beside it is ignored. All 15 vanilla skill globals sit at 100
# in Enderal and nothing ever lowers them. A missing-reference audit cannot see this, because the
# global resolves perfectly well; it just never changes.
#
# So this script checks four things, in the order they can fail:
#
#   1. Each hook we override is `UseAll` with NO ChanceNone and NO Global. UseAll is what makes a
#      merchant carry every entry rather than one per draw, and either gate would silence the lot.
#   2. Each hook is still listed in its merchant's CHEST - in base Enderal and in **every mod in
#      reference/mods/ that overrides that chest**. A hook nobody's chest contains is inert, and
#      this is exactly where a late-loading overhaul could quietly cut us out.
#   3. Every entry resolves to a Book in our own tree.
#   4. The 163 distributed tomes are covered exactly once each (12 summons are withheld pending in-game testing; see 00-cut-summons.ps1).

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$tree = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$mods = Join-Path $repo 'reference\mods'

function Read-Text { param([string]$Path) [IO.File]::ReadAllText($Path) }

# ---------------------------------------------------------------- 1. the hooks themselves
$hooks = @(Get-ChildItem (Join-Path $tree 'LeveledItems') -Filter '*CustomMerchandise*.yaml' -File)
if ($hooks.Count -eq 0) { throw 'no CustomMerchandise hooks in the tree - run 07-place-vendor-tomes.ps1' }

$books = @{}
foreach ($f in Get-ChildItem (Join-Path $tree 'Books') -Filter '*.yaml' -File) {
    $t = Read-Text $f.FullName
    $fk = [regex]::Match($t, '(?m)^FormKey: (.+?)\s*\r?\n').Groups[1].Value
    $books[$fk] = [pscustomobject]@{
        EditorID = [regex]::Match($t, '(?m)^EditorID: (.+?)\s*\r?\n').Groups[1].Value
        Value    = [regex]::Match($t, '(?m)^Value: (\d+)').Groups[1].Value
    }
}

$seen = @{}
$rows = @()
foreach ($h in $hooks) {
    $t   = Read-Text $h.FullName
    $eid = [regex]::Match($t, '(?m)^EditorID: (.+?)\s*\r?\n').Groups[1].Value
    $fk  = [regex]::Match($t, '(?m)^FormKey: (.+?)\s*\r?\n').Groups[1].Value

    if ($t -notmatch '(?m)^- UseAll(?=\r?$)')  { throw "$eid is not UseAll - a merchant would carry one entry per draw, not the line" }
    if ($t -match  '(?m)^ChanceNone:')         { throw "$eid carries ChanceNone - it can yield nothing" }
    if ($t -match  '(?m)^Global:')             { throw "$eid carries a Global - its VALUE is the chance-none percentage and overrides ChanceNone" }

    $refs = @([regex]::Matches($t, '(?m)^    Reference: (.+?)\s*\r?$') | ForEach-Object { $_.Groups[1].Value })
    if ($refs.Count -eq 0) { throw "$eid has no entries" }

    foreach ($r in $refs) {
        if (-not $books.ContainsKey($r)) { throw "$eid entry $r is not a Book in our tree" }
        if ($seen.ContainsKey($r))       { throw "$($books[$r].EditorID) stocked twice: $($seen[$r]) and $eid" }
        $seen[$r] = $eid
    }

    # ------------------------------------------------- 2. is the hook in anyone's chest?
    $short  = $fk -replace ':.*', ''
    $inBase = @()
    foreach ($tree2 in @('Skyrim', 'EnderalFS')) {
        $d = Join-Path $repo "reference\base\$tree2\Containers"
        if (-not (Test-Path -LiteralPath $d)) { continue }
        foreach ($c in Get-ChildItem $d -Filter '*.yaml' -File) {
            if ((Read-Text $c.FullName) -match "(?m)^    Item: $short\:") { $inBase += "$tree2/$(($c.Name -split ' - ')[0])" }
        }
    }
    if ($inBase.Count -eq 0) { throw "$eid is in no merchant chest at all - nothing would ever draw from it" }

    # every third-party override of that chest must ALSO still carry the hook
    $chest   = ($inBase[-1] -split '/')[-1]
    $dropped = @()
    $kept    = @()
    foreach ($m in Get-ChildItem $mods -Directory) {
        # Skip an ingest of our OWN plugin - reference/mods/Apocalypse is the previously shipped
        # conversion re-serialized, so counting it would report us conflicting with ourselves.
        $meta = @(Get-ChildItem $m.FullName -Recurse -Filter 'spriggit-meta.json' -File -ErrorAction SilentlyContinue)
        if ($meta.Count -gt 0 -and (Read-Text $meta[0].FullName) -match 'Apocalypse - Magic of Skyrim\.esp') { continue }
        foreach ($c in Get-ChildItem $m.FullName -Recurse -Filter "$chest - *.yaml" -File -ErrorAction SilentlyContinue) {
            if ($c.FullName -notmatch '\\Containers\\') { continue }
            if ((Read-Text $c.FullName) -match "(?m)^    Item: $short\:") { $kept += $m.Name } else { $dropped += $m.Name }
        }
    }
    if ($dropped.Count -gt 0) {
        throw ("{0}: {1} override(s) of {2} DROP the hook - our stock would be invisible under them: {3}" -f
            $eid, $dropped.Count, $chest, ($dropped -join ', '))
    }

    $rows += [pscustomobject]@{
        Hook    = $eid
        Chest   = $chest
        Tomes   = $refs.Count
        Priced  = @($refs | Where-Object { $books[$_].Value -and [int]$books[$_].Value -gt 0 }).Count
        AlsoOvr = $(if ($kept.Count) { ($kept | Sort-Object -Unique) -join ', ' } else { '-' })
    }
}

$rows | Format-Table -AutoSize | Out-String | Write-Host

# ---------------------------------------------------------------- 4. coverage
$total = $seen.Keys.Count
if ($total -ne 163) { throw "$total tomes stocked, expected 163" }
$unpriced = @($seen.Keys | Where-Object { -not $books[$_].Value -or [int]$books[$_].Value -le 0 })
if ($unpriced.Count -gt 0) { throw "$($unpriced.Count) tome(s) have no gold value - a merchant cannot sell them" }

# ---------------------------------------------------------------- 5. zero container overrides
$owned = @(Get-ChildItem (Join-Path $tree 'Containers') -Filter '*.yaml' -File -ErrorAction SilentlyContinue |
    Where-Object { (Read-Text $_.FullName) -notmatch '(?m)^FormKey: [0-9A-F]{6}:Apocalypse - Magic of Skyrim\.esp' })
if ($owned.Count -gt 0) { throw "overriding $($owned.Count) container(s) of a master - the hooks exist to avoid that" }

"proof: $total/163 tomes stocked across $($hooks.Count) UseAll hooks, each exactly once, all priced"
"       every hook is carried by its chest in base Enderal AND in every reference/mods override of it"
"       0 container records of any master overridden"
