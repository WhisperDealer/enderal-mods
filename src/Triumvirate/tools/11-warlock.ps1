# 11 - The Warlock line (WD-13).
#
# Record-level work for this archetype was done in 08 (the four Illusion-school staff templates).
# The Spirit-binding loop, the poison->minion amplification and the Magister build-up are all
# driven by Triumvirate's own records and property-filled scripts (WD-17: zero hardcoded
# FormIDs), and the Hurl holding cell is the mod's own TVR_Cell 2E99EB - nothing to repoint.
#
# Renames, per arch-docs/Triumvirate/naming-table.md (decision 2, option A + the inherited
# Apocalypse mapping): Oblivion-as-a-place becomes Sinistra, the dark higher school - the same
# call Apocalypse shipped with "Oblivion Unbound" -> "Sinistra Unbound". The Warlock's demons
# keep their own invented names (Gremlin, Temple Grim, Ravagor, Magister, Leviathan, Oathbreaker
# - none is an Elder Scrolls term), and no player-facing string in the mod says "Daedra"
# (checked: the only Daedric* hits are internal dialog-branch and sound-descriptor names).
#
# Deliberately NOT touched:
#   ElementalPotency 0CB41A HasPerk conditions on the ten Conjure effects. The base variants
#   carry "HasPerk == 0" (true forever with the perk dead), the _Potent variants "== 1" (false
#   forever) - so every summon uses its base strength. Enderal has no stronger-summons perk to
#   repoint at (the Sinistrope line was checked; Mystical Binding is summoned WEAPONS).
#   Documented deviation.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "11 - Warlock (WD-13)"
$root = Get-EspRoot

# Longest first: the spell name, then the two description phrasings.
$renames = @(
    @('Hurl Into Oblivion', 'Hurl Into Sinistra'),
    @('into Oblivion',      'into Sinistra'),
    @('to Oblivion',        'to Sinistra')
)
$total = 0
foreach ($r in $renames) {
    $n = Update-TreeStrings -Old $r[0] -New $r[1] -MustExistAfter
    Write-Host ("  '{0}' -> '{1}': {2}" -f $r[0], $r[1], $n)
    $total += $n
}

$left = @()
foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
    foreach ($line in Get-YamlLines $file.FullName) {
        if ($line -match 'Oblivion' -and $line -notmatch 'EditorID|FormKey|File(Name)?:|Name: [A-Za-z_0-9]+\s*$') {
            $left += ("{0}: {1}" -f $file.Name, $line.Trim())
        }
    }
}
if ($left.Count -gt 0) {
    $left | ForEach-Object { Write-Host "    remaining: $_" }
    throw "$($left.Count) player-facing Oblivion string(s) survived."
}
Write-Host "11 - done"
