# 09 - The Druid line (WD-11).
#
# 1. Repopulate TVR_Verdant_FormList_Ingredients. WD-9's DLC strip emptied it - all 36 entries
#    were Hearthfires garden planters - and TVR_Druidcraft_Script does
#    PlaceAtMe(TVR_Spawn.GetAt(RandomInt(...))) on it, so an empty list means Druidcraft grows
#    nothing (and logs a None error) every cast. Refilled with 24 of Enderal's own harvestable
#    wild plants, every one verified against reference/base/Skyrim/{Florae,Trees} with an English
#    display name and an Ingredient yield. Wild herbs and mushrooms rather than the original's
#    garden vegetables - a corpse feeding the wild, which is the spell's own fiction.
#    (TREE-group harvestables are legal FormList members here: Enai's own Mark_Plant list already
#    mixes FLOR and TREE.)
#
# 2. The Hircine renames, per arch-docs/Triumvirate/naming-table.md (decision 1, option B):
#    Enderal has no nature/beast god - the Light-Born are a civic pantheon - so the Druid loses
#    the patron rather than gaining a wrong one. "Hound of Hircine" becomes the Glacier Hound,
#    which is a real Enderal creature (Creature_GlacierHoundFaction, level 55) and already the
#    actor this summon should read as. "Mark of Hircine" becomes "Mark of the Wild".
#    Display strings only - EditorIDs are identifiers, not player-facing, and stay.
#
# Deliberately NOT touched:
#    TwinSouls 0D5F1C (12 effect conditions + the manager quest property). Dead perk means
#    HasPerk always false: the single-summon base variants always fire and the doubling variants
#    never do. Enderal has no two-summons perk to repoint at. Documented deviation.
#    Game.SetBeastForm in tvr_wildshape_script - engine-level werewolf flag, cannot be judged
#    from records. WD-18 test matrix carries it as a named risk.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "09 - Druid (WD-11)"
$root = Get-EspRoot

# --- 1. Druidcraft ingredient list --------------------------------------------------------------
$list = Get-ChildItem -LiteralPath (Join-Path $root 'FormLists') -Filter 'TVR_Verdant_FormList_Ingredients - *.yaml' | Select-Object -First 1
if (-not $list) { throw "TVR_Verdant_FormList_Ingredients not found" }

# EditorID | English name, all [verified] in reference/base/Skyrim
$flora = @(
    '0BB94A:Skyrim.esm',  # TreeFloraCanisRoot01      | Salt Root
    '0BB94B:Skyrim.esm',  # TreeFloraDeathBell01      | Baldris Root
    '0BB949:Skyrim.esm',  # TreeFloraJazBay01         | Wild Berry
    '0BB948:Skyrim.esm',  # TreeFloraJuniper01        | Juniper
    '01BB3D:Skyrim.esm',  # TreeFloraLavender01       | Lavender
    '0BCF3D:Skyrim.esm',  # TreeFloraMountainFlower01Blue   | Blue Malphas Flower
    '0BCF3A:Skyrim.esm',  # TreeFloraMountainFlower01Purple | Purple Malphas Flower
    '0BCF3C:Skyrim.esm',  # TreeFloraMountainFlower01Red    | Red Malphas Flower
    '0C43B0:Skyrim.esm',  # TreeFloraNightshade01     | Nightshade
    '0BCF33:Skyrim.esm',  # TreeFloraSnowberry01      | Holly
    '0B91F0:Skyrim.esm',  # TreeFloraThistle01        | Thistle
    '0BB94D:Skyrim.esm',  # TreeFloraVatyrsTongue01   | Vatyr's Tongue
    '0BB947:Skyrim.esm',  # TreeFloraTundraCotton01   | Endralean Cotton
    '0BE3E0:Skyrim.esm',  # TreeFloraSpikyGrass01     | Spicy Grass
    '0B03AF:Skyrim.esm',  # FloraCreepCluster         | Root Weed
    '07E8C2:Skyrim.esm',  # FloraGiantLichen          | Lichen
    '044F40:Skyrim.esm',  # FloraManapilz             | Mana Fungi
    '04D9FF:Skyrim.esm',  # FloraMushroom01           | Stain Mushroom
    '04DA04:Skyrim.esm',  # FloraMushroom02           | Sporecrown
    '04DA06:Skyrim.esm',  # FloraMushroom03           | Leucoagaricus
    '04DA08:Skyrim.esm',  # FloraMushroom04           | Sheer Cap
    '04DA0A:Skyrim.esm',  # FloraMushroom05           | Laundress Mushroom
    '04DA0C:Skyrim.esm',  # FloraMushroom06           | Red Russula
    '07E8B8:Skyrim.esm')  # FloraSwampFungalPod01     | Mud Morel

$text = Read-YamlText $list.FullName
if ($text -match '(?m)^Items:') {
    Write-Host "  1. ingredient list already populated - skipping"
} else {
    $lines = @(Get-YamlLines $list.FullName | Where-Object { $_ -ne '' })
    $lines += 'Items:'
    foreach ($fk in $flora) { $lines += "- $fk" }
    $lines += ''
    Set-YamlLines -Path $list.FullName -Lines $lines
    Write-Host ("  1. ingredient list repopulated with {0} Enderal plants" -f $flora.Count)
}
$check = Read-YamlText $list.FullName
if (([regex]::Matches($check, '(?m)^- [0-9A-F]{6}:Skyrim\.esm')).Count -ne $flora.Count) {
    throw "ingredient list does not hold exactly $($flora.Count) entries"
}

# --- 2. Hircine renames -------------------------------------------------------------------------
# Longest phrase first so "Call Hound of Hircine" gets its article before the bare-phrase pass.
$renames = @(
    @('Call Hound of Hircine', 'Call the Glacier Hound'),
    @('Mass Mark of Hircine',  'Mass Mark of the Wild'),
    @('Mark of Hircine',       'Mark of the Wild'),
    @('Hound of Hircine',      'Glacier Hound')
)
$total = 0
foreach ($r in $renames) {
    $n = Update-TreeStrings -Old $r[0] -New $r[1] -MustExistAfter
    Write-Host ("  2. '{0}' -> '{1}': {2}" -f $r[0], $r[1], $n)
    $total += $n
}

# --- prove no player-facing Hircine survives ----------------------------------------------------
$left = @()
foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
    foreach ($line in Get-YamlLines $file.FullName) {
        # EditorIDs are identifiers and File:/FileName: lines are asset paths into Enai's BSA -
        # renaming either would break something real to fix a string nobody sees.
        if ($line -match 'Hircine' -and $line -notmatch 'EditorID|FormKey|File(Name)?:|Name: [A-Za-z_0-9]+\s*$') {
            $left += ("{0}: {1}" -f $file.Name, $line.Trim())
        }
    }
}
if ($left.Count -gt 0) {
    $left | ForEach-Object { Write-Host "    remaining: $_" }
    throw "$($left.Count) player-facing Hircine string(s) survived."
}
Write-Host "09 - done"
