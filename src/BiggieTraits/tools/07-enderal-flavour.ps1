# 07 - Make the surviving traits' text true in Enderal, and drop one now-meaningless condition.
#
# Only strings that are FACTUALLY WRONG in Enderal are touched - this is a conversion, not a
# rewrite. Each was found by sweeping every description for Elder Scrolls proper nouns.
#
#   Pacifist    "Those born under the sign of the Atronach do not gain any benefits" refers to a
#               standing stone Enderal does not have. The matching HasSpell 0E5F51 condition
#               compares equal to 0 - "does NOT have the Atronach Stone" - so in Enderal it is
#               always true and the trait works. The condition is removed because it can only
#               ever be true, which also clears the plugin's last unresolved external reference.
#   Bad Natured "wearing a divine amulet will hurt you" - the effect behind it was removed in 06,
#               because Enderal has no Divines and no such amulets.
#   Bane of the Wicked
#               Its conditions are HasKeyword ActorTypeUndead 013796 and ActorTypeDaedra 013797,
#               and BOTH fire in Enderal: 19 races carry the undead keyword (DraugrRace alone is
#               used by 94 Enderal NPCs, plus the skeletons and _00E_Ability_UndeadServantRace)
#               and 8 carry the daedra keyword (the atronachs and Dremora, plus Enderal's own
#               _00E_OorbayaRace, _00E_SoilElementalRace_Small and _00E_StoneGolemRace). So the
#               trait works fully; only the words "daedra and werewolves" name creatures Enderal
#               does not have. Reworded to what the keywords actually hit.
#   Reset menu  Removing a trait is described as costing a dragon soul. Enderal has no dragon
#               souls. Traits_ResetMenuScript does the ModAv unconditionally rather than gating on
#               it, so the reset already works - only the prompt lies. (The .psc line is removed
#               separately, with the script edits.)

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "07 - Enderal flavour pass"

$root = Get-EspRoot

$edits = @(
    @{
        Folder = 'Spells'; Record = 'Traits_PacifistAb'
        From   = ' Those born under the sign of the Atronach do not gain any benefits.'
        To     = ''
        Why    = 'Atronach Stone does not exist in Enderal'
    },
    @{
        Folder = 'Spells'; Record = 'Traits_BadNaturedAb'
        From   = ' and wearing a divine amulet will hurt you'
        To     = ''
        Why    = 'no Divines, no divine amulets'
    },
    @{
        Folder = 'Spells'; Record = 'Traits_BaneoftheWickedAb'
        From   = 'undead, daedra and werewolves'
        To     = 'undead, elementals and golems'
        Why    = 'names what ActorTypeUndead/ActorTypeDaedra actually tag in Enderal'
    },
    @{
        Folder = 'Messages'; Record = 'Traits_ResetConfirmMsg'
        From   = 'spend a dragon soul to remove this trait'
        To     = 'remove this trait'
        Why    = 'Enderal has no dragon souls'
    }
)

$applied = 0
foreach ($e in $edits) {
    $file = Get-ChildItem -Path (Join-Path $root $e.Folder) -Filter "$($e.Record) - *.yaml" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $file) { Write-Host ("  {0}: record not present - skipped" -f $e.Record); continue }
    $text = Read-YamlText $file.FullName
    if ($text.Contains($e.From)) {
        Write-YamlText -Path $file.FullName -Text $text.Replace($e.From, $e.To)
        Write-Host ("  {0}: reworded ({1})" -f $e.Record, $e.Why)
        $applied++
    } else {
        Write-Host ("  {0}: already applied" -f $e.Record)
    }
}

# --- drop Pacifist's always-true Atronach condition ---------------------------------------------
$pacifist = Get-ChildItem -Path (Join-Path $root 'Spells') -Filter 'Traits_PacifistAb - *.yaml' | Select-Object -First 1
$condDropped = 0
if ($pacifist) {
    $lines = Get-YamlLines $pacifist.FullName
    $spellIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*Spell: 0E5F51:Skyrim\.esm\s*$') { $spellIdx = $i; break }
    }
    if ($spellIdx -ge 0) {
        # Walk back to the '- MutagenObjectType: ConditionFloat' that opens this condition.
        $startIdx = $spellIdx
        while ($startIdx -ge 0 -and $lines[$startIdx] -notmatch '^\s*-\s+MutagenObjectType: Condition') { $startIdx-- }
        if ($startIdx -lt 0) { throw "Could not find the condition opening the Atronach check." }
        $startIndent = ($lines[$startIdx] -replace '^(\s*).*$', '$1').Length
        $endIdx = $lines.Count
        for ($i = $startIdx + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq '') { continue }
            $indent = ($lines[$i] -replace '^(\s*).*$', '$1').Length
            if ($indent -le $startIndent) { $endIdx = $i; break }
        }
        $keep = @()
        if ($startIdx -gt 0) { $keep += $lines[0..($startIdx - 1)] }
        if ($endIdx -lt $lines.Count) { $keep += $lines[$endIdx..($lines.Count - 1)] }
        $keep = Remove-EmptyCollectionKeys -Lines $keep
        Set-YamlLines -Path $pacifist.FullName -Lines $keep
        $condDropped = $endIdx - $startIdx
        Write-Host ("  Traits_PacifistAb: removed {0} line(s) - the always-true Atronach condition" -f $condDropped)
    } else {
        Write-Host "  Traits_PacifistAb: Atronach condition already removed"
    }
}

if (($applied + $condDropped) -eq 0) {
    Write-Host "  nothing to do - already applied"
}

Write-Host "07 - done"
