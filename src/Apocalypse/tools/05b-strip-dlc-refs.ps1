#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Remove every reference to a Bethesda DLC from the merged tree.
#
# WHY THIS EXISTS. We drop the `Dragonborn.esm` master (the DLC in Enderal are 44 KB stubs holding
# 1-2 records between them, so a reference into one resolves to nothing anyway), and Spriggit then
# cannot map a `:Dragonborn.esm` FormKey to a master index - the build fails outright with
# "Could not map FormKey to a master index".
#
# For 10.2.3 this was done BY HAND and never written down as a step, which is exactly the trap
# CLAUDE.md guardrail 11 exists to close: the 10.3.0 bump reintroduced three of them
# (`WB_ConjureDeadeyeCaptain_Addon_NiceHat`'s `AdditionalRaces` entry for `DLC2MiraakRace`,
# `WB_IllusionNightmare_ImpactSet_Ban_Terrain`'s ash-material impact pair, and a script object
# property on `WB_Alt_WorldInteractions4_Effect_FabricateObject`) and a regeneration that trusted
# the old note would have failed at deserialize with no idea why.
#
# WHAT IT DOES. Deletes the whole **list entry** containing the DLC FormKey, not just the line, so
# a two-line `- Material:/Impact:` pair or a `- Name: ''/Object:` script property goes as a unit and
# the YAML stays well-formed. A DLC FormKey that is NOT inside a list entry (a plain top-level field
# such as `Object: <hex>:Dragonborn.esm` on the record itself) is reported and left alone - deleting
# a required field is a different decision and should be made deliberately, not by this script.
#
# The output matches what 10.2.3 shipped, byte for byte, on all three records.

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$tree = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$enc  = New-Object System.Text.UTF8Encoding($false)
$dlc  = 'Dawnguard\.esm|HearthFires\.esm|Dragonborn\.esm'

$files = @(Get-ChildItem $tree -Recurse -Filter *.yaml -File |
    Where-Object { [IO.File]::ReadAllText($_.FullName) -match $dlc })

if ($files.Count -eq 0) {
    "no DLC references in the tree - nothing to strip"
    return
}

$removed = 0
$stuck   = @()
foreach ($f in $files) {
    $lines = [IO.File]::ReadAllLines($f.FullName)
    $keep  = New-Object System.Collections.ArrayList
    $cuts  = 0

    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -notmatch $dlc) { [void]$keep.Add($lines[$i]); continue }

        # Walk back to the start of the list entry this line belongs to: the nearest preceding
        # line (this one included) that begins a sequence item.
        $start = -1
        for ($j = $i; $j -ge 0; $j--) {
            if ($lines[$j] -match '^(\s*)- ') { $start = $j; break }
            # A key at lower indent than the DLC line means we left the entry without finding one.
            if ($lines[$j] -match '^\s*[A-Za-z]') {
                $ind  = ($lines[$j] -replace '^(\s*).*', '$1').Length
                $dind = ($lines[$i] -replace '^(\s*).*', '$1').Length
                if ($ind -lt $dind) { break }
            }
        }
        if ($start -lt 0) {
            $stuck += "$($f.Name): line $($i + 1) '$($lines[$i].Trim())' is not inside a list entry"
            [void]$keep.Add($lines[$i]); continue
        }

        # The entry runs until the first non-blank line indented no further than the `- ` itself.
        # Every continuation of a sequence item is indented PAST its dash, so "indent <= entry
        # indent" is the complete terminator: the next sibling `- `, a parent key, or a dedent to
        # an outer list. Testing only for a same-indent sibling misses the dedent case and eats the
        # first line of the outer list's next entry - which is exactly what it did here, silently.
        $indent = ($lines[$start] -replace '^(\s*)- .*', '$1').Length
        $end = $lines.Length
        for ($j = $start + 1; $j -lt $lines.Length; $j++) {
            if ($lines[$j].Trim() -eq '') { continue }
            if (($lines[$j] -replace '^(\s*).*', '$1').Length -le $indent) { $end = $j; break }
        }

        # $start may already be in $keep (we only look back within the same entry, and the entry's
        # first line is either this line or an earlier one we appended). Trim it back off.
        while ($keep.Count -gt $start) { $keep.RemoveAt($keep.Count - 1) }
        $i = $end - 1
        $cuts++
    }

    if ($cuts -gt 0) {
        [IO.File]::WriteAllText($f.FullName, (($keep -join "`r`n") + "`r`n"), $enc)
        $removed += $cuts
        "  {0,-58} -{1} entr{2}" -f ($f.Name -replace ' - .*', ''), $cuts, $(if ($cuts -eq 1) { 'y' } else { 'ies' })
    }
}

if ($stuck.Count -gt 0) {
    $stuck | ForEach-Object { "  !! $_" }
    throw "$($stuck.Count) DLC reference(s) are not list entries - decide what each field should become, then extend this script"
}

# Assert the tree is genuinely clean rather than trusting the loop.
$left = @(Get-ChildItem $tree -Recurse -Filter *.yaml -File |
    Where-Object { [IO.File]::ReadAllText($_.FullName) -match $dlc })
if ($left.Count -gt 0) { throw "still $($left.Count) file(s) referencing a DLC after the strip" }

"`n$removed DLC list entr$(if ($removed -eq 1) { 'y' } else { 'ies' }) removed across $($files.Count) record(s); tree is DLC-free."

# --- every master the tree references must be one the header declares --------------------------
# The FS master was hand-added to the 10.2.3 tree and step 5's header literal never learned about
# it, so a regeneration produced a plugin that could not be deserialized at all - "Could not map
# FormKey to a master index", from 63 FS FormKeys in the forwarded leveled lists and the six
# merchant hooks. Derive the requirement from the records rather than trusting the literal, and do
# it here, after the strip, when the tree is in its final shape.
$header   = [IO.File]::ReadAllText((Join-Path $tree 'RecordData.yaml'))
$declared = @([regex]::Matches($header, '(?m)^  - Master: (.+?)\s*(?=\r?$)') | ForEach-Object { $_.Groups[1].Value })
$used = @{}
foreach ($f in Get-ChildItem $tree -Recurse -Filter *.yaml -File) {
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName), '[0-9A-F]{6}:([^\r\n]+?\.es[pml])')) {
        $used[$m.Groups[1].Value] = $true
    }
}
$undeclared = @($used.Keys | Where-Object { $_ -ne 'Apocalypse - Magic of Skyrim.esp' -and $declared -notcontains $_ })
if ($undeclared.Count -gt 0) {
    throw "tree references undeclared master(s): $($undeclared -join ', ') - add them to the header in 05-merge-tree.ps1"
}
"masters declared: $($declared -join ', ') - all references resolve to one of them."
