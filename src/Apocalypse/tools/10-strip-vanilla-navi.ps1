#requires -Version 5.1
<#
.SYNOPSIS
  Strip the inherited vanilla-Skyrim content out of Apocalypse's NAVI record.

.DESCRIPTION
  Apocalypse ships a NavigationMeshInfoMap (NAVI, 012FB4:Skyrim.esm) because it adds two interior
  cells with navmeshes. The Creation Kit regenerates the WHOLE record when it does that, so the
  plugin carries Bethesda's navigation map alongside its own three entries:

      MapInfos:          13 entries -- 3 Apocalypse, 10 vanilla Skyrim exteriors whose
                                       MergedTo/PreferredMerges lists run to thousands of FormIDs
      PreferredPathing:  6312 references, every one vanilla, zero Apocalypse

  None of the vanilla content exists in Enderal. Enderal's Skyrim.esm has a NAVI with a NULL
  FormKey (Spriggit writes it as NavigationMeshInfoMaps/Null.yaml) and its real navigation map is
  000802:Enderal - Forgotten Stories.esm, so this record is a plugin-authored NAVI in Skyrim.esm's
  space built against a Skyrim.esm that is not the one Enderal ships. That accounts for 3498 of the
  plugin's 4077 missing references - 86% of them.

  We keep the record rather than deleting it: its three Apocalypse-owned entries are what register
  the navmeshes in WB_Dreamscape_Cell (0A0252, 0A0253) and WB_Entomb_Cell (0ABFDE), and they carry
  no vanilla references of their own.

  Idempotent. Re-running after a strip reports "already stripped" and changes nothing.

.NOTES
  Not verified in-game whether the engine merges or replaces Enderal's navigation map when a
  later plugin supplies its own NAVI. That uncertainty is the point: a NAVI built against the
  wrong master is not something to ship on the assumption it is ignored. NPC pathing in Ark and
  Riverville is the in-game check.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$navi = Join-Path $repo 'src\Apocalypse\ApocalypseESP\NavigationMeshInfoMaps\012FB4_Skyrim.esm.yaml'

if (-not (Test-Path -LiteralPath $navi)) { throw "NAVI record not found: $navi" }

$eol   = "`r`n"          # Spriggit writes CRLF; keep it
$lines = [IO.File]::ReadAllText($navi) -split "`r?`n"

# ---- header: everything before "MapInfos:"
$mapIdx = [array]::FindIndex([string[]]$lines, [Predicate[string]] { param($l) $l -eq 'MapInfos:' })
if ($mapIdx -lt 0) { throw "No 'MapInfos:' block in $navi - record shape changed, re-check before editing." }
$header = $lines[0..$mapIdx]

# ---- MapInfos entries: "- NavigationMesh: <hex>:<master>" up to the next one or the next top-level key
$entries = @()
$cur = $null
for ($i = $mapIdx + 1; $i -lt $lines.Count; $i++) {
    $l = $lines[$i]
    if ($l -match '^[A-Za-z]') { break }                      # a new top-level key ends MapInfos
    if ($l -match '^- NavigationMesh: ([0-9A-F]{6}):(.+?)\s*$') {
        if ($cur) { $entries += , $cur }
        $cur = [pscustomobject]@{ Master = $Matches[2].Trim(); Lines = @($l) }
    } elseif ($cur) {
        $cur.Lines += $l
    }
}
if ($cur) { $entries += , $cur }

$ourMaster = 'Apocalypse - Magic of Skyrim.esp'
$keep = @($entries | Where-Object { $_.Master -eq $ourMaster })
$drop = @($entries | Where-Object { $_.Master -ne $ourMaster })

Write-Host "MapInfos entries: $($entries.Count)  keep=$($keep.Count) (Apocalypse)  drop=$($drop.Count) (vanilla)"

if ($keep.Count -eq 0) {
    throw "No Apocalypse-owned MapInfos entries found. Refusing to write an empty NAVI - re-check the record."
}
if ($drop.Count -eq 0 -and $lines -notcontains 'PreferredPathing:') {
    Write-Host 'already stripped - nothing to do.'
    return
}

# Sanity: the entries we keep must not themselves reference anything outside our own plugin.
foreach ($e in $keep) {
    $foreign = @([regex]::Matches(($e.Lines -join $eol), '\b[0-9A-F]{6}:([^\r\n]+?\.(?:esm|esp))\b') |
                 Where-Object { $_.Groups[1].Value.Trim() -ne $ourMaster })
    if ($foreign.Count -gt 0) {
        throw "Kept MapInfos entry references a foreign master ($($foreign[0].Value)) - resolve by hand before stripping."
    }
}

$out = @($header) + @($keep | ForEach-Object { $_.Lines }) + ''
[IO.File]::WriteAllText($navi, ($out -join $eol), (New-Object Text.UTF8Encoding($false)))

$after = [IO.File]::ReadAllText($navi)
$remaining = @([regex]::Matches($after, '\b[0-9A-F]{6}:Skyrim\.esm\b'))
# Only the record's own identity line may still say Skyrim.esm.
if ($remaining.Count -ne 1) {
    throw "Expected exactly 1 remaining ':Skyrim.esm' (the record's own FormKey); found $($remaining.Count)."
}

Write-Host "stripped: $($lines.Count) lines -> $($out.Count) lines; dropped PreferredPathing and $($drop.Count) vanilla MapInfos entries."
