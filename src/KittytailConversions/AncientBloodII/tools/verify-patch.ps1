#requires -Version 5.1
<#
Asserts the generated Ancient Blood Magic II patch. Run after 01-generate-patch.ps1.

  1. Every FormKey resolves - Enderal (reference/base), Kittytail's plugin, or this patch - except
     the five vanilla records Enderal deleted that the generator deliberately leaves dangling, and
     each of those must already have been dangling in Kittytail's original (differential check).
  2. No reference into a DLC stub; no master the header does not declare.
  3. -GameData: every mesh/texture/sound path a COPIED record names exists in Enderal's archives or
     loose files. That is the premise of copying at all, so it is checked rather than assumed.
  4. All 14 tomes stocked by the Undercity fence, priced 20-350, teaching spells costed inside
     Enderal's tier bands (Concentration at <= 80, Enderal's dearest).
  5. Invariants the player feels (CLAUDE.md "write an INVARIANT check per subsystem"):
     every summon carrying a bow carries resolvable arrows at <= 10 damage; the inject quest still
     carries PerkToAdd (The Eternal Legion's third summon) and writes only into the sink.
#>
param([string]$Upstream, [string]$GameData)
. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tools\KittytailCommon.ps1')

$modRoot = Split-Path -Parent $PSScriptRoot
$repo    = Get-KtRepo
if (-not $Upstream) { $Upstream = Join-Path $repo 'reference\mods\AncientBloodII\AncientBloodIIESL' }
$tree     = Join-Path $modRoot 'AncientBloodIIESP'
$PatchKey = 'Ancient Blood II - Enderal.esp'
$masters  = @('Skyrim.esm', 'Enderal - Forgotten Stories.esm', 'AncientBloodII.esl', $PatchKey)
$keepDangling = @('02430D:Skyrim.esm', '058F68:Skyrim.esm', '103A8F:Skyrim.esm', '103A90:Skyrim.esm', '106253:Skyrim.esm')
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
$upstreamText = (Get-ChildItem $Upstream -Recurse -Filter '*.yaml' | ForEach-Object { Read-KtText $_.FullName }) -join "`n"

# ---- 1 + 2
$files = @(Get-ChildItem $tree -Recurse -Filter '*.yaml')
$refs = 0
foreach ($f in $files) {
    foreach ($m in [regex]::Matches((Read-KtText $f.FullName), $fkRx)) {
        $fk = "$($m.Groups[1].Value):$($m.Groups[2].Value)"; $refs++
        if ($masters -notcontains $m.Groups[2].Value) { Fail "$($f.Name): $fk names an undeclared master"; continue }
        if ($ix.Enderal.ContainsKey($fk) -or $own.ContainsKey($fk)) { continue }
        if ($keepDangling -contains $fk) {
            if (-not $upstreamText.Contains($fk)) { Fail "$($f.Name): $fk dangles and was not dangling upstream" }
            continue
        }
        Fail "$($f.Name): $fk does not resolve"
    }
}
"1/2 $refs FormKey references across $($files.Count) files"

# ---- 3. assets of copied records
$copied = @($files | Where-Object { $_.Name -like "_AIIE_*" -and $_.Name -notlike '_AIIE_InjectSink*' })
if ($GameData) {
    . (Join-Path $repo '.claude\config\tools.ps1')
    $assets = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($b in Get-ChildItem (Join-Path $GameData '*.bsa')) {
        & $Tools.bsab $b.FullName -l 2>$null | ForEach-Object { if ($_) { [void]$assets.Add($_.Trim().ToLower()) } }
    }
    foreach ($d in 'meshes', 'textures', 'sound') {
        $p = Join-Path $GameData $d
        if (Test-Path $p) { Get-ChildItem $p -Recurse -File | ForEach-Object { [void]$assets.Add($_.FullName.Substring($GameData.Length + 1).ToLower()) } }
    }
    $checked = 0
    foreach ($f in $copied) {
        foreach ($m in [regex]::Matches((Read-KtText $f.FullName), '(?im)^[ \t]*(?:-[ \t]+)?(?:(\w+):[ \t]+)?([^\r\n:]+\.(?:nif|hkx|dds|egt|tri|wav|xwm))[ \t]*(?=\r?$)')) {
            # IkStartNode / GoreTargetBone hold bone-name strings that merely look like paths
            if ($m.Groups[1].Value -in 'IkStartNode', 'GoreTargetBone', 'TargetBone') { continue }
            $p = $m.Groups[2].Value.Trim().ToLower().Replace('/', '\') -replace '^data\\', ''
            $checked++
            $hit = $false
            foreach ($r in '', 'meshes\', 'textures\', 'sound\') {
                if ($assets.Contains($r + $p)) { $hit = $true; break }
                if ($p.EndsWith('.wav') -and $assets.Contains($r + $p.Substring(0, $p.Length - 4) + '.xwm')) { $hit = $true; break }
            }
            if (-not $hit) { Fail "$($f.Name): asset '$p' is not shipped by Enderal" }
        }
    }
    "3   $checked asset paths in $($copied.Count) copied records checked against $($assets.Count) Enderal files"
} else {
    "3   SKIPPED - pass -GameData <Enderal Data folder> to check the copied records' assets"
}

# ---- 4. tomes
$band = @{ '0C44C0:Skyrim.esm' = @('Adept', 10, 200); '0C44C1:Skyrim.esm' = @('Expert', 29, 260); '0C44C2:Skyrim.esm' = @('Master', 38, 310)
           '0C44BC:Skyrim.esm' = @('Adept', 10, 200); '0C44BD:Skyrim.esm' = @('Expert', 29, 260); '0C44BE:Skyrim.esm' = @('Master', 38, 310) }
$hook = @(Get-ChildItem (Join-Path $tree 'LeveledItems') -Filter 'UndercityHehler01_CustomMerchandise*')
$ht = if ($hook.Count -eq 1) { Read-KtText $hook[0].FullName } else { Fail 'fence hook override missing'; '' }
if ($ht -and ($ht -notmatch '(?m)^- UseAll(?=\r?$)' -or $ht -match 'ChanceNone|Global:')) { Fail 'fence hook lost UseAll or gained a gate' }
$books = @(Get-ChildItem (Join-Path $tree 'Books') -Filter '*.yaml')
if ($books.Count -ne 14) { Fail "expected 14 tomes in the patch, found $($books.Count)" }
foreach ($b in $books) {
    $bt = Read-KtText $b.FullName
    $fk = [regex]::Match($bt, '(?m)^FormKey: (.+?)(?=\r?$)').Groups[1].Value
    $gold = [int][regex]::Match($bt, '(?m)^Value: (\d+)').Groups[1].Value
    if ($gold -lt 20 -or $gold -gt 350) { Fail "$($b.Name): $gold gold outside 20-350" }
    if ($ht -notmatch "Reference: $([regex]::Escape($fk))") { Fail "$($b.Name): not stocked by the fence" }
    $sk = [regex]::Match($bt, '(?m)^  Spell: (.+?)(?=\r?$)').Groups[1].Value
    $sp = @(Get-ChildItem (Join-Path $tree 'Spells') -Filter "* - $($sk.Substring(0,6))_AncientBloodII.esl.yaml")
    if ($sp.Count -ne 1) { Fail "$($b.Name): taught spell $sk not overridden"; continue }
    $st = Read-KtText $sp[0].FullName
    $cost = [int][regex]::Match($st, '(?m)^BaseCost: (\d+)').Groups[1].Value
    if ($st -notmatch '(?m)^- ManualCostCalc(?=\r?$)') { Fail "$sk : ManualCostCalc missing" }
    if ($st -match '(?m)^Type: LesserPower(?=\r?$)') { $t = @('Power', 0, 310) }
    else { $t = $band[[regex]::Match($st, '(?m)^HalfCostPerk: (\S+)').Groups[1].Value] }
    if (-not $t) { Fail "$sk : unknown tier"; continue }
    $max = if ($st -match '(?m)^CastType: Concentration(?=\r?$)') { 80 } else { $t[2] }
    if ($cost -lt $t[1] -or $cost -gt $max) { Fail "$sk : cost $cost outside $($t[0]) band $($t[1])-$max" }
    '4   {0,-7} {1,-34} {2,4} mana {3,4} gold' -f $t[0], $sp[0].Name.Split(' ')[0], $cost, $gold
}

# ---- 5. invariants
$bows = @{}
foreach ($w in Get-ChildItem (Join-Path $Upstream 'Weapons') -Filter '*.yaml') {
    $wt = Read-KtText $w.FullName
    if ($wt -match 'AnimationType: Bow') { $bows[[regex]::Match($wt, '(?m)^FormKey: (.+?)(?=\r?$)').Groups[1].Value] = 1 }
}
$archers = 0
foreach ($n in Get-ChildItem (Join-Path $Upstream 'Npcs') -Filter '*.yaml') {
    $ours = Join-Path (Join-Path $tree 'Npcs') $n.Name
    $nt = if (Test-Path $ours) { Read-KtText $ours } else { Read-KtText $n.FullName }
    if ($nt -notmatch '(?m)^\s*- Summonable(?=\r?$)') { continue }
    $items = @([regex]::Matches($nt, '(?m)^    Item: (.+?)(?=\r?$)') | ForEach-Object { $_.Groups[1].Value })
    if (-not @($items | Where-Object { $bows.ContainsKey($_) }).Count) { continue }
    $archers++
    $ammo = @($items | Where-Object { $own.ContainsKey($_) -and $own[$_] -like '*\Ammunitions\*' })
    if (-not $ammo.Count) { Fail "$($n.Name): summon with a bow and no resolvable arrows"; continue }
    foreach ($a in $ammo) {
        $dmg = [double][regex]::Match((Read-KtText $own[$a]), '(?m)^Damage: ([\d.]+)').Groups[1].Value
        if ($dmg -gt 10) { Fail "$($n.Name): arrows $a at $dmg damage, over Enderal's 10" }
    }
}
if ($archers -lt 1) { Fail 'no summoned archers found - the bow check is not seeing the Legion warriors' }
$q = @(Get-ChildItem (Join-Path $tree 'Quests') -Filter '_AII_Injector*')
if ($q.Count -ne 1) { Fail 'inject quest not overridden' } else {
    $qt = Read-KtText $q[0].FullName
    if ($qt -notmatch 'Name: PerkToAdd') { Fail 'inject quest lost PerkToAdd' }
    if (([regex]::Matches($qt, "Object: 000800:$([regex]::Escape($PatchKey))")).Count -ne 2) { Fail 'inject quest does not write both lists into the sink' }
}
"5   $archers summoned archer(s) armed; inject quest perk + sink checked"

if ($fail.Count) { $fail | ForEach-Object { "FAIL $_" }; throw "$($fail.Count) check(s) failed" }
'ALL CHECKS PASSED'
