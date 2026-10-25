#requires -Version 5.1
<#
Asserts the generated Dark Hierophant Magic patch. Run after 01-generate-patch.ps1.

  1. Every FormKey resolves (Enderal, Ghostlight.esl, or this patch); no DLC references; no
     undeclared master.
  2. -GameData: the copied inventory-art static's mesh ships with Enderal.
  3. All 10 tomes stocked by Mirella, priced 20-350, teaching spells costed inside Enderal's tier
     bands (Concentration at <= 80).
#>
param([string]$Upstream, [string]$GameData)
. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tools\KittytailCommon.ps1')

$modRoot  = Split-Path -Parent $PSScriptRoot
$repo     = Get-KtRepo
if (-not $Upstream) { $Upstream = Join-Path $repo 'reference\mods\DarkHierophant\GhostlightESL' }
$tree     = Join-Path $modRoot 'DarkHierophantESP'
$PatchKey = 'Dark Hierophant - Enderal.esp'
$masters  = @('Skyrim.esm', 'Enderal - Forgotten Stories.esm', 'Ghostlight.esl', $PatchKey)
$fail = New-Object System.Collections.Generic.List[string]
function Fail([string]$m) { $fail.Add($m) }
$fkRx = '([0-9A-F]{6}):([^\r\n]+?\.(?:esm|esp|esl))(?=\r?\n|$)'

$ix = Get-KtFormKeyIndex
$own = @{}
foreach ($root in $Upstream, $tree) {
    foreach ($f in Get-ChildItem $root -Recurse -Filter '*.yaml') {
        $m = [regex]::Match((Read-KtText $f.FullName), '(?m)^FormKey: (.+?)(?=\r?$)')
        if ($m.Success) { $own[$m.Groups[1].Value] = $f.FullName }
    }
}

# ---- 1
$files = @(Get-ChildItem $tree -Recurse -Filter '*.yaml')
$refs = 0
foreach ($f in $files) {
    foreach ($m in [regex]::Matches((Read-KtText $f.FullName), $fkRx)) {
        $fk = "$($m.Groups[1].Value):$($m.Groups[2].Value)"; $refs++
        if ($masters -notcontains $m.Groups[2].Value) { Fail "$($f.Name): $fk names an undeclared master"; continue }
        if (-not ($ix.Enderal.ContainsKey($fk) -or $own.ContainsKey($fk))) { Fail "$($f.Name): $fk does not resolve" }
    }
}
"1   $refs FormKey references across $($files.Count) files"

# ---- 2
$copied = @($files | Where-Object { $_.Name -like '_BLE_*' })
if ($copied.Count -ne 1) { Fail "expected 1 copied record, found $($copied.Count)" }
if ($GameData) {
    . (Join-Path $repo '.claude\config\tools.ps1')
    $assets = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($b in Get-ChildItem (Join-Path $GameData '*.bsa')) {
        & $Tools.bsab $b.FullName -l 2>$null | ForEach-Object { if ($_) { [void]$assets.Add($_.Trim().ToLower()) } }
    }
    foreach ($f in $copied) {
        foreach ($m in [regex]::Matches((Read-KtText $f.FullName), '(?im)^[ \t]*File:[ \t]+([^\r\n]+\.nif)[ \t]*(?=\r?$)')) {
            $p = 'meshes\' + $m.Groups[1].Value.Trim().ToLower().Replace('/', '\')
            if (-not $assets.Contains($p)) { Fail "$($f.Name): mesh '$p' is not shipped by Enderal" } else { "2   $p ships with Enderal" }
        }
    }
} else { '2   SKIPPED - pass -GameData <Enderal Data folder> to check the copied mesh' }

# ---- 3
$band = @{ '0C44C0:Skyrim.esm' = @('Adept', 10, 200); '0C44C1:Skyrim.esm' = @('Expert', 29, 260); '0C44C2:Skyrim.esm' = @('Master', 38, 310) }
$hook = @(Get-ChildItem (Join-Path $tree 'LeveledItems') -Filter 'Mirella_CustomMerchandise*')
$ht = if ($hook.Count -eq 1) { Read-KtText $hook[0].FullName } else { Fail 'Mirella hook override missing'; '' }
if ($ht -and ($ht -notmatch '(?m)^- UseAll(?=\r?$)' -or $ht -match 'ChanceNone|Global:')) { Fail 'Mirella hook lost UseAll or gained a gate' }
$books = @(Get-ChildItem (Join-Path $tree 'Books') -Filter '*.yaml')
if ($books.Count -ne 10) { Fail "expected 10 tomes, found $($books.Count)" }
foreach ($b in $books) {
    $bt = Read-KtText $b.FullName
    $fk = [regex]::Match($bt, '(?m)^FormKey: (.+?)(?=\r?$)').Groups[1].Value
    $gold = [int][regex]::Match($bt, '(?m)^Value: (\d+)').Groups[1].Value
    if ($gold -lt 20 -or $gold -gt 350) { Fail "$($b.Name): $gold gold outside 20-350" }
    if ($ht -notmatch "Reference: $([regex]::Escape($fk))") { Fail "$($b.Name): not stocked by Mirella" }
    $sk = [regex]::Match($bt, '(?m)^  Spell: (.+?)(?=\r?$)').Groups[1].Value
    $sp = @(Get-ChildItem (Join-Path $tree 'Spells') -Filter "* - $($sk.Substring(0,6))_Ghostlight.esl.yaml")
    if ($sp.Count -ne 1) { Fail "$($b.Name): taught spell $sk not overridden"; continue }
    $st = Read-KtText $sp[0].FullName
    $cost = [int][regex]::Match($st, '(?m)^BaseCost: (\d+)').Groups[1].Value
    $t = $band[[regex]::Match($st, '(?m)^HalfCostPerk: (.+?)(?=\r?$)').Groups[1].Value]
    if (-not $t) { Fail "$sk : unknown tier"; continue }
    if ($st -notmatch '(?m)^- ManualCostCalc(?=\r?$)') { Fail "$sk : ManualCostCalc missing" }
    $max = if ($st -match '(?m)^CastType: Concentration(?=\r?$)') { 80 } else { $t[2] }
    if ($cost -lt $t[1] -or $cost -gt $max) { Fail "$sk : cost $cost outside $($t[0]) band $($t[1])-$max" }
    '3   {0,-7} {1,-28} {2,4} mana {3,4} gold' -f $t[0], $sp[0].Name.Split(' ')[0], $cost, $gold
}

if ($fail.Count) { $fail | ForEach-Object { "FAIL $_" }; throw "$($fail.Count) check(s) failed" }
'ALL CHECKS PASSED'
