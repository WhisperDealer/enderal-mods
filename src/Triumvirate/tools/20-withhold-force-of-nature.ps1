# 20 - Withhold Force of Nature from distribution (WD-37).
#
# Force of Nature transforms the player into the Treewarden, and on the reporting modlist the player
# has no body: they attack and cast normally and render nothing. It is NOT a defect in these records.
# Everything about them is provably correct - reloading a save while transformed displays the
# Treewarden perfectly - and a bare `player.setrace` from the console, with no Triumvirate script
# involved at all, reproduces the invisibility. The fault is in the live race-switch path on that
# setup, outside this mod.
#
# We cannot fix someone else's race-switch handling from here, and we will not ship a spell that a
# player can buy and find broken. So the spell stops being sold. This is the Apocalypse precedent
# (CLAUDE.md, "RENAME a ported mod's un-Enderal creatures"): ship what has actually been tested, and
# keep the rest as a TESTING BACKLOG rather than a lore or quality judgement.
#
# What this does NOT do, deliberately:
#
#   * It does not delete any record. TVR_Druid_A025_Spell_ForceOfNature, its magic effect, its race,
#     its skin and its tome all stay exactly as they are. Deleting them would break existing saves
#     where a player already owns the spell, and would throw away work that is correct.
#   * It does not empty TVR_Tomes_Litem_Druid_025_Alteration. That tier list holds the Force of
#     Nature tome and nothing else, so unhooking it from its parent is the whole edit and re-enabling
#     the spell later is one entry going back - see the end of this file for the exact line.
#
# The two paths the tome could reach a player by, both closed here:
#
#   1. VENDORS. TVR_Tomes_Litem_Druid_Alteration (43D320) carries three tier lists and is written
#      into three of Enderal's CustomMerchandise hooks - Vexin (Adreyo), and the Duneville and
#      Frostcliff Tavern Shrouded Mages. Dropping tier list 43820F from it removes the tome from all
#      three at once, and touches none of the other Druid tomes.
#   2. THE DEV CHEAT CHEST. TVR_Tomes_Litem_All (442449) lists every tome directly and is the
#      contents of Enai's TVR_Any_Container_CheatChest. 07-fix-script-bindings.ps1 already removed
#      the alias that filled it, so it is unreachable - but "unreachable" is exactly the state the
#      Apocalypse summons were in for a year before someone reached them, so the entry comes out too.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "20 - withholding Force of Nature from distribution (WD-37)"
$root = Get-EspRoot

$FoNTome     = '41EC7C:Triumvirate - Mage Archetypes.esp'   # TVR_Druid_A025_Book_ForceOfNature
$FoNTierList = '43820F:Triumvirate - Mage Archetypes.esp'   # TVR_Tomes_Litem_Druid_025_Alteration

function Get-LeveledList {
    param([Parameter(Mandatory)][string]$EditorID)
    $hit = Get-ChildItem -LiteralPath (Join-Path $root 'LeveledItems') -Filter "$EditorID - *.yaml" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $hit) { throw "leveled list not found: $EditorID" }
    return $hit.FullName
}

# Count "- Data:" blocks, which is one per leveled-list entry.
function Get-EntryCount {
    param([string]$Path)
    return ([regex]::Matches((Read-YamlText $Path), '(?m)^- Data:\s*(?=\r?$)')).Count
}

# Drop the whole entry block whose Reference is $FormKey.
#
# A leveled-list entry is a multi-line block:
#
#     - Data:
#         Level: 1
#         Reference: <FormKey>
#         Count: 1
#
# so Remove-YamlListEntries in 00-common.ps1 is the wrong tool - it only handles bare "- HEX:Plugin"
# sequence items. The block runs from its "- Data:" line to the next line that is neither indented
# nor blank, which is the same rule Remove-TopLevelBlock uses in 07 and the same trap CLAUDE.md
# records: a YAML block sequence sits at the SAME indentation as the key that owns it.
function Remove-LeveledEntry {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$FormKey)

    $lines   = @(Get-YamlLines $Path)
    $keep    = @()
    $i       = 0
    $dropped = 0

    while ($i -lt $lines.Count) {
        if ($lines[$i] -match '^- Data:\s*$') {
            # Collect the block, then decide.
            $block = @($lines[$i])
            $j = $i + 1
            while ($j -lt $lines.Count -and ($lines[$j] -match '^\s' -or $lines[$j].Trim() -eq '')) {
                # A blank line at the very end of the file is not part of the block.
                if ($lines[$j].Trim() -eq '' -and $j -eq $lines.Count - 1) { break }
                $block += $lines[$j]
                $j++
            }
            if (($block -join "`n") -match ('Reference:\s*' + [regex]::Escape($FormKey))) {
                $dropped++
            } else {
                $keep += $block
            }
            $i = $j
        } else {
            $keep += $lines[$i]
            $i++
        }
    }

    if ($dropped -gt 0) {
        $keep = Remove-EmptyCollectionKeys -Lines $keep
        Set-YamlLines -Path $Path -Lines $keep
    }
    return $dropped
}

$totalDropped = 0

# --- 1. vendors ---------------------------------------------------------------------------------
$parent = Get-LeveledList -EditorID 'TVR_Tomes_Litem_Druid_Alteration'
$before = Get-EntryCount $parent
$n = Remove-LeveledEntry -Path $parent -FormKey $FoNTierList
$after = Get-EntryCount $parent

if ($n -eq 0) {
    if ((Read-YamlText $parent) -match [regex]::Escape($FoNTierList)) {
        throw "TVR_Tomes_Litem_Druid_Alteration still references $FoNTierList but nothing was removed"
    }
    Write-Host "  1. vendors: already withheld - skipping"
} else {
    if ($n -ne 1)             { throw "expected to drop exactly 1 vendor entry, dropped $n" }
    if ($after -ne $before-1) { throw "entry count went $before -> $after, expected $($before-1)" }
    Write-Host ("  1. vendors: dropped the Force of Nature tier list ({0} -> {1} entries)" -f $before, $after)
    $totalDropped += $n
}

# --- 2. the dev cheat chest ---------------------------------------------------------------------
$all = Get-LeveledList -EditorID 'TVR_Tomes_Litem_All'
$before = Get-EntryCount $all
$n = Remove-LeveledEntry -Path $all -FormKey $FoNTome
$after = Get-EntryCount $all

if ($n -eq 0) {
    Write-Host "  2. cheat chest: already withheld - skipping"
} else {
    if ($n -ne 1)             { throw "expected to drop exactly 1 cheat-chest entry, dropped $n" }
    if ($after -ne $before-1) { throw "entry count went $before -> $after, expected $($before-1)" }
    Write-Host ("  2. cheat chest: dropped the Force of Nature tome ({0} -> {1} entries)" -f $before, $after)
    $totalDropped += $n
}

# --- 3. prove it is unreachable -----------------------------------------------------------------
# The point of the change is reachability, not a diff, so assert reachability rather than trusting
# the two edits above. Anything still naming the tome or its tier list, outside the tome record and
# the now-orphaned tier list themselves, is a distribution path we missed.
$leaks = @()
foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
    $name = $file.Name
    if ($name -like 'TVR_Druid_A025_Book_ForceOfNature - *')        { continue }  # the tome itself
    if ($name -like 'TVR_Tomes_Litem_Druid_025_Alteration - *')     { continue }  # the orphaned tier list
    $text = Read-YamlText $file.FullName
    foreach ($fk in @($FoNTome, $FoNTierList)) {
        if ($text -match ('Reference:\s*' + [regex]::Escape($fk))) {
            $leaks += ("{0} -> {1}" -f $name, $fk)
        }
    }
}
if ($leaks.Count -gt 0) {
    $leaks | ForEach-Object { Write-Host "    still reachable: $_" }
    throw "$($leaks.Count) distribution path(s) to Force of Nature survive"
}
Write-Host "  3. no leveled list or container still yields the Force of Nature tome"

Write-Host ("20 - done ({0} entr{1} removed)" -f $totalDropped, $(if ($totalDropped -eq 1) { 'y' } else { 'ies' }))

# ------------------------------------------------------------------------------------------------
# TO RE-ENABLE, once the invisibility is understood and fixed, add this entry back to
# TVR_Tomes_Litem_Druid_Alteration (43D320) and re-run verify-druid-transformations.ps1:
#
#     - Data:
#         Level: 1
#         Reference: 43820F:Triumvirate - Mage Archetypes.esp
#         Count: 1
#
# The cheat-chest entry does not need restoring; that list is unreachable by design.
# ------------------------------------------------------------------------------------------------
