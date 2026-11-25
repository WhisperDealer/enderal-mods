#requires -Version 5.1
<#
.SYNOPSIS
  Add a fourth Shrouded Mage to The Drunken Bee in Riverville, selling Apocalypse's Novice Entropy
  and Psionics tomes.

.DESCRIPTION
  Entropy (Conjuration) and Psionics (Illusion) are the forbidden schools in Enderal, so they belong
  with the forbidden-magic dealers, not in Ark's shops or the Sun Temple. Forgotten Stories already
  has three such dealers - the Shrouded Mages (`_00E_FS_Wildmage_*`) in the Undercity, Frostcliff
  Tavern and Duneville, whose chests stock FS's own `_00E_FS_Forbidden_TraderSpellBooks_All`. None
  is in an early-game town, so this adds one to Riverville's inn.

  EVERYTHING THAT MAKES A SHROUDED MAGE WORK IS DATA-DRIVEN, which is why a new one needs no script:

    * Dialogue and voice. Every FS line they speak - the barter branch, hello, goodbye, idles, combat
      barks - is conditioned on `GetInFaction FS_IsVoiceActorWildmage 01E8F4`, never on a specific
      NPC. The barter fragments are plain `akSpeaker.ShowBarterMenu()` (TIF__0101E845, TIF__0101EAEC).
      NOTE the branch has a third response, TIF__0101E843: if the player has BOTH Psionics and
      Entropy below 15, the mage shows FS's "not enough entropy" message and does not trade. That is
      FS's design for every Shrouded Mage and this one inherits it.
    * Trading. One vendor faction per mage, pointing at a merchant chest placed under the floor of
      the mage's own cell (Frostcliff: faction 01E906 -> chest ref 01E905, 66 units below the mage).
    * AI. Their only package is `_DefaultSitTargetLinkedRef` 0EBD71: sit in the linked chair.

  THE FACE. A new NPC needs FaceGen named after its own FormID, and this release ships no assets -
  without it, the dark-face bug. So the NPC carries a TRAITS template pointing at the Duneville
  mage `01E907`, and borrows his race, voice, head parts and face. He will look exactly like the
  Duneville mage; they are hooded, and the three FS mages already share a name and a voice.
  **Whether the template avoids the dark face is the one thing a build cannot prove - check it in
  game.**

  RECORDS (Apocalypse's own space, continuing the 1C1E71-76 block in the gap below Enai's 1C4D39):
    1C1E77  NPC_        ZP_Apoc_Wildmage_Riverville                copy of 01E907, Traits template
    1C1E78  FACT        ZP_Apoc_Merchant_Wildmage_Riverville       copy of 01E909
    1C1E79  CONT        ZP_Apoc_Merchant_Wildmage_RivervilleChest  copy of 01E90A, minus Duneville's hook
    1C1E7A  ACHR        the mage, persistent in FlusshaimTavern, linked to bench 14983A
    1C1E7B  REFR        the chest, persistent, under the floor below that bench
  plus an override of `FlusshaimTavern` 019C50 built from Forgotten Stories' copy (the winning one;
  nothing in reference/mods/ touches it), cut before NavigationMeshes: and listing only our two refs.

  Idempotent: every file is rebuilt from the reference trees on each run.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSCommandPath) '00-cut-summons.ps1')

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$fs   = Join-Path $repo 'reference\base\EnderalFS'
$tree = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$enc  = New-Object System.Text.UTF8Encoding($false)
$APOC = 'Apocalypse - Magic of Skyrim.esp'
$FSM  = 'Enderal - Forgotten Stories.esm'

$ID = @{ Npc = '1C1E77'; Faction = '1C1E78'; Chest = '1C1E79'; NpcRef = '1C1E7A'; ChestRef = '1C1E7B' }
$EID = @{
  Npc     = 'ZP_Apoc_Wildmage_Riverville'
  Faction = 'ZP_Apoc_Merchant_Wildmage_Riverville'
  Chest   = 'ZP_Apoc_Merchant_Wildmage_RivervilleChest'
  NpcRef  = 'ZP_Apoc_Wildmage_RivervilleREF'
}
$Bench     = '14983A:Skyrim.esm'                 # CommonTableOneBench: persistent (like Frostcliff's chair 0C6B65), no owner, no patrol stop, no NPC linked
$BenchPos  = @(-667.7829, 1891.4133, -1544.0)
$BenchRotZ = '4.7207985'
$ChestDrop = 66                                  # FS's Frostcliff chest sits 66 units below its mage

function Read-Lf { param([string]$Path) ([IO.File]::ReadAllText($Path)) -replace "`r`n", "`n" }
function Write-Crlf { param([string]$Path, [string]$Text)
  New-Item -ItemType Directory -Force (Split-Path -Parent $Path) | Out-Null
  $crlf = ($Text.TrimEnd("`n") + "`n") -replace "`n", "`r`n"
  [IO.File]::WriteAllText($Path, $crlf, $enc)
}
function Replace-Once { param([string]$Text, [string]$Old, [string]$New, [string]$What)
  $n = ([regex]::Matches($Text, [regex]::Escape($Old))).Count
  if ($n -ne 1) { throw "$($What): expected exactly 1 '$Old', found $n" }
  return $Text.Replace($Old, $New)
}
function Find-One { param([string]$Dir, [string]$Pattern)
  $h = @(Get-ChildItem -LiteralPath $Dir -Filter $Pattern -File)
  if ($h.Count -ne 1) { throw "expected 1 file '$Pattern' in $Dir, found $($h.Count)" }
  return $h[0].FullName
}

# Not overriding a record anyone else does (guardrail 5): FS is the only plugin touching the inn.
$cellRel = 'Cells\2\5\FlusshaimTavern - 019C50_Skyrim.esm\RecordData.yaml'
$mods = Join-Path $repo 'reference\mods'
$rival = @(Get-ChildItem $mods -Recurse -Filter 'RecordData.yaml' -File -ErrorAction SilentlyContinue |
  Where-Object { $_.DirectoryName -match 'FlusshaimTavern - 019C50' -and $_.FullName -notmatch '\\Apocalypse\\' })
if ($rival.Count -gt 0) { throw "FlusshaimTavern is overridden by: $(($rival | ForEach-Object FullName) -join ', ') - forward it" }

# --- the six tomes: Novice Entropy + Novice Psionics, minus anything withheld ---------------------
$tomes = @(Get-ChildItem (Join-Path $tree 'Books') -Filter '*.yaml' -File | ForEach-Object {
  $t = Read-Lf $_.FullName
  [pscustomobject]@{
    EditorID = [regex]::Match($t, '(?m)^EditorID: (\S+)').Groups[1].Value
    FormKey  = [regex]::Match($t, '(?m)^FormKey: (.+)$').Groups[1].Value.Trim()
  }
} | Where-Object { $_.EditorID -match '^WB_[CI]000_.+_Book$' -and $removed -notcontains ($_.EditorID -replace '_Book$', '') } |
  Sort-Object EditorID)
if ($tomes.Count -ne 6) { throw "expected 6 Novice Entropy/Psionics tomes, found $($tomes.Count)" }

# --- 1. NPC ----------------------------------------------------------------------------------------
$t = Read-Lf (Find-One (Join-Path $fs 'Npcs') '_00E_FS_Wildmage_Duneville - 01E907_*.yaml')
$t = Replace-Once $t "FormKey: 01E907:$FSM" "FormKey: $($ID.Npc):$APOC" 'npc formkey'
$t = Replace-Once $t 'EditorID: _00E_FS_Wildmage_Duneville' "EditorID: $($EID.Npc)" 'npc editorid'
# factions: keep the voice-actor faction (it IS the dialogue), swap Duneville's vendor, crime and
# town factions for ours and Riverville's - the Frostcliff mage carries his tavern's guest faction.
$t = Replace-Once $t "- Faction: 01E909:$FSM" "- Faction: $($ID.Faction):$APOC" 'npc vendor faction'
$t = Replace-Once $t "- Faction: 02E9AD:$FSM" '- Faction: 07286C:Skyrim.esm' 'npc crime faction (D_ -> FL_CrimeFaction)'
$t = Replace-Once $t '- Faction: 046ECA:Skyrim.esm' '- Faction: 04830C:Skyrim.esm' 'npc town faction (Duenenhaim -> TavernGuests)'
$t = Replace-Once $t "  DispositionBase: 35`n" "  DispositionBase: 35`n  TemplateFlags:`n  - Traits`n" 'npc template flags'
$t = Replace-Once $t "Voice: 01E8FD:$FSM`n" "Voice: 01E8FD:$FSM`nTemplate: 01E907:$FSM`n" 'npc template'
foreach ($k in @("01E8F4:$FSM", '0EBD71:Skyrim.esm')) { if (-not $t.Contains($k)) { throw "npc lost $k" } }
Write-Crlf (Join-Path $tree "Npcs\$($EID.Npc) - $($ID.Npc)_$APOC.yaml") $t

# --- 2. vendor faction -----------------------------------------------------------------------------
$t = Read-Lf (Find-One (Join-Path $fs 'Factions') 'FS_Merchant_Wildmage_Duneville - 01E909_*.yaml')
$t = Replace-Once $t "FormKey: 01E909:$FSM" "FormKey: $($ID.Faction):$APOC" 'faction formkey'
$t = Replace-Once $t 'EditorID: FS_Merchant_Wildmage_Duneville' "EditorID: $($EID.Faction)" 'faction editorid'
$t = Replace-Once $t "MerchantContainer: 01E90B:$FSM" "MerchantContainer: $($ID.ChestRef):$APOC" 'faction chest'
$t = Replace-Once $t '    Link: 048F32:Skyrim.esm' '    Link: 019C50:Skyrim.esm' 'faction vendor location'
Write-Crlf (Join-Path $tree "Factions\$($EID.Faction) - $($ID.Faction)_$APOC.yaml") $t

# --- 3. merchant chest -----------------------------------------------------------------------------
$t = Read-Lf (Find-One (Join-Path $fs 'Containers') '_00E_FS_Merchant_Wildmage_Duneville - 01E90A_*.yaml')
$t = Replace-Once $t "FormKey: 01E90A:$FSM" "FormKey: $($ID.Chest):$APOC" 'chest formkey'
$t = Replace-Once $t 'EditorID: _00E_FS_Merchant_Wildmage_Duneville' "EditorID: $($EID.Chest)" 'chest editorid'
# Duneville's own hook must go, or this chest would also sell whatever is ever put in Duneville's.
$t = Replace-Once $t "- Item:`n    Item: 0302EE:$FSM`n    Count: 1`n" '' 'chest: drop Duneville hook'
foreach ($k in @("01E90D:$FSM", "01EC55:$FSM")) { if (-not $t.Contains($k)) { throw "chest lost forbidden list $k" } }
$add = ($tomes | ForEach-Object { "- Item:`n    Item: $($_.FormKey)`n    Count: 1`n" }) -join ''
$m = [regex]::Match($t, '(?m)^Items:\n(?:- Item:\n(?:    .*\n)+)+')
if (-not $m.Success) { throw 'chest: no Items block' }
$t = $t.Insert($m.Index + $m.Length, $add)
Write-Crlf (Join-Path $tree "Containers\$($EID.Chest) - $($ID.Chest)_$APOC.yaml") $t

# --- 4. the inn: FS's cell, no navmesh, our two refs only ------------------------------------------
$t = Read-Lf (Join-Path $fs $cellRel)
$cut = $t.IndexOf("`nNavigationMeshes:`n")
if ($cut -lt 0) { throw 'FlusshaimTavern: no NavigationMeshes: to cut at' }
$t = $t.Substring(0, $cut + 1)
if ($t -match '(?m)^(Persistent|Temporary):') { throw 'FlusshaimTavern: refs before the navmesh block - layout changed' }
$inv = [Globalization.CultureInfo]::InvariantCulture
$p = $BenchPos
$t += @"
Persistent:
- MutagenObjectType: PlacedNpc
  FormKey: $($ID.NpcRef):$APOC
  MajorRecordFlagsRaw: 1024
  EditorID: $($EID.NpcRef)
  SkyrimMajorRecordFlags:
  - 0x400
  Base: $($ID.Npc):$APOC
  LinkedReferences:
  - Reference: $Bench
  Placement:
    Position: $($p[0].ToString($inv)), $($p[1].ToString($inv)), $($p[2].ToString($inv))
    Rotation: 0, 0, $BenchRotZ
  MajorFlags:
  - Persistent
- MutagenObjectType: PlacedObject
  FormKey: $($ID.ChestRef):$APOC
  MajorRecordFlagsRaw: 1024
  SkyrimMajorRecordFlags:
  - 0x400
  Base: $($ID.Chest):$APOC
  Placement:
    Position: $($p[0].ToString($inv)), $($p[1].ToString($inv)), $(($p[2] - $ChestDrop).ToString($inv))

"@
Write-Crlf (Join-Path $tree $cellRel) $t
Write-Crlf (Join-Path $tree 'Cells\2\GroupRecordData.yaml')   "BlockNumber: 2`nGroupType: InteriorCellBlock`n"
Write-Crlf (Join-Path $tree 'Cells\2\5\GroupRecordData.yaml') "BlockNumber: 5`nGroupType: InteriorCellSubBlock`n"

# --- assertions over what landed -------------------------------------------------------------------
$out = Read-Lf (Join-Path $tree $cellRel)
if ($out -match '(?m)^NavigationMeshes:') { throw 'cell override carries a navmesh' }
if (@([regex]::Matches($out, '(?m)^- MutagenObjectType: ')).Count -ne 2) { throw 'cell override must list exactly our two refs' }
$chest = Read-Lf (Join-Path $tree "Containers\$($EID.Chest) - $($ID.Chest)_$APOC.yaml")
if ($chest -match '0302E[EF]:|0302F0:') { throw 'chest still carries a Shrouded Mage hook' }
foreach ($b in $tomes) { if (-not $chest.Contains("Item: $($b.FormKey)")) { throw "chest missing $($b.EditorID)" } }
foreach ($k in $ID.Values) {
  $hits = @(Get-ChildItem $tree -Recurse -Filter "*$($k)_$APOC.yaml" -File)
  $refHits = @(Select-String -LiteralPath (Join-Path $tree $cellRel) -Pattern "FormKey: $($k):" -SimpleMatch:$false)
  if (($hits.Count + $refHits.Count) -ne 1) { throw "$k is defined $($hits.Count + $refHits.Count) times" }
}

"Shrouded Mage, The Drunken Bee (Riverville)"
"  npc $($ID.Npc) (Traits template 01E907), faction $($ID.Faction), chest $($ID.Chest)"
"  refs $($ID.NpcRef) on bench $Bench, $($ID.ChestRef) $ChestDrop units below"
"  stock: FS's forbidden lists + $($tomes.Count) Novice tomes:"
$tomes | ForEach-Object { "    $($_.EditorID)" }
