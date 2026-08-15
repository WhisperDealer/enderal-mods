#requires -Version 5.1
<#
.SYNOPSIS
  Generate the per-spell test checklist and the console batch files that drive it.

.DESCRIPTION
  Writes arch-docs/Apocalypse/spell-test-matrix.md - one checkbox row per obtainable item:

      175 tome spells   (5 schools x 5 tiers; the 176th "tome" is WB_SecretChest_Note, a note)
      144 scrolls

  Everything in it is derived from the YAML, so it cannot drift from what ships. The "Expected"
  column is the magic effect's own Description with <mag>/<dur>/<area> filled in from the spell's
  effect data - Enai's words, not invented behaviour.

  Risk flags come from build/dist/apocalypse-refs.csv (verify-missing-refs.ps1, run automatically
  if absent). A spell is flagged when the spell record, any of its magic effects, or anything one
  hop out from those effects references a FormID Enderal does not have.

.PARAMETER ModIndex
  Two hex digits: Apocalypse's load-order index in YOUR game. Not knowable from the repo, so the
  batch files are only written when you pass it. Find it in the console with

      help "Spell Tome: Alarm" 0

  which prints e.g. "BOOK: 0703C517 'Spell Tome: Alarm'" -> the index is 07.

.PARAMETER OutDir
  Where the console batch files go. Default build/dist/apoc-console (gitignored - they are
  per-install).
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[0-9A-Fa-f]{2}$')]
    [string]$ModIndex,
    [string]$OutDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$tree = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$doc  = Join-Path $repo 'arch-docs\Apocalypse\spell-test-matrix.md'
if (-not $OutDir) { $OutDir = Join-Path $repo 'build\dist\apoc-console' }

# ------------------------------------------------------------------ YAML helpers
# Deliberately not a YAML parser. PowerShell 5.1 has none, and Spriggit's output is regular enough
# that field-scraping is both sufficient and obvious to read. The tree is CRLF: always (?=\r?$).
function Get-Field {
    param([string]$Text, [string]$Name)
    if ($Text -match ('(?m)^' + [regex]::Escape($Name) + ': (.+?)\s*(?=\r?$)')) { return $Matches[1] }
    ''
}
# "Name:\n  TargetLanguage: English\n  Value: Foo"  ->  Foo
# The terminator must also accept end-of-file: on a MagicEffect, Description is often the LAST
# field, and requiring a following top-level key silently returned '' for most of them.
function Get-Localised {
    param([string]$Text, [string]$Name)
    if ($Text -match ('(?ms)^' + [regex]::Escape($Name) + ':\r?\n  TargetLanguage: [^\r\n]+\r?\n  Value: (.*?)(?=\r?\n[A-Za-z]|\s*\z)')) {
        $v = $Matches[1].Trim()
        $v = $v -replace '^[>|][-+]?\s*', ''      # folded/literal block scalar marker
        $v = $v -replace "^'(.*)'$", '$1'
        $v = $v -replace '\s*\r?\n\s*', ' '
        return $v.Trim()
    }
    ''
}
function Read-Records {
    param([string]$Folder)
    $map = @{}
    $dir = Join-Path $tree $Folder
    if (-not (Test-Path $dir)) { throw "Missing record folder: $dir" }
    foreach ($f in Get-ChildItem -LiteralPath $dir -File -Filter *.yaml) {
        $t = [IO.File]::ReadAllText($f.FullName)
        if ($t -notmatch '(?m)^FormKey: ([0-9A-F]{6}):') { continue }
        $map[$Matches[1]] = [pscustomobject]@{
            Id = $Matches[1]; EditorID = (Get-Field $t 'EditorID'); Text = $t
        }
    }
    $map
}

Write-Host 'reading records...'
$spells  = Read-Records 'Spells'
$mgefs   = Read-Records 'MagicEffects'
$books   = Read-Records 'Books'
$scrolls = Read-Records 'Scrolls'
Write-Host "  spells=$($spells.Count) mgefs=$($mgefs.Count) books=$($books.Count) scrolls=$($scrolls.Count)"

# ------------------------------------------------------------------ missing-reference flags
$csv = Join-Path $repo 'build\dist\apocalypse-refs.csv'
if (-not (Test-Path $csv)) {
    Write-Host 'apocalypse-refs.csv not found - running verify-missing-refs.ps1...'
    & (Join-Path $PSScriptRoot 'verify-missing-refs.ps1') | Out-Null
}
# Owner is a file basename like "WB_Des_Fire1_Effect_Blaze - 0B2C72_Apocalypse - Magic of Skyrim.esp".
$missingByRecord = @{}
foreach ($row in (Import-Csv -LiteralPath $csv | Where-Object State -eq 'MISSING')) {
    if ($row.Owner -match ' - ([0-9A-F]{6})_') {
        $id = $Matches[1]
        if (-not $missingByRecord.ContainsKey($id)) { $missingByRecord[$id] = New-Object System.Collections.ArrayList }
        [void]$missingByRecord[$id].Add($row.Field)
    }
}
Write-Host "  records with missing references: $($missingByRecord.Count)"

# ------------------------------------------------------------------ where each item is sold
# Six named merchant chests, in the wealth order the conversion tiers on.
$merchants = [ordered]@{
    '102AD5' = 'Ark - Emberlord & Fireflash'
    '118050' = 'Sun Temple - Torius Flameling'
    '13824A' = 'Undercity - Barnabas'
    '0F9320' = 'Ark - Ora Stonehand'
    '022BF2' = 'Duneville - Maxus Tabbakus'
    '127928' = 'Ark - Milbert Foxhand'
}
$soldAt = @{}
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $tree 'Containers') -File -Filter '_00E_Merchant_*.yaml') {
    if ($f.BaseName -notmatch ' - ([0-9A-F]{6})_') { continue }
    $chest = $Matches[1]
    if (-not $merchants.Contains($chest)) { continue }
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName), 'Item: ([0-9A-F]{6}):Apocalypse')) {
        $soldAt[$m.Groups[1].Value] = $merchants[$chest]
    }
}
# Loot: the six ZP_Apoc_* leveled lists this conversion adds.
$lootIn = @{}
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $tree 'LeveledItems') -File -Filter 'ZP_Apoc_*.yaml') {
    $list = ($f.BaseName -split ' - ')[0]
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName), 'Reference: ([0-9A-F]{6}):Apocalypse')) {
        $lootIn[$m.Groups[1].Value] = $list
    }
}
Write-Host "  tomes in merchant chests: $($soldAt.Count); items in ZP leveled lists: $($lootIn.Count)"

# ------------------------------------------------------------------ per-spell derivation
function Get-Effects {
    param([string]$Text)
    $out = @()
    if ($Text -notmatch '(?ms)^Effects:\r?\n(.*)$') { return $out }
    foreach ($blk in ($Matches[1] -split '(?m)^(?=- BaseEffect: )')) {
        if ($blk -notmatch '^- BaseEffect: ([0-9A-F]{6}):') { continue }
        $e = [pscustomobject]@{ Id = $Matches[1]; Magnitude = ''; Duration = ''; Area = '' }
        if ($blk -match '(?m)^\s+Magnitude: (\S+)') { $e.Magnitude = $Matches[1] }
        if ($blk -match '(?m)^\s+Duration: (\S+)')  { $e.Duration  = $Matches[1] }
        if ($blk -match '(?m)^\s+Area: (\S+)')      { $e.Area      = $Matches[1] }
        $out += $e
    }
    $out
}
# The player-facing text lives on a MagicEffect, and a spell's FIRST effect is often a silent rider
# (a perk application, a proc, an Arcane Fever tax) with no Description. Take the first that has one.
function Get-DescribingEffect {
    param($Effects)
    foreach ($e in $Effects) {
        if ($mgefs.ContainsKey($e.Id) -and (Get-Localised $mgefs[$e.Id].Text 'Description')) { return $e }
    }
    if ($Effects.Count) { return $Effects[0] }
    $null
}
# Anything in OUR plugin's space that this effect points at - one hop, to catch the summoned actor,
# the quest, the FormList of vanilla containers.
function Get-Neighbours {
    param([string]$Text)
    @([regex]::Matches($Text, '\b([0-9A-F]{6}):Apocalypse - Magic of Skyrim\.esp\b') |
      ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
}

$MaxHop = 1   # spell -> effect. Two hops adds noise (DEAD-SCRIPT-PROP 32 -> 43) without
              # reaching the FormLists behind Locate Object, which are three out and are
              # called out by hand below instead.
function Get-Risks {
    param([string]$SpellId, $Effects, [bool]$NotSold)
    $risks = New-Object System.Collections.ArrayList
    $seen  = New-Object 'System.Collections.Generic.HashSet[string]'

    function Add-Flag($f) { if ($risks -notcontains $f) { [void]$risks.Add($f) } }

    $check = New-Object System.Collections.ArrayList
    [void]$check.Add(@{ Id = $SpellId; Hop = 0 })
    foreach ($e in $Effects) { [void]$check.Add(@{ Id = $e.Id; Hop = 0 }) }

    while ($check.Count -gt 0) {
        $item = $check[0]; $check.RemoveAt(0)
        if (-not $seen.Add($item.Id)) { continue }

        if ($missingByRecord.ContainsKey($item.Id)) {
            foreach ($field in $missingByRecord[$item.Id]) {
                switch -Regex ($field) {
                    '^Perk$'               { Add-Flag 'DEAD-PERK' }
                    '^Object$'             { Add-Flag 'DEAD-SCRIPT-PROP' }
                    '^<list entry>$'       { Add-Flag 'VANILLA-LIST' }
                    '^(Item|DeathItem|Outfit|Template|TemplateArmor)$' { Add-Flag 'SUMMON-GAP' }
                    '^BaseEffect$'         { Add-Flag 'MISSING-EFFECT' }
                    default                { Add-Flag 'DEAD-REF' }
                }
            }
        }
        # Expand one hop out from the effects only - the spell's own neighbours are its effects.
        if ($item.Hop -lt $MaxHop -and $item.Id -ne $SpellId) {
            $rec = $null
            foreach ($m in @($mgefs, $spells)) { if ($m.ContainsKey($item.Id)) { $rec = $m[$item.Id]; break } }
            if ($rec) { foreach ($n in (Get-Neighbours $rec.Text)) { [void]$check.Add(@{ Id = $n; Hop = 1 }) } }
        }
    }

    # Respite (0581F9) exists in Enderal but is on no perk tree and not on the Player record, so
    # every effect item gated on it is permanently inert. Present, therefore invisible to a
    # missing-reference scan - it has to be looked for by hand.
    foreach ($e in $Effects) {
        if ($mgefs.ContainsKey($e.Id) -and $mgefs[$e.Id].Text -match '0581F9:Skyrim\.esm') { Add-Flag 'RESPITE-INERT'; break }
    }
    if ($NotSold) { Add-Flag 'NOT-SOLD' }
    $risks
}

function Resolve-Description {
    param([string]$Desc, $Effect)
    if (-not $Desc) { return '' }
    $d = $Desc
    if ($Effect) {
        if ($Effect.Magnitude) { $d = $d -replace '<mag>',  $Effect.Magnitude }
        if ($Effect.Duration)  { $d = $d -replace '<dur>',  $Effect.Duration }
        if ($Effect.Area)      { $d = $d -replace '<area>', $Effect.Area }
    }
    ($d -replace '\|', '\|').Trim()
}

# Enai's tome EditorIDs encode school and tier: WB_<A|C|D|I|R><000|025|050|075|100>_
$schools = [ordered]@{
    'D' = @{ Vanilla = 'Destruction';  Enderal = 'Elementalism' }
    'C' = @{ Vanilla = 'Conjuration';  Enderal = 'Entropy' }
    'R' = @{ Vanilla = 'Restoration';  Enderal = 'Light Magic' }
    'A' = @{ Vanilla = 'Alteration';   Enderal = 'Mentalism' }
    'I' = @{ Vanilla = 'Illusion';     Enderal = 'Psionics' }
}
$tiers = [ordered]@{ '000' = 'Novice'; '025' = 'Apprentice'; '050' = 'Adept'; '075' = 'Expert'; '100' = 'Master' }

$rows = New-Object System.Collections.ArrayList
foreach ($b in $books.Values) {
    if ($b.EditorID -notmatch '^WB_([ACDIR])(\d{3})_') { continue }   # skips WB_SecretChest_Note
    $school = $Matches[1]; $tier = $Matches[2]

    if ($b.Text -notmatch '(?m)^  Spell: ([0-9A-F]{6}):') { throw "$($b.EditorID) teaches nothing." }
    $spellId = $Matches[1]
    if (-not $spells.ContainsKey($spellId)) { throw "$($b.EditorID) teaches an unknown spell $spellId." }
    $sp = $spells[$spellId]

    $effects = @(Get-Effects $sp.Text)
    $first   = Get-DescribingEffect $effects
    $desc    = ''
    if ($first -and $mgefs.ContainsKey($first.Id)) { $desc = Get-Localised $mgefs[$first.Id].Text 'Description' }
    if (-not $desc) { $desc = Get-Localised $sp.Text 'Description' }

    $notSold = -not ($soldAt.ContainsKey($b.Id) -or $lootIn.ContainsKey($b.Id))

    [void]$rows.Add([pscustomobject]@{
        Kind     = 'Spell'
        School   = $school
        Tier     = $tier
        Name     = (Get-Localised $sp.Text 'Name')
        SpellId  = $spellId
        TomeId   = $b.Id
        Cast     = (Get-Field $sp.Text 'CastType')
        Target   = (Get-Field $sp.Text 'TargetType')
        Cost     = (Get-Field $sp.Text 'BaseCost')
        Gold     = (Get-Field $b.Text 'Value')
        SoldAt   = if ($soldAt.ContainsKey($b.Id)) { $soldAt[$b.Id] } else { '-' }
        Expected = (Resolve-Description $desc $first)
        Risks    = (Get-Risks $spellId $effects $notSold)
        EditorID = $sp.EditorID
    })
}
Write-Host "  tome spells: $($rows.Count)"
if ($rows.Count -ne 175) { throw "Expected 175 tome spells, built $($rows.Count). The tome set changed - re-derive before trusting this." }

$scrollRows = New-Object System.Collections.ArrayList
foreach ($s in ($scrolls.Values | Sort-Object EditorID)) {
    $effects = @(Get-Effects $s.Text)
    $first   = Get-DescribingEffect $effects
    $desc    = ''
    if ($first -and $mgefs.ContainsKey($first.Id)) { $desc = Get-Localised $mgefs[$first.Id].Text 'Description' }
    $school  = if ($s.EditorID -match '^WB_([ACDIR])\d{3}_') { $Matches[1] } else { 'X' }
    [void]$scrollRows.Add([pscustomobject]@{
        School   = $school
        Name     = (Get-Localised $s.Text 'Name')
        Id       = $s.Id
        Gold     = (Get-Field $s.Text 'Value')
        Loot     = if ($lootIn.ContainsKey($s.Id)) { $lootIn[$s.Id] } else { '-' }
        Expected = (Resolve-Description $desc $first)
        Risks    = (Get-Risks $s.Id $effects (-not $lootIn.ContainsKey($s.Id)))
        EditorID = $s.EditorID
    })
}
Write-Host "  scrolls: $($scrollRows.Count)"
if ($scrollRows.Count -ne 144) { throw "Expected 144 scrolls, built $($scrollRows.Count)." }

# ------------------------------------------------------------------ the document
$idx = if ($ModIndex) { $ModIndex.ToUpper() } else { 'XX' }
$md = New-Object System.Collections.ArrayList
function W($s) { [void]$md.Add($s) }

W '# Apocalypse for Enderal -- spell test matrix'
W ''
W '> **Generated** by `src/Apocalypse/tools/13-gen-test-matrix.ps1` from the Spriggit YAML. Do not'
W '> hand-edit -- re-run it. Tick the boxes in a working copy or a PR comment.'
W ''
W ("Covers every obtainable item this release ships: **{0} tome spells** and **{1} scrolls**." -f $rows.Count, $scrollRows.Count)
W '(`WB_SecretChest_Note` is a note, not a tome, and is excluded.)'
W ''
W '## Before you start'
W ''
W '**1. Find the plugin''s load-order index.** It is not knowable from the repo. In the console:'
W ''
W '```'
W 'help "Spell Tome: Alarm" 0'
W '```'
W ''
W 'It prints something like `BOOK: 0703C517 ''Spell Tome: Alarm''`. The leading **two hex digits** are'
W 'the index -- `07` here. **If this returns nothing, stop:** the plugin is not loading at all, which'
W 'on Enderal almost always means the `HEDR` form version is 1.71 rather than 1.70.'
W ''
W ("**2. Generate the batch files** with that index (this doc currently shows ``{0}``):" -f $idx)
W ''
W '```'
W 'powershell -File src/Apocalypse/tools/13-gen-test-matrix.ps1 -ModIndex 07'
W '```'
W ''
W 'Copy the resulting `apoc-*.txt` into Enderal''s game root (beside `SkyrimSE.exe`) and run e.g.'
W '`bat apoc-elementalism` in the console.'
W ''
W '**3. Set up a test character.** `tgm` for god mode, `player.setav magicka 100000`,'
W '`player.setlevel 50` so level-gated distribution is live, and `player.advskill destruction 100000`'
W '(repeat per school) so skill-scaled magnitudes read true.'
W ''
W '**4. Turn on the Papyrus log.** [verified 2026-08-07] Under MO2 the INI the game reads is the'
W '**profile''s**, not the one in `Documents` -- `settings.ini` has `LocalSettings=true`. So edit'
W '`<modlist>\profiles\<profile>\Enderal.ini`, `[Papyrus]` section:'
W ''
W '```'
W 'bEnableLogging=1'
W 'bEnableTrace=1'
W 'bEnableProfiling=0'
W '```'
W ''
W '`bEnableTrace` is the one that matters -- the lines you are looking for are `Debug.Trace` calls'
W 'and they are suppressed without it. Leave profiling off; it is a heavy frame cost.'
W ''
W 'The log then appears at'
W ''
W '```'
W 'Documents\My Games\Skyrim Special Edition\Logs\Script\Papyrus.0.log'
W '```'
W ''
W '**Skyrim''s folder, not Enderal''s** -- the same quirk that puts the SKSE and crash logs there,'
W 'confirmed on this machine. Turn both settings back to `0` when you are done; a long session with'
W 'logging on produces a very large file.'
W ''
W '## Must-pass gate'
W ''
W 'Nothing below is worth doing until these are green. Each is one launch.'
W ''
W '> **PASSED in full on 2026-08-07**, over two sessions, against the build in this branch. The list'
W '> stays here because it has to be re-run on any Apocalypse version bump or record change -- treat'
W '> the ticks as a record of that run, not as permanently true.'
W ''
W '- [x] Enderal starts with the rebuilt `.esp` installed and enabled.'
W '- [x] No new crash log in `Documents\My Games\Skyrim Special Edition\SKSE\` -- **not** Enderal''s'
W '      folder, which only holds INIs and saves. If there is one, `PLUGINS: Total:` must be non-zero;'
W '      `Total: 0` means the crash happened during file loading, so suspect the header, not records.'
W '- [x] `help "Spell Tome: Alarm" 0` returns a hit (the plugin is not form-version-invisible).'
W '- [x] **NAVI strip -- three specific places, not a general sweep.** See "Testing the NAVI strip"'
W '      below. Ark and Riverville are *not* the test; the removed data never named a navmesh in'
W '      either. *All three checked, no issues.*'
W '- [x] **Brawl / intimidate dialogue behaves as base Enderal does** (it should do nothing special).'
W '      This is the test of the loose `dgintimidate*` stubs. Confirm the mod sits *below* Apocalypse'
W '      in MO2''s file order, or its BSA wins and the stubs never load.'
W '- [x] Start a new game, wait 90 seconds, then read the Papyrus log (see below). **Zero**'
W '      `Cannot call AddForm() on a None object` errors. The four `APOCALYPSE DEBUG:` trace lines'
W '      are expected and fine -- the script still runs, it just has nothing to iterate now.'
W '      *Confirmed: 0 in the whole log, down from 685.*'
W '- [x] Open Apocalypse''s MCM and press **Repopulate**. Same expectation: traces yes, `AddForm`'
W '      errors no. It runs the identical loop against its own six `_Replenish` FormLists, so it is'
W '      a separate path from the automatic one and has to be checked separately.'
W '- [x] All six merchants stock Apocalypse tomes (see the shop table below).'
W ("- [x] ``player.additem {0}1C1E71 5`` ... ``{0}1C1E75 5`` each yield Apocalypse tomes, and" -f $idx)
W ("      ``player.additem {0}1C1E76 10`` yields Apocalypse scrolls. ``additem`` resolves a leveled" -f $idx)
W '      list on the spot, so this proves loot distribution without waiting out `iDaysToRespawnVendor: 2`.'
W ''
W '### Testing the NAVI strip'
W ''
W 'An earlier draft of this checklist said "walk around Ark and Riverville and watch the NPCs". That'
W 'was a guess, and resolving the removed record against Enderal shows it is the wrong test:'
W ''
W '| What was removed | Could it affect Enderal? |'
W '|---|---|'
W '| 10 vanilla `MapInfos` entries | **No.** Every one parents to worldspace `00003C` -- Tamriel in Skyrim, **`MQP01Home`** in Enderal. And **0 of their 71 distinct FormIDs** is a navmesh Enderal defines |'
W '| `PreferredPathing`, 6,312 refs | **Almost no.** Of 650 distinct FormIDs, **exactly 1** (`075393`) is a real Enderal navmesh |'
W ''
W 'So 720 of 721 distinct FormIDs in that record named navmeshes that do not exist here -- the engine'
W 'had nothing to apply them to. Ark and Riverville were never named at all. **Treat this as a'
W 'regression check, not a fix confirmation: the expected result everywhere is "no difference".**'
W ''
W 'The three places worth actually visiting, in order of value:'
W ''
W '- [ ] **`coc WB_Entomb_Cell`** and **`coc WB_Dreamscape_Cell`** -- Apocalypse''s own interior cells,'
W '      whose three NAVI entries we **kept**. This is the only place the strip could have *broken*'
W '      something, so it matters more than anything we removed. In each: cast an Entropy summon'
W '      (`bat apoc-entropy` gives you the school), walk to the far side of the cell, and confirm the'
W '      summon **walks** after you rather than standing still or teleporting. Entomb is also reachable'
W '      naturally -- `player.addspell XX04581C`, cast it at an NPC, then cast again to free them; the'
W '      target should walk out under its own power.'
W '- [ ] **`cow Vyn -8 -3`** -- the single unnamed exterior cell whose navmesh (`075393`) the removed'
W '      `PreferredPathing` block actually named. Summon something (`bat apoc-entropy` gives you the'
W '      whole school) and confirm it follows you across the cell and over its boundaries.'
W '- [ ] **`cow MQP01Home 0 0`** -- the worldspace all 10 removed entries parented to. Nothing of'
W '      Enderal''s should have changed here, but it is the one worldspace that was named.'
W ''
W '**How to read "pathing works".** Standing NPCs prove nothing -- an idle NPC with no package looks'
W 'identical to one that cannot path. Use something that must move continuously:'
W ''
W '- A **summon or follower** is the sharpest instrument. It re-paths constantly. Repeated'
W '  teleport-to-catch-up, or a summon that spawns and then never closes distance, is the failure.'
W '- **Combat** second: a hostile that will not approach, or circles without closing, is a navmesh'
W '  problem rather than an AI one. `tcai` off and on again to confirm it is pathing and not fleeing.'
W '- Walking into walls, refusing to cross a cell boundary, or sinking through the floor are the'
W '  unambiguous signs.'
W ''
W '### Log lines that are expected, not bugs'
W ''
W 'Seen on a clean run [verified 2026-08-07]. Do not chase these:'
W ''
W '```'
W 'Error: Property MagicAllegianceFaction on script QF_WBA_Dominate_Quest_0200DBCB attached to'
W '  WB_EnslaveTheWeak_Quest (..00DBCB) cannot be bound because <nullptr form> (0009E0C9) is not'
W '  the right type'
W 'Error: Element of property WB_VendorChest on script wb_newmanager_quest_script attached to'
W '  WB_NewManager_Quest (..08095C) ... <nullptr form> ... is not the right type          x4'
W '```'
W ''
W 'Both are audit findings showing up at runtime: `09E0C9` is the missing allegiance faction behind'
W 'the Psionics simulacrum spells, and `WB_NewManager_Quest` binds six missing forms -- the College'
W 'of Winterhold ritual quests and books (`0D0755`, `0CD987`, `0FDE76`, `0FDE73`) and two vendor'
W 'chests (`098BAC`, `098B9F`) -- for content Enderal has no home for. All of them bind once at load'
W 'and cost nothing after.'
W ''
W 'One more, from actually casting Entomb:'
W ''
W '```'
W 'Error:  (00051181): does not have 3d and cannot have an effect shader played on it.'
W 'stack:'
W '  [ (..00AB5A)].EffectShader.Play() - "<native>"'
W '  [WB_Entomb_Quest].wb_entomb_quest_script.ReleaseCurrentVictim()'
W '  [ (FF00084A)].WB_Entomb_Activator_Script.OnLoad()'
W '```'
W ''
W '`ReleaseCurrentVictim()` plays a shader on the freed victim without checking `Is3DLoaded()` first,'
W 'so releasing someone whose cell is not loaded logs this once and carries on. Enai''s own script,'
W 'unrelated to the conversion. Harmless -- the victim is still released.'
W ''
W '## The shops'
W ''
W '| `coc` target | Shop | Gold | Tier | Tomes |'
W '|---|---|---:|---|---:|'
W '| `CapitalCityMagierkram` | Ark -- Emberlord and Fireflash | 1800 | Master | 45 |'
W '| `SuntempleAlchemy` | Sun Temple -- Torius Flameling | 1430 | Expert | 39 |'
W '| `UndercityBarracks2Barnabas` | Undercity -- Barnabas | 1050 | Adept (Mentalism/Entropy/Elementalism) | 19 |'
W '| -- | Ark -- Ora Stonehand | 980 | Adept (Psionics/Light Magic) | 14 |'
W '| -- | Duneville -- Maxus Tabbakus | 620 | Apprentice | 28 |'
W '| -- | Ark -- Milbert Foxhand | 530 | Novice | 15 |'
W ''
W 'Vendor stock is cached in the save (`iDaysToRespawnVendor: 2`), so a merchant only re-rolls every'
W 'two in-game days. Sleeping three days is the reliable way to force a restock.'
W ''
W '## Risk flags'
W ''
W 'Auto-derived from `verify-missing-refs.ps1`. A flag is **not** proof the spell is broken -- it says'
W 'this row is where to look first, and what to look at.'
W ''
W '| Flag | Means | What to check |'
W '|---|---|---|'
W '| `DEAD-PERK` | An effect applies a vanilla perk Enderal does not have (`Disintegrate 0F3F0E`, `Deep Freeze 0F3933`, `Intense Flames 0F392E`, `0153D2`, Illusion `059B76`) | The spell''s main effect should work; the rider will not fire. Confirm the base damage/effect still lands |'
W '| `RESPITE-INERT` | Gated on `Respite 0581F9`, which exists in Enderal but is on no perk tree and not on the `Player` record | The Stamina half of a heal never fires. Health restore is the real number |'
W '| `DEAD-SCRIPT-PROP` | A script property points at a missing form. Usually the harmless vanilla helpers (`SayOnHitByMagicEffectScript.TopicToSay`, `MG01FireEffectScript.MG01`) | Watch `Papyrus.0.log` while casting. Errors are expected to be noise; a spell that does nothing is not |'
W '| `VANILLA-LIST` | Behaviour depends on a FormList with dangling entries | Does the spell find or affect anything at all |'
W '| `SUMMON-GAP` | Summons an actor whose gear, perks or death item are missing | Does the summon appear, is it hostile, does it have a weapon |'
W '| `MISSING-EFFECT` | An effect record the spell references does not exist | Almost certainly broken. Investigate before shipping |'
W '| `NOT-SOLD` | In no merchant chest and no leveled list -- unobtainable by design (the 15 Daedric/Dwemer summons) | Confirm it is genuinely unreachable, then skip the row |'
W ''
W 'The walk stops one hop past the spell''s magic effects. Going further flagged a third more rows'
W 'without reaching anything new, so what lies deeper is listed by hand below instead.'
W ''
W '### Suggested order'
W ''
W 'The must-pass gate is green, so what remains is the rows. They are not equally worth your time --'
W ("of the {0} rows:" -f ($rows.Count + $scrollRows.Count))
W ''
# @() around every pipeline: under Set-StrictMode, .Count on a single returned object throws.
$byRisk = @{ Clean = 0; NotSoldOnly = 0; Flagged = 0 }
foreach ($r in (@($rows) + @($scrollRows))) {
    $f = @($r.Risks)
    $substantive = @($f | Where-Object { $_ -ne 'NOT-SOLD' })
    if     ($f.Count -eq 0)           { $byRisk.Clean++ }
    elseif ($substantive.Count -eq 0) { $byRisk.NotSoldOnly++ }
    else                              { $byRisk.Flagged++ }
}
W '| Do | Rows | Why |'
W '|---|---:|---|'
W ("| **1. Flagged rows** | {0} | The audit says something they touch is missing. Highest chance of finding a real defect per cast |" -f $byRisk.Flagged)
W '| **2. The "Known gaps" list below** | ~18 | Locate Object''s ten modes, Control Weather, the six simulacrum spells. Hand-found, so no flag marks them |'
W ("| **3. `NOT-SOLD` rows** | {0} | Not casts at all -- one merchant sweep confirms a player cannot reach them |" -f $byRisk.NotSoldOnly)
W ("| **4. Everything else** | {0} | The bulk. Lowest yield per row; batch it by school |" -f $byRisk.Clean)
W ''
W '**Leave Papyrus logging on for the whole run.** A spell that silently does nothing looks the same'
W 'as one that works if you are only watching the screen, and the log is what tells them apart. Cast'
W 'through a school with `bat apoc-<school>`, then afterwards:'
W ''
W '```'
W 'grep -nE "Error|cannot|None" Papyrus.0.log | grep -i "WB_"'
W '```'
W ''
W 'That turns 35 casts into one thing to read, and it catches the failures an eye test misses.'
W ''
W '## Known gaps the flags do not reach'
W ''
W 'Found by reading the records, not by the scan. Test these deliberately.'
W ''
W '- [ ] **Locate Object** (`XX00C143`, Mentalism Adept) is one spell that cycles ten categories, each'
W '      driven by its own quest and inclusion/exclusion FormList. Those lists are vanilla base objects,'
W '      and Enderal kept some and dropped others, so the modes do not stand or fall together:'
W '  - [ ] **Ore vein** -- expected to WORK. Its inclusion list resolves to 561 live Activators,'
W '        including Enderal''s own `_00E_MineOreShadowsteel`.'
W '  - [ ] **Plant** -- expected to WORK. Resolves to live `TreeFlora*` records, e.g.'
W '        `TreeFloraVatyrsTongue01`.'
W '  - [ ] **Potion** -- expected to FAIL. `WB_AlterationAlt_FormList_LocatePotion_Inclusion` is'
W '        7 entries and **all 7 are missing** from Enderal. There is nothing it can match.'
W '  - [ ] **Written text** -- partly dead: the word-wall FormList has a dangling entry.'
W '  - [ ] Gold, container, door, key, soul gem, mineral, equipment -- unverified either way. Note'
W '        which find something and which do not.'
W '- [ ] **The `Locate Container` exclusion list is 68-for-68 dangling.** It is an *exclusion*, so the'
W '      failure mode is over-matching (highlighting containers it should skip), not silence.'
W '- [ ] **Control Weather** (Mentalism Master) backs up and restores the active weather through'
W '      FormLists, and two of its script properties point at missing vanilla records'
W '      (`MAGProjectileStormVar 101DAB`, `MQClearSkyFogSpell 10387F`). Enderal replaces every weather'
W '      setting, so cast it, then confirm the weather **returns to normal** afterwards rather than'
W '      sticking. Watch cutscene fades for a while after -- they are a known casualty of weather'
W '      meddling in Enderal.'
W '- [ ] **The Psionics simulacrum line.** Six effects run six different scripts'
W '      (`WB_EvilTwin_Script`, `WB_EvilTwinAtTarget_Script`, `WB_SeidstoneHazard_Script`,'
W '      `WB_PullFromEternity_Script`, `WB_Warband_Script`) but every one takes a'
W '      `MagicAllegianceFaction` property pointing at `09E0C9`, which Enderal does not have. That'
W '      covers **Pale Shadow, Evil Twin, Fold Into Ether, Seidstone, Pull From Eternity** and'
W '      **Spectral Warband**. Check the summoned copy is **friendly and follows**, not hostile or'
W '      inert. `Compelling Whispers` reads the same property from its proc effect -- check the'
W '      charmed target actually fights for you.'
W ''

foreach ($sk in $schools.Keys) {
    $set = @($rows | Where-Object School -eq $sk)
    W ("## {0} -- *{1}* ({2} spells)" -f $schools[$sk].Enderal, $schools[$sk].Vanilla, $set.Count)
    W ''
    W ("`player.advskill {0} 100000` first, so magnitudes read at full skill." -f $schools[$sk].Vanilla.ToLower())
    W ''
    foreach ($tk in $tiers.Keys) {
        $tset = @($set | Where-Object Tier -eq $tk | Sort-Object Name)
        if (-not $tset.Count) { continue }
        # A tier can span more than one shop (Adept is split by school) and can contain withheld
        # summons, so name every distinct destination rather than whichever row sorted first.
        $shops = @($tset | Select-Object -ExpandProperty SoldAt -Unique | Sort-Object) -replace '^-$', 'NOT SOLD'
        W ("### {0} ({1}) -- {2}" -f $tiers[$tk], $tk, ($shops -join ' / '))
        W ''
        W '| OK | Spell | `addspell` | Cast / Target | Cost | Gold | Sold at | Expected | Risk |'
        W '|---|---|---|---|---:|---:|---|---|---|'
        foreach ($r in $tset) {
            $cast = (@($r.Cast, $r.Target) | Where-Object { $_ }) -join ' / '
            if (-not $cast) { $cast = 'Ability' }
            W ('| [ ] | **{0}** | `player.addspell {1}{2}` | {3} | {4} | {5} | {6} | {7} | {8} |' -f `
                $r.Name, $idx, $r.SpellId, $cast, $r.Cost, $r.Gold, $r.SoldAt, $r.Expected, (($r.Risks -join '<br>')))
        }
        W ''
    }
}

W ("## Scrolls ({0})" -f $scrollRows.Count)
W ''
W 'Scrolls carry the same magic effects as their tome spells, so a scroll row is a check that the'
W '**item** works -- that it exists, is obtainable, and casts on use -- not a re-test of the effect.'
W ''
W ("All of them at once: ``bat apoc-scrolls``, or one at a time with the ``additem`` below." -f $idx)
W ''
W '| OK | Scroll | `additem` | Gold | Loot list | Expected | Risk |'
W '|---|---|---|---:|---|---|---|'
foreach ($r in ($scrollRows | Sort-Object School, Name)) {
    W ('| [ ] | **{0}** | `player.additem {1}{2} 1` | {3} | {4} | {5} | {6} |' -f `
        $r.Name, $idx, $r.Id, $r.Gold, $r.Loot, $r.Expected, (($r.Risks -join '<br>')))
}
W ''
W '## Known-unobtainable by design'
W ''
W 'Fifteen Daedric and Dwemer summons are in no merchant chest and no leveled list, following the'
W '`enderal-magic-porter` rule that Daedra and Dwemer have no place in Enderal''s setting. Their'
W 'records still ship (removing them would break every FormList and script that indexes them), so'
W 'they are flagged `NOT-SOLD` above rather than deleted. Nothing to test -- but verify a player'
W 'cannot reach them:'
W ''
$notSold = @($rows | Where-Object { $_.Risks -contains 'NOT-SOLD' } | Sort-Object Name)
foreach ($r in $notSold) { W ('- [ ] `{0}` -- **{1}** is not offered by any merchant and does not drop' -f $r.EditorID, $r.Name) }
W ''
W ("**Note the inconsistency:** {0} tomes are withheld but only 14 of the matching scrolls are. " -f $notSold.Count)
W '`WB_C075_SixDemonBag`''s scroll is still in `ZP_Apoc_Scrolls`, so that summon *is* reachable, once,'
W 'from a scroll. Either sell the tome or pull the scroll -- it should not be half-in.'

$docDir = Split-Path -Parent $doc
if (-not (Test-Path $docDir)) { $null = New-Item -ItemType Directory -Force -Path $docDir }
[IO.File]::WriteAllText($doc, (($md -join "`r`n") + "`r`n"), (New-Object Text.UTF8Encoding($false)))
Write-Host "wrote $doc"

# ------------------------------------------------------------------ console batch files
if (-not $ModIndex) {
    Write-Host 'no -ModIndex given, so no batch files were written. Pass the two hex digits from `help "Spell Tome: Alarm" 0`.'
    return
}
if (-not (Test-Path $OutDir)) { $null = New-Item -ItemType Directory -Force -Path $OutDir }

# NOTE: no comments in these files. The console runs a .bat line-by-line as commands, and there is
# no comment syntax - a ';' line just prints an error, and a trailing ';' would be parsed as an
# extra argument. Everything explanatory belongs in the matrix doc, not here.
function Write-Batch {
    param([string]$Name, [string[]]$Lines)
    $path = Join-Path $OutDir $Name
    foreach ($l in $Lines) { if ($l -match ';') { throw "Batch line would confuse the console: '$l'" } }
    [IO.File]::WriteAllText($path, (($Lines -join "`r`n") + "`r`n"), (New-Object Text.ASCIIEncoding))
}

foreach ($sk in $schools.Keys) {
    $set = @($rows | Where-Object School -eq $sk | Sort-Object Tier, Name)
    $name = ($schools[$sk].Enderal -replace '\s', '').ToLower()
    $lines = @("player.advskill $($schools[$sk].Vanilla.ToLower()) 100000")
    foreach ($r in $set) { $lines += ("player.addspell {0}{1}" -f $idx, $r.SpellId) }
    Write-Batch "apoc-$name.txt" $lines
}
$lines = @()
foreach ($r in ($scrollRows | Sort-Object School, Name)) { $lines += ("player.additem {0}{1} 1" -f $idx, $r.Id) }
Write-Batch 'apoc-scrolls.txt' $lines

# additem resolves a leveled list on the spot, so this proves the loot path without waiting out
# iDaysToRespawnVendor. 1C1E71-75 are the five ZP_Apoc_Tomes_R* tiers; 1C1E76 is ZP_Apoc_Scrolls.
Write-Batch 'apoc-distribution.txt' @(
    'player.setlevel 50'
    "player.additem ${idx}1C1E71 5"
    "player.additem ${idx}1C1E72 5"
    "player.additem ${idx}1C1E73 5"
    "player.additem ${idx}1C1E74 5"
    "player.additem ${idx}1C1E75 5"
    "player.additem ${idx}1C1E76 10"
)

Write-Batch 'apoc-setup.txt' @(
    'tgm'
    'player.setlevel 50'
    'player.setav magicka 100000'
    'player.advskill destruction 100000'
    'player.advskill conjuration 100000'
    'player.advskill restoration 100000'
    'player.advskill alteration 100000'
    'player.advskill illusion 100000'
)

Write-Host "wrote console batch files to $OutDir"
Get-ChildItem -LiteralPath $OutDir -Filter 'apoc-*.txt' | ForEach-Object { "  $($_.Name)" }
