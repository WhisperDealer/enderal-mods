# 16 - The naming close-out (WD-10, applying half).
#
# The archetype passes (09-13) carried their renames with them, so by the time this ran for the
# first time only two strings were left, both internal labels a player never sees - renamed
# anyway so the assertion below can demand a flat ZERO with no allowlist to maintain:
#
#   "AtronachBodyArtHolder"  -> "DemonBodyArtHolder"   (HideInUI art-holder effect on the
#                                                       Warlock's Balefire body ability)
#   "DaedricTaunts" etc.     -> "DemonTaunts" etc.     (Combat/Taunt DialogTopic display names -
#                                                       taunt topics never appear in a menu, and
#                                                       every response subtitle was read and is
#                                                       lore-neutral: growls and generic menace)
#
# Then THE CHECK THAT MAKES WD-10 TRUE: every player-facing string line in the tree - Name,
# Description, BookText, Message and dialogue Values - is scanned against the Elder Scrolls
# lexicon and the script throws on any hit. EditorIDs, FormKeys and asset paths are identifiers,
# not prose, and are exempt (renaming an asset path would break a real file to fix a string
# nobody sees). Re-run this after ANY later edit that touches strings - WD-18's build should run
# it as a gate.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "16 - naming close-out (WD-10)"
$root = Get-EspRoot

# --- the last two renames -----------------------------------------------------------------------
$renames = @(
    @('Value: AtronachBodyArtHolder', 'Value: DemonBodyArtHolder'),
    @('Value: DaedricTaunts',         'Value: DemonTaunts'),
    @('Value: TVR_DaedricDying',      'Value: TVR_DemonDying'),
    @('Value: TVR_DaedricHit',        'Value: TVR_DemonHit'),
    @('Value: TVR_DaedricSeek',       'Value: TVR_DemonSeek')
)
foreach ($r in $renames) {
    $n = Update-TreeStrings -Old $r[0] -New $r[1] -MustExistAfter
    Write-Host ("  '{0}' -> '{1}': {2}" -f $r[0], $r[1], $n)
}

# --- the assertion ------------------------------------------------------------------------------
# Word-boundary regex over the whole Elder Scrolls lexicon. Case-insensitive. Every term the
# naming table maps, plus the gods, princes, races, holds and factions a future edit might
# plausibly reintroduce.
$lexicon = @(
    'Hircine', 'Azra', 'Oblivion', 'Daedr\w*', 'Tamriel', 'Nirn', 'All-?Maker', 'Earth[ -]Bones',
    'Old Ways', 'Skaal', 'Solstheim', 'Morrowind', 'Cyrodiil',
    'Stendarr', 'Mara', 'Arkay', 'Kynareth', 'Talos', 'Dibella', 'Akatosh', 'Julianos',
    'Zenithar', 'Kyne', 'Divines?', 'Aedra',
    'Meridia', 'Azura', 'Sheogorath', 'Molag', 'Boethiah', 'Namira', 'Vaermina', 'Sanguine',
    'Clavicus', 'Hermaeus', 'Malacath', 'Mehrunes', 'Peryite', 'Nocturnal',
    'Sovngarde', 'Aetherius', 'Atronach\w*', 'Draugr', 'Dwemer', 'Falmer', 'Dremora',
    'Nords?', 'Imperials?', 'Khajiits?', 'Argonians?', 'Orcs?', 'Bretons?', 'Redguards?',
    'Altmer', 'Bosmer', 'Dunmer', 'Dark Elf', 'Wood Elf', 'High Elf', 'Orsimer',
    'Winterhold', 'Whiterun', 'Riverwood', 'Markarth', 'Solitude', 'Windhelm', 'Morthal',
    'Falkreath', 'Riften', 'Dawnstar', 'Kynesgrove', 'Largashbur', 'Narzulbur',
    'Elder Scrolls', 'Companions', 'Greybeards?', 'Thalmor', 'Ysgramor', 'Shor', 'Magnus',
    'Alduin', 'Dragonborn', 'Septim', 'Jarl', 'Skyrim', 'College of', 'Tel Mithryn',
    'Telvanni', 'Skyforge', 'Sithis', 'Night Mother'
)
$termRx = [regex]::new('\b(' + ($lexicon -join '|') + ')\b', 'IgnoreCase')
# identifier/asset lines, never prose:
$skipRx = [regex]::new('(EditorID:|FormKey:|^\s*(File|FileName):|\.nif|\.dds|\.wav|\.hkx|scriptName|Name: [A-Za-z_0-9]+\s*$|SkyrimMajorRecordFlags|Spriggit\.Yaml|Master: |:Skyrim\.esm|_Skyrim\.esm)')

$hits = @()
foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
    foreach ($line in Get-YamlLines $file.FullName) {
        if ($skipRx.IsMatch($line)) { continue }
        $m = $termRx.Match($line)
        if ($m.Success) {
            $hits += ("[{0}] {1}: {2}" -f $m.Groups[1].Value, $file.Name, $line.Trim())
        }
    }
}
if ($hits.Count -gt 0) {
    $hits | ForEach-Object { Write-Host "  LEFTOVER: $_" }
    throw "$($hits.Count) Elder Scrolls proper noun(s) survive in player-facing strings."
}
Write-Host "16 - ZERO Elder Scrolls proper nouns in player-facing strings. WD-10's done-when holds."
