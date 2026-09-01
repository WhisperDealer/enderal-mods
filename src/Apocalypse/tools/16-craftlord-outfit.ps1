#requires -Version 5.1
<#
.SYNOPSIS
  Clothe the Craftlord summon -- its outfit's body, hands and feet are vanilla Dwarven armour.

.DESCRIPTION
  `WB_ConjureCraftlord_Outfit` 123E5E holds five entries. Two are Apocalypse's own and render fine:

      123E5F  WB_ConjureCraftlord_Hood    Hair + Circlet
      0B1C12  WB_ConjureCraftlord_Cloak   Amulet   (a Nikinoodles cloak mesh)

  The other three are Bethesda's, and Enderal has none of them:

      01394D  ArmorDwarvenCuirass         Body
      01394C  ArmorDwarvenBoots           Feet
      01394E  ArmorDwarvenGauntlets       Hands

  So every slot below the neck is empty, and `WB_ConjureCraftlord_Race`'s Skin is `SkinNaked`
  000D64 -- the summon arrives hooded, cloaked and otherwise naked.

  Repointed to Enderal's own top-tier ordinary heavy plate, the same three slots and nothing else:

      138273  _04E_30_EndreleanPlateArmor       Body    AR 52.8
      138272  _04E_30_EndreleanPlateGauntlets   Hands   AR 18.9
      138274  _04E_30_EndreleanPlateBoots       Feet    AR 25.2

  Why this set. It is a level-30-tier *ordinary* set, not one of Enderal's unique `HSet`/`MSet`
  artefacts -- a conjured NPC wearing a named unique would read as a bug of its own. The Craftlord is
  a level 40 summon, so the top ordinary tier is the right shelf. The `Forged` variants are the
  player-crafted duplicates; the base records are what Enderal's own NPCs wear.

  **The check that made this safe, and nearly made it unsafe.** An `ARMO` renders on an actor only if
  its `ARMA` covers that actor's race's `ArmorRace`. `WB_ConjureCraftlord_Race` sets `ArmorRace:
  013743` (HighElfRace) -- not the DefaultRace most gear is keyed to. Vanilla's Dwarven armatures list
  27 races including `013743`, and so do Enderal's three here (`DaedricCuirassAA` 098BB3,
  `DaedricGlovesAA` 098BB5, `DaedricBootsAA` 098BB4 -- Endralean Plate is Enderal's reskin of the
  Daedric set, which is why the armature EditorIDs still say Daedric). A first read of those records
  truncated the list at three entries and made it look as though `013743` was absent, i.e. as though
  this swap would build clean, pass every audit and render nothing. Re-verify the race coverage, not
  just the FormID, before substituting any armour.

  Idempotent.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$esp  = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$base = Join-Path $repo 'reference\base'
$outfit = Join-Path $esp 'Outfits\WB_ConjureCraftlord_Outfit - 123E5E_Apocalypse - Magic of Skyrim.esp.yaml'
if (-not (Test-Path -LiteralPath $outfit)) { throw "Craftlord outfit not found: $outfit" }

# dead vanilla FormKey -> Enderal replacement, with the slot both are expected to occupy
$subs = @(
    @{ Dead = '01394D:Skyrim.esm'; New = '138273:Skyrim.esm'; Slot = 'Body';  Eid = '_04E_30_EndreleanPlateArmor' }
    @{ Dead = '01394E:Skyrim.esm'; New = '138272:Skyrim.esm'; Slot = 'Hands'; Eid = '_04E_30_EndreleanPlateGauntlets' }
    @{ Dead = '01394C:Skyrim.esm'; New = '138274:Skyrim.esm'; Slot = 'Feet';  Eid = '_04E_30_EndreleanPlateBoots' }
)

# The Craftlord race's ArmorRace. Anything we put on him must have an ARMA that covers it.
$armorRace = '013743:Skyrim.esm'
$raceFile  = Join-Path $esp 'Races\WB_ConjureCraftlord_Race - 0BBEE7_Apocalypse - Magic of Skyrim.esp.yaml'
if (-not (Test-Path -LiteralPath $raceFile)) { throw "Craftlord race not found: $raceFile" }
$raceText = [IO.File]::ReadAllText($raceFile)
if ($raceText -notmatch "(?m)^ArmorRace: $([regex]::Escape($armorRace))(?=\r?`$)") {
    throw "WB_ConjureCraftlord_Race no longer declares ArmorRace $armorRace. Re-derive the armour picks against whatever it declares now."
}

$armorDir = Join-Path (Join-Path $base 'Skyrim') 'Armors'
$armaDir  = Join-Path (Join-Path $base 'Skyrim') 'ArmorAddons'
foreach ($d in @($armorDir, $armaDir)) {
    if (-not (Test-Path -LiteralPath $d)) { throw "Not found: $d -- regenerate reference/ with /spriggit-decompile-reference." }
}

# --- prove each replacement exists, sits in the slot it is replacing, and covers the race --------
foreach ($s in $subs) {
    $hex   = $s.New.Split(':')[0]
    $files = @(Get-ChildItem -LiteralPath $armorDir -File -Filter "*$($hex)_Skyrim.esm.yaml")
    if ($files.Count -ne 1) { throw "$($s.New) is not a single Armor record in reference/base/Skyrim (found $($files.Count))." }
    $text = [IO.File]::ReadAllText($files[0].FullName)

    if ($text -notmatch "(?m)^EditorID: $([regex]::Escape($s.Eid))(?=\r?`$)") {
        throw "$($s.New) is not $($s.Eid) in this Enderal install -- it is '$($files[0].Name)'. Re-derive before substituting."
    }
    if ($text -notmatch "(?m)^  - $($s.Slot)(?=\r?`$)") {
        throw "$($s.Eid) does not occupy the $($s.Slot) slot. Substituting it would leave that slot empty and double up another."
    }

    # Every armature on the replacement must cover the Craftlord's ArmorRace, or it renders nothing.
    $armatures = @([regex]::Matches($text, '(?ms)^Armature:\r?\n(?:- .+\r?\n)+') |
                   ForEach-Object { [regex]::Matches($_.Value, '(?m)^- (.+?)(?=\r?$)') } |
                   ForEach-Object { $_.Groups[1].Value })
    if ($armatures.Count -eq 0) { throw "$($s.Eid) has no Armature -- it cannot render." }
    foreach ($aa in $armatures) {
        $aaHex   = $aa.Split(':')[0]
        $aaFiles = @(Get-ChildItem -LiteralPath $armaDir -File -Filter "*$($aaHex)_Skyrim.esm.yaml")
        if ($aaFiles.Count -ne 1) { throw "Armature $aa of $($s.Eid) not found in Enderal (found $($aaFiles.Count))." }
        $aaText = [IO.File]::ReadAllText($aaFiles[0].FullName)
        $covers = ($aaText -match "(?m)^Race: $([regex]::Escape($armorRace))(?=\r?`$)") -or
                  ($aaText -match "(?m)^- $([regex]::Escape($armorRace))(?=\r?`$)")
        if (-not $covers) {
            throw "Armature $aa ($($aaFiles[0].BaseName)) does not cover ArmorRace $armorRace, so $($s.Eid) would be invisible on the Craftlord. This builds clean and ships wrong -- pick different armour."
        }
    }
    Write-Host "  ok  $($s.Eid.PadRight(34)) $($s.Slot.PadRight(6)) armatures covering $armorRace : $($armatures.Count)"
}

# --- rewrite the outfit ---------------------------------------------------------------------------
# CRLF tree: anchor with (?=\r?$), never '$' (CLAUDE.md).
$text    = [IO.File]::ReadAllText($outfit)
$changed = 0
$already = 0
foreach ($s in $subs) {
    if ($text -match "(?m)^- $([regex]::Escape($s.New))(?=\r?`$)") { $already++; continue }
    $rx  = "(?m)^- $([regex]::Escape($s.Dead))(?=\r?`$)"
    $new = [regex]::Replace($text, $rx, "- $($s.New)")
    if ($new -eq $text) {
        throw "Craftlord outfit holds neither $($s.Dead) nor $($s.New). Upstream changed the outfit -- re-derive."
    }
    $text = $new
    $changed++
}
if ($changed -gt 0) { [IO.File]::WriteAllText($outfit, $text, (New-Object Text.UTF8Encoding($false))) }

Write-Host "Craftlord outfit: repointed $changed entries; $already already correct."
if (($changed + $already) -ne $subs.Count) {
    throw "Expected $($subs.Count) entries handled, got $($changed + $already)."
}
foreach ($s in $subs) {
    if ($text.Contains($s.Dead)) { throw "$($s.Dead) is still in the Craftlord outfit." }
}
Write-Host 'no dead vanilla armour left in the Craftlord outfit.'
