# 08 - Cross-archetype record fixes shared by WD-11..WD-15.
#
# Every fix below was decided by reading the record AND the Enderal archetype it must match, not
# by reasoning from names. Sources: build/dist/triumvirate-dead-refs.csv (regenerated after the
# WD-9 verdicts), reference/base/Skyrim, and the decompiled scripts.
#
# 1. MagicAllegianceFaction 09E0C9:Skyrim.esm is dead in Enderal. Enderal's own player summons
#    carry exactly one faction - Creature__SummonableFaction 046E6B:Skyrim.esm (read off
#    _05E_SummonableGhostlyWolf_Player and siblings) - so every occurrence is substituted with
#    that: 20 SpiritGuardian NPC faction entries, 2 VMAD script properties (TVR_Shadow_Script and
#    TVR_ProjectedSpirit_Script both do AddToFaction(property)), 2 faction Relations targets, and
#    1 quest-alias faction entry. 25 occurrences.
#
# 2. The 8 Illusion-school staves template to StaffTemplateIIllusion 07A91B, which Enderal
#    dropped. Enderal keeps five staff templates and its OWN staves all template to the surviving
#    one for their school (_00E_StaffOfTheOorbaya -> StaffTemplateConjuration 07E647). Illusion is
#    Psionics, a Sinistra school like Entropy/Conjuration, so these repoint to 07E647.
#
# 3. Three effects carry vanilla's SayOnHitByMagicEffectScript with a TopicToSay pointing at a
#    WICastMagicNonHostileSpell* topic. Enderal has NO WICastMagic topics at all (checked the
#    whole DialogTopics group), so the script can never say anything and logs against a None
#    topic. The script entry is removed; on the GrandHealing subspell it is the only script, so
#    the whole VirtualMachineAdapter goes.
#
# 4. The Cleric aura cloak-procs exclude guards via GetInFaction IsGuardFaction 086EEE < 1.
#    That FormID is dead here, but Enderal HAS an IsGuardFaction of its own - 07286D:Skyrim.esm -
#    so the exclusion is repointed rather than lost.
#
# 5. PredatorFaction 02E893 / PreyFaction 02E894 do not exist in Enderal and have no equivalent
#    (Enderal's creature factions are per-species). The NPC faction entries are ambient-ecology
#    flavor - stripped. The TrackEnemies alias condition "GetInFaction PreyFaction == 0" is
#    removed outright: its only job was excluding prey animals, and the alias already requires
#    IsHostileToActor, which excludes them.
#
# 6. The Conversion quest arms converted followers with FollowerHuntingBow/FollowerIronArrow,
#    both dead. Enderal's own basic hunting kit is _01E_01_HuntingBow 015C39 and
#    _01E_05_IronArrow 0457D8 - substituted.
#
# 7. Dead <list entry> pruning, all inert but kept out of the tree so the dead-ref audit stays
#    readable: 14 vanilla flora in the Veil/Diviner Mark lists, 11 vanilla campfire statics in
#    the Elemental ControlFlames list, 10 vanilla Argonian chargen presets in the ForceOfNature
#    race, and FemaleSoldier in the Conversion voice-type list.
#
# Deliberately NOT touched (graceful degradation, documented in the gap audit):
#   TwinSouls 0D5F1C and ElementalPotency 0CB41A HasPerk conditions - the base (non-potent,
#   single-summon) effect variants carry "HasPerk == 0" conditions that stay TRUE when the perk
#   is dead, so the base path always fires. No Enderal perk means "two summons" or "stronger
#   summons" (checked the Sinistrope line), so there is nothing to repoint at.
#   MasterOfTheMind 059B76 on Possession - automatons stay immune, which is vanilla's
#   no-perk behaviour.
#   TVR_Stone_Quest_Mark's 16 WETravel/WESceneCenter LocationReferenceTypes - the quest is not
#   StartGameEnabled and NOTHING references it (records or scripts); it is Enai's orphaned dev
#   content, like TVR_Diviner_FormList_Mark_Gold_UNUSED_ATM.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "08 - shared cross-archetype fixes"
$root = Get-EspRoot

function Get-RecordFile {
    param([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$EditorID)
    $hit = Get-ChildItem -LiteralPath (Join-Path $root $Group) -Filter "$EditorID - *.yaml" | Select-Object -First 1
    if (-not $hit) { throw "record not found: $Group\$EditorID" }
    return $hit.FullName
}

# --- 1. MagicAllegianceFaction -> Creature__SummonableFaction -----------------------------------
$n = Update-TreeStrings -Old '09E0C9:Skyrim.esm' -New '046E6B:Skyrim.esm'
if ($n -gt 0 -and $n -ne 25) { throw "MagicAllegianceFaction: expected 25 occurrences, replaced $n" }
Write-Host "  1. MagicAllegianceFaction -> Creature__SummonableFaction: $n"

# --- 2. staff templates -------------------------------------------------------------------------
$n = Update-TreeStrings -Old 'Template: 07A91B:Skyrim.esm' -New 'Template: 07E647:Skyrim.esm'
if ($n -gt 0 -and $n -ne 8) { throw "staff Template: expected 8, replaced $n" }
Write-Host "  2. staff Template -> StaffTemplateConjuration: $n"

# --- 3. SayOnHitByMagicEffectScript removals ----------------------------------------------------
$say = 0
$f = Get-RecordFile 'MagicEffects' 'TVR_Shaman_Totem_Effect_FylgjaSun_Subspell_GrandHealing'
if ((Read-YamlText $f) -match 'SayOnHitByMagicEffectScript') {
    $say += Remove-TopLevelKeyBlock -Path $f -Key 'VirtualMachineAdapter'
    if ((Read-YamlText $f) -match 'SayOnHit') { throw "GrandHealing subspell still carries SayOnHit" }
}
foreach ($ed in 'TVR_Cleric_Controller_Effect_Suggestion', 'TVR_Cleric_Controller_Effect_Obedience') {
    $f = Get-RecordFile 'MagicEffects' $ed
    if ((Read-YamlText $f) -match 'SayOnHitByMagicEffectScript') {
        $say += Remove-SequenceItemContaining -Path $f -ContainsPattern 'Name: SayOnHitByMagicEffectScript'
        $t = Read-YamlText $f
        if ($t -match 'SayOnHit') { throw "$ed still carries SayOnHit" }
        if ($t -notmatch 'TVR_(Suggestion|Conversion3)_Script') { throw "$ed lost its own script - the edit took too much" }
    }
}
Write-Host "  3. SayOnHitByMagicEffectScript removed: $say lines"

# --- 4. guard exclusion repoint -----------------------------------------------------------------
$n = Update-TreeStrings -Old 'Faction: 086EEE:Skyrim.esm' -New 'Faction: 07286D:Skyrim.esm'
if ($n -gt 0 -and $n -ne 2) { throw "IsGuardFaction: expected 2, replaced $n" }
Write-Host "  4. IsGuardFaction repointed: $n"

# --- 5. predator/prey ---------------------------------------------------------------------------
$pp = 0
foreach ($pair in @(
    @('Npcs', 'TVR_Primal_Actor_CallWolf',        '02E893'),
    @('Npcs', 'TVR_Primal_Actor_CallSnowLeopard', '02E893'),
    @('Npcs', 'TVR_Warrior_Actor_FylgjaSun',      '02E893'),
    @('Npcs', 'TVR_Warrior_Actor_FylgjaWind',     '02E893'),
    @('Npcs', 'TVR_Primal_Actor_CallRaven',       '02E894'))) {
    $f = Get-RecordFile $pair[0] $pair[1]
    $pp += Remove-SequenceItemContaining -Path $f -ContainsPattern ('Faction: ' + $pair[2] + ':Skyrim\.esm')
}
$f = Get-RecordFile 'Quests' 'TVR_TrackEnemies_Quest'
$pp += Remove-SequenceItemContaining -Path $f -ContainsPattern 'Faction: 02E894:Skyrim\.esm'
Write-Host "  5. predator/prey stripped: $pp lines"

# --- 6. follower bow/arrow ----------------------------------------------------------------------
$n  = Update-TreeStrings -Old 'Object: 10E2DD:Skyrim.esm' -New 'Object: 015C39:Skyrim.esm'
$n += Update-TreeStrings -Old 'Object: 10E2DE:Skyrim.esm' -New 'Object: 0457D8:Skyrim.esm'
if ($n -gt 0 -and $n -ne 2) { throw "follower bow/arrow: expected 2, replaced $n" }
Write-Host "  6. follower bow/arrow -> Enderal hunting kit: $n"

# --- 7. dead list entries -----------------------------------------------------------------------
$deadFlora = @('023CFF','052185','07EDF0','08B5C4','0AED89','0DD683','0ECA58','0ECA5C','0ECA5D',
               '0ECA5F','0ECA60','0F675F','10C3B4','10C3B5') | ForEach-Object { "$($_):Skyrim.esm" }
$deadFire  = @('013B42','04C5CE','04E263','0877F3','0BBCF1','0C2BF1','0C6918','0CBB23','0E7C9A',
               '0FB9B0','10D820') | ForEach-Object { "$($_):Skyrim.esm" }
$deadPresets = @('0A2CEB','0A2CEF','0A2CF0','0B2E10','0B2E11','0B2E12','0B2E13','0B2E14','0B2E15',
                 '0B2E16') | ForEach-Object { "$($_):Skyrim.esm" }
$pruned = 0
$pruned += Remove-YamlListEntries -Path (Get-RecordFile 'FormLists' 'TVR_Veil_FormList_Mark_Plant') -FormKeys $deadFlora
$pruned += Remove-YamlListEntries -Path (Get-RecordFile 'FormLists' 'TVR_Diviner_FormList_Mark_Gold_UNUSED_ATM') -FormKeys $deadFlora
$pruned += Remove-YamlListEntries -Path (Get-RecordFile 'FormLists' 'TVR_Elemental_FormList_ControlFlames_FireSources') -FormKeys $deadFire
$pruned += Remove-YamlListEntries -Path (Get-RecordFile 'Races' 'TVR_Verdant_Race_ForceOfNature') -FormKeys $deadPresets
$pruned += Remove-YamlListEntries -Path (Get-RecordFile 'FormLists' 'TVR_Ancestors_FormList_Conversion_VoiceTypes') -FormKeys @('01B560:Skyrim.esm')
Write-Host "  7. dead list entries pruned: $pruned"

# --- prove the dead keys are gone ---------------------------------------------------------------
$gone = @('09E0C9:Skyrim.esm','07A91B:Skyrim.esm','086EEE:Skyrim.esm','02E893:Skyrim.esm',
          '02E894:Skyrim.esm','10E2DD:Skyrim.esm','10E2DE:Skyrim.esm','0AB87F:Skyrim.esm',
          '0B2DD8:Skyrim.esm','01B560:Skyrim.esm') + $deadFlora + $deadFire + $deadPresets
$left = @()
foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
    $text = Read-YamlText $file.FullName
    foreach ($fk in $gone) {
        if ($text.Contains($fk)) { $left += ("{0} -> {1}" -f $file.Name, $fk) }
    }
}
if ($left.Count -gt 0) {
    $left | ForEach-Object { Write-Host "    remaining: $_" }
    throw "$($left.Count) dead reference(s) survived 08."
}
Write-Host "08 - done, all targeted dead keys verified gone"
