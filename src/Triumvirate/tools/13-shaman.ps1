# 13 - The Shaman line (WD-15).
#
# 1. TVR_Shaman_Elemental_Effect_ControlFlames_DirectDamage carries a VMAD property "MG01"
#    pointing at vanilla's College of Winterhold quest, dead here. The property is removed - an
#    unfilled property is None at runtime, exactly what the dead reference already produced, and
#    removing it keeps the dead-ref audit clean.
#
# 2. TVR_Senua_Descriptor_Release_ShieldOfAwe - the release sound of the Shaman's master rune -
#    was copied from a civil-war ambience descriptor and kept its "GetGlobalValue
#    CWDistantCatapultsAMB == 1" condition. That global is dead in Enderal, so the master spell's
#    release sound NEVER plays. The condition block is removed; the .wav files are vanilla
#    (Skyrim - Sounds.bsa, which Enderal ships), so the sound itself resolves fine.
#
# 3. Renames, per arch-docs/Triumvirate/naming-table.md (decision 4, option A): the All-Maker and
#    the Earth Bones are Skaal/Nordic religion with no Enderal referent; the Shaman's frame
#    becomes the ancestors - Enderal ships an AncestralSpiritFaction, and Triumvirate's own
#    subsystem prefix for this line is already "Ancestors". "Eye of the All-Maker" -> "Eye of
#    the Ancestors"; the Fissure staff "Staff of Earth Bones" -> "Staff of Fissures", following
#    both Enai's own staff naming (Staff of Suggestions) and Enderal's (Staff of Fireball).
#
# The Fylgja possession, totem placement, vision curses and Sacred Hearth persistence are
# runtime behaviour on the mod's own records - WD-18 test matrix rows, not record edits. The
# Fylgjas' granted spells (Winter's Howl, Crystalize, Sun Flare, Grand Healing) are all
# Triumvirate's own subspell copies and resolve - the only dead piece was the WI-say script 08
# already removed.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "13 - Shaman (WD-15)"
$root = Get-EspRoot

function Get-RecordFile {
    param([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$EditorID)
    $hit = Get-ChildItem -LiteralPath (Join-Path $root $Group) -Filter "$EditorID - *.yaml" | Select-Object -First 1
    if (-not $hit) { throw "record not found: $Group\$EditorID" }
    return $hit.FullName
}

# --- 1. dead MG01 property ----------------------------------------------------------------------
$f = Get-RecordFile 'MagicEffects' 'TVR_Shaman_Elemental_Effect_ControlFlames_DirectDamage'
if ((Read-YamlText $f) -match '01F251:Skyrim\.esm') {
    $n = Remove-SequenceItemContaining -Path $f -ContainsPattern 'Object: 01F251:Skyrim\.esm'
    Assert-Changed -Count $n -What 'MG01 property removal'
    Write-Host "  1. MG01 property removed: $n lines"
} else {
    Write-Host "  1. MG01 property already gone"
}

# --- 2. Shield of Awe release sound gate --------------------------------------------------------
$f = Get-RecordFile 'SoundDescriptors' 'TVR_Senua_Descriptor_Release_ShieldOfAwe'
if ((Read-YamlText $f) -match '10DE1E:Skyrim\.esm') {
    $n = Remove-TopLevelKeyBlock -Path $f -Key 'Conditions'
    Assert-Changed -Count $n -What 'ShieldOfAwe sound condition removal'
    if ((Read-YamlText $f) -notmatch 'SoundFiles:') { throw "descriptor lost its sound files - the edit took too much" }
    Write-Host "  2. dead sound condition removed: $n lines"
} else {
    Write-Host "  2. sound condition already gone"
}

# --- 3. renames ---------------------------------------------------------------------------------
$renames = @(
    @('Eye of the All-Maker', 'Eye of the Ancestors'),
    @('Staff of Earth Bones', 'Staff of Fissures')
)
foreach ($r in $renames) {
    $n = Update-TreeStrings -Old $r[0] -New $r[1] -MustExistAfter
    Write-Host ("  3. '{0}' -> '{1}': {2}" -f $r[0], $r[1], $n)
}

# --- prove nothing player-facing survives -------------------------------------------------------
$left = @()
foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
    foreach ($line in Get-YamlLines $file.FullName) {
        if ($line -match 'All-?Maker|Earth Bones|01F251:Skyrim\.esm|10DE1E:Skyrim\.esm' -and
            $line -notmatch 'EditorID|FormKey|File(Name)?:|Name: [A-Za-z_0-9]+\s*$') {
            $left += ("{0}: {1}" -f $file.Name, $line.Trim())
        }
    }
}
if ($left.Count -gt 0) {
    $left | ForEach-Object { Write-Host "    remaining: $_" }
    throw "$($left.Count) Shaman fix(es) survived."
}
Write-Host "13 - done"
