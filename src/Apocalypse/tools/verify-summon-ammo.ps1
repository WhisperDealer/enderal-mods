#requires -Version 5.1
<#
.SYNOPSIS
  Assert every Apocalypse summon that carries a bow also carries ammo Enderal actually has.

.DESCRIPTION
  The failure this exists to catch is silent in every other check: an archer summon whose quiver
  FormID does not resolve builds clean, loads clean, passes the Papyrus compiler, and then stands in
  front of the player holding a bow it never fires. It is the "MISSING" class from the gap audit, and
  verify-missing-refs.ps1 does report it - but as one line among ~269, with nothing to say that this
  one costs a spell its entire function.

  So the check is on the invariant, not the reference. For every Apocalypse NPC whose inventory or
  default outfit holds a Weapon with `AnimationType: Bow`, at least one Ammunition record must be in
  the same inventory AND resolve - either in Apocalypse's own tree or in Enderal's masters (base
  Enderal, Update, Forgotten Stories).

  Enderal has no crossbows and Apocalypse ships none, so bolts are not distinguished.

  NOTE on the regexes below: a FormKey contains spaces ("011878:Apocalypse - Magic of Skyrim.esp"),
  so `(\S+)` anchored to end-of-line never matches one. Capture with `(.+?)` and let the anchor stop
  it. Getting that wrong reads as "no bows in this plugin" and passes nothing.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$esp  = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$base = Join-Path $repo 'reference\base'
foreach ($p in @($esp, $base)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Not found: $p" }
}

# CRLF tree: anchor with (?=\r?$), never '$' on its own (CLAUDE.md).
$RX_FORMKEY = '(?m)^FormKey: (.+?)(?=\r?$)'
$RX_BOW     = '(?m)^  AnimationType: Bow(?=\r?$)'
$RX_EDITOR  = '(?m)^EditorID: (.+?)(?=\r?$)'
$RX_ITEM    = '(?m)^    Item: (.+?)(?=\r?$)'
$RX_OUTFIT  = '(?m)^DefaultOutfit: (.+?)(?=\r?$)'
$RX_LISTENT = '(?m)^- (.+?)(?=\r?$)'

function Get-Hex([string]$formKey) { $formKey.Split(':')[0].Trim().ToUpperInvariant() }
function Get-Key([string]$formKey) { $formKey.Trim().ToUpperInvariant() }

function Get-FormKeyOf([string]$text) {
    $m = [regex]::Match($text, $RX_FORMKEY)
    if (-not $m.Success) { return $null }
    return $m.Groups[1].Value
}

# --- index Apocalypse's own bows and ammo ---------------------------------------------------------
$bows = @{}
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $esp 'Weapons') -File -Filter *.yaml) {
    $text = [IO.File]::ReadAllText($f.FullName)
    if ($text -notmatch $RX_BOW) { continue }
    $fk = Get-FormKeyOf $text
    if ($fk) { $bows[(Get-Hex $fk)] = $f.Name }
}
if ($bows.Count -eq 0) { throw 'No bows found in the Apocalypse tree - the AnimationType probe is wrong.' }

$ourAmmo = @{}
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $esp 'Ammunitions') -File -Filter *.yaml) {
    $fk = Get-FormKeyOf ([IO.File]::ReadAllText($f.FullName))
    if ($fk) { $ourAmmo[(Get-Hex $fk)] = $f.Name }
}

# --- index Enderal's ammo, keyed <hex>:<master> ---------------------------------------------------
# Hex-only keying is the mistake verify-missing-refs.ps1 documents: it lets a hex defined by any
# plugin count as defined by all of them, and silently resolves references that are in fact dead.
$enderalAmmo = @{}
foreach ($tree in 'Skyrim', 'Update', 'EnderalFS') {
    $dir = Join-Path (Join-Path $base $tree) 'Ammunitions'
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    foreach ($f in Get-ChildItem -LiteralPath $dir -File -Filter *.yaml) {
        $fk = Get-FormKeyOf ([IO.File]::ReadAllText($f.FullName))
        if ($fk) { $enderalAmmo[(Get-Key $fk)] = "$tree/$($f.Name)" }
    }
}
if ($enderalAmmo.Count -eq 0) {
    throw "No Enderal Ammunition records indexed under $base - regenerate reference/ with /spriggit-decompile-reference."
}
Write-Host "indexed $($bows.Count) Apocalypse bows, $($ourAmmo.Count) own ammo, $($enderalAmmo.Count) Enderal ammo"

# --- outfits, so a bow or quiver granted by an outfit still counts --------------------------------
$outfitItems = @{}
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $esp 'Outfits') -File -Filter *.yaml) {
    $text = [IO.File]::ReadAllText($f.FullName)
    $fk   = Get-FormKeyOf $text
    if (-not $fk) { continue }
    $outfitItems[(Get-Hex $fk)] = @([regex]::Matches($text, $RX_LISTENT) | ForEach-Object { $_.Groups[1].Value })
}

# --- walk every NPC -------------------------------------------------------------------------------
$archers = 0
$failed  = @()
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $esp 'Npcs') -File -Filter *.yaml) {
    $text = [IO.File]::ReadAllText($f.FullName)
    $m    = [regex]::Match($text, $RX_EDITOR)
    $eid  = if ($m.Success) { $m.Groups[1].Value } else { $f.BaseName }

    $items = @([regex]::Matches($text, $RX_ITEM) | ForEach-Object { $_.Groups[1].Value })
    $mo = [regex]::Match($text, $RX_OUTFIT)
    if ($mo.Success) {
        $ok = Get-Hex $mo.Groups[1].Value
        if ($outfitItems.ContainsKey($ok)) { $items += $outfitItems[$ok] }
    }
    if ($items.Count -eq 0) { continue }

    $bow = @($items | Where-Object { $bows.ContainsKey((Get-Hex $_)) })
    if ($bow.Count -eq 0) { continue }
    $archers++

    $live = @($items | Where-Object { $ourAmmo.ContainsKey((Get-Hex $_)) -or $enderalAmmo.ContainsKey((Get-Key $_)) })
    if ($live.Count -eq 0) {
        $other = ($items | Where-Object { -not $bows.ContainsKey((Get-Hex $_)) }) -join ', '
        $failed += "  $eid  carries $($bows[(Get-Hex $bow[0])]) but no resolvable ammunition. Other items: $other"
    } else {
        Write-Host "  OK  $eid  -> $($live -join ', ')"
    }
}

Write-Host "archer NPCs checked: $archers"
if ($archers -lt 3) {
    throw "Only $archers archer summon(s) found; Apocalypse has at least 3 (Herne, Dremora Assassin, Bear Totem). The bow/outfit probe is wrong."
}
if ($failed.Count -gt 0) {
    Write-Host ''
    $failed | ForEach-Object { Write-Host $_ }
    throw "$($failed.Count) archer summon(s) have no ammunition Enderal can resolve - they hold a bow and never fire it."
}
Write-Host 'PASS - every archer summon has resolvable ammunition.'
