# 02 - Delete the six records that override a DLC record outright.
#
# WD-9 verdict 7, first shape. These are whole-record overrides of Dawnguard/Dragonborn vendor
# plumbing, and Enderal ships the DLC as empty stubs (44 KB / 80 bytes / 44 KB, 1-2 records
# between them), so every one of them overrides a record that does not exist:
#
#   DLC1VendorChestFlorentius            00F82B:Dawnguard.esm
#   DLC2dunFrostmoonVendorChest          01DC65:Dragonborn.esm
#   DLC2MerchantTelMithrynNelothChest    0177C1:Dragonborn.esm
#   DLC2SkaalBlacksmithChest             01F897:Dragonborn.esm
#   DLC2SkaalMerchantChest               01F88D:Dragonborn.esm
#   DLC2dunFrostmoonWerewolvesVendorFaction  01DC62:Dragonborn.esm
#
# Deleting is unambiguous rather than a judgement call: the whole vendor distribution is rebuilt
# onto Enderal merchants in WD-16, so nothing downstream wants these back.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "02 - dropping whole-record DLC overrides"

$root = Get-EspRoot

$targets = @(
    'Containers\DLC1VendorChestFlorentius - 00F82B_Dawnguard.esm.yaml',
    'Containers\DLC2dunFrostmoonVendorChest - 01DC65_Dragonborn.esm.yaml',
    'Containers\DLC2MerchantTelMithrynNelothChest - 0177C1_Dragonborn.esm.yaml',
    'Containers\DLC2SkaalBlacksmithChest - 01F897_Dragonborn.esm.yaml',
    'Containers\DLC2SkaalMerchantChest - 01F88D_Dragonborn.esm.yaml',
    'Factions\DLC2dunFrostmoonWerewolvesVendorFaction - 01DC62_Dragonborn.esm.yaml'
)

$removed = 0
foreach ($t in $targets) {
    $path = Join-Path $root $t
    if (Test-Path $path) {
        Remove-Item -LiteralPath $path -Force
        Write-Host ("    - {0}" -f (Split-Path -Leaf $t))
        $removed++
    }
}

if ($removed -eq 0) {
    Write-Host "  nothing to do - already applied"
} else {
    Write-Host ("  removed {0} record(s)" -f $removed)
}

# Nothing else in the tree may still be a DLC-suffixed record file.
$stragglers = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.yaml' |
                Where-Object { $_.Name -match '_(Dawnguard|HearthFires|Dragonborn)\.esm\.yaml$' })
if ($stragglers.Count -gt 0) {
    $stragglers | ForEach-Object { Write-Host ("    still present: {0}" -f $_.Name) }
    throw "$($stragglers.Count) DLC override record(s) remain."
}

Write-Host "02 - done; no DLC-defined records remain in the tree"
