#requires -Version 5.1
<#
.SYNOPSIS
  Assert every summonable Apocalypse NPC's outfit actually puts clothes on it.

.DESCRIPTION
  Sibling of `verify-summon-ammo.ps1`, and the same argument. A summon whose outfit points at armour
  Enderal does not have builds clean, loads clean, and arrives naked; the dead entries are a few
  lines in a ~264-line missing-reference report, indistinguishable from the ones that cost nothing.
  `WB_ConjureCraftlord_Outfit` lost its body, hands and feet that way -- three vanilla Dwarven pieces
  on a race whose Skin is `SkinNaked`.

  Two things are asserted, for every entry of every outfit worn by an NPC flagged `Summonable`:

    1. **The entry resolves** -- in Apocalypse's own tree or in Enderal's masters. A dead outfit entry
       is never intentional.
    2. **If it is an `Armor`, its armature covers the wearer's race's `ArmorRace`.** This is the
       nastier half: an `ARMO` whose `ARMA` does not list the actor's `ArmorRace` renders nothing at
       all, with no error anywhere, so a substitution can resolve perfectly and still ship a naked
       summon. `WB_ConjureCraftlord_Race` sets `ArmorRace: 013743` (HighElfRace) rather than the
       DefaultRace most gear is keyed to, which is exactly the case where a plausible swap fails.

  **What is deliberately NOT asserted: which slots get covered.** The first draft demanded Body,
  Hands and Feet and reported 14 failures that were all design -- Dremora and Xivilai go barehanded
  and barefoot throughout Apocalypse, and `WB_Con_Undead_Actor_ConjureDeadeyeCaptain` has no body
  armour because his race skin *is* the body. Slot coverage is an aesthetic judgement; a dead
  reference is not. Assert the objective thing.

  Scope is `Summonable` only, which is likewise objective rather than a carve-out to dodge a failure.
  `WB_Kyrgar_Actor` has the same defect -- three dead vanilla Orcish pieces -- but it is a *placed*
  merchant stranded in `MQP01Home` (worldspace `00003C`: Tamriel in Skyrim, Enderal's prologue
  house), where no player meets it. See the gap audit.

  NOTE on the regexes: a FormKey can contain spaces ("123E5F:Apocalypse - Magic of Skyrim.esp"), so
  `(\S+)` anchored to end-of-line never matches one. Capture with `(.+?)`.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$esp  = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$base = Join-Path $repo 'reference\base'
foreach ($p in @($esp, $base)) { if (-not (Test-Path -LiteralPath $p)) { throw "Not found: $p" } }

$RX_FORMKEY = '(?m)^FormKey: (.+?)(?=\r?$)'
$RX_EDITOR  = '(?m)^EditorID: (.+?)(?=\r?$)'
$RX_OUTFIT  = '(?m)^DefaultOutfit: (.+?)(?=\r?$)'
$RX_LISTENT = '(?m)^- (.+?)(?=\r?$)'
$RX_RACE    = '(?m)^Race: (.+?)(?=\r?$)'
$RX_ARMRACE = '(?m)^ArmorRace: (.+?)(?=\r?$)'

function Get-Key([string]$fk) { $fk.Trim().ToUpperInvariant() }
function Get-One([string]$text, [string]$rx) {
    $m = [regex]::Match($text, $rx)
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

# --- index the record groups an outfit entry can legally name -------------------------------------
# Keyed <hex>:<master>. Hex-only keying is what verify-missing-refs.ps1 documents as the way to
# silently resolve a reference that is in fact dead.
$armors = @{}   # Armor records, kept as text so the armature can be walked
$other  = @{}   # anything else an outfit may hold: weapons, ammo, leveled lists
$armas  = @{}
$races  = @{}
$sources = @($esp, (Join-Path $base 'Skyrim'), (Join-Path $base 'Update'), (Join-Path $base 'EnderalFS'))

foreach ($src in $sources) {
    foreach ($grp in @('Armors', 'ArmorAddons', 'Races', 'Weapons', 'Ammunitions', 'LeveledItems')) {
        $dir = Join-Path $src $grp
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($f in Get-ChildItem -LiteralPath $dir -File -Filter *.yaml) {
            $t  = [IO.File]::ReadAllText($f.FullName)
            $fk = Get-One $t $RX_FORMKEY
            if (-not $fk) { continue }
            $k = Get-Key $fk
            # First-wins: Apocalypse's own tree is scanned first, and a master's later override of
            # the same FormKey is the same record for the purposes of "does this exist".
            switch ($grp) {
                'Armors'      { if (-not $armors.ContainsKey($k)) { $armors[$k] = $t } }
                'ArmorAddons' { if (-not $armas.ContainsKey($k))  { $armas[$k]  = $t } }
                'Races'       { if (-not $races.ContainsKey($k))  { $races[$k]  = $t } }
                default       { if (-not $other.ContainsKey($k))  { $other[$k]  = $grp } }
            }
        }
    }
}
if ($armors.Count -eq 0 -or $armas.Count -eq 0 -or $races.Count -eq 0) {
    throw "Indexed $($armors.Count) Armors / $($armas.Count) ArmorAddons / $($races.Count) Races -- regenerate reference/ with /spriggit-decompile-reference."
}
Write-Host "indexed $($armors.Count) Armor, $($armas.Count) ArmorAddon, $($races.Count) Race, $($other.Count) other"

$outfits = @{}
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $esp 'Outfits') -File -Filter *.yaml) {
    $t  = [IO.File]::ReadAllText($f.FullName)
    $fk = Get-One $t $RX_FORMKEY
    if (-not $fk) { continue }
    $eid = Get-One $t $RX_EDITOR
    if (-not $eid) { $eid = $f.BaseName }
    $outfits[(Get-Key $fk)] = [pscustomobject]@{
        EditorID = $eid
        Items    = @([regex]::Matches($t, $RX_LISTENT) | ForEach-Object { $_.Groups[1].Value })
    }
}
if ($outfits.Count -eq 0) { throw 'No outfits found in the Apocalypse tree.' }

# Does this Armor's armature cover $armorRace? An ARMO that fails this renders nothing at all.
function Test-RendersOnRace([string]$armorText, [string]$armorRace) {
    if (-not $armorRace) { return $true }   # race declares no ArmorRace: nothing to check against
    $block = [regex]::Match($armorText, '(?ms)^Armature:\r?\n(?:- .+\r?\n)+').Value
    $ars   = @([regex]::Matches($block, '(?m)^- (.+?)(?=\r?$)') | ForEach-Object { $_.Groups[1].Value })
    if ($ars.Count -eq 0) { return $false }
    $e = [regex]::Escape($armorRace)
    foreach ($aa in $ars) {
        $ak = Get-Key $aa
        if (-not $armas.ContainsKey($ak)) { continue }
        $at = $armas[$ak]
        if (($at -match "(?m)^Race: $e(?=\r?`$)") -or ($at -match "(?m)^- $e(?=\r?`$)")) { return $true }
    }
    return $false
}

# --- walk the summonable NPCs ----------------------------------------------------------------------
$checked  = 0
$entries  = 0
$noOutfit = 0
$failed   = @()
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $esp 'Npcs') -File -Filter *.yaml) {
    $t = [IO.File]::ReadAllText($f.FullName)
    if ($t -notmatch '(?m)^  - Summonable(?=\r?$)') { continue }

    $eid = Get-One $t $RX_EDITOR
    if (-not $eid) { $eid = $f.BaseName }

    $ok = Get-One $t $RX_OUTFIT
    if (-not $ok) { $noOutfit++; continue }
    $okey = Get-Key $ok
    if (-not $outfits.ContainsKey($okey)) {
        $failed += "  $eid  names DefaultOutfit $ok, which is not a record in this plugin."
        continue
    }
    $outfit = $outfits[$okey]

    $armorRace = $null
    $raceKey = Get-One $t $RX_RACE
    if ($raceKey -and $races.ContainsKey((Get-Key $raceKey))) {
        $armorRace = Get-One $races[(Get-Key $raceKey)] $RX_ARMRACE
    }

    $checked++
    $bad = @()
    foreach ($i in $outfit.Items) {
        $entries++
        $k = Get-Key $i
        if ($armors.ContainsKey($k)) {
            if (-not (Test-RendersOnRace $armors[$k] $armorRace)) {
                $bad += "$i (resolves, but no armature covers ArmorRace $armorRace - renders nothing)"
            }
            continue
        }
        if ($other.ContainsKey($k)) { continue }
        $bad += "$i (dead - no record in Apocalypse or in Enderal's masters)"
    }
    if ($bad.Count -gt 0) {
        $failed += "  $eid  wears $($outfit.EditorID): " + ($bad -join '; ')
    }
}

Write-Host "summonable NPCs with an outfit: $checked ($entries entries checked; $noOutfit summons have no outfit)"
if ($checked -lt 10) {
    throw "Only $checked summonable NPCs with an outfit were found; Apocalypse has dozens. The Summonable/DefaultOutfit probe is wrong."
}
if ($failed.Count -gt 0) {
    Write-Host ''
    $failed | ForEach-Object { Write-Host $_ }
    throw "$($failed.Count) summon(s) wear an outfit entry that is dead or cannot render."
}
Write-Host 'PASS - every summon outfit entry resolves and renders on its wearer.'
