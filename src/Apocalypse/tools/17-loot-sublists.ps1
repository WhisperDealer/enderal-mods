#requires -Version 5.1
<#
.SYNOPSIS
  Rebuild the five tome sublists and the scroll sublist from our own tree, so every tome and
  scroll is in the loot tables.

.DESCRIPTION
  `02-gen-distribution.ps1` builds `ZP_Apoc_Tomes_R000`..`R100` and `ZP_Apoc_Scrolls` at STAGING
  FormKeys, which step 5 then remaps into Apocalypse's own space (`1C1E71`-`1C1E76`). That makes 02
  un-re-runnable against the built tree: it would write `Apocalypse - Staging.esp` FormKeys back
  into records that have long since been remapped.

  This step does the same job on the other side of the merge -- it reads the Books and Scrolls out
  of `src/Apocalypse/ApocalypseESP/` and rewrites the six sublists with their real FormKeys. Same
  selection, same `Sort-Object EditorID` ordering and same record shape as 02, so on a full
  regeneration (where 02 already produced the full set) this rewrites them byte-identically and is
  a no-op.

  It exists because the set of withheld summons changed. All 15 Dremora/Xivilai/Daedra/Atronach/
  Dwemer summons are renamed for Enderal now (see `01-gen-renames.ps1`), so naming withholds nothing;
  what is left is that most of them have never been cast in game. `00-cut-summons.ps1` holds the one
  definition of which are still held back -- currently 12 tomes and 11 scrolls, leaving 163 and 133
  distributed.

  The host lists themselves are not touched. `02` injects a reference to each sublist into Enderal's
  loot lists and `06-weight-distribution.ps1` weights those injections; both point at the sublist by
  FormKey, so growing a sublist needs no change to either. Vendor stock is a separate mechanism
  entirely -- `07-place-vendor-tomes.ps1` writes tomes straight into the merchant hooks.

  Idempotent: always rebuilt from scratch, never appended to.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path (Split-Path -Parent $PSCommandPath) '00-cut-summons.ps1')

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$tree = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$out  = Join-Path $tree 'LeveledItems'
$enc  = New-Object System.Text.UTF8Encoding($false)
foreach ($d in @($tree, $out)) { if (-not (Test-Path -LiteralPath $d)) { throw "Not found: $d" } }

# The sublist FormIDs, in Apocalypse's own space. Step 5 put them here; do not renumber.
$sublists = [ordered]@{
    'ZP_Apoc_Tomes_R000' = '1C1E71'
    'ZP_Apoc_Tomes_R025' = '1C1E72'
    'ZP_Apoc_Tomes_R050' = '1C1E73'
    'ZP_Apoc_Tomes_R075' = '1C1E74'
    'ZP_Apoc_Tomes_R100' = '1C1E75'
    'ZP_Apoc_Scrolls'    = '1C1E76'
}
$modKey = 'Apocalypse - Magic of Skyrim.esp'

function Read-Recs([string]$group) {
    $dir = Join-Path $tree $group
    if (-not (Test-Path -LiteralPath $dir)) { throw "Not found: $dir" }
    @(Get-ChildItem -LiteralPath $dir -File -Filter *.yaml | ForEach-Object {
        $t = [IO.File]::ReadAllText($_.FullName)
        [pscustomobject]@{
            EditorID = [regex]::Match($t, '(?m)^EditorID: (.+?)(?=\r?$)').Groups[1].Value
            FormKey  = [regex]::Match($t, '(?m)^FormKey: (.+?)(?=\r?$)').Groups[1].Value
        }
    })
}

function Write-Sublist([string]$EditorID, [object[]]$Refs) {
    $hex = $sublists[$EditorID]
    $sb  = New-Object Text.StringBuilder
    [void]$sb.AppendLine("FormKey: ${hex}:$modKey")
    [void]$sb.AppendLine("EditorID: $EditorID")
    [void]$sb.AppendLine('Version2: 1')
    [void]$sb.AppendLine('Flags:')
    [void]$sb.AppendLine('- CalculateFromAllLevelsLessThanOrEqualPlayer')
    [void]$sb.AppendLine('- CalculateForEachItemInCount')
    [void]$sb.AppendLine('Entries:')
    foreach ($r in $Refs) {
        [void]$sb.AppendLine('- Data:')
        [void]$sb.AppendLine('    Level: 1')
        [void]$sb.AppendLine("    Reference: $($r.FormKey)")
        [void]$sb.AppendLine('    Count: 1')
    }
    # CRLF, to match every other record Spriggit wrote in this tree.
    $text = ($sb.ToString() -replace "(?<!`r)`n", "`r`n")
    $path = Join-Path $out "$EditorID - ${hex}_$modKey.yaml"
    if (-not (Test-Path -LiteralPath $path)) { throw "sublist record missing, refusing to invent it: $path" }
    [IO.File]::WriteAllText($path, $text, $enc)
    "  {0}  {1,-20} {2,3} entries" -f $hex, $EditorID, $Refs.Count
}

# --- tomes, one sublist per Apocalypse spell rank -------------------------------------------------
$allBooks = @(Read-Recs 'Books' | Where-Object { $_.EditorID -match '^WB_[ACDIR](000|025|050|075|100)_.+_Book$' })
if ($allBooks.Count -ne $ALL_TOMES) { throw "expected $ALL_TOMES tomes in the tree, found $($allBooks.Count)" }
$books = @($allBooks | Where-Object { $removed -notcontains ($_.EditorID -replace '_Book$','') })
if ($books.Count -ne $SHIP_TOMES) { throw "expected $SHIP_TOMES distributable tomes, found $($books.Count)" }

'Tome sublists:'
$placed = 0
foreach ($rank in '000', '025', '050', '075', '100') {
    $refs = @($books | Where-Object { $_.EditorID -match "^WB_[ACDIR]$rank`_" } | Sort-Object EditorID)
    if ($refs.Count -eq 0) { throw "rank $rank matched no tomes - the EditorID probe is wrong." }
    Write-Sublist -EditorID "ZP_Apoc_Tomes_R$rank" -Refs $refs
    $placed += $refs.Count
}
if ($placed -ne $SHIP_TOMES) { throw "sublists hold $placed tomes, expected $SHIP_TOMES" }

# --- scrolls --------------------------------------------------------------------------------------
$allScrolls = @(Read-Recs 'Scrolls')
if ($allScrolls.Count -ne $ALL_SCROLLS) { throw "expected $ALL_SCROLLS scrolls in the tree, found $($allScrolls.Count)" }
$scrolls = @($allScrolls | Where-Object { $removed -notcontains ($_.EditorID -replace '_Scroll$','') } | Sort-Object EditorID)
if ($scrolls.Count -ne $SHIP_SCROLLS) { throw "expected $SHIP_SCROLLS distributable scrolls, found $($scrolls.Count)" }
"`nScroll sublist:"
Write-Sublist -EditorID 'ZP_Apoc_Scrolls' -Refs $scrolls

"`n$SHIP_TOMES tomes and $SHIP_SCROLLS scrolls are in the loot sublists; $CUT_TOMES tomes and $CUT_SCROLLS scrolls withheld pending in-game testing."
