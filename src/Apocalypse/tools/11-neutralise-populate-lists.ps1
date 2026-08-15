#requires -Version 5.1
<#
.SYNOPSIS
  Stop Apocalypse's runtime list-population from running. Its destinations do not exist in Enderal.

.DESCRIPTION
  Apocalypse distributes its books, scrolls and staves at runtime by walking three pairs of
  FormLists and calling AddForm on each destination:

      Int i = <Origin>.GetSize()
      while i > 0
        i -= 1
        CurrentDestinationLitem = <Destination>.GetAt(i) as LeveledItem
        CurrentOriginFormlist   = <Origin>.GetAt(i) as FormList
        ... CurrentDestinationLitem.AddForm(<book>, 1, 1)

  The loop counts down from the ORIGIN list's size and indexes the DESTINATION list in parallel.
  The origin lists hold Apocalypse's own FormLists, so they are full. The destination lists hold
  vanilla Skyrim vendor and loot leveled lists -- 54 for books, 24 for staves, 5 for scrolls, and
  the same again in the _Replenish twins -- and not one of them exists in Enderal. So every AddForm
  lands on None.

  It would be wrong even if it worked: this conversion distributes through named merchant
  containers (07-place-vendor-tomes.ps1) and Enderal's own loot lists (02/03/06), so anything it
  managed to add would be a second, uncontrolled copy.

  TWO entry points, which is why emptying the lists is the fix and flags are not:

    WB_PopulateLists_Script.OnUpdate()    automatic, 60 s into a new game
                                          -> binds 11BBC0/11BBC2/07A1C9 + 118981/11BBC1/07A1C8
    WB_MCMQuest_Script.RepopulateLists()  the "Repopulate" toggle in Apocalypse's MCM
                                          -> binds a SECOND set, the six _Replenish lists 08F880-85

  Twelve FormLists, not six. The MCM path runs the identical loop against its own copies, so
  emptying only the automatic set leaves a button in the menu that reproduces the whole error storm
  on demand.

  Emptying the ORIGIN lists makes GetSize() return 0, so every loop iterates zero times. Emptying
  the DESTINATION lists as well removes 166 dead references from the audit and costs nothing --
  verified that WB_PopulateLists_Quest and WB_SkyUI_Quest are the ONLY records in the plugin that
  reference any of the twelve.

  StartGameEnabled is also cleared, but do not mistake that for the fix. See the note below.

  Idempotent.

.NOTES
  Clearing StartGameEnabled ALONE does not stop it. [verified in-game 2026-08-07] With the flag
  clear in the shipped .esp (confirmed by reading DNAM out of the built plugin: flags 0x0110, so
  RunOnce set and StartGameEnabled clear), a brand-new game still logged

      APOCALYPSE DEBUG: Initialising Populate Lists script...
      Error: Cannot call AddForm() on a None object, aborting function call    x685

  The quest script's OnInit runs -- and its RegisterForSingleUpdate with it -- whether or not the
  quest is flagged to start. Only the empty lists actually stop the work.

  After this, OnUpdate still runs and still emits its four APOCALYPSE DEBUG trace lines. That is
  expected and harmless; what must be gone is the AddForm errors.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo  = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$tree  = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$quest = Join-Path $tree 'Quests\WB_PopulateLists_Quest - 03F65D_Apocalypse - Magic of Skyrim.esp.yaml'

# hex -> expected entry count, purely as an assertion that we are editing what we think we are.
$lists = [ordered]@{
    '11BBC0' = @{ Name = 'WB_Quest_Populate_OriginFormlist_List_Books';       Expect = 54 }
    '11BBC2' = @{ Name = 'WB_Quest_Populate_OriginFormlist_List_Scrolls';     Expect = 5  }
    '07A1C9' = @{ Name = 'WB_Quest_Populate_OriginFormlist_List_Staves';      Expect = 24 }
    '118981' = @{ Name = 'WB_Quest_Populate_DestinationLitem_List_Books';     Expect = 54 }
    '11BBC1' = @{ Name = 'WB_Quest_Populate_DestinationLitem_List_Scrolls';   Expect = 5  }
    '07A1C8' = @{ Name = 'WB_Quest_Populate_DestinationLitem_List_Staves';    Expect = 24 }
    # the MCM "Repopulate" button's own copies
    '08F883' = @{ Name = 'WB_Quest_Populate_OriginFormlist_List_Books_Replenish';     Expect = 54 }
    '08F884' = @{ Name = 'WB_Quest_Populate_OriginFormlist_List_Scrolls_Replenish';   Expect = 5  }
    '08F885' = @{ Name = 'WB_Quest_Populate_OriginFormlist_List_Staves_Replenish';    Expect = 24 }
    '08F880' = @{ Name = 'WB_Quest_Populate_DestinationLitem_List_Books_Replenish';   Expect = 54 }
    '08F881' = @{ Name = 'WB_Quest_Populate_DestinationLitem_List_Scrolls_Replenish'; Expect = 5  }
    '08F882' = @{ Name = 'WB_Quest_Populate_DestinationLitem_List_Staves_Replenish';  Expect = 24 }
}

if (-not (Test-Path -LiteralPath $quest)) { throw "Quest record not found: $quest" }
$utf8 = New-Object Text.UTF8Encoding($false)

# ---------------------------------------------------------------- 1. empty the six FormLists
$emptied = 0
$already = 0
foreach ($hex in $lists.Keys) {
    $name = $lists[$hex].Name
    $file = @(Get-ChildItem -LiteralPath (Join-Path $tree 'FormLists') -File -Filter "$name - ${hex}_*.yaml")
    if ($file.Count -ne 1) { throw "Expected exactly 1 file for $name ($hex), found $($file.Count)." }
    $path = $file[0].FullName
    $text = [IO.File]::ReadAllText($path)

    if ($text -notmatch '(?m)^Items:(?=\r?$)') { $already++; continue }

    # CRLF tree: anchor with (?=\r?$), never '$' (CLAUDE.md).
    $count = ([regex]::Matches($text, '(?m)^- [0-9A-F]{6}:[^\r\n]+(?=\r?$)')).Count
    if ($count -ne $lists[$hex].Expect) {
        throw "$name holds $count entries, expected $($lists[$hex].Expect). Upstream changed - re-derive before emptying."
    }

    # Drop the whole "Items:" block. A FormList with no Items reads GetSize() == 0.
    $new = [regex]::Replace($text, '(?m)^Items:\r?\n(?:- [0-9A-F]{6}:[^\r\n]*\r?\n)+', '')
    if ($new -eq $text) { throw "$name matched 'Items:' but nothing was removed - check line endings." }
    if ($new -match '(?m)^- [0-9A-F]{6}:') { throw "$name still has entries after the strip." }

    [IO.File]::WriteAllText($path, $new, $utf8)
    Write-Host ("  emptied {0,-48} ({1} entries)" -f $name, $count)
    $emptied++
}
Write-Host "FormLists emptied: $emptied; already empty: $already"
if ($emptied -eq 0 -and $already -ne $lists.Count) {
    throw "Nothing emptied and not all six are clean - the pattern did not match."
}

# ---------------------------------------------------------------- 2. belt and braces: the flag
$text = [IO.File]::ReadAllText($quest)
if ($text -notmatch '(?m)^Flags:(?=\r?$)') { throw "No 'Flags:' block in the quest record - shape changed." }
if ($text -match '(?m)^- StartGameEnabled(?=\r?$)') {
    $updated = [regex]::Replace($text, '(?m)^- StartGameEnabled\r?\n', '')
    if ($updated -eq $text) { throw 'StartGameEnabled matched but produced no change - check line endings.' }
    [IO.File]::WriteAllText($quest, $updated, $utf8)
    Write-Host 'WB_PopulateLists_Quest: StartGameEnabled removed (not sufficient on its own - see .NOTES)'
} else {
    Write-Host 'WB_PopulateLists_Quest: StartGameEnabled already clear'
}
