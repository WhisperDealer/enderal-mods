#requires -Version 5.1
<#
Regenerates src/KittytailConversions/HolyTemplarMagic/HolyTemplarMagicESP/ - the Enderal patch for
Kittytail's Holy Templar Magic (Lightpower.esl) - from Kittytail's untouched plugin, serialized to
reference/mods/HolyTemplarMagic/LightpowerESL/ (gitignored; see the README for the command).

The patch is a PATCH, not a replacement: Lightpower.esl is HEDR 1.70 and its DLC masters are stubs
the engine force-loads, so it loads in Enderal as shipped. Everything wrong with it is fixable by
overriding its own records, which needs no redistribution of Kittytail's plugin.

The tree is WIPED and rebuilt on every run (CLAUDE.md guardrail 12), so every decision lives here.
Every substitution asserts an exact match count and throws otherwise.

  A. DLC references -> Enderal records. 47 MGEF/spell menu icons, 31 casting arts, 31 hit shaders,
     impact sets, sounds and script shader properties point into Dawnguard.esm / Dragonborn.esm,
     which are empty stubs in Enderal, so every one of those visuals resolved to nothing. They are
     repointed onto vanilla's Turn Undead / Bane of the Undead family, which Enderal kept and uses
     for its own light-versus-undead spells. Image-space modifiers have no counterpart and are
     dropped (a null IMOD is simply no screen flash).
  B. The NPC variants' friendly-fire conditions excluded the Vigilants of Stendarr and the
     Dawnguard - neither exists. They now exclude the Sun Temple factions, which is who the SPID
     ini gives the spells to.
  C. Mana costs rescaled onto Enderal's authored bands (see CLAUDE.md "A ported spell's MANA COST").
  D. Tome prices rescaled onto Enderal's 20-350 tome range.
  E. Consecrate Dead's self-heal (Blessing) pays Arcane Fever, like every Enderal healing spell.
  F. The two inject quests lose their scripts. They AddForm into five vanilla leveled lists, none of
     which exist in Enderal, so they did nothing but log errors.
  G. The six tomes are stocked through Halda Stronghand's empty merchandise hook in the Sun Temple.
#>
param(
    [string]$Upstream
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modRoot = Split-Path -Parent $PSScriptRoot
$repo    = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $modRoot))
if (-not $Upstream) { $Upstream = Join-Path $repo 'reference\mods\HolyTemplarMagic\LightpowerESL' }
$out     = Join-Path $modRoot 'HolyTemplarMagicESP'
$fsTree  = Join-Path $repo 'reference\base\EnderalFS'

$PatchKey = 'Holy Templar Magic - Enderal.esp'
$enc = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path (Join-Path $Upstream 'RecordData.yaml'))) {
    throw "Upstream tree not found at $Upstream - serialize Lightpower.esl there first (see README)."
}
$upHeader = [IO.File]::ReadAllText((Join-Path $Upstream 'RecordData.yaml'))
if ($upHeader -notmatch 'ModKey: Lightpower\.esl') { throw "$Upstream is not Lightpower.esl" }

function Read-Text([string]$p) { [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) }
function Write-Text([string]$p, [string]$t) {
    $d = Split-Path -Parent $p
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force $d | Out-Null }
    [IO.File]::WriteAllText($p, $t, $enc)
}
function Get-UpstreamFile([string]$group, [string]$hex) {
    $f = @(Get-ChildItem (Join-Path $Upstream $group) -Filter "* - ${hex}_Lightpower.esl.yaml")
    if ($f.Count -ne 1) { throw "$group/$hex : expected 1 upstream file, found $($f.Count)" }
    return $f[0]
}
# The patch's copy of an upstream record if stage A already wrote one, else a fresh copy.
function Get-PatchFile([string]$group, [string]$hex) {
    $u = Get-UpstreamFile $group $hex
    $p = Join-Path (Join-Path $out $group) $u.Name
    if (-not (Test-Path $p)) { Write-Text $p (Read-Text $u.FullName) }
    return $p
}

# ---------------------------------------------------------------- wipe + header
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null

Write-Text (Join-Path $out 'RecordData.yaml') (@(
    'SpriggitSource:'
    '  PackageName: Spriggit.Yaml.Skyrim'
    '  Version: 0.40'
    "ModKey: $PatchKey"
    'GameRelease: EnderalSE'
    'ModHeader:'
    '  Flags:'
    '  - Small'
    '  Stats:'
    '    Version: 1.7'
    '  Author: WhisperDealer (Holy Templar Magic by Kittytail)'
    "  Description: Enderal conversion patch for Kittytail's Holy Templar Magic. Requires Lightpower.esl."
    '  MasterReferences:'
    '  - Master: Skyrim.esm'
    '    FileSize: 0'
    '  - Master: Enderal - Forgotten Stories.esm'
    '    FileSize: 0'
    '  - Master: Lightpower.esl'
    '    FileSize: 0'
    '  INTV: 1'
    ''
) -join "`r`n")

Write-Text (Join-Path $out 'spriggit-meta.json') (@(
    '{'
    '  "PackageName": "Spriggit.Yaml.Skyrim",'
    '  "Version": "0.40.0",'
    '  "Release": "EnderalSE",'
    "  `"ModKey`": `"$PatchKey`""
    '}'
) -join "`r`n")

# ---------------------------------------------------------------- A + B: substitutions
# key -> @(replacement, expected occurrences in upstream, what it is)
$subs = [ordered]@{
    '018F02:Dawnguard.esm'  = @('1097CA:Skyrim.esm', 47, 'DLC1MAGINVVampireBane -> MAGINVTurnUndead (menu icon)')
    '00F64A:Dawnguard.esm'  = @('0E755B:Skyrim.esm', 31, 'DLC1_VampireBaneHandFX -> BaneUndeadHandEffects (casting art)')
    '019C9D:Dawnguard.esm'  = @('0E7557:Skyrim.esm', 20, 'DLC1SunFireImpactFXShader -> TurnUndeadFlamesFXS (hit shader)')
    '00A3BB:Dawnguard.esm'  = @('0E7557:Skyrim.esm',  4, 'DLC1SunFireFXShader -> TurnUndeadFlamesFXS (hit shader)')
    '019C9E:Dawnguard.esm'  = @('04D6B5:Skyrim.esm',  7, 'DLC1SunDamageImpactSmoke -> DragonHolesSmokeFXS (script shader; Kittytail already uses it)')
    '00D9AE:Dawnguard.esm'  = @('04C6DA:Skyrim.esm',  4, 'DLC1MAGSunFireImpactSet -> MAGTurnUnlImpactSet')
    '00D94A:Dawnguard.esm'  = @('056622:Skyrim.esm',  1, 'MAGDestructionStendarrsAuraCharge0500 -> MAGRestorationChargeSD')
    '019956:Dawnguard.esm'  = @('02518F:Skyrim.esm',  1, 'FXExplosionAurielsSunFar -> MAGDestructionFireballExplosionDistant')
    '03280A:Dragonborn.esm' = @('00001B:Skyrim.esm',  1, 'DLC2AshSpawnAshPile -> DefaultAshPile1 (Consecrate Dead ash pile)')
    '014217:Dawnguard.esm'  = @('0F76C0:Skyrim.esm',  4, 'DLC1DawnguardFaction -> SuntempleGuardFaction (NPC friendly fire)')
    '0B3292:Skyrim.esm'     = @('0F76BD:Skyrim.esm',  4, 'VigilantOfStendarrFaction (absent) -> SuntempleFaction (NPC friendly fire)')
}
$imodRx = '(?m)^ImageSpaceModifier: [0-9A-F]{6}:Dawnguard\.esm\r?\n'
$imodExpected = 7

$counts = @{}; foreach ($k in $subs.Keys) { $counts[$k] = 0 }
$imodDropped = 0; $touched = 0
foreach ($group in 'MagicEffects', 'Spells', 'SoundMarkers') {
    foreach ($f in Get-ChildItem (Join-Path $Upstream $group) -Filter '*.yaml') {
        $t = Read-Text $f.FullName
        $orig = $t
        foreach ($k in $subs.Keys) {
            $n = ([regex]::Matches($t, [regex]::Escape($k))).Count
            if ($n) { $counts[$k] += $n; $t = $t.Replace($k, $subs[$k][0]) }
        }
        $m = [regex]::Matches($t, $imodRx).Count
        if ($m) { $imodDropped += $m; $t = [regex]::Replace($t, $imodRx, '') }
        if ($t -ne $orig) {
            Write-Text (Join-Path (Join-Path $out $group) $f.Name) $t
            $touched++
        }
    }
}
foreach ($k in $subs.Keys) {
    if ($counts[$k] -ne $subs[$k][1]) {
        throw "Substitution $k : expected $($subs[$k][1]) occurrences, found $($counts[$k]) - upstream changed?"
    }
    '  A/B {0,3} x {1}' -f $counts[$k], $subs[$k][2]
}
if ($imodDropped -ne $imodExpected) { throw "ImageSpaceModifier: expected $imodExpected dropped, found $imodDropped" }
"  A   {0,3} x Dawnguard ImageSpaceModifier dropped (no Enderal counterpart)" -f $imodDropped
"  A/B $touched records overridden"

# ---------------------------------------------------------------- C + D: mana and gold, by tier
# Tier is read off the spell's HalfCostPerk (CLAUDE.md: the field Enderal's talents read).
$tierOf = @{
    '0F2CAA:Skyrim.esm' = 'Novice'; '0C44C7:Skyrim.esm' = 'Apprentice'; '0C44C8:Skyrim.esm' = 'Adept'
    '0C44C9:Skyrim.esm' = 'Expert'; '0C44CA:Skyrim.esm' = 'Master'
}
# Mana: ratio = Enderal tier p75 / Kittytail tier median, capped so the tier max stays inside
# Enderal's tier max (140/140/200/260/310). Novice (25) and Apprentice (41/s) already sit inside
# Enderal's bands, so they are left alone.
$manaRatio = @{ Novice = 1.0; Apprentice = 1.0; Adept = 0.45; Expert = 0.40; Master = 0.21 }
$manaMax   = @{ Novice = 140; Apprentice = 140; Adept = 200; Expert = 260; Master = 310 }
$manaFloor = @{ Novice = 14;  Apprentice = 27;  Adept = 34;  Expert = 49;  Master = 68 }
# Gold: Apocalypse's tome ratios (src/Apocalypse/tools/08-reprice.ps1), except Master at 0.30 rather
# than 0.28 so Kittytail's masters (1000) do not price below the expert tome (725 -> 285).
$goldRatio = @{ Novice = 0.72; Apprentice = 0.92; Adept = 0.50; Expert = 0.39; Master = 0.30 }

function Round5([double]$v) { if ($v -le 20) { return [int][math]::Round($v) } return [int]([math]::Round($v / 5) * 5) }

$valueRx = '(?m)^Value: (\d+)(?=\r?\n)'
$costRx  = '(?m)^BaseCost: (\d+)(?=\r?\n)'
$books = @(Get-ChildItem (Join-Path $Upstream 'Books') -Filter '*.yaml')
if ($books.Count -ne 6) { throw "Expected 6 tomes upstream, found $($books.Count)" }
foreach ($b in $books) {
    $bt = Read-Text $b.FullName
    $sm = [regex]::Match($bt, '(?m)^  Spell: ([0-9A-F]{6}):Lightpower\.esl')
    if (-not $sm.Success) { throw "$($b.Name): teaches no Lightpower spell" }
    $spellHex = $sm.Groups[1].Value
    $sp = Get-PatchFile 'Spells' $spellHex
    $st = Read-Text $sp
    $perk = [regex]::Match($st, '(?m)^HalfCostPerk: ([0-9A-F]{6}:Skyrim\.esm)').Groups[1].Value
    if (-not $tierOf.ContainsKey($perk)) { throw "$spellHex : unknown HalfCostPerk '$perk'" }
    $tier = $tierOf[$perk]
    if ($st -notmatch '(?m)^- ManualCostCalc(?=\r?$)') { throw "$spellHex : ManualCostCalc not set" }

    $cm = [regex]::Matches($st, $costRx)
    if ($cm.Count -ne 1) { throw "$spellHex : expected 1 BaseCost, found $($cm.Count)" }
    $oldCost = [int]$cm[0].Groups[1].Value
    $newCost = Round5 ($oldCost * $manaRatio[$tier])
    if ($manaRatio[$tier] -lt 1 -and $newCost -lt $manaFloor[$tier]) { $newCost = $manaFloor[$tier] }
    if ($newCost -gt $manaMax[$tier]) { throw "$spellHex : $newCost over Enderal's $tier ceiling $($manaMax[$tier])" }
    Write-Text $sp ([regex]::Replace($st, $costRx, "BaseCost: $newCost"))

    $vm = [regex]::Matches($bt, $valueRx)
    if ($vm.Count -ne 1) { throw "$($b.Name): expected 1 top-level Value, found $($vm.Count)" }
    $oldGold = [int]$vm[0].Groups[1].Value
    $newGold = Round5 ($oldGold * $goldRatio[$tier])
    if ($newGold -lt 20 -or $newGold -gt 350) { throw "$($b.Name): $newGold outside Enderal's 20-350 tome range" }
    Write-Text (Join-Path (Join-Path $out 'Books') $b.Name) ([regex]::Replace($bt, $valueRx, "Value: $newGold"))

    '  C/D {0,-10} {1,-24} mana {2,4} -> {3,-4} gold {4,5} -> {5}' -f $tier, $b.Name.Split(' ')[0], $oldCost, $newCost, $oldGold, $newGold
}

# ---------------------------------------------------------------- E: Arcane Fever on the self-heal
# _LIP_ConsecrateDeadHeal is cast by _LIP_ConsecrateScript on the caster when a corpse is destroyed:
# 60 Health (+60 Magicka/Stamina). 3 fever = 20 HP per point, inside Enderal's 26-per-point burst
# ceiling. 11A4B6 is FireAndForget/Self and this spell is FireAndForget/Self (TargetType omitted).
$heal = Get-PatchFile 'Spells' '000827'
$ht = Read-Text $heal
if ($ht -match 'TargetType:') { throw '_LIP_ConsecrateDeadHeal is no longer Self-targeted - 11A4B6 would be inert' }
if ($ht -match '11A4B6:Skyrim\.esm') { throw '_LIP_ConsecrateDeadHeal already carries Arcane Fever upstream' }
$ht = $ht.TrimEnd("`r", "`n") + "`r`n" + (@(
    '- BaseEffect: 11A4B6:Skyrim.esm'
    '  Data:'
    '    Magnitude: 3'
    '    Duration: 1'
    ''
) -join "`r`n")
Write-Text $heal $ht
'  E   Arcane Fever 3 added to _LIP_ConsecrateDeadHeal'

# ---------------------------------------------------------------- F: inert inject quests
foreach ($hex in '00084B', '000866') {
    $q = Get-UpstreamFile 'Quests' $hex
    $lines = (Read-Text $q.FullName) -split "`r?`n"
    $keep = New-Object System.Collections.Generic.List[string]
    $skip = $false; $removed = 0
    foreach ($l in $lines) {
        if ($l -eq 'VirtualMachineAdapter:') { $skip = $true; $removed++; continue }
        if ($skip -and $l -match '^\S') { $skip = $false }
        if (-not $skip) { $keep.Add($l) }
    }
    if ($removed -ne 1) { throw "$($q.Name): expected one VirtualMachineAdapter block" }
    Write-Text (Join-Path (Join-Path $out 'Quests') $q.Name) ($keep -join "`r`n")
    "  F   $($q.Name.Split(' ')[0]) : inject script removed"
}

# ---------------------------------------------------------------- G: Sun Temple merchandise hook
# Halda Stronghand (_00E_SuntempleHaldaHammerschlag), the Sun Temple's armourer. Her chest
# _00E_Merchant_STHalda carries this hook in FS, EGO and EGO Leveling Redone alike, and no other
# known plugin overrides the hook itself. UseAll, no ChanceNone: all six tomes every restock.
$hookSrc = @(Get-ChildItem (Join-Path $fsTree 'LeveledItems') -Filter 'HaldaHammerschlag_CustomMerchandise - 0302FF_*.yaml')
if ($hookSrc.Count -ne 1) { throw 'HaldaHammerschlag_CustomMerchandise not found in reference/base/EnderalFS' }
$hk = (Read-Text $hookSrc[0].FullName).TrimEnd("`r", "`n")
if ($hk -match 'Entries:') { throw 'Halda''s hook is no longer empty in FS - merge instead of creating Entries' }
$entries = foreach ($b in ($books | Sort-Object Name)) {
    $hex = [regex]::Match($b.Name, ' - ([0-9A-F]{6})_Lightpower').Groups[1].Value
    '- Data:'; '    Level: 1'; "    Reference: ${hex}:Lightpower.esl"; '    Count: 1'
}
Write-Text (Join-Path (Join-Path $out 'LeveledItems') $hookSrc[0].Name) ($hk + "`r`nEntries:`r`n" + ($entries -join "`r`n") + "`r`n")
"  G   $($books.Count) tomes stocked via HaldaHammerschlag_CustomMerchandise"

# ---------------------------------------------------------------- final guard
$left = @(Get-ChildItem $out -Recurse -Filter '*.yaml' | Select-String -Pattern ':(Dawnguard|Dragonborn|HearthFires)\.esm')
if ($left.Count) { throw "DLC references survived:`n$($left -join "`n")" }
$n = @(Get-ChildItem $out -Recurse -Filter '*.yaml' | Where-Object { $_.Name -ne 'RecordData.yaml' -or $_.DirectoryName -ne $out }).Count
"Done: $n record files in $out"
