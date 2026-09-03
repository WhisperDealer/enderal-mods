#requires -Version 5.1
<#
.SYNOPSIS
  Invariant check for Triumvirate's player transformations (WD-37).

.DESCRIPTION
  CLAUDE.md's lesson from the Apocalypse summon-ammo bug: a missing-reference count tells you what
  is dead, never what dying costs. Both WD-37 defects were invisible to verify-missing-refs.ps1 -
  it reads 0 for these records - because nothing they point at is missing. What was wrong was that
  a condition could not pass and a skin could not render.

  So this asserts the things a player actually experiences, per subsystem:

    1. Every magic effect binding TVR_Wildshape_Script - i.e. every player transformation in the
       mod - names a TVR_Race that exists.

    2. That race's skin can actually RENDER on it. "The FormID exists" is half a check; the second
       condition for an ARMO is that one of its armatures covers the wearer's ArmorRace (or the
       race itself, when ArmorRace is unset). This is the Craftlord invariant from CLAUDE.md.

    3. The Wildshape morph effect is not gated behind a movement state a hand-cast spell cannot
       satisfy, and its description does not promise a trigger that no longer exists.

    4. The loose TVR_Wildshape_Script.pex we ship is OUR build - it must contain QueueNiNodeUpdate
       and must NOT contain StripArmor, the reverted first attempt. build.ps1 fails on a MISSING
       .pex but cannot detect a STALE one, and a stale one here ships a known-bad script.

  Exits non-zero on any failure.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$ours = Join-Path $repo 'src\Triumvirate\TriumvirateESP'
$base = Join-Path $repo 'reference\base'
$pex  = Join-Path $repo 'src\Triumvirate\Scripts\compiled\TVR_Wildshape_Script.pex'

if (-not (Test-Path $ours)) { throw "Triumvirate YAML tree not found: $ours" }

$failures = @()
function Fail($msg) { $script:failures += $msg; Write-Host "  FAIL  $msg" }
function Pass($msg) { Write-Host "  ok    $msg" }

function Read-Text { param([string]$Path) [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) }

# Find a record by FormKey across our tree and then the serialized masters. Returns the file text.
function Find-Record {
    param([Parameter(Mandatory)][string]$FormKey, [string[]]$Groups)
    $roots = @($ours)
    if (Test-Path $base) { $roots += @((Join-Path $base 'Skyrim'), (Join-Path $base 'EnderalFS'), (Join-Path $base 'Update')) }
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($g in $Groups) {
            $dir = Join-Path $root $g
            if (-not (Test-Path $dir)) { continue }
            foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.yaml' -ErrorAction SilentlyContinue) {
                $t = Read-Text $f.FullName
                if ($t -match ('(?m)^FormKey: ' + [regex]::Escape($FormKey) + '\s*$')) { return $t }
            }
        }
    }
    return $null
}

Write-Host "verify-druid-transformations (WD-37)"

# --- 1. every transformation, and its race ------------------------------------------------------
Write-Host "`n[1] player transformations bound to TVR_Wildshape_Script"

$transforms = @()
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $ours 'MagicEffects') -Filter '*.yaml') {
    $t = Read-Text $f.FullName
    if ($t -notmatch '(?m)^\s*- Name: TVR_Wildshape_Script\s*$') { continue }
    $ed   = [regex]::Match($t, '(?m)^EditorID: (.+?)(?=\r?$)')
    $race = [regex]::Match($t, '(?ms)Name: TVR_Race\r?\n\s*Object: (.+?)(?=\r?$)')
    $transforms += [pscustomobject]@{
        EditorID = if ($ed.Success) { $ed.Groups[1].Value.Trim() } else { $f.BaseName }
        Race     = if ($race.Success) { $race.Groups[1].Value.Trim() } else { $null }
    }
}

if ($transforms.Count -eq 0) {
    Fail "no magic effect binds TVR_Wildshape_Script - the transformation subsystem has vanished"
} else {
    Pass ("found {0} transformation(s): {1}" -f $transforms.Count, (($transforms | ForEach-Object { $_.EditorID }) -join ', '))
}

foreach ($tr in $transforms) {
    if (-not $tr.Race) { Fail "$($tr.EditorID): no TVR_Race property"; continue }

    $raceText = Find-Record -FormKey $tr.Race -Groups @('Races')
    if (-not $raceText) { Fail "$($tr.EditorID): TVR_Race $($tr.Race) resolves to no RACE record"; continue }

    $raceEd = [regex]::Match($raceText, '(?m)^EditorID: (.+?)(?=\r?$)').Groups[1].Value.Trim()

    # --- 2. can the skin render on this race? ---
    $skin = [regex]::Match($raceText, '(?m)^Skin: (.+?)(?=\r?$)')
    if (-not $skin.Success) { Fail "$raceEd has no Skin - the transformed player has no body"; continue }

    $armo = Find-Record -FormKey $skin.Groups[1].Value.Trim() -Groups @('Armors')
    if (-not $armo) { Fail "$raceEd Skin $($skin.Groups[1].Value.Trim()) resolves to no ARMO"; continue }

    # ArmorRace decides what an armature must cover; unset means the race stands for itself.
    $armorRace = [regex]::Match($raceText, '(?m)^ArmorRace: (.+?)(?=\r?$)')
    $wanted = if ($armorRace.Success) { $armorRace.Groups[1].Value.Trim() } else { $tr.Race }

    $covered = $false
    foreach ($m in [regex]::Matches($armo, '(?m)^- ([0-9A-Fa-f]{6}:.+?)(?=\r?$)')) {
        $arma = Find-Record -FormKey $m.Groups[1].Value.Trim() -Groups @('ArmorAddons')
        if (-not $arma) { continue }
        $races = @()
        $r = [regex]::Match($arma, '(?m)^Race: (.+?)(?=\r?$)')
        if ($r.Success) { $races += $r.Groups[1].Value.Trim() }
        $add = [regex]::Match($arma, '(?ms)^AdditionalRaces:\r?\n((?:- .+?\r?\n)+)')
        if ($add.Success) {
            foreach ($a in [regex]::Matches($add.Groups[1].Value, '(?m)^- (.+?)(?=\r?$)')) { $races += $a.Groups[1].Value.Trim() }
        }
        if ($races -contains $wanted) { $covered = $true; break }
    }
    if ($covered) { Pass "$($tr.EditorID): skin renders on $raceEd" }
    else { Fail "$($tr.EditorID): no armature of $raceEd's skin covers $wanted - the transformed player is INVISIBLE" }
}

# --- 3. Wildshape morph conditions + description -------------------------------------------------
Write-Host "`n[2] Wildshape morph is reachable"

$spellFile = Get-ChildItem -LiteralPath (Join-Path $ours 'Spells') -Filter 'TVR_Druid_A050_Spell_Wildshape - *.yaml' | Select-Object -First 1
if (-not $spellFile) { Fail "TVR_Druid_A050_Spell_Wildshape not found" }
else {
    $st = Read-Text $spellFile.FullName
    foreach ($gate in 'IsSprintingConditionData', 'IsRunningConditionData') {
        if ($st -match $gate) { Fail "Wildshape still gated on $gate - a hand-cast spell cannot satisfy it" }
        else { Pass "no $gate gate" }
    }
    if ($st -notmatch 'IsInCombatConditionData') { Fail "Wildshape lost its out-of-combat condition" }
    else { Pass "out-of-combat condition intact" }
}

$mgefFile = Get-ChildItem -LiteralPath (Join-Path $ours 'MagicEffects') -Filter 'TVR_Druid_Verdant_Effect_Wildshape - *.yaml' | Select-Object -First 1
if ($mgefFile) {
    $mt = Read-Text $mgefFile.FullName
    if ($mt -match 'while sprinting') { Fail "Wildshape description still promises a sprint trigger" }
    else { Pass "description matches the trigger" }
}

# --- 4. the loose .pex is OUR build --------------------------------------------------------------
Write-Host "`n[3] shipped TVR_Wildshape_Script.pex"

if (-not (Test-Path $pex)) {
    Fail "TVR_Wildshape_Script.pex is not in Scripts/compiled - Enai's BSA copy would win and the invisibility returns"
} else {
    $bytes = [System.IO.File]::ReadAllBytes($pex)
    $ascii = -join ($bytes | ForEach-Object { if ($_ -ge 32 -and $_ -lt 127) { [char]$_ } else { "`n" } })
    # QueueNiNodeUpdate marks our build. StripArmor must NOT come back: it was removed after a
    # Papyrus log showed it threw on save-restored effects and spammed another mod's unequip handler.
    if ($ascii -match 'StripArmor') { Fail "TVR_Wildshape_Script.pex still contains StripArmor - the removed armour strip has come back" }
    else { Pass "no StripArmor" }
    foreach ($sym in 'QueueNiNodeUpdate', 'ForceRedraw') {
        if ($ascii -match $sym) { Pass "contains $sym" }
        else { Fail "TVR_Wildshape_Script.pex does not contain $sym - it is Enai's build or a stale one, recompile it" }
    }
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host ("FAILED: {0} problem(s)" -f $failures.Count) -ForegroundColor Red
    exit 1
}
Write-Host "all transformation invariants hold" -ForegroundColor Green
