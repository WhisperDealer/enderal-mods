#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Re-check the built tree against Enderal's own mana scale. Run after 14-magicka-costs.ps1, and
# after any regeneration - a hand edit and an upstream change look identical in a diff, so the
# verifier is what proves the tree still says what we decided it should (CLAUDE.md guardrail 12).
#
# Two assertions, both absolute rather than diff-based:
#
#   1. Every spell this mod's tomes teach carries ManualCostCalc. Without it the engine derives the
#      cost from effect magnitude and duration at runtime and the authored BaseCost is dead text -
#      the original bug, and one that is invisible in the YAML because the stale CK value still
#      sits there looking authoritative.
#   2. Every such spell's BaseCost sits inside the band Enderal uses for that tier.
#
# The bands are Enderal's own tome-taught spells with authored costs, measured from
# reference/base/{Skyrim,EnderalFS}/Spells joined through reference/base/*/Books. They are
# hardcoded so this runs without reference/, which is gitignored.

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$mine = Join-Path $repo 'src\Apocalypse\ApocalypseESP'

# tier -> @(min, max) across Enderal's 249 authored tome-taught spells
$band = @{
  Novice     = @(6, 140)
  Apprentice = @(12, 140)
  Adept      = @(10, 200)
  Expert     = @(29, 260)
  Master     = @(38, 310)
}
$order = @('Novice','Apprentice','Adept','Expert','Master')

$tierOf = @{}
foreach ($p in @(
  @('0F2CA6','Novice'), @('0C44B7','Apprentice'), @('0C44B8','Adept'), @('0C44B9','Expert'), @('0C44BA','Master')
  @('0F2CA7','Novice'), @('0C44BB','Apprentice'), @('0C44BC','Adept'), @('0C44BD','Expert'), @('0C44BE','Master')
  @('0F2CA8','Novice'), @('0C44BF','Apprentice'), @('0C44C0','Adept'), @('0C44C1','Expert'), @('0C44C2','Master')
  @('0F2CA9','Novice'), @('0C44C3','Apprentice'), @('0C44C4','Adept'), @('0C44C5','Expert'), @('0C44C6','Master')
  @('0F2CAA','Novice'), @('0C44C7','Apprentice'), @('0C44C8','Adept'), @('0C44C9','Expert'), @('0C44CA','Master')
)) { $tierOf["$($p[0]):Skyrim.esm"] = $p[1] }

$rxEditor   = '(?m)^EditorID: (.+?)(?=\r?$)'
$rxFormKey  = '(?m)^FormKey: (.+?)(?=\r?$)'
$rxBaseCost = '(?m)^BaseCost: (\d+)(?=\r?$)'
$rxHalfCost = '(?m)^HalfCostPerk: (.+?)(?=\r?$)'
$rxManual   = '(?m)^- ManualCostCalc(?=\r?$)'

function Read-Text { param([string]$p) return [IO.File]::ReadAllText($p) }

$spells = @{}
foreach ($f in Get-ChildItem (Join-Path $mine 'Spells\*.yaml')) {
  $t  = Read-Text $f.FullName
  $fk = [regex]::Match($t, $rxFormKey)
  if (-not $fk.Success) { continue }
  $hc = [regex]::Match($t, $rxHalfCost)
  $spells[$fk.Groups[1].Value.Trim()] = [pscustomobject]@{
    EditorID = [regex]::Match($t, $rxEditor).Groups[1].Value.Trim()
    Cost     = [int][regex]::Match($t, $rxBaseCost).Groups[1].Value
    Manual   = [bool]([regex]::IsMatch($t, $rxManual))
    Tier     = $(if ($hc.Success) { $tierOf[$hc.Groups[1].Value.Trim()] } else { $null })
  }
}

$taught = @()
foreach ($f in Get-ChildItem (Join-Path $mine 'Books\*.yaml')) {
  $m = [regex]::Match((Read-Text $f.FullName), '(?m)^  MutagenObjectType: BookSpell\r?\n  Spell: (.+?)(?=\r?$)')
  if (-not $m.Success) { continue }
  $k = $m.Groups[1].Value.Trim()
  if (-not $spells.ContainsKey($k)) { throw "a tome teaches $k, which is not a spell in this tree" }
  $taught += $spells[$k]
}
if ($taught.Count -lt 100) { throw "only $($taught.Count) tome-taught spells found - the Books parse is wrong" }

$fail = @()
foreach ($s in $taught) {
  if (-not $s.Manual) { $fail += "  $($s.EditorID): no ManualCostCalc - the engine will recompute this cost" }
  if (-not $s.Tier)   { $fail += "  $($s.EditorID): no HalfCostPerk, so no tier to check against"; continue }
  $lo, $hi = $band[$s.Tier]
  if ($s.Cost -lt $lo -or $s.Cost -gt $hi) {
    $fail += "  $($s.EditorID): $($s.Cost) is outside Enderal's $($s.Tier) band $lo-$hi"
  }
}

"checked $($taught.Count) tome-taught spells"
foreach ($t in $order) {
  $g = @($taught | Where-Object { $_.Tier -eq $t })
  if ($g.Count -eq 0) { continue }
  $c = @($g.Cost | Sort-Object)
  "  {0,-11} n={1,-3} {2,3}-{3,-4} (med {4,3})   Enderal {5,3}-{6}" -f `
    $t, $g.Count, $c[0], $c[-1], $c[[int]($c.Count/2)], $band[$t][0], $band[$t][1]
}

if ($fail.Count) {
  ''
  "FAILED - $($fail.Count) problem(s):"
  $fail | ForEach-Object { $_ }
  exit 1
}
''
'OK - every tome-taught spell has an authored cost inside Enderal''s band for its tier.'
