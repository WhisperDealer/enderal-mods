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
#   4. Our OWN merchant - the Riverville Shrouded Mage (18-shrouded-mage-riverville.ps1) - is wired
#      end to end: a Vendor faction whose MerchantContainer is a ref placed in our tree, whose base is
#      our container, which the NPC carrying that faction stands in the same cell as.
#   5. 116 of the 163 distributed tomes are stocked exactly once each: 100 in hooks, 16 in our own
#      chest. The 47 Master tomes (all five schools) are loot-only by design
#      (07's $PENDING) - base Enderal sells its own Master tier only at random, from level 30.
#      12 summons are withheld entirely (00-cut-summons.ps1).
#   7. No hook we write is also written by Triumvirate (src/Triumvirate). Two plugins writing one
#      LeveledItem is an override conflict - the later one's stock silently replaces the other's.
#   6. Entropy (C) and Psionics (I) - forbidden schools in Enderal - are sold ONLY by the four
#      Shrouded Mages, and the Shrouded Mages sell nothing else of ours.

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
            if ((Read-Text $c.FullName) -match "(?m)^    Item: $short\:") { $inBase += "$tree2/$(($c.Name -split ' - ')[0])"; $chestKey = [regex]::Match($c.Name, ' - ([0-9A-F]{6}_.+)$').Groups[1].Value }
        }
    }
    if ($inBase.Count -eq 0) { throw "$eid is in no merchant chest at all - nothing would ever draw from it" }

    # every third-party override of that chest must ALSO still carry the hook. Matched by FormKey
    # (the file-name suffix), not EditorID: EGO renames the Shrouded Mage chests.
    $chest   = ($inBase[-1] -split '/')[-1]
    $dropped = @()
    $kept    = @()
    foreach ($m in Get-ChildItem $mods -Directory) {
        # Skip an ingest of our OWN plugin - reference/mods/Apocalypse is the previously shipped
        # conversion re-serialized, so counting it would report us conflicting with ourselves.
        $meta = @(Get-ChildItem $m.FullName -Recurse -Filter 'spriggit-meta.json' -File -ErrorAction SilentlyContinue)
        if ($meta.Count -gt 0 -and (Read-Text $meta[0].FullName) -match 'Apocalypse - Magic of Skyrim\.esp') { continue }
        foreach ($c in Get-ChildItem $m.FullName -Recurse -Filter "* - $chestKey" -File -ErrorAction SilentlyContinue) {
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

# ---------------------------------------------------------------- 4. our own merchants
$apoc = 'Apocalypse - Magic of Skyrim.esp'
$ownVendors = @(Get-ChildItem (Join-Path $tree 'Factions') -Filter "ZP_Apoc_*_$apoc.yaml" -File |   # ours, not Enai's (his Kyrgar is a vendor too)
    Where-Object { (Read-Text $_.FullName) -match '(?m)^- Vendor\s*$' })
if ($ownVendors.Count -ne 1) { throw "expected 1 vendor faction of our own (the Riverville Shrouded Mage), found $($ownVendors.Count)" }
$cellText = @{}
foreach ($c in Get-ChildItem (Join-Path $tree 'Cells') -Recurse -Filter 'RecordData.yaml' -File) { $cellText[$c.FullName] = Read-Text $c.FullName }
foreach ($vf in $ownVendors) {
    $t   = Read-Text $vf.FullName
    $eid = [regex]::Match($t, '(?m)^EditorID: (.+?)\s*\r?\n').Groups[1].Value
    $ffk = [regex]::Match($t, '(?m)^FormKey: (.+?)\s*\r?\n').Groups[1].Value
    $cref = [regex]::Match($t, '(?m)^MerchantContainer: (.+?)\s*\r?$').Groups[1].Value
    $loc  = [regex]::Match($t, '(?m)^    Link: (.+?)\s*\r?$').Groups[1].Value
    if (-not $cref) { throw "$eid has no MerchantContainer" }
    # the chest ref, and the cell it is placed in
    $hit = @($cellText.Keys | Where-Object { $cellText[$_] -match "(?m)^  FormKey: $([regex]::Escape($cref))\s*\r?$" })
    if ($hit.Count -ne 1) { throw "$eid's chest ref $cref is placed in $($hit.Count) cells of our tree" }
    $ct = $cellText[$hit[0]]
    $cellFk = [regex]::Match($ct, '(?m)^FormKey: (.+?)\s*\r?$').Groups[1].Value
    if ($cellFk -ne $loc) { throw "$($eid): VendorLocation $loc is not the cell its chest is in ($cellFk)" }
    $blk = [regex]::Match($ct, "(?ms)^  FormKey: $([regex]::Escape($cref))\s*\r?\n(.*?)(?=^- MutagenObjectType: |\z)").Groups[1].Value
    $base = [regex]::Match($blk, '(?m)^  Base: (.+?)\s*\r?$').Groups[1].Value
    $cf = @(Get-ChildItem (Join-Path $tree 'Containers') -Filter "* - $($base -replace ':.*','')_$apoc.yaml" -File)
    if ($cf.Count -ne 1) { throw "$eid's chest ref $cref has base $base, which is not a container of ours" }
    # an NPC of ours carrying this faction must stand in the same cell
    $npcs = @(Get-ChildItem (Join-Path $tree 'Npcs') -Filter "*_$apoc.yaml" -File |
        Where-Object { (Read-Text $_.FullName) -match "(?m)^- Faction: $([regex]::Escape($ffk))\s*\r?$" })
    if ($npcs.Count -ne 1) { throw "$eid is carried by $($npcs.Count) NPCs of ours, expected 1" }
    $nfk = [regex]::Match((Read-Text $npcs[0].FullName), '(?m)^FormKey: (.+?)\s*\r?$').Groups[1].Value
    if ($ct -notmatch "(?m)^  Base: $([regex]::Escape($nfk))\s*\r?$") { throw "$eid's NPC $nfk is not placed in the chest's cell" }
    $ctext = Read-Text $cf[0].FullName
    $crefs = @([regex]::Matches($ctext, '(?m)^    Item: (.+?)\s*\r?$') | ForEach-Object { $_.Groups[1].Value } |
        Where-Object { $books.ContainsKey($_) })
    foreach ($r in $crefs) {
        if ($seen.ContainsKey($r)) { throw "$($books[$r].EditorID) stocked twice: $($seen[$r]) and $eid" }
        $seen[$r] = $eid
    }
    $rows += [pscustomobject]@{ Hook = "$eid (own chest)"; Chest = ($cf[0].Name -split ' - ')[0]; Tomes = $crefs.Count
        Priced = @($crefs | Where-Object { $books[$_].Value -and [int]$books[$_].Value -gt 0 }).Count; AlsoOvr = '-' }
}

$rows | Format-Table -AutoSize | Out-String | Write-Host

# ---------------------------------------------------------------- 5. coverage
$total = $seen.Keys.Count
if ($total -ne 116) { throw "$total tomes stocked, expected 116 (100 in hooks + 16 at the Riverville Shrouded Mage)" }

# ---------------------------------------------------------------- 7. no hook shared with Triumvirate
$tvr = Join-Path $repo 'src\Triumvirate\TriumvirateESP\LeveledItems'
if (Test-Path -LiteralPath $tvr) {
    $theirs = @(Get-ChildItem $tvr -Filter '*_CustomMerchandise - *.yaml' -File | ForEach-Object Name)
    $shared = @($hooks | Where-Object { $theirs -contains $_.Name } | ForEach-Object { $_.Name -replace ' - .*', '' })
    if ($shared.Count -gt 0) { throw "hook(s) also written by Triumvirate - one mod's stock would vanish: $($shared -join ', ')" }
}

# ---------------------------------------------------------------- 6. forbidden schools stay off respectable shelves
$shady = @('Wildmage_Undercity_CustomMerchandise', 'Wildmage_FrostcliffTavern_CustomMerchandise', 'Wildmage_Duneville_CustomMerchandise') + @($ownVendors | ForEach-Object { [regex]::Match((Read-Text $_.FullName), '(?m)^EditorID: (.+?)\s*\r?\n').Groups[1].Value })
foreach ($r in $seen.Keys) {
    if ($books[$r].EditorID -match '^WB_[CI]' -and $shady -notcontains $seen[$r]) {
        throw "$($books[$r].EditorID) is a forbidden-school tome sold by $($seen[$r])"
    }
    if ($books[$r].EditorID -notmatch '^WB_[CI]' -and $shady -contains $seen[$r]) {
        throw "$($books[$r].EditorID) is not Entropy/Psionics but is sold by Shrouded Mage $($seen[$r])"
    }
}
$unpriced = @($seen.Keys | Where-Object { -not $books[$_].Value -or [int]$books[$_].Value -le 0 })
if ($unpriced.Count -gt 0) { throw "$($unpriced.Count) tome(s) have no gold value - a merchant cannot sell them" }

# ---------------------------------------------------------------- 5. zero container overrides
$owned = @(Get-ChildItem (Join-Path $tree 'Containers') -Filter '*.yaml' -File -ErrorAction SilentlyContinue |
    Where-Object { (Read-Text $_.FullName) -notmatch '(?m)^FormKey: [0-9A-F]{6}:Apocalypse - Magic of Skyrim\.esp' })
if ($owned.Count -gt 0) { throw "overriding $($owned.Count) container(s) of a master - the hooks exist to avoid that" }

"proof: $total tomes stocked exactly once, all priced: $($hooks.Count) UseAll hooks + $($ownVendors.Count) merchant chest of our own"
"       Entropy/Psionics only at the four Shrouded Mages, and nothing else there"
"       no hook shared with Triumvirate"
"       every hook is carried by its chest in base Enderal AND in every reference/mods override of it"
"       0 container records of any master overridden"
