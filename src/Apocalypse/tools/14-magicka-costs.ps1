#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Put Apocalypse's player spells on Enderal's mana scale, and stop the engine recomputing them.
#
# WHY, PART 1 - THE MECHANISM. A SPELL record only uses its stored BaseCost when the
# ManualCostCalc flag is set. Without the flag the engine DERIVES the cost at runtime from the
# spell's effects:
#
#     cost = sum over effects of  MGEF.BaseCost * magnitude^1.1 * (duration / 10)^1.1
#
# Enderal never relies on that. 271 of the 274 spells its own spell tomes teach carry
# ManualCostCalc, so every SureAI cost is a number a designer typed. (The three that do not are
# _00E_SpellFireExtinguisherMQ04 and the two ranks of Silence - and Silence Rank II at 309 is the
# single most expensive Apprentice-tier spell in the game, which is exactly the tell.)
#
# Apocalypse does the opposite: NONE of its 175 tome-taught spells sets the flag, so all 175 costs
# are whatever the Creation Kit's formula produced. The duration term is what wrecks it. Conjure
# Battlemage is a 50-cost effect with a 180 s duration, so (180/10)^1.1 = 23.9 and the spell bills
# 1201. A long buff or summon is punished for being long, not for being strong.
#
# WHY, PART 2 - THE SCALE. Measured against reference/base (Enderal's own tome-taught spells,
# authored costs only), Enderal's bands are:
#
#     tier          n    min   p25   med   p75   max
#     Novice       51      6    14    21    38   140
#     Apprentice   52     12    27    40    55   140
#     Adept        51     10    34    55    80   200
#     Expert       57     29    49    65   110   260
#     Master       38     38    68    80   170   310
#
# Apocalypse's medians were 50 / 80 / 170 / 361 / 689 with a 1607 ceiling - the gap widening with
# tier, because that is where the long durations live. Enderal's mana pool makes this fatal rather
# than merely expensive: the player gains +8 max mana per level and only when they spend that
# level's attribute choice on it (_00e_epupdatefunctions.psc), so even a mage who never picks
# anything else ends a playthrough near 400-500. A 689-median master tier is uncastable, which is
# precisely what the mod page reports - Conjure Battlemage at 1201 was billing roughly 700 mana to
# a level-95 Entropy mage with every discount the game offers.
#
# WHAT THIS DOES. Sets ManualCostCalc and writes a per-tier RATIO of Enai's original value, so his
# ordering inside each tier survives exactly and only the scale changes. Rounded to 5 above 20, and
# floored at the 25th percentile of Enderal's own spells at that tier, so a cheap high-tier utility
# does not fall to single digits. Resulting medians 40 / 55 / 75 / 110 / 130 against Enderal's
# 21 / 40 / 55 / 65 / 80, and a 305 ceiling just under Enderal's own 310. Conjure Battlemage lands
# at 230.
#
# SCOPE. Only spells the player can actually obtain: the 175 taught by this mod's tomes, plus 7
# variants that share a taught spell's EditorID prefix, its exact cost and a school tier of their
# own - the five per-school Conjure Dremora Mentor spells the AbFX ability hands the player, plus
# Strength of Earth's Flourish and Wild Healing's proc. NPC-suffixed variants are left alone: an
# enemy's magicka budget is not this fix's business.
#
# Idempotent: values are always recomputed from Enai's untouched tree, never from our own output.

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$orig = Join-Path $repo 'reference\mods\Apocalypse\esp'
$mine = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$enc  = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path $orig)) {
  throw "Enai's untouched tree not found: $orig (reference/ is gitignored - re-serialize it)"
}

# The 25 vanilla school perks Enderal reuses as tier tags. A ported spell's HalfCostPerk IS its
# tier - see CLAUDE.md, "Keep a ported spell's HalfCostPerk".
$tierOf = @{}
foreach ($p in @(
  @('0F2CA6','Novice'), @('0C44B7','Apprentice'), @('0C44B8','Adept'), @('0C44B9','Expert'), @('0C44BA','Master')  # Alteration
  @('0F2CA7','Novice'), @('0C44BB','Apprentice'), @('0C44BC','Adept'), @('0C44BD','Expert'), @('0C44BE','Master')  # Conjuration
  @('0F2CA8','Novice'), @('0C44BF','Apprentice'), @('0C44C0','Adept'), @('0C44C1','Expert'), @('0C44C2','Master')  # Destruction
  @('0F2CA9','Novice'), @('0C44C3','Apprentice'), @('0C44C4','Adept'), @('0C44C5','Expert'), @('0C44C6','Master')  # Illusion
  @('0F2CAA','Novice'), @('0C44C7','Apprentice'), @('0C44C8','Adept'), @('0C44C9','Expert'), @('0C44CA','Master')  # Restoration
)) { $tierOf["$($p[0]):Skyrim.esm"] = $p[1] }

$ratio = @{ Novice = 0.80; Apprentice = 0.70; Adept = 0.45; Expert = 0.30; Master = 0.19 }
# The 25th percentile of Enderal's own tome-taught spells at each tier. A ported spell never ends
# up cheaper than a quarter of what Enderal already sells at its tier - which matters because Enai
# prices a few high-tier utilities very low (his master-tier Mystic Wind is 58) and a flat ratio
# would drop those into single digits.
$floor = @{ Novice = 14;   Apprentice = 27;   Adept = 34;   Expert = 49;   Master = 68 }
$order = @('Novice','Apprentice','Adept','Expert','Master')

# CRLF: never anchor with '$' (CLAUDE.md guardrail 10).
$rxEditor   = '(?m)^EditorID: (.+?)(?=\r?$)'
$rxFormKey  = '(?m)^FormKey: (.+?)(?=\r?$)'
$rxBaseCost = '(?m)^BaseCost: (\d+)(?=\r?$)'
$rxHalfCost = '(?m)^HalfCostPerk: (.+?)(?=\r?$)'

function Read-Text { param([string]$p) return [IO.File]::ReadAllText($p) }

# ------------------------------------------------------------ index our spells by FormKey
$spells = @{}
foreach ($f in Get-ChildItem (Join-Path $mine 'Spells\*.yaml')) {
  $t  = Read-Text $f.FullName
  $fk = [regex]::Match($t, $rxFormKey)
  if (-not $fk.Success) { continue }
  $ed = [regex]::Match($t, $rxEditor)
  $bc = [regex]::Match($t, $rxBaseCost)
  $spells[$fk.Groups[1].Value.Trim()] = [pscustomobject]@{
    EditorID = $ed.Groups[1].Value.Trim()
    Path     = $f.FullName
    Name     = $f.Name
    Cost     = $(if ($bc.Success) { [int]$bc.Groups[1].Value } else { -1 })
  }
}
"indexed $($spells.Count) spell records"

# ------------------------------------------------------------ what the tomes teach
$taught = @{}
foreach ($f in Get-ChildItem (Join-Path $mine 'Books\*.yaml')) {
  $m = [regex]::Match((Read-Text $f.FullName), '(?m)^  MutagenObjectType: BookSpell\r?\n  Spell: (.+?)(?=\r?$)')
  if ($m.Success) { $taught[$m.Groups[1].Value.Trim()] = $true }
}
if ($taught.Count -lt 100) { throw "only $($taught.Count) tome-taught spells found - the Books parse is wrong" }
"$($taught.Count) spells taught by this mod's tomes"

# ------------------------------------------------------------ tier of every taught spell
# The tier comes from the spell's own HalfCostPerk, and the ORIGINAL cost comes from Enai's tree -
# never from ours, or a second run would compare our output against itself.
# $null when the record has no BaseCost at all, which is how Mutagen writes a spell that bills no
# magicka - a Power, LesserPower or Ability. Those are skipped: there is no cost to scale.
function Get-OriginalCost {
  param([string]$FileName)
  $p = Join-Path (Join-Path $orig 'Spells') $FileName
  if (-not (Test-Path $p)) { throw "$FileName : not in Enai's tree - cannot recompute idempotently" }
  $m = [regex]::Match((Read-Text $p), $rxBaseCost)
  if (-not $m.Success) { return $null }
  return [int]$m.Groups[1].Value
}
function Get-Tier {
  param([string]$Text, [string]$Label)
  $hc = [regex]::Match($Text, $rxHalfCost)
  if (-not $hc.Success) { return $null }
  $t = $tierOf[$hc.Groups[1].Value.Trim()]
  if (-not $t) { throw "$Label : HalfCostPerk $($hc.Groups[1].Value) is not one of the 25 school perks" }
  return $t
}

# FormKey -> tier to price it at. Taught spells use their own; a lockstep variant below inherits
# its parent's, so the two always land on the same number however their own tags differ.
$targets = @{}
$taughtByEditor = @{}
$costless = @()
foreach ($k in $taught.Keys) {
  if (-not $spells.ContainsKey($k)) { throw "a tome teaches $k, which is not a spell in this tree" }
  $s = $spells[$k]
  $oc = Get-OriginalCost $s.Name
  if ($null -eq $oc) {
    # A tome can teach something that is not a magicka-billed spell - Enslave the Weak ships with a
    # LesserPower for executing the slave. Assert that reading rather than assume it.
    $ty = [regex]::Match((Read-Text $s.Path), '(?m)^Type: (.+?)(?=
?$)')
    if (-not $ty.Success -or $ty.Groups[1].Value.Trim() -eq 'Spell') {
      throw "$($s.EditorID) : no BaseCost but Type is '$($ty.Groups[1].Value)' - expected a Power or Ability"
    }
    $costless += "$($s.EditorID) ($($ty.Groups[1].Value.Trim()))"
    continue
  }
  $tier = Get-Tier -Text (Read-Text $s.Path) -Label $s.EditorID
  if (-not $tier) { throw "$($s.EditorID) : no HalfCostPerk - cannot tell its tier" }
  $targets[$k] = $tier
  $taughtByEditor[$s.EditorID] = [pscustomobject]@{ Tier = $tier; OrigCost = $oc }
}
if ($costless.Count) {
  "$($costless.Count) taught record(s) bill no magicka and are left alone:"
  foreach ($c in ($costless | Sort-Object)) { "    $c" }
}

# ------------------------------------------------------------ lockstep variants
# A spell the player can end up holding that is not itself tome-taught: its EditorID is a taught
# spell's EditorID plus a suffix, Enai gave it that spell's exact cost, and it carries a
# HalfCostPerk of its own - so it is the same spell wearing a different hat. The HalfCostPerk test
# is what separates a player-equippable variant from an internal one: Enai tags every castable
# spell with a school tier and leaves it off the procs and hazards a script fires. Anything
# suffixed _NPC is excluded too.
$lockstep = @()
foreach ($k in @($spells.Keys)) {
  if ($targets.ContainsKey($k)) { continue }
  $s = $spells[$k]
  if ((Read-Text $s.Path) -notmatch $rxHalfCost) { continue }
  foreach ($parent in $taughtByEditor.Keys) {
    if (-not $s.EditorID.StartsWith($parent + '_')) { continue }
    if ($s.EditorID.Substring($parent.Length + 1) -match '^NPC') { continue }
    $oc = Get-OriginalCost $s.Name
    if ($null -eq $oc -or $oc -ne $taughtByEditor[$parent].OrigCost) { continue }
    $targets[$k] = $taughtByEditor[$parent].Tier
    $lockstep += "$($s.EditorID)  <- $parent"
    break
  }
}
"$($lockstep.Count) lockstep variants of a taught spell:"
foreach ($l in ($lockstep | Sort-Object)) { "    $l" }

# ------------------------------------------------------------ rewrite
$rows = @()
foreach ($fk in $targets.Keys) {
  $s    = $spells[$fk]
  $ours = Read-Text $s.Path
  $tier = $targets[$fk]
  $old  = Get-OriginalCost $s.Name

  $scaled = $old * $ratio[$tier]
  $new = $(if ($scaled -lt 20) { [int][math]::Round($scaled) } else { [int][math]::Round($scaled / 5) * 5 })
  $floored = $false
  if ($new -lt $floor[$tier]) { $new = $floor[$tier]; $floored = $true }

  $upd = [regex]::Replace($ours, $rxBaseCost, "BaseCost: $new", 1)
  # Assert against the file, not against a "did the text change" test: on a second run the value is
  # already correct and nothing changes, which is exactly what idempotent means.
  $wrote = [regex]::Match($upd, $rxBaseCost)
  if (-not $wrote.Success -or [int]$wrote.Groups[1].Value -ne $new) {
    throw "$($s.EditorID) : BaseCost is $($wrote.Groups[1].Value) after the rewrite, expected $new"
  }

  # ManualCostCalc is bit 0, so Mutagen always writes it first in the Flags list.
  if ($upd -notmatch '(?m)^- ManualCostCalc(?=\r?$)') {
    if ($upd -match '(?m)^Flags:(?=\r?$)') {
      $upd = [regex]::Replace($upd, '(?m)^Flags:(\r?\n)', 'Flags:${1}- ManualCostCalc${1}', 1)
    } else {
      # No Flags key at all: create one immediately after BaseCost, where Mutagen emits it.
      $upd = [regex]::Replace($upd, '(?m)^(BaseCost: \d+)(\r?\n)', '${1}${2}Flags:${2}- ManualCostCalc${2}', 1)
    }
    if ($upd -notmatch '(?m)^- ManualCostCalc(?=\r?$)') { throw "$($s.EditorID) : failed to add ManualCostCalc" }
  }

  if ($upd -ne $ours) { [IO.File]::WriteAllText($s.Path, $upd, $enc) }
  $rows += [pscustomobject]@{ Tier = $tier; Old = $old; New = $new; Floored = $floored; EditorID = $s.EditorID }
}

if ($rows.Count -ne $targets.Count) { throw "expected $($targets.Count) rewrites, made $($rows.Count)" }

''
"rewrote $($rows.Count) spells"
foreach ($t in $order) {
  $g = @($rows | Where-Object { $_.Tier -eq $t })
  if ($g.Count -eq 0) { continue }
  $o = @($g.Old | Sort-Object)
  $n = @($g.New | Sort-Object)
  $fl = @($g | Where-Object { $_.Floored }).Count
  $note = $(if ($fl) { "   [$fl at the tier floor]" } else { '' })
  "  {0,-11} n={1,-3} x{2,-5} {3,5}-{4,-5} (med {5,4})  ->  {6,3}-{7,-4} (med {8,3}){9}" -f `
    $t, $g.Count, $ratio[$t], $o[0], $o[-1], $o[[int]($o.Count/2)], $n[0], $n[-1], $n[[int]($n.Count/2)], $note
}

$ceiling = ($rows.New | Measure-Object -Maximum).Maximum
if ($ceiling -gt 310) { throw "ceiling $ceiling exceeds Enderal's own most expensive spell (310)" }
''
"ceiling $ceiling, against Enderal's 310. Run verify-magicka-costs.ps1 to re-check the tree."
