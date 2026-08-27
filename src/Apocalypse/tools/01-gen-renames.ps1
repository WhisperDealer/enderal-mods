#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$apoc = Join-Path $repo 'reference\mods\Apocalypse\esp'
$dst  = Join-Path $repo 'src\Apocalypse\ApocalypseESP'
$enc  = New-Object System.Text.UTF8Encoding($false)

# old -> new, ordered longest-first so no pair is a prefix of another
$renames = [ordered]@{
  # Genuinely longest-first: this key CONTAINS "Hrormir's Misdirection", so it has to fire before
  # it. Put it second and the shorter key wins, leaving the unreadable "Staff of Veil of
  # Misdirection" - and then this one matches nothing and the run fails, which is how it was caught.
  "Staff of Hrormir's Misdirection" = 'Staff of Misdirection'
  "Silmane's Spell Sentinel"        = 'Spell Sentinel'
  "Welloc's Instant Forest"         = 'Instant Forest'
  "Hrormir's Misdirection"          = 'Veil of Misdirection'
  "Malviser's Gauntlet"             = 'Telekinetic Gauntlet'
  "Hethoth's Grimoire"              = 'Eventuality Grimoire'
  "Sotha's Maelstrom"               = 'Thaumaturgic Maelstrom'
  "Stendarr's Embrace"              = "Erodan's Embrace"
  "Medora's Memory"                 = "Esara's Memory"
  "Meridia's Wrath"                 = "Malphas' Wrath"
  "Ocato's Recital"                 = "Baledor's Recital"
  "Tharn's Prison"                  = "Girath" + [char]0x00FB + "'s Prison"   # Girathu-circumflex
  'Oblivion Unbound'                = 'Sinistra Unbound'
  'Breath of Arkay'                 = 'Breath of Tyr'
  'Talons of Nirn'                  = 'Talons of Vyn'
  'Lamb of Mara'                    = 'Lamb of Irlanda'
  "Reynos' Fins"                    = 'Fins of Kil' + [char]0x00E9                # Kile-acute
  # --- items and creatures named for Daedra ---------------------------------
  # Enderal has no Daedra at all. These are the ones the 10.2.3 release fixed BY HAND, in record
  # groups this script never scanned; they are here so a version bump reproduces them.
  # Before the bare 'Daedric Crescent' key, or the article is left disagreeing: Enai's
  # sentence is "Binds a Daedric Crescent", which becomes "Binds a Entropic Crescent".
  'Binds a Daedric Crescent'        = 'Binds an Entropic Crescent'
  'Daedric Crescent'                = 'Entropic Crescent'
  'Daedric Dagger'                  = 'Entropic Dagger'
  'Daedric Body'                    = 'Summoned Body'
  'Daedric Wolf'                    = 'Spirit Wolf'
  'a summoned Dremora or humanoid'  = 'a summoned or raised humanoid'
  'Nordic totem spirit'             = 'ancient totem spirit'
  'Imperial Sword'                  = 'Battlemage Sword'
  # --- the ten conjured battlemages -----------------------------------------
  # Full strings rather than bare race words: a blanket 'Nord' -> 'Endralean' would also hit
  # 'Nordic', and Enai reuses each race at two tiers. Enderal's peoples, mapped by rough
  # cultural fit: Altmer/Nord -> Endralean, Imperial/Bosmer -> Nehrimese, Breton/Redguard ->
  # Kilean, Dunmer/Khajiit -> Qyranian.
  'Altmer Veteran Battlemage'       = 'Endralean Veteran Battlemage'
  'Imperial Veteran Battlemage'     = 'Nehrimese Veteran Battlemage'
  'Breton Veteran Battlemage'       = 'Kil' + [char]0x00E9 + 'an Veteran Battlemage'
  'Dunmer Trained Battlemage'       = 'Qyranian Trained Battlemage'
  'Nord Trained Battlemage'         = 'Endralean Trained Battlemage'
  'Bosmer Trained Battlemage'       = 'Nehrimese Trained Battlemage'
  'Khajiit Expert Battlemage'       = 'Qyranian Expert Battlemage'
  'Redguard Expert Battlemage'      = 'Kil' + [char]0x00E9 + 'an Expert Battlemage'
  'Altmer Novice Battlemage'        = 'Endralean Novice Battlemage'
  'Imperial Novice Battlemage'      = 'Nehrimese Novice Battlemage'
  # --- the five school load screens -----------------------------------------
  # Enderal renames all five schools (CLAUDE.md). The player has never heard of "the School of
  # Conjuration", and these strings are read on every loading screen.
  'The School of Alteration enables'   = 'The discipline of Mentalism enables'
  'The School of Conjuration offers'   = 'The discipline of Entropy offers'
  'The School of Destruction offers'   = 'The discipline of Elementalism offers'
  'The School of Illusion allows'      = 'The discipline of Psionics allows'
  'The School of Restoration can'      = 'The discipline of Light Magic can'
  'a variety of Daedra and undead'     = 'a variety of spirits and undead'
  # description-only rewrites
  'Banish a living creature to Oblivion.' = 'Banish a living creature into the Sea of Eventualities.'
  'serving the will of the Dragonborn.'   = 'serving your will.'
}

# Dead vanilla assets that a user-visible record points at. Not a string rename, but the same
# pass and the same reason: the player sees the result. Enderal has none of vanilla's load-screen
# art, so all five school load screens rendered nothing; 036F5C is `_00E_Loadscreen_Cabin`, a real
# Enderal static. [verified 2026-08-27]
$formKeySubs = [ordered]@{
  'LoadingScreenNif: 10D185:Skyrim.esm' = 'LoadingScreenNif: 036F5C:Skyrim.esm'
  'LoadingScreenNif: 10D186:Skyrim.esm' = 'LoadingScreenNif: 036F5C:Skyrim.esm'
  'LoadingScreenNif: 10D187:Skyrim.esm' = 'LoadingScreenNif: 036F5C:Skyrim.esm'
  'LoadingScreenNif: 10D188:Skyrim.esm' = 'LoadingScreenNif: 036F5C:Skyrim.esm'
  'LoadingScreenNif: 10D189:Skyrim.esm' = 'LoadingScreenNif: 036F5C:Skyrim.esm'
}
foreach ($k in @($formKeySubs.Keys)) { $renames[$k] = $formKeySubs[$k] }

# EVERY record group, not a hand-picked few.
#
# This used to be seven folders - Books, Spells, Scrolls, MagicEffects, Perks, Weapons, Messages -
# and the strings living anywhere else were fixed BY HAND after the fact. Regenerating against
# Apocalypse 10.3.0 exposed that: ObjectEffects, Races, Armors, Npcs, Hazards and LoadScreens all
# came back with their Elder Scrolls names intact (32 nouns' worth), because no script had ever
# touched them. Scan the lot instead, and let the per-rename assertion below prove each one landed.
#
# ConstructibleObjects and Worldspaces are excluded because step 5 drops both groups outright.
$skipDirs = @('ConstructibleObjects', 'Worldspaces')
$dirs = @(Get-ChildItem $apoc -Directory | Where-Object { $skipDirs -notcontains $_.Name } |
    Select-Object -ExpandProperty Name)

$touched = 0; $byDir = @{}; $perName = @{}
foreach ($dir in $dirs) {
  $srcDir = Join-Path $apoc $dir
  if (-not (Test-Path $srcDir)) { continue }
  # Recursive: Cells and other nested groups serialize to <folder>/RecordData.yaml, which a
  # flat wildcard misses entirely.
  foreach ($f in Get-ChildItem -LiteralPath $srcDir -Recurse -Filter *.yaml -File) {
    $rel     = $f.FullName.Substring($srcDir.Length + 1)
    $inSrc   = Join-Path (Join-Path $dst $dir) $rel
    $origin  = if (Test-Path $inSrc) { $inSrc } else { $f.FullName }
    $t       = [IO.File]::ReadAllText($origin)
    $t2      = $t
    $applied = @()
    foreach ($old in $renames.Keys) {
      if ($t2.Contains($old)) {
        $n = ([regex]::Matches($t2, [regex]::Escape($old))).Count
        $t2 = $t2.Replace($old, $renames[$old])
        $applied += $old
        $perName[$old] = $n + $(if ($perName.ContainsKey($old)) { $perName[$old] } else { 0 })
      }
    }
    if ($applied.Count -eq 0) { continue }
    $outFile = Join-Path (Join-Path $dst $dir) $rel
    New-Item -ItemType Directory -Force (Split-Path $outFile -Parent) | Out-Null
    [IO.File]::WriteAllText($outFile, $t2, $enc)
    $touched++
    $byDir[$dir] = 1 + $(if ($byDir.ContainsKey($dir)) { $byDir[$dir] } else { 0 })
  }
}

"Records overridden for renames: $touched"
''
'-- by record type --'
$byDir.GetEnumerator() | Sort-Object Name | ForEach-Object { "  {0,-14} {1,3}" -f $_.Key, $_.Value }
''
'-- string replacements applied --'
foreach ($old in $renames.Keys) {
  $c = if ($perName.ContainsKey($old)) { $perName[$old] } else { 0 }
  $flag = if ($c -eq 0) { '  <-- NEVER MATCHED' } else { '' }
  "  {0,-42} -> {1,-42} x{2}{3}" -f $old, $renames[$old], $c, $flag
}
''
$missed = @($renames.Keys | Where-Object { -not $perName.ContainsKey($_) })
if ($missed.Count -gt 0) { throw "these renames matched nothing: $($missed -join '; ')" }
'All renames matched at least one record.'
