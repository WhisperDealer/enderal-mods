# 01 - Remove the Homeowner trait.
#
# WHY: Homeowner lets the player take a mortgage on one of five Skyrim city houses. None of those
# cells exists in Enderal - Breezehome 0165A8, Honeyside 016BDD, Vlindrel Hall 016DFA, Hjerim
# 016778 and Proudspire Manor 016A06 all resolve to nothing in reference/base/, and so do all 31
# placed refs its enable/disable FormLists drive. Verified 2026-08-05.
#
# This is also the whole of the plugin's conflict surface: every one of its 11 overrides of a
# master is Homeowner content, so deleting the trait leaves a plugin that overrides nothing.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "01 - cutting the Homeowner trait"

$root  = Get-EspRoot
$index = Get-RecordIndex

# --- the six overridden Skyrim cells and their COC markers ------------------------------------
# These serialize to a Cells/ tree that contains nothing else, so the whole folder goes.
$cells = Join-Path $root 'Cells'
$cellFiles = 0
if (Test-Path $cells) {
    $cellFiles = @(Get-ChildItem -Path $cells -Recurse -Filter '*.yaml').Count
    Remove-Item -LiteralPath $cells -Recurse -Force
    Write-Host ("  cells: removed the Cells/ tree ({0} file(s)) - all 11 master overrides" -f $cellFiles)
} else {
    Write-Host "  cells: already removed"
}

# --- every record whose EditorID names the trait ------------------------------------------------
$records = Get-RecordsMatching -Patterns @('Homeowner') -Index $index
$removed = Remove-RecordFiles -Records $records -Label 'homeowner records'

if ($cellFiles -eq 0 -and $removed -eq 0) {
    Write-Host "  nothing to do - already applied"
} else {
    Assert-Changed -Count ($cellFiles + $removed) -What 'Homeowner cut'
}

Write-Host "01 - done"
