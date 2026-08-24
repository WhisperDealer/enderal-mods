# 06 - Fix the references whose FormID survived into Enderal as a DIFFERENT record.
#
# WD-9 verdict 6. These are the dangerous ones: a dead reference is inert, but a reference that
# RESOLVES to the wrong record is a live bug. verify-ref-drift.ps1 found 15 of them among 1462
# surviving :Skyrim.esm references - the other 1402 are exact matches - and only two need touching.
#
#   0C891B   vanilla ReligiousMaraLove (Amulet of Mara)
#            Enderal _04E_30_Unique_SongOfTheWinter, an unrelated unique weapon
#            -> stocked as an Item in TVR_Cleric_Container_MerchantMaramalChest. REMOVE the entry.
#
#            This is the THIRD mod in this workspace to hit that exact FormID: CLAUDE.md documents
#            it from Biggie Traits, where an Amulet-of-the-Divines OR-group resolved it to the same
#            weapon and fired Divine-amulet effects on it. The blast radius here is small - Maramal
#            does not exist in Enderal and WD-16 deletes the chest - but leaving a known-wrong item
#            in place because something downstream will probably delete it is not a verdict.
#
#   092A6C   vanilla an AtT_ art-attach node keyword (a mesh attachment point for magic effects)
#            Enderal SomeWolfKeyword, a wolf-family tag carried by WolfRace, FoxRace, WolfHoheRace
#            and C06WolfSpiritRace
#            -> in the Keywords list of TVR_Primal_Race_CallWolf and TVR_Warrior_Race_Fylgja.
#            REMOVE from both.
#
#            Enderal has ZERO AtT_ keywords, so there is no substitute to point at - the art-attach
#            system Enai was using simply does not exist here. Nothing in Enderal reads
#            SomeWolfKeyword either (only four race records carry it, nothing conditions on it), so
#            this is tidiness rather than a bug fix. Removed from both rather than kept on the wolf
#            where it happens to fit, so that a future reader does not read an accident of FormID
#            reuse as a deliberate choice.
#
# The other 13 drifted references are deliberately left alone and are listed in the audit: five
# Blackreach ore veins that became _00E_MineOreShadowsteel* (the Druid's Mark Ore list wanted ore
# and got ore), two glowing mushrooms that became _00E_Mistshroom*, DragonsTongue -> VatyrsTongue,
# two voice types, and deathBell -> BaldrisRoot.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "06 - fixing drifted references"

$root = Get-EspRoot
$changes = 0

function Get-Record {
    param([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$EditorID)
    $hit = Get-ChildItem -LiteralPath (Join-Path $root $Group) -Filter "$EditorID - *.yaml" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $hit) { throw "record not found: $Group\$EditorID" }
    return $hit.FullName
}

# --- 0C891B: drop the Amulet-of-Mara item entry -------------------------------------------------
$chest = Get-Record -Group 'Containers' -EditorID 'TVR_Cleric_Container_MerchantMaramalChest'
$lines = Get-YamlLines $chest
$before = @($lines | Where-Object { $_ -match '^\s*-\s+Item:\s*$' }).Count

$keep = @()
$i = 0
$dropped = 0
while ($i -lt $lines.Count) {
    # An item is three lines: "- Item:", "    Item: <fk>", "    Count: <n>".
    if ($lines[$i] -match '^\s*-\s+Item:\s*$' -and
        $i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^\s*Item: 0C891B:Skyrim\.esm\s*$') {
        $indent = ($lines[$i] -replace '^(\s*).*$', '$1').Length
        $j = $i + 1
        while ($j -lt $lines.Count) {
            if ($lines[$j].Trim() -eq '') { $j++; continue }
            $ind = ($lines[$j] -replace '^(\s*).*$', '$1').Length
            if ($ind -le $indent) { break }
            $j++
        }
        $dropped++
        $i = $j
        continue
    }
    $keep += $lines[$i]
    $i++
}

if ($dropped -gt 0) {
    Set-YamlLines -Path $chest -Lines (Remove-EmptyCollectionKeys -Lines $keep)
    $after = @((Get-YamlLines $chest) | Where-Object { $_ -match '^\s*-\s+Item:\s*$' }).Count
    Write-Host ("    TVR_Cleric_Container_MerchantMaramalChest  items {0} -> {1} (dropped ReligiousMaraLove)" -f $before, $after)
    if ($after -ne $before - 1) { throw "Expected to drop exactly one item, went $before -> $after." }
    $changes += $dropped
}

# --- 092A6C: drop the art-attach keyword from both races ----------------------------------------
foreach ($race in @('TVR_Primal_Race_CallWolf', 'TVR_Warrior_Race_Fylgja')) {
    $path = Get-Record -Group 'Races' -EditorID $race
    $n = Remove-YamlListEntries -Path $path -FormKeys @('092A6C:Skyrim.esm')
    if ($n -gt 0) {
        Write-Host ("    {0,-30} -{1} keyword entry" -f $race, $n)
        $changes += $n
    }
}

if ($changes -eq 0) {
    Write-Host "  nothing to do - already applied"
} else {
    Write-Host ("  {0} change(s)" -f $changes)
}

# --- prove both are gone ------------------------------------------------------------------------
$left = @()
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.yaml') {
    $text = Read-YamlText $file.FullName
    foreach ($fk in @('0C891B:Skyrim.esm', '092A6C:Skyrim.esm')) {
        if ($text -match [regex]::Escape($fk)) { $left += ("{0} -> {1}" -f $file.Name, $fk) }
    }
}
if ($left.Count -gt 0) {
    $left | ForEach-Object { Write-Host "    remaining: $_" }
    throw "$($left.Count) drifted reference(s) survived."
}

Write-Host "06 - done"
