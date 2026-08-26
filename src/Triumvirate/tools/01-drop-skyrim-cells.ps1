# 01 - Delete the cell and worldspace overrides for places Enderal does not have.
#
# WD-9 verdicts 6 and 8. Triumvirate overrides five locations, and none of them exists in Enderal:
#
#   Tamriel                      00003C  ->  Enderal has MQP01Home at that FormID (the prologue
#                                            house). This is the same defect Apocalypse shipped;
#                                            the override also drags in a Regions list whose only
#                                            resolvable entry, 041449, is _00E_Ark_1024WallRound01
#                                            - a Static where Bethesda had a Region.
#   Riverwood                    009732  ->  absent
#   RiftenHouseofClanSnowShod    016BDE  ->  absent
#   MarkarthTempleofDibella      016DF3  ->  absent
#   SolitudeTempleoftheDivines   016A02  ->  absent
#
# Each interior override carries exactly one placed actor - Nura (013372), Hamal (01E765) and
# 0132A2 - vanilla NPCs Triumvirate touches to wire up its vendor factions. All three are Skyrim
# NPCs that Enderal does not have, so the overrides are dead weight that INJECTS four Skyrim cells
# into Enderal's FormID space.
#
# Deleting rather than forwarding: Apocalypse forwarded Enderal's own 00003C record back because it
# needed the worldspace to exist for its containers. Triumvirate needs nothing in any of these
# cells - its own content lives in TVR_Cell 2E99EB, which this script leaves alone.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "01 - dropping cell and worldspace overrides for places Enderal lacks"

$root = Get-EspRoot

$targets = @(
    'Cells\0\5\RiftenHouseofClanSnowShod - 016BDE_Skyrim.esm',
    'Cells\3\8\MarkarthTempleofDibella - 016DF3_Skyrim.esm',
    'Cells\4\7\SolitudeTempleoftheDivines - 016A02_Skyrim.esm',
    'Worldspaces'
)

$removed = 0
foreach ($t in $targets) {
    $path = Join-Path $root $t
    if (Test-Path $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
        Write-Host ("    - {0}" -f $t)
        $removed++
    }
}

# Prune the block/sub-block folders the deleted cells left behind.
#
# Spriggit emits a GroupRecordData.yaml for every CELL block and sub-block, so a folder whose cell
# is gone is NOT empty - it still holds that one file, and would serialize as an empty GRUP. A
# block folder is orphaned when it has no child directories and nothing but GroupRecordData.yaml.
$pruned = 0
$cells = Join-Path $root 'Cells'
if (Test-Path $cells) {
    # Deepest-first, so a sub-block goes before its parent block is tested.
    Get-ChildItem -LiteralPath $cells -Recurse -Directory |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            $kids  = @(Get-ChildItem -LiteralPath $_.FullName -Force -Directory)
            $files = @(Get-ChildItem -LiteralPath $_.FullName -Force -File | Where-Object { $_.Name -ne 'GroupRecordData.yaml' })
            if ($kids.Count -eq 0 -and $files.Count -eq 0) {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force
                Write-Host ("    - pruned empty block {0}" -f $_.FullName.Substring($root.Length + 1))
                $pruned++
            }
        }
}

if ($removed -eq 0) {
    Write-Host "  nothing to do - already applied"
} else {
    Write-Host ("  removed {0} override tree(s), pruned {1} empty folder(s)" -f $removed, $pruned)
}

# TVR_Cell is Triumvirate's own Night Gate portal interior and must survive.
$own = Get-ChildItem -LiteralPath $root -Recurse -Directory -Filter 'TVR_Cell - *' -ErrorAction SilentlyContinue
if (-not $own) { throw "TVR_Cell is gone - this script deleted more than it should have." }
$placed = @(Get-YamlLines (Join-Path $own[0].FullName 'RecordData.yaml') | Where-Object { $_ -match 'MutagenObjectType: Placed' })
if ($placed.Count -lt 13) { throw "TVR_Cell lost placed objects: $($placed.Count) left, expected 13." }
Write-Host ("  TVR_Cell intact: {0} placed objects" -f $placed.Count)

# No reference into the deleted cells may survive anywhere in the tree.
$dead = @('00003C:Skyrim.esm', '009732:Skyrim.esm', '016BDE:Skyrim.esm', '016DF3:Skyrim.esm', '016A02:Skyrim.esm')
$left = @()
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.yaml') {
    $text = Read-YamlText $file.FullName
    foreach ($d in $dead) { if ($text -match [regex]::Escape($d)) { $left += ("{0} -> {1}" -f $file.Name, $d) } }
}
if ($left.Count -gt 0) {
    $left | Select-Object -Unique | ForEach-Object { Write-Host "    still referenced: $_" }
    throw "Deleted a cell that is still referenced $($left.Count) time(s)."
}

Write-Host "01 - done"
