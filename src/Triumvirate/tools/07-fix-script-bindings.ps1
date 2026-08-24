# 07 - Fix the two script bindings that are broken in Enderal.
#
# WD-17. Both were found by decompiling the BSA's 106 scripts and reading the records they bind to,
# not by reasoning from names.
#
# 1. TVR_Shaman_Violence_Effect_Worldshatter_Hazard_AshShell binds a script called
#    DLC2AshShellScript. That is BETHESDA's Dragonborn script, not one of Triumvirate's, and it is
#    NOT in Triumvirate's BSA - the 106 scripts there were listed and it is absent. Enderal ships no
#    Dragonborn scripts either, so the binding can never resolve and the effect logs a missing-script
#    warning on every load. 04 already removed its dead DLC2AshShellDmgPerk property; this removes
#    the binding itself.
#
#    Removing the whole VirtualMachineAdapter rather than just the script entry: it was the only
#    script on the record, and Spriggit omits an empty collection key entirely.
#
# 2. TVR_Manager_Quest carries an alias, TVR_CheatChicken, with
#    ForcedReference: 1066DF:Skyrim.esm and an Items block holding TVR_Tomes_Litem_All - a UseAll
#    leveled item containing EVERY Triumvirate spell tome.
#
#    In vanilla Skyrim 1066DF is a placed chicken in Riverwood. It is Enai's developer cheat: loot
#    the chicken, get all 75 tomes. In ENDERAL the same FormID is a placed
#    _00E_PaintingSquarePortrait_04 in MQ07aManor - so the alias binds to a painting in an Enderal
#    manor and tries to stuff the mod's entire spell list into it.
#
#    This is the drift class again, and it is one my verify-ref-drift.ps1 could NOT see: that script
#    only compares top-level records carrying an EditorID, and a placed reference has neither. Worth
#    remembering as a limit of the tool rather than a gap in the data.
#
#    Removing the alias, not repointing it. It is a debug leftover with no player-facing purpose, and
#    leaving it costs something concrete: a non-optional alias that fails to fill stops a quest
#    starting, and TVR_Manager_Quest is what grants the player TVR_Primal_Perk. With no alias at all
#    the quest starts unconditionally, which is strictly safer than binding it to a painting.
#
# What this script deliberately does NOT touch: TVR_PopulateSpellBooks2_Quest. Its script calls
# AddToFaction/AddItem/AddForm on ~76 dead properties and will log that many "Cannot call X on a None
# object" errors once at game start. That is WD-16's to fix by rebuilding the distribution, and there
# is a trap waiting there - the script's FIRST line is TVR_Conversion_Quest.Start(), which does real
# work on a quest that exists. Do not neutralise the quest wholesale; make its work empty.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "07 - fixing broken script bindings"

$root = Get-EspRoot
$changes = 0

function Get-Record {
    param([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$EditorID)
    $hit = Get-ChildItem -LiteralPath (Join-Path $root $Group) -Filter "$EditorID - *.yaml" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $hit) { throw "record not found: $Group\$EditorID" }
    return $hit.FullName
}

# Remove a top-level YAML key and everything belonging to it.
#
# "Everything indented beneath it" is NOT the right test, and getting it wrong here removed only the
# `Aliases:` line and left its contents orphaned at column 0 - the assertion at the bottom caught it.
# A YAML block sequence sits at the SAME indentation as the key that owns it:
#
#     Aliases:
#     - Name: TVR_CheatChicken
#
# so the block ends at the next line that is neither indented NOR a `- ` item at column 0. This is
# the same trap CLAUDE.md records against Remove-EmptyCollectionKeys, in its other direction.
function Remove-TopLevelBlock {
    param([string]$Path, [string]$Key)
    $lines = Get-YamlLines $Path
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('^' + [regex]::Escape($Key) + ':\s*$')) { $start = $i; break }
    }
    if ($start -lt 0) { return 0 }
    $end = $lines.Count
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '') { continue }
        if ($lines[$i] -match '^\s') { continue }        # indented -> still inside the block
        if ($lines[$i] -match '^-\s') { continue }        # the key's own sequence item
        $end = $i; break
    }
    $keep = @()
    if ($start -gt 0) { $keep += $lines[0..($start - 1)] }
    if ($end -lt $lines.Count) { $keep += $lines[$end..($lines.Count - 1)] }
    Set-YamlLines -Path $Path -Lines $keep
    return ($end - $start)
}

# --- 1. the unresolvable DLC2AshShellScript binding ---------------------------------------------
$ash = Get-Record -Group 'MagicEffects' -EditorID 'TVR_Shaman_Violence_Effect_Worldshatter_Hazard_AshShell'
if ((Read-YamlText $ash) -match 'DLC2AshShellScript') {
    $n = Remove-TopLevelBlock -Path $ash -Key 'VirtualMachineAdapter'
    Assert-Changed -Count $n -What 'AshShell VMAD removal'
    Write-Host ("    TVR_Shaman_Violence_Effect_Worldshatter_Hazard_AshShell  -{0} lines (DLC2AshShellScript binding)" -f $n)
    $changes += $n
}

# --- 2. the TVR_CheatChicken debug alias --------------------------------------------------------
$mgr = Get-Record -Group 'Quests' -EditorID 'TVR_Manager_Quest'
if ((Read-YamlText $mgr) -match 'TVR_CheatChicken') {
    $n = Remove-TopLevelBlock -Path $mgr -Key 'Aliases'
    Assert-Changed -Count $n -What 'CheatChicken alias removal'
    Write-Host ("    TVR_Manager_Quest  -{0} lines (TVR_CheatChicken debug alias)" -f $n)
    $changes += $n

    # The quest must keep its script and its two properties - that is what grants TVR_Primal_Perk.
    $text = Read-YamlText $mgr
    foreach ($needle in @('TVR_Manager_Quest', 'TVR_Primal_Perk', 'StartGameEnabled')) {
        if ($text -notmatch [regex]::Escape($needle)) { throw "TVR_Manager_Quest lost '$needle' - the edit took too much." }
    }
    Write-Host "      quest still StartGameEnabled and still fills TVR_Primal_Perk"
}

if ($changes -eq 0) { Write-Host "  nothing to do - already applied" }

# --- prove both are gone ------------------------------------------------------------------------
$left = @()
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.yaml') {
    $text = Read-YamlText $file.FullName
    foreach ($needle in @('DLC2AshShellScript', 'TVR_CheatChicken', '1066DF:Skyrim.esm')) {
        if ($text -match [regex]::Escape($needle)) { $left += ("{0} -> {1}" -f $file.Name, $needle) }
    }
}
if ($left.Count -gt 0) {
    $left | ForEach-Object { Write-Host "    remaining: $_" }
    throw "$($left.Count) broken binding(s) survived."
}

Write-Host "07 - done"
