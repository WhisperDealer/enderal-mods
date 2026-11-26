#requires -Version 5.1
<#
.SYNOPSIS
  Make Priest Vildas, Riverville's temple priest, a merchant selling Apocalypse's Apprentice Light
  Magic tomes.

.DESCRIPTION
  Vildas (`_00E_Flusshaim_PaterVildas` 111E79) is not a merchant in Enderal. Becoming one needs:

    1. A vendor faction (ours), whose MerchantContainer is a placed chest and whose VendorLocation is
       NearSelf, so he trades wherever his packages take him (the temple, the town).
    2. That faction on his NPC record. Nothing in reference/mods/ overrides 111E79 and FS does not
       either, so the override is base Enderal's record verbatim plus one faction entry
       (guardrail 5). EGO's FlusshaimTemple cell override touches his placed REFERENCE, which is a
       separate record.
    3. A way to open the shop. Enderal's trade lines are per merchant VOICE: each merchant voice type
       has its own barter topic conditioned on MerchantFaction plus that voice's IsVoiceActor*
       faction. Vildas's VT_Male_Priest has no recorded trade line at all, so this adds a player
       topic - "I'd like to see your spell tomes." - whose response is SILENT (empty text, no audio)
       and whose fragment calls `akSpeaker.ShowBarterMenu()`, the same body as FS's Shrouded Mage
       barter fragments (TIF__0101E845). It is a top-level branch in base Enderal's GenericDialogue
       quest 06A1AC, the quest that already hosts the priests' own "the Path" topic, so no new quest
       (and no SEQ file) is needed.
    4. The chest. It is placed PERSISTENT in Apocalypse's own WB_Entomb_Cell rather than under the
       temple floor, so no Enderal cell is overridden: FlusshaimTemple is already overridden by EGO
       and by this repo's Relentless Sword. A merchant chest can live in any cell as long as it is
       persistent - FS keeps Aurora's and Tarhutie's chests persistent in Vyn.

  RECORDS (Apocalypse's own space):
    1C1E7C  DLBR  ZP_Apoc_VildasBarterBranch   (Player, TopLevel, quest GenericDialogue 06A1AC)
    1C1E7D  DIAL  ZP_Apoc_VildasBarterTopic
    1C1E7E  INFO  silent response, GetIsID Vildas, fragment ZP_Apoc_TIF_VildasBarter
    1C1E7F  FACT  ZP_Apoc_Merchant_Vildas      (copy of Tarhutie's vendor faction's values)
    1C1E80  CONT  ZP_Apoc_Merchant_VildasChest (gold + the 6 Apprentice Light Magic tomes)
    1C1E81  REFR  the chest, persistent in WB_Entomb_Cell
  plus the override of NPC 111E79. The fragment's .pex ships in Scripts/ (build/manifest.json).

  Idempotent: every file is rebuilt from the reference trees, and the chest ref is replaced in place.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSCommandPath) '00-cut-summons.ps1')

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$base = Join-Path $repo 'reference\base'
$tree = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$enc  = New-Object System.Text.UTF8Encoding($false)
$APOC = 'Apocalypse - Magic of Skyrim.esp'

$ID = @{ Branch = '1C1E7C'; Topic = '1C1E7D'; Info = '1C1E7E'; Faction = '1C1E7F'; Chest = '1C1E80'; ChestRef = '1C1E81' }
$Vildas    = '111E79:Skyrim.esm'
$Quest     = '06A1AC:Skyrim.esm'                  # GenericDialogue
$Script    = 'ZP_Apoc_TIF_VildasBarter'
$Prompt    = "I'd like to see your spell tomes."
$ChestGold = 300

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

# --- preconditions ---------------------------------------------------------------------------------
if (@(Get-ChildItem (Join-Path $base 'EnderalFS\Npcs') -Filter '* - 111E79_*' -File).Count -ne 0) { throw 'FS now overrides Vildas - copy its version instead' }
$rival = @(Get-ChildItem (Join-Path $repo 'reference\mods') -Recurse -Filter '* - 111E79_Skyrim.esm.yaml' -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '\\Npcs\\' -and $_.FullName -notmatch '\\Apocalypse\\' })
if ($rival.Count -gt 0) { throw "Vildas's NPC record is overridden by: $(($rival | ForEach-Object FullName) -join ', ') - forward it" }
if (-not (Test-Path -LiteralPath (Join-Path $repo "src\Apocalypse\Scripts\compiled\$Script.pex"))) { throw "$Script.pex is not compiled" }

$tomes = @(Get-ChildItem (Join-Path $tree 'Books') -Filter '*.yaml' -File | ForEach-Object {
  $t = Read-Lf $_.FullName
  [pscustomobject]@{
    EditorID = [regex]::Match($t, '(?m)^EditorID: (\S+)').Groups[1].Value
    FormKey  = [regex]::Match($t, '(?m)^FormKey: (.+)$').Groups[1].Value.Trim()
  }
} | Where-Object { $_.EditorID -match '^WB_R025_.+_Book$' -and $removed -notcontains ($_.EditorID -replace '_Book$', '') } | Sort-Object EditorID)
if ($tomes.Count -ne 6) { throw "expected 6 Apprentice Light Magic tomes, found $($tomes.Count)" }

# --- 1. NPC override: base Enderal's record + our vendor faction ------------------------------------
$t = Read-Lf (Find-One (Join-Path $base 'Skyrim\Npcs') '_00E_Flusshaim_PaterVildas - 111E79_Skyrim.esm.yaml')
$t = Replace-Once $t "Voice: 111E76:Skyrim.esm`n" "Voice: 111E76:Skyrim.esm`n" 'npc voice is VT_Male_Priest'
$m = [regex]::Match($t, '(?m)^Factions:\n(?:- Faction: .+\n  Fluff: .+\n)+')
if (-not $m.Success) { throw 'npc: no Factions block' }
$t = $t.Insert($m.Index + $m.Length, "- Faction: $($ID.Faction):$APOC`n  Fluff: 0x000000`n")
Write-Crlf (Join-Path $tree 'Npcs\_00E_Flusshaim_PaterVildas - 111E79_Skyrim.esm.yaml') $t

# --- 2. vendor faction: Tarhutie's values, our chest, trades wherever he stands ---------------------
$t = Read-Lf (Find-One (Join-Path $base 'Skyrim\Factions') 'Merchant_Flusshaim_Tarhutie - 05BCF5_Skyrim.esm.yaml')
$t = Replace-Once $t 'FormKey: 05BCF5:Skyrim.esm' "FormKey: $($ID.Faction):$APOC" 'faction formkey'
$t = Replace-Once $t 'EditorID: Merchant_Flusshaim_Tarhutie' 'EditorID: ZP_Apoc_Merchant_Vildas' 'faction editorid'
$t = Replace-Once $t 'MerchantContainer: 05BECC:Skyrim.esm' "MerchantContainer: $($ID.ChestRef):$APOC" 'faction chest'
$t = [regex]::Replace($t, '(?m)^Name:\n(?:  .*\n)+', '')   # copied FULL read "Tarhutie"; a vendor faction needs no name
if ($t -match '(?m)^Name:') { throw 'faction: Name not dropped' }
$t = [regex]::Replace($t, '(?ms)^VendorLocation:\n(?:  .*\n)+',"VendorLocation:`n  Target:`n    MutagenObjectType: LocationFallback`n    Type: NearSelf`n")
if ($t -notmatch 'Type: NearSelf') { throw 'faction: VendorLocation not replaced' }
Write-Crlf (Join-Path $tree "Factions\ZP_Apoc_Merchant_Vildas - $($ID.Faction)_$APOC.yaml") $t

# --- 3. merchant chest: Tarhutie's chest shape, our stock only --------------------------------------
$t = Read-Lf (Find-One (Join-Path $base 'EnderalFS\Containers') '_00E_Merchant_FlusshaimTarhutieContainer - 05BCD6_Skyrim.esm.yaml')
$t = Replace-Once $t 'FormKey: 05BCD6:Skyrim.esm' "FormKey: $($ID.Chest):$APOC" 'chest formkey'
$t = Replace-Once $t 'EditorID: _00E_Merchant_FlusshaimTarhutieContainer' 'EditorID: ZP_Apoc_Merchant_VildasChest' 'chest editorid'
$items = "Items:`n- Item:`n    Item: 00000F:Skyrim.esm`n    Count: $ChestGold`n" +
  (($tomes | ForEach-Object { "- Item:`n    Item: $($_.FormKey)`n    Count: 1`n" }) -join '')
$t = [regex]::Replace($t, '(?m)^Items:\n(?:- Item:\n(?:    .*\n)+)+', $items.Replace('$', '$$'))
if (@([regex]::Matches($t, '(?m)^- Item:')).Count -ne 7) { throw 'chest: Items not rebuilt to gold + 6 tomes' }
if ($t -notmatch '(?m)^- Respawns') { throw 'chest: lost Respawns' }
Write-Crlf (Join-Path $tree "Containers\ZP_Apoc_Merchant_VildasChest - $($ID.Chest)_$APOC.yaml") $t

# --- 4. the chest ref, persistent in Apocalypse's own WB_Entomb_Cell --------------------------------
$cell = Join-Path (@(Get-ChildItem (Join-Path $tree 'Cells\1\6') -Directory -Filter 'WB_Entomb_Cell - *')[0].FullName) 'RecordData.yaml'
$t = Read-Lf $cell
$t = [regex]::Replace($t, "(?m)^- MutagenObjectType: PlacedObject\n  FormKey: $($ID.ChestRef):[^\n]+\n(?:  .*\n)+", '')   # idempotent
$ref = "- MutagenObjectType: PlacedObject`n  FormKey: $($ID.ChestRef):$APOC`n  MajorRecordFlagsRaw: 1024`n  SkyrimMajorRecordFlags:`n  - 0x400`n  Base: $($ID.Chest):$APOC`n  Placement:`n    Position: 0, 0, -2000`n"
$t = Replace-Once $t "`nTemporary:`n" "`n$($ref)Temporary:`n" 'entomb cell: Temporary anchor'
Write-Crlf $cell $t

# --- 5. dialogue: branch, topic, silent response ----------------------------------------------------
Write-Crlf (Join-Path $tree "DialogBranches\ZP_Apoc_VildasBarterBranch - $($ID.Branch)_$APOC.yaml") @"
FormKey: $($ID.Branch):$APOC
EditorID: ZP_Apoc_VildasBarterBranch
Quest: $Quest
Category: Player
Flags:
- TopLevel
StartingTopic: $($ID.Topic):$APOC
"@
$topicDir = Join-Path $tree "DialogTopics\ZP_Apoc_VildasBarterTopic - $($ID.Topic)_$APOC"
Write-Crlf (Join-Path $topicDir 'RecordData.yaml') @"
FormKey: $($ID.Topic):$APOC
EditorID: ZP_Apoc_VildasBarterTopic
Name:
  TargetLanguage: English
  Value: "$Prompt"
Branch: $($ID.Branch):$APOC
Quest: $Quest
SubtypeName: CUST
"@
Write-Crlf (Join-Path $topicDir "Responses\$($ID.Info)_$APOC.yaml") @"
FormKey: $($ID.Info):$APOC
VirtualMachineAdapter:
  Scripts:
  - Name: $Script
  ScriptFragments:
    MutagenObjectType: ScriptFragments
    FileName: $Script
    OnEnd:
      ExtraBindDataVersion: 1
      ScriptName: $Script
      FragmentName: Fragment_0
Flags: {}
FavorLevel: None
Responses:
- EmotionValue: 50
  ResponseNumber: 1
  Unknown2: 0x000000
  Unknown3: 0x000000
  Text:
    TargetLanguage: English
    Value: ''
  ScriptNotes: ''
  Edits: ''
Conditions:
- MutagenObjectType: ConditionFloat
  Data:
    MutagenObjectType: GetIsIDConditionData
    Object: $Vildas
  ComparisonValue: 1
"@

# --- report ----------------------------------------------------------------------------------------
"Priest Vildas, Riverville: merchant"
"  npc override $Vildas + faction $($ID.Faction); chest $($ID.Chest) ($ChestGold gold) as ref $($ID.ChestRef) in WB_Entomb_Cell"
"  topic '$Prompt' ($($ID.Topic)) in GenericDialogue, silent response $($ID.Info) -> $Script"
"  stock: $($tomes.Count) Apprentice Light Magic tomes:"
$tomes | ForEach-Object { "    $($_.EditorID)" }
