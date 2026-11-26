#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Place every Apocalypse spell tome directly with a named Enderal merchant.
#
# WHY DIRECT PLACEMENT. Injecting sublists into Enderal's vendor leveled lists (02/03/06) makes the
# tomes *available* but never *findable*: a list is rolled per draw, so which spells a shop has is
# random, most of the 163 are never purchasable anywhere, and a player hunting one specific spell
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

# Which summons are withheld: one definition, shared with steps 2 and 17. All 15 Daedra/Dwemer
# summons are renamed for Enderal now; the 12 still held back are the ones never cast in game.
. (Join-Path (Split-Path -Parent $PSCommandPath) '00-cut-summons.ps1')

# --- the merchants ------------------------------------------------------------
#
# NOT TARHUTIE OR TORIUS FLAMELING. Triumvirate writes their hooks (Tarhutie_, TuriousFlammentrunk_),
# and two plugins writing one LeveledItem is an override conflict: the later-loading one's entries
# win and the other's stock disappears without error. So Apocalypse uses neither, and the cleanup
# below deletes any hook file in our tree that this table no longer writes.
#
# Each vendor's `Lines` is one or more '<rank>:<schools>' pairs: '025:A 050:R' is Apprentice
# Mentalism plus Adept Light Magic.
#
# ENTROPY (C) AND PSIONICS (I) ARE FORBIDDEN SCHOOLS IN ENDERAL, so the five respectable shops -
# Milbert, Tarhutie, Ora, Torius in the Sun Temple, Emberlord and Fireflash, Barnabas - sell
# neither. They go to the SHROUDED MAGES, Forgotten Stories' forbidden-magic dealers, whose chests
# already stock FS's own `_00E_FS_Forbidden_TraderSpellBooks_All`, tiered the same way as the rest:
#   Novice + Apprentice  a fourth mage we add in Riverville's inn (18-shrouded-mage-riverville.ps1;
#                        his chest is ours, so it holds the tomes directly - no hook)
#   Adept                the Undercity mage   (630 gold; 730 under EGO)
#   Expert Entropy       the Frostcliff mage  (674; 924)
#   Expert Psionics      the Duneville mage   (707; 1357)
#   Master               loot only (see $PENDING)
# Their three hooks are empty UseAll lists in FS, and EGO and EGO Leveling Redone - the only mods in
# reference/mods/ that override those chests - both keep them.
#
# LIGHT MAGIC (R) stays whole on the respectable ladder, DELIBERATELY. About half of Enai's
# Restoration is death/disease/drain magic (Slay Living, Decompose, Poisoned Chalice, Circle of
# Death, Life's Finale...), which sits oddly at the Sun Temple and in Ark. Considered and kept
# (2026-11-26): it gives Light Magic utility beyond healing. Do not split it off to the dealers.
#
# `File` is the merchant's *_CustomMerchandise hook - all six are Forgotten Stories records.
# `Shop` and `Gold` describe the chest that already contains it, recorded so the wealth ladder
# stays readable; we never touch that record. The hook<->chest pairing was read out of each
# chest's own Items list, not guessed from the names.
$vendors = @(
  # Emberlord and Fireflash: Expert Elementalism + Light Magic. Its Master tomes are being re-homed
  # (see $PENDING below) and are loot-only until then.
  @{ File = 'GabrielleFunkenfrst_CustomMerchandise - 0302D5_Enderal - Forgotten Stories.esm.yaml'; Shop = 'Ark, Emberlord and Fireflash'; Gold = 1800; Lines = '075:DR'; Expect = 18 }
  @{ File = 'Barnabas_CustomMerchandise - 030302_Enderal - Forgotten Stories.esm.yaml';            Shop = 'Undercity, Barnabas';          Gold = 1050; Lines = '050:AD'; Expect = 14 }
  @{ File = 'OraSteinschlag_CustomMerchandise - 0302E3_Enderal - Forgotten Stories.esm.yaml';      Shop = 'Ark, Ora Stonehand';           Gold =  980; Lines = '025:A 050:R'; Expect = 13 }   # Apprentice Mentalism + Adept Light Magic
  # Apprentice Elementalism + Light Magic: Kurro Mongerson, Kurro's General Store in Riverville. His
  # chest _00E_Merchant_FlusshaimKurroContainer 05BCD8 (480 gold); EGO and EGO Leveling Redone keep the hook.
  @{ File = 'Kurro_CustomMerchandise - 0302F4_Enderal - Forgotten Stories.esm.yaml';               Shop = 'Riverville, Kurro''s General Store'; Gold = 480; Lines = '025:DR'; Expect = 12 }
  @{ File = 'MilbertFuchshand_CustomMerchandise - 0302DE_Enderal - Forgotten Stories.esm.yaml';    Shop = 'Ark, Milbert Foxhand';         Gold =  530; Lines = '000:A'; Expect = 3 }
  # Expert Mentalism: Fitzai Galabagadananka, Fitzai's Puzzle Box in Ark. Mentalism is the Starlings'
  # art and EGO stocks his shop with Starling gear, so the two sit well together. His chest is
  # _00E_Merchant_CCStarWarehouse 11B214 (890 gold; 1390 under EGO); FS, EGO and EGO Leveling Redone
  # all carry this hook in it.
  @{ File = 'FitzaiGalabagadananka_CustomMerchandise - 0302D6_Enderal - Forgotten Stories.esm.yaml'; Shop = 'Ark, Fitzai''s Puzzle Box';    Gold =  890; Lines = '075:A'; Expect = 9 }
  # Master Mentalism: Mirella Godshand's alchemy shop in Ark, whose chest already stocks Enderal's
  # top-tier spell books (_00ETraderSpellBooksLevelD x10). Chest _00E_Merchant_CCMirellasAlchemy
  # 106EA7 (2135 gold); EGO and EGO Leveling Redone keep the hook.
  @{ File = 'Mirella_CustomMerchandise - 0302DF_Enderal - Forgotten Stories.esm.yaml';             Shop = 'Ark, Mirella Godshand';        Gold = 2135; Lines = '100:A'; Expect = 10 }
  # Novice Light Magic + Elementalism: Eshra Miraya, one of the first merchants a player meets in the
  # open world (she trades once her quest is done). Her chest is _00E_TraderSonnenkueste 050FCF;
  # FS, EGO and EGO Leveling Redone all carry this hook in it.
  @{ File = 'Eshra_CustomMerchandise - 0302F3_Enderal - Forgotten Stories.esm.yaml';               Shop = 'Eshra Miraya';                 Gold =  450; Lines = '000:DR'; Expect = 6 }
  # the forbidden schools, at the Shrouded Mages
  @{ File = 'Wildmage_Undercity_CustomMerchandise - 0302F0_Enderal - Forgotten Stories.esm.yaml';        Shop = 'Undercity, Shrouded Mage';  Gold = 630; Lines = '050:CI'; Expect = 12 }
  @{ File = 'Wildmage_FrostcliffTavern_CustomMerchandise - 0302EF_Enderal - Forgotten Stories.esm.yaml'; Shop = 'Frostcliff Tavern, Shrouded Mage'; Gold = 674; Lines = '075:C';  Expect = 4 }    # Expert Entropy
  @{ File = 'Wildmage_Duneville_CustomMerchandise - 0302EE_Enderal - Forgotten Stories.esm.yaml';        Shop = 'Duneville, Shrouded Mage';  Gold = 707; Lines = '075:I';  Expect = 9 }    # Expert Psionics
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
# ...and any CustomMerchandise hook we used to write but no longer do (Tarhutie, Torius), or it ships on
$keep = @($vendors | ForEach-Object { $_.File })
foreach ($f in @(Get-ChildItem $out -Filter '*_CustomMerchandise - *.yaml' -File)) {
  if ($keep -notcontains $f.Name) {
    Remove-Item -LiteralPath $f.FullName -Force
    "  dropped hook: $($f.Name -replace ' - .*','') (no longer stocked by us)"
  }
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
if ($tomes.Count -ne $SHIP_TOMES) { throw "expected $SHIP_TOMES distributable tomes, found $($tomes.Count)" }

# --- write each hook ----------------------------------------------------------
# Always rebuilt from the Forgotten Stories record, never from our own previous output, which makes
# the script idempotent and guarantees we never stack our entries twice.
$placed = @{}
"{0,-42} {1,5}  {2,-18} {3,5}" -f 'hook', 'gold', 'tier', 'tomes'
foreach ($v in $vendors) {
  $srcPath = Join-Path $refFS $v.File
  if (-not (Test-Path -LiteralPath $srcPath)) { throw "hook not found in Forgotten Stories: $srcPath" }

  $pairs = @($v.Lines -split ' ' | ForEach-Object { $r, $sc = $_ -split ':'; @{ Rank = $r; Schools = $sc } })
  $mine = @($tomes | Where-Object {
    $m2 = [regex]::Match($_.EditorID, '^WB_([ACDIR])(\d{3})_')
    $m2.Success -and @($pairs | Where-Object { $_.Rank -eq $m2.Groups[2].Value -and $_.Schools.Contains($m2.Groups[1].Value) }).Count -gt 0
  } | Sort-Object EditorID)
  if ($mine.Count -ne $v.Expect) {
    throw "$($v.Shop): expected $($v.Expect) tomes for $($v.Lines), got $($mine.Count)"
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

  "{0,-42} {1,5}  {2,-18} {3,5}" -f ($v.File -replace ' - .*', ''), $v.Gold, $v.Lines, $mine.Count
}

# --- final assertions ---------------------------------------------------------
# The only tomes NOT placed here are the 16 Novice/Apprentice Entropy/Psionics tomes the Riverville
# Shrouded Mage sells from his own chest (step 18), and $PENDING: lines taken off a merchant and not
# yet given a new one, loot-only meanwhile. Nothing else may fall through.
# MASTER TOMES ARE LOOT-ONLY, except Mirella's Master Mentalism. Base Enderal sells its Master tier
# only at random (its _00ETraderSpellBooksLevelD vendor list yields from player level 30) and leaves
# several to be found in the world, so Master Elementalism, Light Magic, Entropy and Psionics are
# found through the ZP_Apoc_Tomes_R100 loot sublist (_00E_SpellBooksLootD, level 40) and not sold.
$PENDING     = '^WB_[DRCI]100_'    # Master Elementalism/Light Magic/Entropy/Psionics: loot-only
$PLACED_HERE = 110
$RIVERVILLE  = 16
$LOOT_ONLY   = 37
if ($placed.Keys.Count -ne $PLACED_HERE) { throw "placed $($placed.Keys.Count) tomes, expected $PLACED_HERE" }
$unplaced = @($tomes | Where-Object { -not $placed.ContainsKey($_.EditorID) })
$legal    = @($unplaced | Where-Object { $_.EditorID -notmatch '^WB_[CI]' -and $_.EditorID -notmatch $PENDING })
if ($legal.Count -gt 0) { throw "not placed, and neither Entropy/Psionics nor pending: $($legal.EditorID -join ', ')" }
$novice   = @($unplaced | Where-Object { $_.EditorID -match '^WB_[CI](000|025)_' })
if ($novice.Count -ne $RIVERVILLE) { throw "$($novice.Count) Novice/Apprentice Entropy/Psionics tomes unplaced, expected $RIVERVILLE (the Riverville mage)" }
if ($unplaced.Count - $novice.Count -ne $LOOT_ONLY) { throw "$($unplaced.Count - $novice.Count) tomes loot-only, expected $LOOT_ONLY" }
if ($PLACED_HERE + $RIVERVILLE + $LOOT_ONLY -ne $SHIP_TOMES) { throw "counts do not add up to $SHIP_TOMES" }
# and no forbidden tome on a respectable shelf, nor anything else at a Shrouded Mage
foreach ($k in $placed.Keys) {
  $shady = $placed[$k] -like '*Shrouded Mage'
  if ($k -match '^WB_[CI]' -and -not $shady) { throw "$k is a forbidden-school tome at $($placed[$k])" }
  if ($k -notmatch '^WB_[CI]' -and $shady)   { throw "$k is not Entropy/Psionics but is at $($placed[$k])" }
}

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
"$RIVERVILLE Novice/Apprentice Entropy/Psionics tomes left to the Riverville Shrouded Mage (step 18); $LOOT_ONLY Master tomes loot-only by design."
"0 container records of any master overridden."
