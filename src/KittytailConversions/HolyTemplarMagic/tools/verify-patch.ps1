#requires -Version 5.1
<#
Asserts the generated Holy Templar Magic patch against Enderal and against Kittytail's plugin.
Run after 01-generate-patch.ps1. Exits non-zero on any failure.

  1. Every FormKey the patch emits resolves: :Skyrim.esm / :Enderal - Forgotten Stories.esm against
     reference/base (keyed by <hex>:<master>, never hex alone), :Lightpower.esl against the
     serialized upstream. PlayerRef 000014 is allow-listed (CLAUDE.md guardrail 11).
  2. No reference into a DLC stub, and no master the header does not declare.
  3. Every substituted visual resolves to the record TYPE the field needs.
  4. Every tome is reachable: stocked in Halda's hook, priced 20-350, teaching a spell whose mana
     cost sits inside Enderal's band for its tier.
  5. The self-heal pays Arcane Fever and the inject quests carry no script.
#>
param([string]$Upstream)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modRoot = Split-Path -Parent $PSScriptRoot
$repo    = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $modRoot))
if (-not $Upstream) { $Upstream = Join-Path $repo 'reference\mods\HolyTemplarMagic\LightpowerESL' }
$tree    = Join-Path $modRoot 'HolyTemplarMagicESP'
$base    = Join-Path $repo 'reference\base'
$fail    = New-Object System.Collections.Generic.List[string]
function Fail([string]$m) { $fail.Add($m) }
function Read-Text([string]$p) { [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) }

# ---- index: FormKey -> record group, from file/folder names
$index = @{}
function Add-Tree([string]$root) {
    foreach ($f in Get-ChildItem $root -Recurse -Filter '*.yaml') {
        $name = if ($f.Name -eq 'RecordData.yaml') { $f.Directory.Name } else { $f.BaseName }
        $m = [regex]::Match($name, '([0-9A-F]{6})_(.+\.(esm|esp|esl))$')
        if (-not $m.Success) { continue }
        $rel = $f.FullName.Substring($root.Length + 1)
        $index["$($m.Groups[1].Value):$($m.Groups[2].Value)"] = $rel.Split('\')[0]
    }
}
Add-Tree (Join-Path $base 'Skyrim')
Add-Tree (Join-Path $base 'EnderalFS')
Add-Tree $Upstream
$index['000014:Skyrim.esm'] = 'PlayerRef'

$masters = @('Skyrim.esm', 'Enderal - Forgotten Stories.esm', 'Lightpower.esl', 'Holy Templar Magic - Enderal.esp')
$files = @(Get-ChildItem $tree -Recurse -Filter '*.yaml')
$refs = 0
foreach ($f in $files) {
    foreach ($m in [regex]::Matches((Read-Text $f.FullName), '([0-9A-F]{6}):([^\r\n]+?\.(esm|esp|esl))(?=\r?\n|$)')) {
        $fk = "$($m.Groups[1].Value):$($m.Groups[2].Value)"
        $refs++
        if ($masters -notcontains $m.Groups[2].Value) { Fail "$($f.Name): $fk names an undeclared master"; continue }
        if (-not $index.ContainsKey($fk)) { Fail "$($f.Name): $fk does not resolve" }
    }
}
"1/2 $refs FormKey references across $($files.Count) files checked"

# ---- 3. substitutes are the right type
$expectType = @{
    '1097CA:Skyrim.esm' = 'Statics'; '0E755B:Skyrim.esm' = 'ArtObjects'; '0E7557:Skyrim.esm' = 'EffectShaders'
    '04D6B5:Skyrim.esm' = 'EffectShaders'; '04C6DA:Skyrim.esm' = 'ImpactDataSets'; '056622:Skyrim.esm' = 'SoundDescriptors'
    '02518F:Skyrim.esm' = 'SoundDescriptors'; '00001B:Skyrim.esm' = 'Activators'; '0F76C0:Skyrim.esm' = 'Factions'
    '0F76BD:Skyrim.esm' = 'Factions'; '11A4B6:Skyrim.esm' = 'MagicEffects'
    '0302FF:Enderal - Forgotten Stories.esm' = 'LeveledItems'
}
foreach ($k in $expectType.Keys) {
    if (-not $index.ContainsKey($k)) { Fail "substitute $k missing from Enderal" }
    elseif ($index[$k] -ne $expectType[$k]) { Fail "substitute $k is a $($index[$k]), expected $($expectType[$k])" }
}
"3   $($expectType.Count) substitute records type-checked"

# ---- 4. tomes reachable and priced
$band = @{ '0F2CAA:Skyrim.esm' = @('Novice', 6, 140); '0C44C7:Skyrim.esm' = @('Apprentice', 12, 140)
           '0C44C8:Skyrim.esm' = @('Adept', 10, 200); '0C44C9:Skyrim.esm' = @('Expert', 29, 260)
           '0C44CA:Skyrim.esm' = @('Master', 38, 310) }
$hook = @(Get-ChildItem (Join-Path $tree 'LeveledItems') -Filter 'HaldaHammerschlag_CustomMerchandise*')
if ($hook.Count -ne 1) { Fail 'Halda hook override missing' } else {
    $ht = Read-Text $hook[0].FullName
    if ($ht -notmatch '(?m)^- UseAll(?=\r?$)') { Fail 'Halda hook lost UseAll' }
    if ($ht -match 'ChanceNone|Global:') { Fail 'Halda hook gained a ChanceNone/Global gate' }
}
foreach ($b in Get-ChildItem (Join-Path $Upstream 'Books') -Filter '*.yaml') {
    $hex = [regex]::Match($b.Name, ' - ([0-9A-F]{6})_').Groups[1].Value
    $ours = Join-Path (Join-Path $tree 'Books') $b.Name
    if (-not (Test-Path $ours)) { Fail "$($b.Name): not repriced"; continue }
    $bt = Read-Text $ours
    $gold = [int][regex]::Match($bt, '(?m)^Value: (\d+)').Groups[1].Value
    if ($gold -lt 20 -or $gold -gt 350) { Fail "$($b.Name): price $gold outside 20-350" }
    if ($hook.Count -eq 1 -and $ht -notmatch "Reference: ${hex}:Lightpower\.esl") { Fail "$($b.Name): not stocked by Halda" }
    $sHex = [regex]::Match($bt, '(?m)^  Spell: ([0-9A-F]{6}):Lightpower').Groups[1].Value
    $sp = @(Get-ChildItem (Join-Path $tree 'Spells') -Filter "* - ${sHex}_*")
    if ($sp.Count -ne 1) { Fail "$($b.Name): taught spell $sHex not overridden"; continue }
    $st = Read-Text $sp[0].FullName
    $perk = [regex]::Match($st, '(?m)^HalfCostPerk: (\S+)').Groups[1].Value
    $cost = [int][regex]::Match($st, '(?m)^BaseCost: (\d+)').Groups[1].Value
    $t = $band[$perk]
    if (-not $t) { Fail "$sHex : unknown tier perk $perk"; continue }
    if ($st -notmatch '(?m)^- ManualCostCalc(?=\r?$)') { Fail "$sHex : ManualCostCalc missing" }
    if ($cost -lt $t[1] -or $cost -gt $t[2]) { Fail "$sHex : cost $cost outside Enderal $($t[0]) band $($t[1])-$($t[2])" }
    '4   {0,-10} {1,-34} {2,3} mana  {3,3} gold' -f $t[0], $sp[0].Name.Split(' ')[0], $cost, $gold
}

# ---- 5. fever + quests
$heal = @(Get-ChildItem (Join-Path $tree 'Spells') -Filter '_LIP_ConsecrateDeadHeal - *')
if ($heal.Count -ne 1 -or (Read-Text $heal[0].FullName) -notmatch 'BaseEffect: 11A4B6:Skyrim\.esm') { Fail 'Blessing does not pay Arcane Fever' }
foreach ($q in Get-ChildItem (Join-Path $tree 'Quests') -Filter '*.yaml') {
    if ((Read-Text $q.FullName) -match 'VirtualMachineAdapter') { Fail "$($q.Name): still carries a script" }
}
"5   Arcane Fever + quest scripts checked"

if ($fail.Count) { $fail | ForEach-Object { "FAIL $_" }; throw "$($fail.Count) check(s) failed" }
'ALL CHECKS PASSED'
