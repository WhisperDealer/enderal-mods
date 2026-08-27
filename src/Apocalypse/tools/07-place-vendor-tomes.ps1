#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Place every Apocalypse spell tome directly with a named Enderal merchant.
#
# WHY DIRECT PLACEMENT. Injecting sublists into Enderal's vendor leveled lists (02/03/06) makes the
# tomes *available* but never *findable*: a list is rolled per draw, so which spells a shop has is
# random, most of the 160 are never purchasable anywhere, and a player hunting one specific spell
# has no route to it. Weighting was raised twice and still did not deliver in play. Direct placement
# is deterministic - every tome is buyable from one known shop, forever.
#
# WHERE IT WRITES: **SureAI's own <Merchant>_CustomMerchandise hooks**, not the merchant chests.
# [verified 2026-08-27] Enderal ships 67 LeveledItems named <Merchant>_CustomMerchandise, one per
# merchant, and every one is empty - UseAll, no entries, no ChanceNone, no Global. Each merchant's
# chest already contains its own. So adding stock to a merchant does NOT require touching that
# merchant's CONT record: put the entries in the hook and the chest yields them, in full, on every
# restock (UseAll), with exactly the determinism direct chest placement had.
#
# That is the difference between conflicting and not. This script used to override six
# _00E_Merchant_* containers, and all six are contested:
#
#   * `EGO SE - Leveling Redone.esp` overrides **all six** (50 containers in total).
#   * `KataPUMBSpellPack.esp` overrides CCFunkentanz, STTurious and FlusshaimTarhutieContainer,
#     adding the same 15 Kata_W_Staff_* to each - those three shops are their only vendor.
#   * KataEmberlord and xxOpenSpells each override CCFunkentanz as well.
#
# Against the hooks, **none of those mods overrides any of the six** - verified by resolving each
# hook FormKey across reference/mods/, where every hit is a container carrying the hook in its
# Items list rather than an override of the hook itself. EGO's conflict index has no entry for any
# of them either. So this step now leaves Apocalypse overriding **zero** container records of any
# master, and the load-order dodging below is history rather than a constraint.
#
# TARHUTIE IS BACK. The old note here said "do not repoint the Apprentice tier back at Tarhutie
# without re-checking that" - the check is this file. We no longer claim his chest, so KataPUMB's 15
# staves are untouched, and the Apprentice tier returns to the Riverville spell merchant it always
# belonged with. Maxus Tabbakus (620 gold) was only ever the stand-in; he has no hook at all, being
# one of the merchants whose chest SureAI left without one.
#
# The loot lists (_00E_SpellBooksLoot*) keep their random injections. Random is the right shape for
# loot; it is the wrong shape for a shop.

$repo  = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$refFS = Join-Path $repo 'reference\base\EnderalFS\LeveledItems'
$book  = Join-Path $repo 'src\Apocalypse\ApocalypseESP\Books'
$tree  = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$out   = Join-Path $tree 'LeveledItems'
$enc   = New-Object System.Text.UTF8Encoding($false)

# The 15 summons cut as un-Enderal. Kept in sync with 02-gen-distribution.ps1 by the assertion at
# the end, which requires the placed set to equal exactly 160 tomes.
$removed = @(
  'WB_C025_ConjureDremoraChurl',      'WB_C050_ConjureDremoraPitFighter',
  'WB_C075_ConjureDremoraChampion',   'WB_C075_ConjureDremoraHonorGuard',
  'WB_C075_ConjureDremoraMentor',     'WB_C100_ConjureDremoraAssassin',
  'WB_C050_ConjureXivilaiSorcerer',   'WB_C075_ConjureXivilaiLord',
  'WB_C100_ConjureWeepingDaedra',     'WB_C100_ConjureLordOfBindings',
  'WB_C075_SixDemonBag',              'WB_C075_ConjureHerne',
  'WB_C100_ConjureKyrkrim',           'WB_C025_AtronachMark',
  'WB_C100_ConjureCraftlord'
)

# --- the six merchants --------------------------------------------------------
#
# `File` is the merchant's *_CustomMerchandise hook - all six are Forgotten Stories records.
# `Shop` and `Gold` describe the chest that already contains it, recorded so the wealth ladder
# stays readable; we never touch that record. The hook<->chest pairing was read out of each
# chest's own Items list, not guessed from the names.
$vendors = @(
  @{ File = 'GabrielleFunkenfrst_CustomMerchandise - 0302D5_Enderal - Forgotten Stories.esm.yaml'; Shop = 'Ark, Emberlord and Fireflash'; Gold = 1800; Rank = '100'; Schools = 'ACDIR'; Expect = 45 }
  @{ File = 'TuriousFlammentrunk_CustomMerchandise - 0302FE_Enderal - Forgotten Stories.esm.yaml'; Shop = 'Sun Temple, Torius Flameling'; Gold = 1430; Rank = '075'; Schools = 'ACDIR'; Expect = 39 }
  @{ File = 'Barnabas_CustomMerchandise - 030302_Enderal - Forgotten Stories.esm.yaml';            Shop = 'Undercity, Barnabas';          Gold = 1050; Rank = '050'; Schools = 'ACD';   Expect = 19 }
  @{ File = 'OraSteinschlag_CustomMerchandise - 0302E3_Enderal - Forgotten Stories.esm.yaml';      Shop = 'Ark, Ora Stonehand';           Gold =  980; Rank = '050'; Schools = 'IR';    Expect = 14 }
  @{ File = 'Tarhutie_CustomMerchandise - 0302F7_Enderal - Forgotten Stories.esm.yaml';            Shop = 'Riverville, Tarhutie';         Gold =  630; Rank = '025'; Schools = 'ACDIR'; Expect = 28 }
  @{ File = 'MilbertFuchshand_CustomMerchandise - 0302DE_Enderal - Forgotten Stories.esm.yaml';    Shop = 'Ark, Milbert Foxhand';         Gold =  530; Rank = '000'; Schools = 'ACDIR'; Expect = 15 }
)

New-Item -ItemType Directory -Force $out | Out-Null

# --- migration: drop the old chest overrides ----------------------------------
# Anything under Containers/ whose FormKey is not Apocalypse's own is a leftover from the chest
# era. Enai's own WB_*_Chest records stay; they are his content, not overrides of a master.
$stale = @(Get-ChildItem (Join-Path $tree 'Containers') -Filter '*.yaml' -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notmatch 'Apocalypse - Magic of Skyrim\.esp\.yaml$' })
foreach ($f in $stale) {
  Remove-Item -LiteralPath $f.FullName -Force
  "  migrated away: $($f.Name -replace ' - .*','') (chest override deleted)"
}

# --- read every tome out of our own tree --------------------------------------
$tomes = Get-ChildItem (Join-Path $book '*.yaml') | ForEach-Object {
  $t = [IO.File]::ReadAllText($_.FullName)
  [pscustomobject]@{
    EditorID = [regex]::Match($t, '(?m)^EditorID: (.+?)\s*\r?\n').Groups[1].Value
    FormKey  = [regex]::Match($t, '(?m)^FormKey: (.+?)\s*\r?\n').Groups[1].Value
  }
}
$tomes = @($tomes | Where-Object {
  $_.EditorID -match '^WB_[ACDIR](000|025|050|075|100)_.+_Book$' -and
  $removed -notcontains ($_.EditorID -replace '_Book$','')
})
if ($tomes.Count -ne 160) { throw "expected 160 distributable tomes, found $($tomes.Count)" }

# --- write each hook ----------------------------------------------------------
# Always rebuilt from the Forgotten Stories record, never from our own previous output, which makes
# the script idempotent and guarantees we never stack our entries twice.
$placed = @{}
"{0,-42} {1,5}  {2,-18} {3,5}" -f 'hook', 'gold', 'tier', 'tomes'
foreach ($v in $vendors) {
  $srcPath = Join-Path $refFS $v.File
  if (-not (Test-Path -LiteralPath $srcPath)) { throw "hook not found in Forgotten Stories: $srcPath" }

  $mine = @($tomes | Where-Object {
    $_.EditorID -match "^WB_(?<s>[ACDIR])$($v.Rank)_" -and $v.Schools.Contains($Matches['s'])
  } | Sort-Object EditorID)
  if ($mine.Count -ne $v.Expect) {
    throw "$($v.Shop): expected $($v.Expect) tomes for rank $($v.Rank) schools $($v.Schools), got $($mine.Count)"
  }

  # The hook must genuinely be an EMPTY UseAll list in the master, or we are misreading the record
  # and would be replacing somebody's stock rather than adding to it. Spriggit omits an empty
  # collection entirely, so an untouched hook has no Entries: key at all.
  #    NOT `$lines -notmatch ...`: against an ARRAY, -match/-notmatch are FILTERS returning the
  #    matching/non-matching elements, so -notmatch yields every other line and is always truthy.
  $lines = @([IO.File]::ReadAllLines($srcPath) | Where-Object { $_.Trim() -ne '' })
  if ($lines -match '^Entries:')            { throw "$($v.File): hook is not empty upstream - inspect before writing" }
  if ($lines -match '^(ChanceNone|Global):') { throw "$($v.File): hook carries a chance gate - inspect" }
  if (-not ($lines -match '^- UseAll$'))     { throw "$($v.File): hook is not UseAll - not every entry would yield" }

  $nl  = "`r`n"
  $add = @('Entries:')
  foreach ($m in $mine) {
    $add += '- Data:'
    $add += '    Level: 1'
    $add += "    Reference: $($m.FormKey)"
    $add += '    Count: 1'
  }
  [IO.File]::WriteAllText((Join-Path $out $v.File), ((($lines + $add) -join $nl) + $nl), $enc)

  foreach ($m in $mine) {
    if ($placed.ContainsKey($m.EditorID)) {
      throw "$($m.EditorID) placed twice: $($placed[$m.EditorID]) and $($v.Shop)"
    }
    $placed[$m.EditorID] = $v.Shop
  }

  "{0,-42} {1,5}  {2,-18} {3,5}" -f ($v.File -replace ' - .*', ''), $v.Gold, "R$($v.Rank) [$($v.Schools)]", $mine.Count
}

# --- final assertions ---------------------------------------------------------
if ($placed.Keys.Count -ne 160) { throw "placed $($placed.Keys.Count) tomes, expected 160" }
$missing = @($tomes | Where-Object { -not $placed.ContainsKey($_.EditorID) })
if ($missing.Count -gt 0) { throw "not placed: $($missing.EditorID -join ', ')" }

# The whole point of the hooks: we must be left overriding no container of any master. Enai's own
# WB_* chests are his records, not overrides, so they are excluded by FormKey rather than by name.
$owned = @(Get-ChildItem (Join-Path $tree 'Containers') -Filter '*.yaml' -File -ErrorAction SilentlyContinue |
  Where-Object { [IO.File]::ReadAllText($_.FullName) -notmatch '(?m)^FormKey: [0-9A-F]{6}:Apocalypse - Magic of Skyrim\.esp' })
if ($owned.Count -gt 0) {
  throw ("still overriding {0} container(s) of a master: {1} - the hooks exist to avoid exactly this" -f
    $owned.Count, (($owned.Name -replace ' - .*', '') -join ', '))
}

""
"$($placed.Keys.Count) tomes placed across $($vendors.Count) CustomMerchandise hooks, each in exactly one."
"0 container records of any master overridden."
