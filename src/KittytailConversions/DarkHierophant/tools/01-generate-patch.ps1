#requires -Version 5.1
<#
Regenerates src/KittytailConversions/DarkHierophant/DarkHierophantESP/ - the Enderal patch for
Kittytail's Dark Hierophant Magic (Ghostlight.esl) - from Kittytail's untouched plugin, serialized
to reference/mods/DarkHierophant/GhostlightESL/ (gitignored; see the README).

A PATCH, not a replacement: Ghostlight.esl is HEDR 1.70 and loads as shipped. The tree is WIPED and
rebuilt every run (CLAUDE.md guardrail 12); every step asserts its count.

This is the cleanest of the three Kittytail mods. Of the 119 records the player's spells reach,
exactly ONE external reference is dead - the tomes' inventory art, a Dawnguard static. What breaks
in Enderal is how the tomes are obtained, and the mana scale:

  A. Distribution. Every tome is CRAFTED at the "Ghostlight Altar", a workbench placed only in the
     Forgotten Vale temple (DLC1FalmerTemple01, a Dawnguard cell Enderal does not have). Moving the
     altar would not help: the ten recipes need 20 filled black soul gems and 20 ghost wrappings,
     and the whole of Enderal contains TWO filled black soul gems (one container, one placed) and
     ghost wrappings only in fixed containers - none in any leveled list. So the tomes are SOLD
     instead, by Mirella Godshand in Ark through her empty Mirella_CustomMerchandise hook. The
     recipes, the altar and the temple cell are left alone in Kittytail's plugin: unreachable,
     harmless.
  B. Tome prices. Kittytail priced every tome at 100 because the recipe was the real cost; they are
     authored per tier onto Enderal's 20-350 range, matching the other two Kittytail patches.
  C. Mana. Costs run to 4500 (Ordinance of Light) against Enderal's 310 ceiling. Per-tier ratio
     (CLAUDE.md "A ported spell's MANA COST"); Absolution is Concentration and takes Enderal's Expert
     Elementalism concentration ceiling.
  D. The Dawnguard inventory-art static is copied into the patch (Enderal ships its mesh).
#>
param([string]$Upstream)
. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tools\KittytailCommon.ps1')

$modRoot  = Split-Path -Parent $PSScriptRoot
$repo     = Get-KtRepo
if (-not $Upstream) { $Upstream = Join-Path $repo 'reference\mods\DarkHierophant\GhostlightESL' }
$out      = Join-Path $modRoot 'DarkHierophantESP'
$fsTree   = Join-Path $repo 'reference\base\EnderalFS'
$ModKey   = 'Ghostlight.esl'
$PatchKey = 'Dark Hierophant - Enderal.esp'

if (-not (Test-Path (Join-Path $Upstream 'RecordData.yaml'))) { throw "Upstream tree not found at $Upstream - serialize Ghostlight.esl there first (see README)." }
if ((Read-KtText (Join-Path $Upstream 'RecordData.yaml')) -notmatch 'ModKey: Ghostlight\.esl') { throw "$Upstream is not Ghostlight.esl" }

"Loading FormKey index..."
$ix = Get-KtFormKeyIndex
$fkRx = '([0-9A-F]{6}):([^\r\n]+?\.(?:esm|esp|esl))(?=\r?\n|$)'

# ------------------------------------------------------------------ wipe + header
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
Write-KtText (Join-Path $out 'RecordData.yaml') ((@(
    'SpriggitSource:', '  PackageName: Spriggit.Yaml.Skyrim', '  Version: 0.40',
    "ModKey: $PatchKey", 'GameRelease: EnderalSE', 'ModHeader:', '  Flags:', '  - Small',
    '  Stats:', '    Version: 1.7',
    '  Author: WhisperDealer (Dark Hierophant Magic by Kittytail)',
    "  Description: Enderal conversion patch for Kittytail's Dark Hierophant Magic. Requires Ghostlight.esl.",
    '  MasterReferences:', '  - Master: Skyrim.esm', '    FileSize: 0',
    '  - Master: Enderal - Forgotten Stories.esm', '    FileSize: 0',
    "  - Master: $ModKey", '    FileSize: 0', '  INTV: 1', '') -join "`r`n"))
Write-KtText (Join-Path $out 'spriggit-meta.json') ((@('{', '  "PackageName": "Spriggit.Yaml.Skyrim",', '  "Version": "0.40.0",', '  "Release": "EnderalSE",', "  `"ModKey`": `"$PatchKey`"", '}') -join "`r`n"))

# ------------------------------------------------------------------ scope: tomes + taught spells
$books = @(Get-ChildItem (Join-Path $Upstream 'Books') -Filter '*.yaml' | Sort-Object Name)
if ($books.Count -ne 10) { throw "Expected 10 tomes upstream, found $($books.Count)" }
$work = [ordered]@{}   # output path -> text
$pairs = @()
foreach ($b in $books) {
    $bt = Read-KtText $b.FullName
    $sm = [regex]::Match($bt, '(?m)^  Spell: ([0-9A-F]{6}):Ghostlight\.esl(?=\r?$)')
    if (-not $sm.Success) { throw "$($b.Name) teaches no Ghostlight spell" }
    $sf = @(Get-ChildItem (Join-Path $Upstream 'Spells') -Filter "* - $($sm.Groups[1].Value)_Ghostlight.esl.yaml")
    if ($sf.Count -ne 1) { throw "$($b.Name): taught spell file not found" }
    $bp = Join-Path (Join-Path $out 'Books') $b.Name
    $sp = Join-Path (Join-Path $out 'Spells') $sf[0].Name
    $work[$bp] = $bt
    $work[$sp] = Read-KtText $sf[0].FullName
    $pairs += , @($bp, $sp)
}

# ------------------------------------------------------------------ D. dead references -> copies
$dead = New-Object System.Collections.Generic.List[string]
foreach ($p in $work.Keys) {
    foreach ($m in [regex]::Matches($work[$p], $fkRx)) {
        $fk = "$($m.Groups[1].Value):$($m.Groups[2].Value)"
        if ($fk.EndsWith(":$ModKey") -or $ix.Enderal.ContainsKey($fk)) { continue }
        $dead.Add($fk)
    }
}
$seeds = @($dead | Sort-Object -Unique)
if ($seeds.Count -ne 1 -or $seeds[0] -ne '011E21:Dawnguard.esm') { throw "Expected exactly one dead reference (011E21:Dawnguard.esm HighPolyDLC01DwemerBook01), found: $($seeds -join ', ')" }
$map = Copy-KtDeadRecords -Seeds $seeds -Index $ix -OutDir $out -PatchKey $PatchKey -EdidPrefix '_BLE_'
if ($map.Count -ne 1) { throw "Copy closure: expected 1 record, got $($map.Count)" }
foreach ($p in @($work.Keys)) { foreach ($k in $map.Keys) { $work[$p] = $work[$p].Replace($k, $map[$k]) } }
"  D   copied HighPolyDLC01DwemerBook01 -> $($map['011E21:Dawnguard.esm']) (tome inventory art on 10 tomes)"

# ------------------------------------------------------------------ B + C. prices and mana
$tierOf = @{ '0C44C0:Skyrim.esm' = 'Adept'; '0C44C1:Skyrim.esm' = 'Expert'; '0C44C2:Skyrim.esm' = 'Master' }
# ratio = Enderal tier p75 / Kittytail tier median (Adept 365, Expert 1245, Master 3088), checked
# against the tier ceilings 200 / 260 / 310. The ratios are severe because the source is.
$manaRatio = @{ Adept = 0.22; Expert = 0.088; Master = 0.055 }
$manaMax   = @{ Adept = 200; Expert = 260; Master = 310 }
$manaFloor = @{ Adept = 34; Expert = 49; Master = 68 }
$concentrationCost = @{ Expert = 50 }   # Flame Bite 40, Wall of Lightning 50, Grounding 50
# Kittytail's 100-gold-everywhere was a crafting price; authored per tier against the other two
# Kittytail patches (Adept 150-325, Expert 225-335, Master 300-340).
$gold = @{ Adept = 180; Expert = 270; Master = 340 }

foreach ($pr in $pairs) {
    $bp = $pr[0]; $sp = $pr[1]
    $st = $work[$sp]
    if ($st -notmatch '(?m)^- ManualCostCalc(?=\r?$)') { throw "$sp : ManualCostCalc not set" }
    $perk = [regex]::Match($st, '(?m)^HalfCostPerk: (.+?)(?=\r?$)').Groups[1].Value
    if (-not $tierOf.ContainsKey($perk)) { throw "$sp : unknown HalfCostPerk '$perk'" }
    $tier = $tierOf[$perk]
    $cm = [regex]::Matches($st, '(?m)^BaseCost: (\d+)(?=\r?$)')
    if ($cm.Count -ne 1) { throw "$sp : expected one BaseCost" }
    $old = [int]$cm[0].Groups[1].Value
    if ($st -match '(?m)^CastType: Concentration(?=\r?$)') {
        if (-not $concentrationCost.ContainsKey($tier)) { throw "$sp : no concentration cost for $tier" }
        $new = $concentrationCost[$tier]
    } else {
        $new = Get-KtRound5 ($old * $manaRatio[$tier])
        if ($new -lt $manaFloor[$tier]) { $new = $manaFloor[$tier] }
        if ($new -gt $manaMax[$tier]) { throw "$sp : $new over Enderal's $tier ceiling $($manaMax[$tier])" }
    }
    $work[$sp] = [regex]::Replace($st, '(?m)^BaseCost: \d+(?=\r?$)', "BaseCost: $new")

    $bt = $work[$bp]
    $vm = [regex]::Matches($bt, '(?m)^Value: (\d+)(?=\r?$)')
    if ($vm.Count -ne 1) { throw "$bp : expected one top-level Value" }
    if ([int]$vm[0].Groups[1].Value -ne 100) { throw "$bp : upstream price is no longer 100 - revisit the authored prices" }
    $work[$bp] = [regex]::Replace($bt, '(?m)^Value: \d+(?=\r?$)', "Value: $($gold[$tier])")
    '  B/C {0,-7} {1,-28} mana {2,5} -> {3,-4} gold 100 -> {4}' -f $tier, ([IO.Path]::GetFileName($sp)).Split(' ')[0], $old, $new, $gold[$tier]
}
foreach ($p in $work.Keys) { Write-KtText $p $work[$p] }

# ------------------------------------------------------------------ A. Mirella's hook
# Mirella Godshand (_00E_CapitalCity_Mirella, TrainerIllusionMaster), Ark, chest
# _00E_Merchant_CCMirellasAlchemy (2135 gold, already stocks Enderal's spell-book vendor list). Her
# hook is in the FS, EGO and Leveling Redone chests alike; no release in this repo overrides it.
$hookSrc = @(Get-ChildItem (Join-Path $fsTree 'LeveledItems') -Filter 'Mirella_CustomMerchandise - 0302DF_*.yaml')
if ($hookSrc.Count -ne 1) { throw 'Mirella_CustomMerchandise not found in reference/base/EnderalFS' }
$hk = (Read-KtText $hookSrc[0].FullName).TrimEnd("`r", "`n")
if ($hk -match 'Entries:') { throw 'Mirella''s hook is no longer empty in FS - merge instead' }
$entries = foreach ($b in $books) {
    $hex = [regex]::Match($b.Name, ' - ([0-9A-F]{6})_Ghostlight').Groups[1].Value
    '- Data:'; '    Level: 1'; "    Reference: ${hex}:$ModKey"; '    Count: 1'
}
Write-KtText (Join-Path (Join-Path $out 'LeveledItems') $hookSrc[0].Name) ($hk + "`r`nEntries:`r`n" + ($entries -join "`r`n") + "`r`n")
"  A   $($books.Count) tomes stocked via Mirella_CustomMerchandise"

# ------------------------------------------------------------------ final guard
$bad = @(Get-ChildItem $out -Recurse -Filter '*.yaml' | Select-String -Pattern ':(Dawnguard|Dragonborn|HearthFires)\.esm')
if ($bad.Count) { throw "DLC references survived:`n$($bad -join "`n")" }
"Done: $(@(Get-ChildItem $out -Recurse -Filter '*.yaml').Count - 1) record files in $out"
