# 06 - Repair the surviving traits whose internals still pointed at Skyrim-only content.
#
# 03 proved no reference dangles INSIDE the plugin. This step handles the other direction:
# references OUT to master records that Enderal does not have. Resolving all 140 external
# FormKeys against reference/base/ on 2026-08-05 left 15 unresolved, and they are not all benign.
#
#   Angler          EncMudcrabMedium 0E4010 / EncMudcrabLarge 0E4011 do not exist in Enderal, so
#                   the trait's summoned pet crab never spawns - the whole point of the trait.
#                   Repointed to Enderal's own crabs, which sit on the same MudcrabRace 0BA545
#                   that the SPID faction distribution already targets.
#   Good Natured    All three of its BENEFITS are gated on wearing one of the nine Amulets of the
#                   Divines. Enderal has no Divines and no such amulets, so only its ungated
#                   ModSpellMagnitude x0.75 penalty survives - a trait that is purely negative.
#                   Cut.
#   Bad Natured     Its perk is sneak-based and works untouched. Only the "wearing a divine amulet
#                   hurts you" effect is dead, so that single effect is removed and the trait keeps
#                   its crouch/stand tradeoff.
#
# The amulet checks are worse than merely dead. Eight of the nine FormIDs resolve to nothing, but
# 0C891B resolves in Enderal to _04E_30_Unique_SongOfTheWinter - an unrelated unique weapon. Left
# alone, equipping that weapon would trigger Good Natured's bonuses and Bad Natured's self-damage.
# This is exactly the trap CLAUDE.md records: a surviving vanilla FormID may be a different record.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "06 - repairing kept traits"

$root = Get-EspRoot

# --- Angler: repoint the summoned crabs to Enderal's own -----------------------------------------
# _03E_Crab 0164C4 (ordinary) and _05E_KingscrabNormal 01722B (larger) - both on MudcrabRace.
$angler = Get-ChildItem -Path (Join-Path $root 'MagicEffects') -Filter 'Traits_AnglerAttackEffect - *.yaml' | Select-Object -First 1
$anglerFixed = 0
if ($angler) {
    $text = Read-YamlText $angler.FullName
    $repoints = @{
        '0E4011:Skyrim.esm' = '01722B:Skyrim.esm'   # EncMudcrabLarge  -> _05E_KingscrabNormal
        '0E4010:Skyrim.esm' = '0164C4:Skyrim.esm'   # EncMudcrabMedium -> _03E_Crab
    }
    foreach ($from in $repoints.Keys) {
        $to = $repoints[$from]
        $pattern = '(?m)^(\s*Object: )' + [regex]::Escape($from) + '(?=\r?$)'
        $new = [regex]::Replace($text, $pattern, ('${1}' + $to))
        if ($new -ne $text) {
            Write-Host ("  Angler: {0} -> {1}" -f $from, $to)
            $text = $new
            $anglerFixed++
        }
    }
    if ($anglerFixed -gt 0) { Write-YamlText -Path $angler.FullName -Text $text }
    Write-Host ("  Angler: repointed {0} crab property/properties" -f $anglerFixed)
}

# --- Good Natured: cut ---------------------------------------------------------------------------
$index = Get-RecordIndex
$goodNatured = Get-RecordsMatching -Patterns @('GoodNatured') -Index $index
$gnRemoved = 0
if ($goodNatured.Count -gt 0) {
    Write-Host "  Good Natured (benefits all gated on Divine amulets):"
    $gnRemoved = Remove-RecordFiles -Records $goodNatured -Label 'Good Natured'
}

# --- Bad Natured: drop the divine-amulet self-damage effect --------------------------------------
# Effect 000029 is the one carrying the nine GetEquipped conditions.
$badNatured = Get-ChildItem -Path (Join-Path $root 'Spells') -Filter 'Traits_BadNaturedAb - *.yaml' | Select-Object -First 1
$bnRemoved = 0
if ($badNatured) {
    $lines = Get-YamlLines $badNatured.FullName
    $startIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^-\s+BaseEffect: 000029:Biggie Traits\.esp\s*$') { $startIdx = $i; break }
    }
    if ($startIdx -ge 0) {
        $endIdx = $lines.Count
        for ($i = $startIdx + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^-\s+BaseEffect:') { $endIdx = $i; break }
        }
        $keep = @()
        if ($startIdx -gt 0) { $keep += $lines[0..($startIdx - 1)] }
        if ($endIdx -lt $lines.Count) { $keep += $lines[$endIdx..($lines.Count - 1)] }
        Set-YamlLines -Path $badNatured.FullName -Lines $keep
        $bnRemoved = $endIdx - $startIdx
    }
    Write-Host ("  Bad Natured: removed {0} line(s) - the divine-amulet damage effect" -f $bnRemoved)
}

# The two records that effect used are now orphaned.
$index = Get-RecordIndex
$bnOrphans = Get-RecordsMatching -Patterns @('BadNaturedNeg1') -Index $index
if ($bnOrphans.Count -gt 0) {
    $bnRemoved += Remove-RecordFiles -Records $bnOrphans -Label 'Bad Natured orphans'
}

# --- dead entries in surviving lists -------------------------------------------------------------
# Each is a Skyrim record Enderal lacks; the list keeps working on its remaining entries.
$deadEntries = @{
    'FormLists|Traits_GiantkinExcludesList'   = '035369:Skyrim.esm'   # a CC staff, FLM-populated
    'FormLists|Traits_AnglerAllyFactionsList' = '0418EA:Skyrim.esm'   # vanilla mudcrab faction
}
$entriesDropped = 0
foreach ($k in $deadEntries.Keys) {
    $parts = $k -split '\|'
    $file = Get-ChildItem -Path (Join-Path $root $parts[0]) -Filter "$($parts[1]) - *.yaml" | Select-Object -First 1
    if (-not $file) { continue }
    $n = Remove-YamlListEntries -Path $file.FullName -FormKeys @($deadEntries[$k])
    if ($n -gt 0) { Write-Host ("  {0}: dropped {1} dead entry" -f $parts[1], $n) }
    $entriesDropped += $n
}

# A LeveledItem entry is a '- Data:' block rather than a bare sequence item, so it needs the
# block treatment. 100E8A is a vanilla fish the Angler reward list rolls; the other two resolve.
$fish = Get-ChildItem -Path (Join-Path $root 'LeveledItems') -Filter 'Traits_AnglerCatchFishReward - *.yaml' | Select-Object -First 1
if ($fish) {
    $lines = Get-YamlLines $fish.FullName
    $refIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*Reference: 100E8A:Skyrim\.esm\s*$') { $refIdx = $i; break }
    }
    if ($refIdx -ge 0) {
        $startIdx = $refIdx
        while ($startIdx -ge 0 -and $lines[$startIdx] -notmatch '^-\s+Data:') { $startIdx-- }
        if ($startIdx -lt 0) { throw "Could not find the '- Data:' line opening the dead fish entry." }
        $endIdx = $lines.Count
        for ($i = $startIdx + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^-\s+Data:') { $endIdx = $i; break }
        }
        $keep = @()
        if ($startIdx -gt 0) { $keep += $lines[0..($startIdx - 1)] }
        if ($endIdx -lt $lines.Count) { $keep += $lines[$endIdx..($lines.Count - 1)] }
        Set-YamlLines -Path $fish.FullName -Lines $keep

        $remaining = ($keep | Where-Object { $_ -match '^-\s+Data:' }).Count
        Write-Host ("  Traits_AnglerCatchFishReward: dropped 1 dead entry, {0} remain" -f $remaining)
        if ($remaining -lt 2) { throw "Angler fish reward list dropped below 2 usable entries." }
        $entriesDropped += ($endIdx - $startIdx)
    }
}

# The Nosferatu snack's second effect is an Update.esm magic effect Enderal does not have.
$snack = Get-ChildItem -Path (Join-Path $root 'Ingestibles') -Filter 'Traits_CookedSkeeverTail - *.yaml' | Select-Object -First 1
if ($snack) {
    $lines = Get-YamlLines $snack.FullName
    $startIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^-\s+BaseEffect: [0-9A-Fa-f]{6}:Update\.esm\s*$') { $startIdx = $i; break }
    }
    if ($startIdx -ge 0) {
        $endIdx = $lines.Count
        for ($i = $startIdx + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^-\s+BaseEffect:') { $endIdx = $i; break }
        }
        $keep = @()
        if ($startIdx -gt 0) { $keep += $lines[0..($startIdx - 1)] }
        if ($endIdx -lt $lines.Count) { $keep += $lines[$endIdx..($lines.Count - 1)] }
        Set-YamlLines -Path $snack.FullName -Lines $keep
        Write-Host ("  Traits_CookedSkeeverTail: removed {0} line(s) - an Update.esm effect Enderal lacks" -f ($endIdx - $startIdx))
        $entriesDropped += ($endIdx - $startIdx)
    }
}

$total = $anglerFixed + $gnRemoved + $bnRemoved + $entriesDropped
if ($total -eq 0) {
    Write-Host "  nothing to do - already applied"
} else {
    Assert-Changed -Count $total -What 'kept-trait repairs'
}

Write-Host "06 - done. Run 03 again to prune Good Natured out of the driver lists."
