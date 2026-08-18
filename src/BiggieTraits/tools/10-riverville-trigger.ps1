# 10 - Open the trait menu automatically when the player first enters Riverville.
#
# WHY: stock Biggie Traits does not open the menu by itself at all. `Traits_Quest` is
# StartGameEnabled and its PlayerRef alias grants `Traits_SelectionSpell` — a **Power** on the
# Voice equip type — which the player has to cast by hand. That is workable in Skyrim, where the
# Voice slot is idle until the first shout, but poor in Enderal, where the Voice slot carries
# Meditate and the talent powers from the first minutes. It is worse with Skip Intro SE, which
# skips the prologue entirely and drops the player at SonnenkuesteTempelausgang with a fresh
# character and no prompt of any kind.
#
# WHAT: adds a conditioned constant-effect ability to the same alias, gated on
# `GetInCurrentLoc FlusshaimLocation` (Riverville). When the player walks into town the effect
# starts, `Traits_PickTraitScript.OnEffectStart` runs, the menu opens, and the script's existing
# `Traits_Quest.Stop()` tears the alias down — which removes BOTH the new ability and the old
# power. No new Papyrus: this reuses the mod's own script.
#
# Evidence for each choice, measured 2026-08-05:
#   * Riverville is `FlusshaimLocation 032706`. Enderal's EditorIDs are German (CLAUDE.md), so the
#     English town name finds nothing. 13 exterior cells in Vyn carry that Location, including
#     `FlusshaimEingang` — the town entrance — plus every interior, so both walking in and fast
#     travelling land in it.
#   * `GetInCurrentLocConditionData` is the right condition type: Enderal uses it **221 times**.
#     `GetInCurrentLocation` — the name that looks right — appears **zero** times and is not what
#     Mutagen emits here.
#   * The ability/MGEF pair is copied from this mod's own `Traits_AnglerAb` + `Traits_Angler`,
#     which is the same archetype: Type Ability, a Script-archetype magic effect, and no explicit
#     CastType/TargetType because Spriggit omits the ConstantEffect/Self defaults.
#
# The manual Power is deliberately KEPT as a fallback. Nothing here has been proven in game yet,
# and if the conditioned ability does not fire the mod would otherwise be unusable with no way in.
# Once the automatic trigger is confirmed working, the power can be dropped — see the note at the
# bottom of this file.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "10 - adding the Riverville trigger"

$root = Get-EspRoot

# Riverville. Enderal's own record; see the header comment for why it is spelled Flusshaim.
$RivervilleLocation = '032706:Skyrim.esm'

# New records go just past the plugin's highest own FormID, the way the Apocalypse replacement
# allocates in its host's space rather than in an ESL 0x800 block (CLAUDE.md, "Allocations in use").
$MgefKey = '000DA8'
$SpelKey = '000DA9'

# --- refuse to collide -----------------------------------------------------------------------------
$index = Get-RecordIndex
foreach ($k in @($MgefKey, $SpelKey)) {
    $full = "${k}:Biggie Traits.esp"
    if ($index.ContainsKey($full)) {
        $existing = $index[$full].EditorID
        if ($existing -notlike 'ZP_Traits_Riverville*') {
            throw "FormID $k is already taken by '$existing'. Pick another block."
        }
    }
}
$highest = 0
foreach ($k in $index.Keys) {
    $hex = [Convert]::ToInt32(($k -split ':')[0], 16)
    if ($hex -gt $highest -and $k -notlike '000DA*') { $highest = $hex }
}
Write-Host ("  highest pre-existing own FormID: 0x{0:X3}; allocating 0x{1} and 0x{2}" -f $highest, $MgefKey.Substring(3), $SpelKey.Substring(3))
if ($highest -ge 0xDA8) { throw "Allocation block 0xDA8-0xDA9 is not past the highest own FormID (0x$('{0:X}' -f $highest))." }

# --- the magic effect ------------------------------------------------------------------------------
$mgef = @"
FormKey: ${MgefKey}:Biggie Traits.esp
EditorID: ZP_Traits_RivervilleTrigger
VirtualMachineAdapter:
  Scripts:
  - Name: Traits_PickTraitScript
    Properties:
    - MutagenObjectType: ScriptObjectProperty
      Name: Traits_Quest
      Object: 000001:Biggie Traits.esp
Name:
  TargetLanguage: English
  Value: Select Traits
Flags:
- NoDuration
- NoMagnitude
- NoArea
Archetype:
  MutagenObjectType: MagicEffectArchetype
  Type: Script
DualCastScale: 1
CastingSoundLevel: Normal
Sounds: []
Description:
  TargetLanguage: English
  Value: ''
"@

# --- the ability -----------------------------------------------------------------------------------
$spel = @"
FormKey: ${SpelKey}:Biggie Traits.esp
EditorID: ZP_Traits_RivervilleTriggerAb
Name:
  TargetLanguage: English
  Value: Select Traits
Description:
  TargetLanguage: English
  Value: ''
Flags:
- IgnoreResistance
- NoAbsorbOrReflect
Type: Ability
Effects:
- BaseEffect: ${MgefKey}:Biggie Traits.esp
  Data: {}
  Conditions:
  - MutagenObjectType: ConditionFloat
    Data:
      MutagenObjectType: GetInCurrentLocConditionData
      Location: $RivervilleLocation
    ComparisonValue: 1
"@

$mgefPath = Join-Path $root ("MagicEffects/ZP_Traits_RivervilleTrigger - ${MgefKey}_Biggie Traits.esp.yaml")
$spelPath = Join-Path $root ("Spells/ZP_Traits_RivervilleTriggerAb - ${SpelKey}_Biggie Traits.esp.yaml")
Write-YamlText -Path $mgefPath -Text (($mgef -split "`r?`n") -join "`r`n")
Write-YamlText -Path $spelPath -Text (($spel -split "`r?`n") -join "`r`n")
Write-Host "  wrote ZP_Traits_RivervilleTrigger (MGEF) and ZP_Traits_RivervilleTriggerAb (SPEL)"

# --- hang the ability off the quest's player alias --------------------------------------------------
$quest = Get-ChildItem -Path (Join-Path $root 'Quests') -Filter 'Traits_Quest - *.yaml' | Select-Object -First 1
if (-not $quest) { throw "Traits_Quest not found - it must survive the cut." }

$lines = Get-YamlLines $quest.FullName
$entry = "  - ${SpelKey}:Biggie Traits.esp"
if ($lines -contains $entry) {
    Write-Host "  Traits_Quest: alias already grants the trigger ability"
} else {
    $spellsIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*Spells:\s*$') { $spellsIdx = $i; break }
    }
    if ($spellsIdx -lt 0) { throw "Traits_Quest's PlayerRef alias has no 'Spells:' list to extend." }

    # append after the last entry of that sequence
    $insertAt = $spellsIdx + 1
    while ($insertAt -lt $lines.Count -and $lines[$insertAt] -match '^\s*-\s+[0-9A-Fa-f]{6}:') { $insertAt++ }

    $new = @()
    $new += $lines[0..($insertAt - 1)]
    $new += $entry
    if ($insertAt -lt $lines.Count) { $new += $lines[$insertAt..($lines.Count - 1)] }
    Set-YamlLines -Path $quest.FullName -Lines $new
    Write-Host "  Traits_Quest: alias now grants the trigger ability alongside the manual power"
}

# --- prove it ----------------------------------------------------------------------------------------
$questText = Read-YamlText $quest.FullName
if ($questText -notmatch [regex]::Escape("${SpelKey}:Biggie Traits.esp")) {
    throw "Alias edit did not take - the quest does not reference $SpelKey."
}
$index = Get-RecordIndex
foreach ($k in @($MgefKey, $SpelKey)) {
    if (-not $index.ContainsKey("${k}:Biggie Traits.esp")) { throw "Record $k was not written." }
}
Write-Host "10 - done"

# To drop the manual power once the automatic trigger is confirmed in game: remove the
# '  - 000004:Biggie Traits.esp' line from Traits_Quest's alias Spells list, and delete
# Traits_SelectionSpell (000004) and Traits_PickTraitEffect (000003). Leave this script's records
# in place - they are what opens the menu.
