#requires -Version 5.1
<#
Regenerates src/KittytailConversions/AncientBloodII/AncientBloodIIESP/ - the Enderal patch for
Kittytail's Ancient Blood Magic II (AncientBloodII.esl) - from Kittytail's untouched plugin,
serialized to reference/mods/AncientBloodII/AncientBloodIIESL/ (gitignored; see the README).

A PATCH, not a replacement: AncientBloodII.esl is HEDR 1.70 and loads as shipped. The tree is
WIPED and rebuilt every run (CLAUDE.md guardrail 12); every decision lives in this file and every
step asserts its count.

Unlike Holy Templar Magic, the dead references here cannot be substituted: they are Dawnguard's
vampire-bat effects, the gargoyle race's abilities and body data, and the dragonbone gear, and
Enderal has no records like them. But Enderal DOES ship Dawnguard's ASSETS (meshes\actors\dlc01,
sound\fx\dlc01, ...) - only the records are stubbed. So the dead records are COPIED into this patch
from reference/base/*Real as new ESL records, following their own references until the set closes,
and Kittytail's records are repointed at the copies.

  A. Scope. Process every Kittytail record that touches a DLC master, plus the tomes, the taught
     spells and the inject quest. The two boss fights (placed in Dawnguard worldspaces Enderal does
     not have), their races/skins/death items/music, and the Fort Volkihar vendor chest are left
     alone in Kittytail's plugin: unreachable, so harmless.
  B. Substitute what must not be copied: voice types (the engine finds voice files by PLUGIN name,
     so a copied voice type would be silent), the fishman footstep set (Dragonborn, dragging in a
     MaterialType) -> the gargoyle set being copied anyway, and the boss armour races.
  C. Drop: dead faction memberships, the gargoyle death item, dead armour races, and NPC sound
     templates whose target is gone (Enderal has no AudioTemplate NPCs at all; race sounds apply).
  D. Copy the rest (closure over the *Real trees), de-localized to English.
  E. Dragonbone arrows 25 -> 10 damage (Enderal's arrow ceiling, _30E_AeternaArrow).
  F. Mana and gold rescaled onto Enderal's bands; Cascading Torment (Concentration) set to Enderal's
     Expert-Elementalism concentration ceiling.
  G. The inject quest's two vanilla leveled lists -> one empty sink list, so the script still runs
     its Game.GetPlayer().AddPerk() - that perk is what lets The Eternal Legion summon three.
  H. "Swordstress of Oblivion" renamed. The 14 tomes stocked by the Undercity fence.
#>
param([string]$Upstream)
. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tools\KittytailCommon.ps1')

$modRoot = Split-Path -Parent $PSScriptRoot
$repo    = Get-KtRepo
if (-not $Upstream) { $Upstream = Join-Path $repo 'reference\mods\AncientBloodII\AncientBloodIIESL' }
$out     = Join-Path $modRoot 'AncientBloodIIESP'
$fsTree  = Join-Path $repo 'reference\base\EnderalFS'
$ModKey  = 'AncientBloodII.esl'
$PatchKey = 'Ancient Blood II - Enderal.esp'
$PatchRx  = [regex]::Escape($PatchKey)

if (-not (Test-Path (Join-Path $Upstream 'RecordData.yaml'))) { throw "Upstream tree not found at $Upstream - serialize AncientBloodII.esl there first (see README)." }
if ((Read-KtText (Join-Path $Upstream 'RecordData.yaml')) -notmatch 'ModKey: AncientBloodII\.esl') { throw "$Upstream is not AncientBloodII.esl" }

"Loading FormKey index..."
$ix = Get-KtFormKeyIndex
$fkRx = '([0-9A-F]{6}):([^\r\n]+?\.(?:esm|esp|esl))(?=\r?\n|$)'
function Test-Dead([string]$fk) {
    $master = $fk.Substring(7)
    if ($master -eq $ModKey -or $master -eq $PatchKey) { return $false }
    return -not $ix.Enderal.ContainsKey($fk)
}

# ------------------------------------------------------------------ decision tables
# B. substitutes. A target may itself be a dead record; it is then copied by stage D like any other.
$subst = [ordered]@{
    '00F8AE:Dawnguard.esm'  = '01F289:Skyrim.esm'      # CrGargoyleVoice      -> CrTrollVoice
    '009400:Dawnguard.esm'  = '01F152:Skyrim.esm'      # CrChaurusInsectVoice -> CrChaurusVoice
    '011CD6:Dawnguard.esm'  = '01F1CD:Skyrim.esm'      # CrMistmanVoice       -> CrDraugrVoice (the Legion NPCs already use it)
    '01F14C:Dragonborn.esm' = '00F8AD:Dawnguard.esm'   # fishman footsteps    -> gargoyle footsteps (copied)
}
# C. list items / fields to delete, by target FormKey
$dropListItems = @('018C4F:Dawnguard.esm', '00A2C6:Dawnguard.esm', '019D86:Dawnguard.esm')   # VampireCompanionFaction; gargoyle races in AdditionalRaces
$dropFieldLines = @('DeathItem: 01913E:Dawnguard.esm')                                       # DLC1DeathItemGargoyle
# Vanilla records Enderal deleted that stay dangling in records we override anyway. Proven harmless
# (CLAUDE.md "Don't give a patch you author a DLC master"); asserted so a new one cannot slip in.
$keepDangling = @('02430D:Skyrim.esm', '058F68:Skyrim.esm', '103A8F:Skyrim.esm', '103A90:Skyrim.esm', '106253:Skyrim.esm')
# Vanilla records Enderal deleted that the player DOES see - copied like the DLC ones.
$copyVanilla = @('08ADB0:Skyrim.esm', '0F651B:Skyrim.esm', '0E5F50:Skyrim.esm')   # tome inventory art, sword enchantment, gargoyle summon's absorb effect

$skipGroups = @('Worldspaces', 'Containers', 'MusicTypes')
$skipEdid   = '^_AII_(Boss|DPriest|AbBoss|AbDragonPriestBoss|DeathItem|SkinGargoyleBoss|SkinDPriestBoss|GargoyleBossAA)'

# ------------------------------------------------------------------ wipe + header
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
Write-KtText (Join-Path $out 'RecordData.yaml') ((@(
    'SpriggitSource:', '  PackageName: Spriggit.Yaml.Skyrim', '  Version: 0.40',
    "ModKey: $PatchKey", 'GameRelease: EnderalSE', 'ModHeader:', '  Flags:', '  - Small',
    '  Stats:', '    Version: 1.7',
    '  Author: WhisperDealer (Ancient Blood Magic II by Kittytail)',
    "  Description: Enderal conversion patch for Kittytail's Ancient Blood Magic II. Requires AncientBloodII.esl.",
    '  MasterReferences:', '  - Master: Skyrim.esm', '    FileSize: 0',
    '  - Master: Enderal - Forgotten Stories.esm', '    FileSize: 0',
    "  - Master: $ModKey", '    FileSize: 0', '  INTV: 1', '') -join "`r`n"))
Write-KtText (Join-Path $out 'spriggit-meta.json') ((@('{', '  "PackageName": "Spriggit.Yaml.Skyrim",', '  "Version": "0.40.0",', '  "Release": "EnderalSE",', "  `"ModKey`": `"$PatchKey`"", '}') -join "`r`n"))

# ------------------------------------------------------------------ A. scope
$records = @{}   # upstream FormKey -> @{ Group; Name; Text; Edid }
foreach ($f in Get-ChildItem $Upstream -Recurse -Filter '*.yaml') {
    if ($f.Name -eq 'RecordData.yaml' -and $f.DirectoryName -eq $Upstream) { continue }
    $t = Read-KtText $f.FullName
    $m = [regex]::Match($t, '(?m)^FormKey: (.+?)(?=\r?$)')
    if (-not $m.Success) { continue }
    $grp = $f.FullName.Substring($Upstream.Length + 1).Split('\')[0]
    $records[$m.Groups[1].Value] = @{ Group = $grp; Name = $f.Name; Text = $t; Edid = [regex]::Match($t, '(?m)^EditorID: (\S+)').Groups[1].Value }
}
$tomes = @($records.Keys | Where-Object { $records[$_].Group -eq 'Books' } | Sort-Object)
if ($tomes.Count -ne 14) { throw "Expected 14 tomes upstream, found $($tomes.Count)" }
$taught = @{}
foreach ($b in $tomes) {
    $sm = [regex]::Match($records[$b].Text, '(?m)^  Spell: ([0-9A-F]{6}:AncientBloodII\.esl)')
    if (-not $sm.Success) { throw "$($records[$b].Edid) teaches no AncientBloodII spell" }
    $taught[$sm.Groups[1].Value] = $b
}
$injector = '000908:AncientBloodII.esl'

$work = [ordered]@{}   # FormKey -> current text
foreach ($k in ($records.Keys | Sort-Object)) {
    $r = $records[$k]
    if ($r.Group -in $skipGroups -or $r.Edid -match $skipEdid) { continue }
    $touchesDlc = $r.Text -match ':(Dawnguard|Dragonborn|HearthFires)\.esm'
    $needsVanilla = @($copyVanilla | Where-Object { $r.Text.Contains($_) }).Count -gt 0
    if ($touchesDlc -or $needsVanilla -or $tomes -contains $k -or $taught.ContainsKey($k) -or $k -eq $injector) { $work[$k] = $r.Text }
}
"  A   $($work.Count) Kittytail records in scope"

# ------------------------------------------------------------------ B + C
$nSubst = @{}; foreach ($s in $subst.Keys) { $nSubst[$s] = 0 }
$nDropItem = 0; $nDropField = 0; $nDropSound = 0
foreach ($k in @($work.Keys)) {
    $t = $work[$k]
    foreach ($s in $subst.Keys) {
        $c = ([regex]::Matches($t, [regex]::Escape($s))).Count
        if ($c) { $nSubst[$s] += $c; $t = $t.Replace($s, $subst[$s]) }
    }
    foreach ($d in $dropListItems) { $res = Remove-KtListItem $t $d; $t = $res[0]; $nDropItem += $res[1] }
    foreach ($d in $dropFieldLines) {
        $rx = "(?m)^$([regex]::Escape($d))\r?\n"
        $c = ([regex]::Matches($t, $rx)).Count
        if ($c) { $nDropField += $c; $t = [regex]::Replace($t, $rx, '') }
    }
    $snd = [regex]::Match($t, '(?m)^  InheritsSoundsFrom: (.+?)(?=\r?$)')
    if ($snd.Success -and (Test-Dead $snd.Groups[1].Value)) {
        $res = Remove-KtTopLevelBlock $t 'Sound'
        if ($res[1] -ne 1) { throw "$k : could not remove its Sound: block" }
        $t = $res[0]; $nDropSound++
    }
    $work[$k] = $t
}
$expectSubst = @{ '00F8AE:Dawnguard.esm' = 4; '009400:Dawnguard.esm' = 1; '011CD6:Dawnguard.esm' = 2; '01F14C:Dragonborn.esm' = 1 }
foreach ($s in $subst.Keys) {
    if ($nSubst[$s] -ne $expectSubst[$s]) { throw "Substitution $s : expected $($expectSubst[$s]), found $($nSubst[$s])" }
}
if ($nDropItem -ne 1) { throw "Expected 1 dropped list item (Familiar's VampireCompanionFaction), found $nDropItem" }
if ($nDropField -ne 1) { throw "Expected 1 dropped DeathItem, found $nDropField" }
if ($nDropSound -ne 7) { throw "Expected 7 dead sound templates dropped (6 Legion + Familiar), found $nDropSound" }
"  B   substitutes: " + (($subst.Keys | ForEach-Object { "$_ x$($nSubst[$_])" }) -join ', ')
"  C   dropped 1 faction entry, 1 death item, $nDropSound sound templates"

# ------------------------------------------------------------------ D. closure over the *Real trees
$seeds = New-Object System.Collections.Generic.List[string]
foreach ($k in $work.Keys) {
    foreach ($m in [regex]::Matches($work[$k], $fkRx)) {
        $fk = "$($m.Groups[1].Value):$($m.Groups[2].Value)"
        if (-not (Test-Dead $fk)) { continue }
        if ($keepDangling -contains $fk) { continue }
        if ($fk -match ':(Dawnguard|Dragonborn|HearthFires)\.esm$' -or $copyVanilla -contains $fk) { $seeds.Add($fk); continue }
        if ($k -eq $injector) { continue }   # its two vanilla lists are handled in G
        throw "$($records[$k].Edid): dead vanilla reference $fk has no decision - add it to `$copyVanilla or `$keepDangling"
    }
}
$copy = [ordered]@{}   # source FormKey -> @{ Path; Text }
$q = New-Object System.Collections.Queue
foreach ($s in ($seeds | Sort-Object -Unique)) { $q.Enqueue($s) }
while ($q.Count) {
    $fk = $q.Dequeue()
    if ($copy.Contains($fk)) { continue }
    if (-not $ix.Real.ContainsKey($fk)) { throw "Dead record $fk has no source YAML in reference/base/*Real" }
    $src = $ix.Real[$fk]
    $t = Read-KtText $src
    foreach ($s in $subst.Keys) { $t = $t.Replace($s, $subst[$s]) }
    $copy[$fk] = @{ Path = $src; Text = $t }
    foreach ($m in [regex]::Matches($t, $fkRx)) {
        $ref = "$($m.Groups[1].Value):$($m.Groups[2].Value)"
        if ($ref -ne $fk -and (Test-Dead $ref)) { $q.Enqueue($ref) }
    }
}
$expectCopies = 70
if ($copy.Count -ne $expectCopies) {
    $copy.Keys | ForEach-Object { "    $_  $([IO.Path]::GetFileName($copy[$_].Path))" }
    throw "Copy closure: expected $expectCopies records, got $($copy.Count) - upstream or reference/base changed; review the list above"
}

# FormIDs: 0x800 = inject sink; copies from 0x810 in sorted source order, so a regeneration
# reassigns the same IDs as long as the copy set is unchanged.
$sinkKey = "000800:$PatchKey"
$newKey = @{}; $n = 0x810
foreach ($fk in ($copy.Keys | Sort-Object)) { $newKey[$fk] = ('{0:X6}:{1}' -f $n, $PatchKey); $n++ }
if ($n -gt 0x1000) { throw 'ESL FormID range exhausted' }
function Update-Refs([string]$t) { foreach ($fk in $newKey.Keys) { $t = $t.Replace($fk, $newKey[$fk]) }; return $t }

foreach ($fk in $copy.Keys) {
    $src = $copy[$fk]
    $grp = ($src.Path -split '\\base\\')[1].Split('\')[1]
    $edid = [regex]::Match($src.Text, '(?m)^EditorID: (\S+)').Groups[1].Value
    if (-not $edid) { throw "$fk has no EditorID" }
    $t = ConvertTo-KtUnlocalized (Update-Refs $src.Text)
    $t = [regex]::Replace($t, '(?m)^EditorID: \S+', "EditorID: _AIIE_$edid")
    $hex = $newKey[$fk].Substring(0, 6)
    Write-KtText (Join-Path (Join-Path $out $grp) "_AIIE_$edid - ${hex}_$PatchKey.yaml") $t
}
"  D   copied $($copy.Count) dead records into the patch ($('{0:X3}' -f 0x810)-$('{0:X3}' -f ($n - 1)))"

# ------------------------------------------------------------------ write the in-scope records
foreach ($k in @($work.Keys)) { $work[$k] = Update-Refs $work[$k] }
function Get-OutPath([string]$fk) { $r = $records[$fk]; Join-Path (Join-Path $out $r.Group) $r.Name }

# ------------------------------------------------------------------ E. dragonbone arrow damage
$arrow = $newKey['0176F4:Dawnguard.esm']
$af = @(Get-ChildItem (Join-Path $out 'Ammunitions') -Filter "* - $($arrow.Substring(0,6))_*")
if ($af.Count -ne 1) { throw 'copied DLC1DragonboneArrow not found' }
$at = Read-KtText $af[0].FullName
if (([regex]::Matches($at, '(?m)^Damage: 25(?=\r?$)')).Count -ne 1) { throw 'DLC1DragonboneArrow damage is no longer 25' }
Write-KtText $af[0].FullName ([regex]::Replace($at, '(?m)^Damage: 25(?=\r?$)', 'Damage: 10'))
"  E   dragonbone arrow damage 25 -> 10"

# ------------------------------------------------------------------ F. mana + gold
$tierOf = @{
    '0C44C0:Skyrim.esm' = 'Adept'; '0C44C1:Skyrim.esm' = 'Expert'; '0C44C2:Skyrim.esm' = 'Master'
    '0C44BC:Skyrim.esm' = 'Adept'; '0C44BD:Skyrim.esm' = 'Expert'; '0C44BE:Skyrim.esm' = 'Master'
}
# ratio = Enderal tier p75 / Kittytail tier median (Adept 162, Expert 331, Master 789), checked
# against Enderal's tier ceilings 200 / 260 / 310.
$manaRatio = @{ Adept = 0.49; Expert = 0.33; Master = 0.215 }
$manaMax   = @{ Adept = 200; Expert = 260; Master = 310 }
$manaFloor = @{ Adept = 34; Expert = 49; Master = 68 }
# Enderal's Expert Elementalism concentration spells: Flame Bite 40, Wall of Lightning 50, Grounding 50.
$concentrationCost = @{ Expert = 50 }
# Gold onto Enderal's 20-350 tome range. Kittytail prices Adept 400-720, Expert 625-925,
# Master 1750-1800; powers 940 / 1300.
$goldRatio = @{ Adept = 0.45; Expert = 0.36; Master = 0.19; Power = 0.26 }

foreach ($sk in ($taught.Keys | Sort-Object)) {
    $t = $work[$sk]
    $cost = [regex]::Matches($t, '(?m)^BaseCost: (\d+)(?=\r?$)')
    if ($cost.Count -ne 1) { throw "$sk : expected one BaseCost" }
    if ($t -notmatch '(?m)^- ManualCostCalc(?=\r?$)') { throw "$sk : ManualCostCalc not set" }
    $old = [int]$cost[0].Groups[1].Value
    $perk = [regex]::Match($t, '(?m)^HalfCostPerk: (\S+)').Groups[1].Value
    if ($t -match '(?m)^Type: LesserPower(?=\r?$)') {
        $tier = 'Power'; $new = $old
        if ($new -gt 310) { throw "$sk : power cost $new over Enderal's 310 ceiling" }
    } else {
        if (-not $tierOf.ContainsKey($perk)) { throw "$sk : unknown HalfCostPerk $perk" }
        $tier = $tierOf[$perk]
        if ($t -match '(?m)^CastType: Concentration(?=\r?$)') {
            if (-not $concentrationCost.ContainsKey($tier)) { throw "$sk : no concentration cost for $tier" }
            $new = $concentrationCost[$tier]
        } else {
            $new = Get-KtRound5 ($old * $manaRatio[$tier])
            if ($new -lt $manaFloor[$tier]) { $new = $manaFloor[$tier] }
            if ($new -gt $manaMax[$tier]) { throw "$sk : $new over Enderal's $tier ceiling $($manaMax[$tier])" }
        }
    }
    $work[$sk] = [regex]::Replace($t, '(?m)^BaseCost: \d+(?=\r?$)', "BaseCost: $new")

    $bk = $taught[$sk]
    $bt = $work[$bk]
    $val = [regex]::Matches($bt, '(?m)^Value: (\d+)(?=\r?$)')
    if ($val.Count -ne 1) { throw "$bk : expected one top-level Value" }
    $oldG = [int]$val[0].Groups[1].Value
    $newG = Get-KtRound5 ($oldG * $goldRatio[$tier])
    if ($newG -lt 20 -or $newG -gt 350) { throw "$bk : $newG gold outside 20-350" }
    $work[$bk] = [regex]::Replace($bt, '(?m)^Value: \d+(?=\r?$)', "Value: $newG")
    '  F   {0,-7} {1,-34} mana {2,5} -> {3,-4} gold {4,5} -> {5}' -f $tier, $records[$sk].Edid, $old, $new, $oldG, $newG
}

# ------------------------------------------------------------------ G. inject quest -> sink
$qt = $work[$injector]
$nq = 0
foreach ($dead in '10FACA:Skyrim.esm', '04C165:Skyrim.esm') {
    $c = ([regex]::Matches($qt, [regex]::Escape("Object: $dead"))).Count
    if ($c -ne 1) { throw "Injector: expected 1 property on $dead, found $c" }
    $qt = $qt.Replace("Object: $dead", "Object: $sinkKey"); $nq++
}
if ($qt -notmatch 'Name: PerkToAdd') { throw 'Injector lost its PerkToAdd property' }
$work[$injector] = $qt
Write-KtText (Join-Path (Join-Path $out 'LeveledItems') "_AIIE_InjectSink - 000800_$PatchKey.yaml") ((@(
    "FormKey: $sinkKey", 'EditorID: _AIIE_InjectSink', '') -join "`r`n"))
"  G   inject script's 2 leveled lists -> _AIIE_InjectSink; its AddPerk still runs"

# ------------------------------------------------------------------ H. rename + merchant hook
$sw = '0008BA:AncientBloodII.esl'
if (([regex]::Matches($work[$sw], 'Value: Swordstress of Oblivion')).Count -ne 1) { throw 'Swordstress of Oblivion not found' }
$work[$sw] = $work[$sw].Replace('Value: Swordstress of Oblivion', 'Value: Swordstress of Ruin')
"  H   'Swordstress of Oblivion' -> 'Swordstress of Ruin'"

foreach ($k in $work.Keys) { Write-KtText (Get-OutPath $k) $work[$k] }

# The Undercity fence (_00E_UndercityHehler01, "Fence", Undercity barracks; chest
# _00E_Merchant_UCHehler01, 1450 gold). Its hook is in the FS, EGO and Leveling Redone chests alike,
# and no release in this repo overrides it (CLAUDE.md "Merchant hooks ... are shared ground").
$hookSrc = @(Get-ChildItem (Join-Path $fsTree 'LeveledItems') -Filter 'UndercityHehler01_CustomMerchandise - 030306_*.yaml')
if ($hookSrc.Count -ne 1) { throw 'UndercityHehler01_CustomMerchandise not found in reference/base/EnderalFS' }
$hk = (Read-KtText $hookSrc[0].FullName).TrimEnd("`r", "`n")
if ($hk -match 'Entries:') { throw 'The fence''s hook is no longer empty in FS - merge instead' }
$entries = foreach ($b in $tomes) { '- Data:'; '    Level: 1'; "    Reference: $b"; '    Count: 1' }
Write-KtText (Join-Path (Join-Path $out 'LeveledItems') $hookSrc[0].Name) ($hk + "`r`nEntries:`r`n" + ($entries -join "`r`n") + "`r`n")
"  H   $($tomes.Count) tomes stocked via UndercityHehler01_CustomMerchandise"

# ------------------------------------------------------------------ final guard
$bad = New-Object System.Collections.Generic.List[string]
foreach ($f in Get-ChildItem $out -Recurse -Filter '*.yaml') {
    foreach ($m in [regex]::Matches((Read-KtText $f.FullName), $fkRx)) {
        $fk = "$($m.Groups[1].Value):$($m.Groups[2].Value)"
        if ($fk -match ':(Dawnguard|Dragonborn|HearthFires)\.esm$') { $bad.Add("$($f.Name): $fk (DLC)") }
        elseif ((Test-Dead $fk) -and $keepDangling -notcontains $fk) { $bad.Add("$($f.Name): $fk (dead)") }
    }
}
if ($bad.Count) { $bad | Select-Object -First 30; throw "$($bad.Count) unresolved references survived" }
"Done: $(@(Get-ChildItem $out -Recurse -Filter '*.yaml').Count - 1) record files in $out"
