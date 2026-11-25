# 17 - Ungate the high tiers, then hand Expert/Master to each archetype's one vendor (WD-16b).
#
# TWO defects, one pass.
#
# 1. THE 45 GATED TOMES. Enai's Adept/Expert/Master tier bundles carry vanilla Skyrim's
#    spell-tome gate: `ChanceNone: 1` plus `Global: PC<School><Tier>`. When a leveled list names
#    a Global, that global's value IS the chance-none percentage. In Enderal all 15 of those
#    globals read `Data: 100` - a 100% chance of nothing - and NOTHING ever lowers them: vanilla
#    zeroes them from `WISkillIncrease02`, a quest that exists in the real Skyrim.esm and not in
#    Enderal's, no Enderal script mentions them, and across Enderal's whole tree the only file
#    referencing 0F2584 is the global's own record. So 45 of the 75 tomes were unobtainable while
#    15-distribution.ps1's chain-walk proof happily reported "75/75 tomes at >=3 vendors" - it
#    resolves the chain STRUCTURALLY and never reads ChanceNone. Dropping the `Global:` line lets
#    the authored `ChanceNone: 1` stand (a 1% miss per restock, which is Enai's own value).
#
# 2. EXPERT/MASTER GO TO THE SAME ONE VENDOR. Distribution is one merchant per archetype line
#    ($script:TvrVendors in 00-common.ps1): Shadow -> Sister Envy, Warlock Entropy + Psionics ->
#    Aurora Leklerk, Warlock Elementalism -> Tarhutie, Druid + Shaman + Cleric -> Torius Flameling,
#    EXCEPT the Entropy/Psionics lines
#    in $script:TvrNonVendorLines, which no merchant sells (15 stashes them). 15 writes each
#    archetype's per-school parent bundles (Novice/Apprentice/Adept) into its vendor's hook; this
#    step cuts Expert/Master out of those parents and writes the 075/100 tier bundles into the SAME
#    hook directly. The end state is that each vendor sells its archetypes' whole line and nobody
#    else sells any of it.
#
#    History: this step used to confine Expert/Master to five Ark/Undercity merchants while Novice-
#    Adept sat at ten vendors across the map. That layout was retired for one-vendor-per-archetype;
#    the cut-and-place structure was kept because it still produces the right hooks and keeps the
#    parent bundles' shape (three common tiers) stable across the change.
#
# WHERE IT WRITES: the merchants' `*_CustomMerchandise` hooks, the same empty SureAI leveled lists
# 15-distribution.ps1 populates - NOT their chests. See that script's header for why.
#
# NAMING: `Wildmage` is the German EditorID. All three display in English as **"Shrouded Mage"**,
# and they are the only three NPCs in the game that do. CLAUDE.md's rule about Enderal's German
# EditorIDs vs its English display strings applies to NPCs too, not just cells.
#
# NO NEW RECORDS. The 075/100 tier bundles already exist and are already UseAll-with-one-entry,
# so they go into the hooks directly. Nothing is allocated, so the FormID block is untouched.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "17 - high-tier gating (WD-16b)"
$root = Get-EspRoot
$lvli = Join-Path $root 'LeveledItems'

$ARCHETYPES = @('Druid', 'Shadow', 'Warlock', 'Cleric', 'Shaman')
$HIGH = @('075', '100')          # Expert, Master - placed directly in the vendor hook
$COMMON = @('000', '025', '050') # Novice, Apprentice, Adept - unchanged vendors

# Expert/Master go to the same hook 15 stocked with the archetype's common tiers - one vendor per
# archetype, from the shared table in 00-common.ps1.
$highVendors = @($script:TvrVendors)
foreach ($a in $ARCHETYPES) { if (@($highVendors | Where-Object { $_.Archetypes -contains $a }).Count -eq 0) { throw "no vendor for archetype $a" } }
# Non-vendor lines (unhomed + stashed, 00-common.ps1) get no Expert/Master bundles at any hook, and a
# vendor with Lines gets only those (Test-VendorSellsLine, 00-common.ps1).

# ------------------------------------------------------------------ record lookups
$fkOf = @{}   # EditorID -> FormKey
$fileOf = @{} # EditorID -> path
foreach ($f in Get-ChildItem -LiteralPath $lvli -Filter 'TVR_Tomes_*.yaml') {
    $eid = ($f.Name -split ' - ')[0]
    $fk = [regex]::Match((Read-YamlText $f.FullName), '(?m)^FormKey: (.+?)(?=\r?$)').Groups[1].Value
    if (-not $fk) { throw "no FormKey in $($f.Name)" }
    $fkOf[$eid] = $fk
    $fileOf[$eid] = $f.FullName
}

# every archetype's three schools, read off the parent-bundle names rather than hardcoded
$schoolsOf = @{}
foreach ($a in $ARCHETYPES) {
    $s = @($fkOf.Keys | Where-Object { $_ -match ("^TVR_Tomes_Litem_" + $a + "_([A-Z][a-z]+)$") } |
           ForEach-Object { ($_ -split '_')[-1] } | Sort-Object)
    if ($s.Count -ne 3) { throw "$a has $($s.Count) schools, expected 3" }
    $schoolsOf[$a] = $s
}

function Get-TierBundleKey {
    param([string]$Arch, [string]$Tier, [string]$School)
    $eid = "TVR_Tomes_Litem_${Arch}_${Tier}_${School}"
    if (-not $fkOf.ContainsKey($eid)) { throw "missing tier bundle $eid" }
    return $fkOf[$eid]
}

# ------------------------------------------------------------------ 1. drop the dead gate
$ungated = 0
foreach ($a in $ARCHETYPES) {
    foreach ($t in @('050', '075', '100')) {
        foreach ($sc in $schoolsOf[$a]) {
            $path = $fileOf["TVR_Tomes_Litem_${a}_${t}_${sc}"]
            $lines = Get-YamlLines $path
            $keep = @($lines | Where-Object { $_ -notmatch '^Global: ' })
            if ($keep.Count -eq $lines.Count) { continue }
            if ($lines.Count - $keep.Count -ne 1) { throw "unexpected Global: count in $path" }
            Set-YamlLines -Path $path -Lines $keep
            $ungated++
        }
    }
}
if ($ungated -gt 0 -and $ungated -ne 45) { throw "expected to ungate 45 tier bundles, did $ungated" }
Write-Host "  1. skill-gate Global: dropped from $ungated tier bundles (Adept/Expert/Master)"

# nothing anywhere may still name one of the vanilla skill globals
$stillGated = @(Get-ChildItem -LiteralPath $lvli -Filter '*.yaml' |
    Where-Object { (Read-YamlText $_.FullName) -match '(?m)^Global: 0F25[0-9A-F]{2}:Skyrim\.esm' })
if ($stillGated.Count -gt 0) { throw "$($stillGated.Count) leveled items still carry a PC<School><Tier> gate" }

# ------------------------------------------------------------------ 2. cut Expert/Master out of the parent bundles
$trimmed = 0
foreach ($a in $ARCHETYPES) {
    foreach ($sc in $schoolsOf[$a]) {
        $parent = $fileOf["TVR_Tomes_Litem_${a}_${sc}"]
        foreach ($t in $HIGH) {
            $key = Get-TierBundleKey -Arch $a -Tier $t -School $sc
            $text = Read-YamlText $parent
            if ($text -notmatch [regex]::Escape($key)) { continue }
            $n = Remove-SequenceItemContaining -Path $parent -ContainsPattern ([regex]::Escape("Reference: $key"))
            if ($n -le 0) { throw "failed to trim $t from TVR_Tomes_Litem_${a}_${sc}" }
            $trimmed++
        }
        # whatever happened above, the parent must now be exactly the three common tiers - less any
        # withheld tier bundle, which 20-withhold-force-of-nature.ps1 cuts after this step has run
        $text = Read-YamlText $parent
        $refs = @([regex]::Matches($text, '(?m)^    Reference: (.+?)(?=\r?$)') | ForEach-Object { $_.Groups[1].Value })
        $commonKeys = @($COMMON | ForEach-Object { Get-TierBundleKey -Arch $a -Tier $_ -School $sc })
        $extra = @($refs | Where-Object { $commonKeys -notcontains $_ })
        if ($extra.Count -gt 0) { throw "TVR_Tomes_Litem_${a}_${sc} carries $($extra.Count) non-common entries" }
        foreach ($key in $commonKeys) {
            if ($refs -notcontains $key -and $script:TvrWithheldTierBundles -notcontains $key) { throw "TVR_Tomes_Litem_${a}_${sc} lost tier bundle $key" }
        }
    }
}
if ($trimmed -gt 0 -and $trimmed -ne 30) { throw "expected to trim 30 parent entries, did $trimmed" }
Write-Host "  2. Expert/Master cut from the 15 parent bundles: $trimmed entries (each now Novice/Apprentice/Adept)"

# ------------------------------------------------------------------ 3. place them with the archetype's vendor
function Add-LeveledEntries {
    param([string]$Path, [string[]]$FormKeys)
    $lines = @(Get-YamlLines $Path | Where-Object { $_.Trim() -ne '' })
    # NOT `$lines -notmatch ...`: against an ARRAY, -match/-notmatch are FILTERS returning the
    # matching/non-matching elements, so -notmatch yields every other line and is always truthy.
    if (-not ($lines -match '^Entries:\s*$')) { throw "no Entries: block in $Path - run 15-distribution.ps1 first" }
    $insert = @()
    foreach ($fk in $FormKeys) {
        $insert += '- Data:'
        $insert += '    Level: 1'
        $insert += "    Reference: $fk"
        $insert += '    Count: 1'
    }
    Set-YamlLines -Path $Path -Lines ($lines + $insert)
    return $FormKeys.Count
}

$placed = 0
foreach ($v in $highVendors) {
    $path = Join-Path $lvli $v.File
    if (-not (Test-Path -LiteralPath $path)) { throw "hook not found (run 15-distribution.ps1 first): $($v.File)" }
    $adds = @()
    foreach ($a in $v.Archetypes) {
        foreach ($t in $HIGH) {
            foreach ($sc in $schoolsOf[$a]) {
                if (-not (Test-VendorSellsLine -Vendor $v -Line "${a}_${sc}")) { continue }
                $adds += Get-TierBundleKey -Arch $a -Tier $t -School $sc
            }
        }
    }
    $text = Read-YamlText $path
    $missing = @($adds | Where-Object { $text -notmatch [regex]::Escape($_) })
    if ($missing.Count -eq 0) {
        Write-Host ("  3. {0}: already stocked" -f $v.Merchant)
        continue
    }
    if ($missing.Count -ne $adds.Count) { throw "$($v.File) is half-stocked - delete it, re-run 15, then re-run 17" }
    [void](Add-LeveledEntries -Path $path -FormKeys $adds)
    $placed += $adds.Count
    $what = $v.Archetypes -join ', '
    if ($v.ContainsKey('Lines')) { $what = $v.Lines -join ', ' }
    Write-Host ("  3. {0}: +{1} Expert/Master bundles ({2})" -f $v.Merchant, $adds.Count, $what)
}
Write-Host "  3. Expert/Master bundles placed: $placed"

# ------------------------------------------------------------------ prove it
# Resolve every chest to the set of tomes it actually yields, the same way the engine would:
# an Items entry is either a parent bundle (-> 3 tier bundles -> 3 tomes) or a tier bundle
# directly (-> 1 tome).
$tomeOf = @{}       # tier-bundle FormKey -> tome FormKey
$tierOf = @{}       # tier-bundle FormKey -> '000'..'100'
$lineOfTb = @{}     # tier-bundle FormKey -> 'Arch_School'
$childrenOf = @{}   # parent-bundle FormKey -> tier-bundle FormKeys
$archOfTb = @{}     # tier-bundle FormKey -> archetype
# Enai also ships a vestigial `TVR_Tomes_Litem_All*` family - a partial, never-finished set (only
# Alteration at 000 and Destruction at 000-075). `TVR_Tomes_Litem_All` is referenced solely by his
# debug chest TVR_Any_Container_CheatChest and the other five by nothing at all, so they are no
# part of the merchant chain. They are excluded here and asserted out of the chests below.
$allFamily = @($fkOf.Keys | Where-Object { $_ -match '^TVR_Tomes_Litem_All' } | ForEach-Object { $fkOf[$_] })
foreach ($eid in $fkOf.Keys) {
    $text = Read-YamlText $fileOf[$eid]
    $refs = @([regex]::Matches($text, '(?m)^    Reference: (.+?)(?=\r?$)') | ForEach-Object { $_.Groups[1].Value })
    if ($eid -match '^TVR_Tomes_Litem_(Druid|Shadow|Warlock|Cleric|Shaman)_(\d{3})_') {
        if ($refs.Count -ne 1) { throw "$eid has $($refs.Count) entries, want 1" }
        $tomeOf[$fkOf[$eid]] = $refs[0]
        $tierOf[$fkOf[$eid]] = $Matches[2]
        $archOfTb[$fkOf[$eid]] = $Matches[1]
        $lineOfTb[$fkOf[$eid]] = "$($Matches[1])_" + ($eid -split '_')[-1]
    } elseif ($eid -match '^TVR_Tomes_Litem_(Druid|Shadow|Warlock|Cleric|Shaman)_[A-Z]') {
        $childrenOf[$fkOf[$eid]] = $refs
    }
}

$sources = @{}   # tome FormKey -> list of chest file names
foreach ($f in Get-ChildItem -LiteralPath $lvli -Filter '*_CustomMerchandise*.yaml') {
    $text = Read-YamlText $f.FullName
    $items = @([regex]::Matches($text, '(?m)^    Reference: (.+?)(?=\r?$)') | ForEach-Object { $_.Groups[1].Value })
    $stray = @($items | Where-Object { $allFamily -contains $_ })
    if ($stray.Count -gt 0) { throw "merchant hook $($f.Name) stocks a TVR_Tomes_Litem_All bundle - that is the debug chest's list" }
    $yield = @()
    foreach ($it in $items) {
        if ($childrenOf.ContainsKey($it)) { foreach ($tb in $childrenOf[$it]) { $yield += $tomeOf[$tb] } }
        elseif ($tomeOf.ContainsKey($it)) { $yield += $tomeOf[$it] }
    }
    foreach ($tome in ($yield | Sort-Object -Unique)) {
        if (-not $sources.ContainsKey($tome)) { $sources[$tome] = @() }
        $sources[$tome] += $f.Name
    }
}

$allTomes = @($tomeOf.Values | Sort-Object -Unique)
if ($allTomes.Count -ne 75) { throw "chain resolves $($allTomes.Count) tomes, want 75" }

$tierOfTome = @{}
foreach ($tb in $tomeOf.Keys) { $tierOfTome[$tomeOf[$tb]] = $tierOf[$tb] }

$archOfTome = @{}
foreach ($tb in $tomeOf.Keys) { $archOfTome[$tomeOf[$tb]] = $archOfTb[$tb] }
$lineOfTome = @{}
foreach ($tb in $tomeOf.Keys) { $lineOfTome[$tomeOf[$tb]] = $lineOfTb[$tb] }

# Withheld tomes (00-common.ps1) may be reachable or not, so this proof holds on either side of
# 20-withhold-force-of-nature.ps1. Every other tome must be sold by exactly one merchant: the one
# its archetype maps to.
$wrong = @()
$unhomedTomes = 0
foreach ($tome in $allTomes) {
    $srcs = @()
    if ($sources.ContainsKey($tome)) { $srcs = @($sources[$tome] | Sort-Object -Unique) }
    if ($script:TvrNonVendorLines -contains $lineOfTome[$tome]) {
        if ($srcs.Count -gt 0) { $wrong += "$tome (non-vendor line $($lineOfTome[$tome])) sold by $($srcs -join ', ')" }
        $unhomedTomes++
        continue
    }
    if ($script:TvrWithheldTomes -contains $tome) {
        if ($srcs.Count -gt 0 -and ($srcs.Count -ne 1 -or $srcs[0] -ne (Get-VendorOfLine -Line $lineOfTome[$tome]))) { $wrong += "$tome (withheld) sold by $($srcs -join ', ')" }
        continue
    }
    if ($srcs.Count -eq 0) { $wrong += "$tome ($($tierOfTome[$tome]), $($archOfTome[$tome])) is unobtainable"; continue }
    if ($srcs.Count -ne 1 -or $srcs[0] -ne (Get-VendorOfLine -Line $lineOfTome[$tome])) {
        $wrong += "$tome ($($tierOfTome[$tome]), $($archOfTome[$tome])) sold by $($srcs -join ', ')"
    }
}
if ($wrong.Count -gt 0) { $wrong | ForEach-Object { Write-Host "    $_" }; throw "$($wrong.Count) tomes are not sold by exactly their line's one vendor" }
if ($unhomedTomes -ne 5 * $script:TvrNonVendorLines.Count) { throw "non-vendor lines hold $unhomedTomes tomes, want $(5 * $script:TvrNonVendorLines.Count)" }

$byTier = @{}
foreach ($tome in $allTomes) {
    $t = $tierOfTome[$tome]
    if (-not $byTier.ContainsKey($t)) { $byTier[$t] = 0 }
    $byTier[$t]++
}
$summary = @($byTier.Keys | Sort-Object | ForEach-Object { "$_=$($byTier[$_])" }) -join ' '
Write-Host "  proof: 75 tomes resolved ($summary); every homed, non-withheld tome sold by exactly its line's one vendor; $unhomedTomes tomes in non-vendor lines at no merchant (stashed or unhomed - 15 proves the stash)"
Write-Host "17 - done"
