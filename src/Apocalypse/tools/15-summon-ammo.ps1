#requires -Version 5.1
<#
.SYNOPSIS
  Repoint the two archer summons' dead ammunition onto Enderal's own top-tier arrow.

.DESCRIPTION
  Apocalypse's two Dremora archers are handed a bow and a quiver of vanilla Skyrim arrows:

      WB_Con_Dremora_Actor_ConjureHerne            0139C0:Skyrim.esm  x100  (DaedricArrow)
      WB_Con_Dremora_Actor_ConjureDremoraAssassin  037C14:Skyrim.esm  x250  (BaseArrowDaedric75,
                                                                            a leveled list of the same)

  Neither FormID exists in Enderal - `reference/base/SkyrimReal` has both, `reference/base/Skyrim`,
  `Update` and `EnderalFS` have neither. So both summons spawn holding a bow with nothing to shoot,
  and an AI archer with no ammo just stands there. Reported in-game against Herne on 2026-09-01;
  the Assassin is the same defect, unreported.

  This is the plain MISSING case from the gap audit, not the drifted-FormID one: nothing answers at
  either ID, so the entry is simply dropped on load.

  The fix is a substitution onto Enderal's own tier-equivalent record rather than a new Ammunition
  record of our own (guardrail 3):

      13E219:Skyrim.esm   _30E_AeternaArrow   damage 10, value 3, projectile 03BE15 ArrowElvenProjectile

  Enderal's arrow ladder tops out at 10 damage where vanilla's Daedric Arrow is 24, so "best arrow"
  maps to "best arrow" and the numbers land where Enderal put them: Herne's Bow is 25 damage against
  Enderal's best bow at 23, so 25+10 puts a master-tier summon a shade above the best archer a player
  can build (23+10). Carrying vanilla's 24-damage arrow across, or minting a 30-damage one like
  Enai's own WB_ConjureBearTotem_Ammo, would have put it half again over that.

  Why not a new record: the Bear Totem shows what one costs - a mesh, a projectile, a keyword, a
  FormID and a damage number to keep in step with Enderal forever - and it would resolve to an Elven
  arrow's projectile and an Elven arrow's mesh anyway. Enai handed Herne an ordinary playable arrow
  from the host game; so do we.

  Counts are left as authored. The Assassin's 250 was 250 draws at ChanceNone 0.25 (~187 arrows) and
  is now a flat 250; for a summon that despawns on a timer the distinction is not a real one.

  Idempotent.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$npcs = Join-Path $repo 'src\Apocalypse\ApocalypseESP\Npcs'
if (-not (Test-Path -LiteralPath $npcs)) { throw "Npcs folder not found: $npcs" }

$ENDERAL_ARROW = '13E219:Skyrim.esm'   # _30E_AeternaArrow

# EditorID prefix -> the dead FormKey it carries in its Items list.
$targets = @(
    @{ Editor = 'WB_Con_Dremora_Actor_ConjureHerne';           Dead = '0139C0:Skyrim.esm' }
    @{ Editor = 'WB_Con_Dremora_Actor_ConjureDremoraAssassin'; Dead = '037C14:Skyrim.esm' }
)

# Prove the substitute is real before writing it anywhere.
$arrowHex  = $ENDERAL_ARROW.Split(':')[0]
$arrowFile = @(Get-ChildItem -LiteralPath (Join-Path $repo 'reference\base\Skyrim\Ammunitions') `
                             -File -Filter "*$($arrowHex)_Skyrim.esm.yaml" -ErrorAction SilentlyContinue)
if ($arrowFile.Count -ne 1) {
    throw "Substitute ammo $ENDERAL_ARROW is not a single Ammunition record in reference/base/Skyrim (found $($arrowFile.Count)). Regenerate reference/ before running this."
}
Write-Host "substitute ammo: $ENDERAL_ARROW -> $($arrowFile[0].Name)"

$changed = 0
$already = 0
foreach ($t in $targets) {
    $file = @(Get-ChildItem -LiteralPath $npcs -File -Filter "$($t.Editor) - *.yaml")
    if ($file.Count -ne 1) { throw "Expected exactly one NPC record for $($t.Editor), found $($file.Count)." }
    $path = $file[0].FullName
    $text = [IO.File]::ReadAllText($path)

    # CRLF tree: anchor with (?=\r?$), never '$' (CLAUDE.md - '$' silently fails to match before \r).
    $dead = [regex]::Escape($t.Dead)
    $rx   = "(?m)^(    Item: )$dead(?=\r?`$)"

    if ($text -match "(?m)^    Item: $([regex]::Escape($ENDERAL_ARROW))(?=\r?`$)") {
        Write-Host "  $($t.Editor): already on $ENDERAL_ARROW"
        $already++
        continue
    }
    $new = [regex]::Replace($text, $rx, "`${1}$ENDERAL_ARROW")
    if ($new -eq $text) {
        throw "$($t.Editor): neither '$($t.Dead)' nor '$ENDERAL_ARROW' found in its Items list. Upstream changed the inventory - re-derive before trusting this."
    }
    [IO.File]::WriteAllText($path, $new, (New-Object Text.UTF8Encoding($false)))
    Write-Host "  $($t.Editor): $($t.Dead) -> $ENDERAL_ARROW"
    $changed++
}

Write-Host "repointed $changed summon quiver(s); $already already correct."

if (($changed + $already) -ne $targets.Count) {
    throw "Expected $($targets.Count) archer summons handled, got $($changed + $already)."
}

# No other record may still name either dead arrow.
foreach ($t in $targets) {
    $stale = @(Select-String -Path (Join-Path $npcs '*.yaml') -SimpleMatch $t.Dead -List)
    if ($stale.Count -gt 0) {
        throw "$($t.Dead) still present in: $($stale.Path -join ', ')"
    }
}
Write-Host "no NPC record still references a dead arrow."
