# 04 - Resolve the last DLC references: the named fields inside Triumvirate's own records.
#
# WD-9 verdict 7, third shape - the part that is a content decision rather than a strip, which is
# why WD-8 deliberately left it alone. Each reference gets a substitute from Enderal's own tree, or
# is removed where absence is the archetype Enderal itself uses. Nothing is nulled: CLAUDE.md
# records that a null FormKey is untested here and was reverted once already on the Apocalypse
# recipes, whereas an absent optional field is measured and common.
#
# Every substitute below was read out of reference/base/Skyrim, and every removal is backed by a
# count of how often Enderal omits that field.
#
# SUBSTITUTIONS
#   FootstepSound  NPCDogDeathHoundFootWalkFootstepSet -> NPCDogFootWalkFootstepSet   04E86E
#   Voice/Class    the Temple Grim is a death hound    -> CrDogVoice 01F180, EncClassAnimalPredator
#                                                          0131E6 (the class Enderal's own
#                                                          _05E_SummonableGhostlyWolf_Player uses)
#   Voice          the Ravagor is a demon              -> CrDremoraVoice 01F1CE
#   Voice          the Hound of Hircine is a hound     -> CrWolfVoice 01F6A7
#   Raven rig      ChaurusFlyer_* -> Enderal's ground chaurus records, ChaurusDefault_MT 064113 and
#                  ChaurusBodyPartData 059060. The race is genuinely chaurus-rigged (its skeleton is
#                  Actors\Chaurus\Character Assets\skeleton.nif), so these are the closest real
#                  archetype; Enderal has no flying-creature rig at all. FLAG FOR IN-GAME TEST.
#   CombatStyle    DLC1csChaurusHunter                 -> csChaurus 05A832, same lineage
#   Leviathan      DLC2HulkingDraugrRace on the Armor, MorphRace and ArmorRace -> the creature's OWN
#                  race, TVR_Demon_Race_ConjureLeviathan 247842. That is already the ArmorAddon's
#                  primary Race, so this makes the four agree instead of routing through a Bethesda
#                  race. (Its FEMALE world model still points at a Dragonborn mesh Enderal does not
#                  ship - a file path, not a FormID, so it does not block the master drop. The male
#                  model is Triumvirate's own and summons use it.)
#   Shaders        DLC1SunFireFXShader and DLC1SunDamageImpactSmoke -> FireFXShader 01B212;
#                  DLC1DrainVitalCasterFXS -> AbsorbHealthFXS 0ABEFF;
#                  DLC1SoulCairnGhostFXShader -> GhostFXShader 03B6CB
#   OutputModel    DLC sound output models -> Enderal's nearest radius: Rad04000_verb -> Rad04000
#                  0E363A, Rad08000 -> Rad07000 08F3E4, Rad01400_verb -> Rad01400 0F11FD
#   MenuDisplay    DLC2MAGInvAsh -> 109AC2, the icon Triumvirate's own SandSpirit uses. The
#                  Worldshatter family picks its icon by terrain material and ash is nearest sand.
#
# REMOVALS (field absent, not nulled)
#   ImageSpaceModifier   2 refs. 97 of Enderal's 1008 magic effects carry none.
#   Explosion            1 ref.  105 of Enderal's 162 projectiles carry none - absence is the norm.
#   - Material: MaterialAsh   3 refs. An ImpactDataSet is a material->impact lookup; with no ash
#                        material in Enderal the entry is unreachable, and substituting would
#                        duplicate a mapping the set already has for another material.
#   HasKeyword conditions on ActorTypeDLC1Boss (3) and DLC2AshSpawnKeyword (2). These carry no
#                        ComparisonValue, and Spriggit omits defaults, so each reads
#                        "HasKeyword(X) == 0" - an EXCLUSION. With X absent the test is always true
#                        and the exclusion is already inert, so removing it preserves behaviour.
#                        That was checked, not assumed; an "== 1" condition would have been the
#                        opposite and removing it would have ENABLED a dead effect.
#   Script object properties naming DLC merchant chests (5, on TVR_PopulateSpellBooks2_Quest) and
#                        DLC2AshShellDmgPerk (1). A property pointing at a dead FormID already
#                        resolves to None, so removal changes nothing at runtime and is what lets
#                        the masters go. Neutralising that quest properly is WD-16.
#
# NOTE FOR WD-17: TVR_Shaman_Violence_Effect_Worldshatter_Hazard_AshShell runs a script called
# DLC2AshShellScript - Bethesda's Dragonborn script, not one of Triumvirate's. Whether the BSA
# ships a copy is unknown until an extractor is configured.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "04 - substituting and removing DLC fields"

$root = Get-EspRoot

function Get-Record {
    param([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$EditorID)
    $hit = Get-ChildItem -LiteralPath (Join-Path $root $Group) -Filter "$EditorID - *.yaml" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $hit) { throw "record not found: $Group\$EditorID" }
    return $hit.FullName
}

# Replace "<Field>: <old>" with "<Field>: <new>" on every matching line.
function Set-Field {
    param([string]$Path, [string]$Field, [string]$From, [string]$To)
    $lines = Get-YamlLines $Path
    $n = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('^(\s*)' + [regex]::Escape($Field) + ': ' + [regex]::Escape($From) + '\s*$')) {
            $lines[$i] = "{0}{1}: {2}" -f $Matches[1], $Field, $To
            $n++
        }
    }
    if ($n -gt 0) { Set-YamlLines -Path $Path -Lines $lines }
    return $n
}

# Delete every "<Field>: <value>" line outright.
function Remove-Field {
    param([string]$Path, [string]$Field, [string]$Value)
    $lines = Get-YamlLines $Path
    $keep = @(); $n = 0
    foreach ($line in $lines) {
        if ($line -match ('^\s*' + [regex]::Escape($Field) + ': ' + [regex]::Escape($Value) + '\s*$')) { $n++ } else { $keep += $line }
    }
    if ($n -gt 0) { Set-YamlLines -Path $Path -Lines (Remove-EmptyCollectionKeys -Lines $keep) }
    return $n
}

# Delete the whole YAML sequence item that contains a line matching $Inner.
#
# A sequence item starts at a "- " line and runs until the next line whose indentation is <= that
# line's AND which is not a deeper continuation. This one helper covers all three shapes that need
# it - an ImpactDataSet "- Material:" pair, a "- MutagenObjectType: ConditionFloat" block, and a
# "- MutagenObjectType: ScriptObjectProperty" block - because they are all sequence items.
function Remove-SequenceItemContaining {
    param([string]$Path, [string]$Inner)
    $lines = Get-YamlLines $Path
    $removedTotal = 0
    while ($true) {
        $hit = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $Inner) { $hit = $i; break } }
        if ($hit -lt 0) { break }

        # Walk back to the "- " line that owns this item.
        $start = -1
        for ($i = $hit; $i -ge 0; $i--) { if ($lines[$i] -match '^\s*-\s') { $start = $i; break } }
        if ($start -lt 0) { throw "no owning sequence item for match at line $($hit + 1) of $Path" }

        $indent = ($lines[$start] -replace '^(\s*).*$', '$1').Length
        $end = $lines.Count
        for ($i = $start + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq '') { continue }
            $ind = ($lines[$i] -replace '^(\s*).*$', '$1').Length
            if ($ind -le $indent) { $end = $i; break }
        }
        if ($hit -ge $end) { throw "sequence-item bounds did not contain the match in $Path" }

        $keep = @()
        if ($start -gt 0) { $keep += $lines[0..($start - 1)] }
        if ($end -lt $lines.Count) { $keep += $lines[$end..($lines.Count - 1)] }
        $lines = $keep
        $removedTotal += ($end - $start)
    }
    if ($removedTotal -gt 0) { Set-YamlLines -Path $Path -Lines (Remove-EmptyCollectionKeys -Lines $lines) }
    return $removedTotal
}

$changes = 0

# ---------------------------------------------------------------- substitutions
$subs = @(
    @{ G='ArmorAddons';   E='TVR_Demon_Addon_ConjureTempleGrim';                    F='FootstepSound';           From='0115CD:Dawnguard.esm';  To='04E86E:Skyrim.esm' },
    @{ G='Armors';        E='TVR_Demon_Armor_ConjureLeviathan';                     F='Race';                    From='02A6FD:Dragonborn.esm'; To='247842:Triumvirate - Mage Archetypes.esp' },
    @{ G='Races';         E='TVR_Demon_Race_ConjureLeviathan';                      F='MorphRace';               From='02A6FD:Dragonborn.esm'; To='247842:Triumvirate - Mage Archetypes.esp' },
    @{ G='Races';         E='TVR_Demon_Race_ConjureLeviathan';                      F='ArmorRace';               From='02A6FD:Dragonborn.esm'; To='247842:Triumvirate - Mage Archetypes.esp' },

    @{ G='MagicEffects';  E='TVR_Cleric_Auras_Effect_Aura_1_CloakProc';             F='HitShader';               From='00A3BB:Dawnguard.esm';  To='01B212:Skyrim.esm' },
    @{ G='MagicEffects';  E='TVR_Cleric_Auras_Effect_Aura_1_CloakProc_VsUndead';    F='HitShader';               From='00A3BB:Dawnguard.esm';  To='01B212:Skyrim.esm' },
    @{ G='MagicEffects';  E='TVR_Cleric_Auras_Effect_Aura_3_Damage';                F='HitShader';               From='00A3BB:Dawnguard.esm';  To='01B212:Skyrim.esm' },
    @{ G='MagicEffects';  E='TVR_Cleric_Auras_Effect_Aura_3_Damage_2H';             F='HitShader';               From='00A3BB:Dawnguard.esm';  To='01B212:Skyrim.esm' },
    @{ G='MagicEffects';  E='TVR_Cleric_Auras_Effect_Aura_3_Damage_VsUndead';       F='HitShader';               From='00A3BB:Dawnguard.esm';  To='01B212:Skyrim.esm' },
    @{ G='MagicEffects';  E='TVR_Cleric_Auras_Effect_Aura_1_CloakProc';             F='Object';                  From='019C9E:Dawnguard.esm';  To='01B212:Skyrim.esm' },
    @{ G='MagicEffects';  E='TVR_Cleric_Auras_Effect_Aura_1_Proc';                  F='Object';                  From='019C9E:Dawnguard.esm';  To='01B212:Skyrim.esm' },

    @{ G='Npcs';          E='TVR_Demon_Actor_ConjureRavagor';                       F='Voice';                   From='00F8AE:Dawnguard.esm';  To='01F1CE:Skyrim.esm' },
    @{ G='Npcs';          E='TVR_Demon_Actor_ConjureRavagor_Potent';                F='Voice';                   From='00F8AE:Dawnguard.esm';  To='01F1CE:Skyrim.esm' },
    @{ G='Npcs';          E='TVR_Primal_Actor_CallHoundOfHircine';                  F='Voice';                   From='00F8AE:Dawnguard.esm';  To='01F6A7:Skyrim.esm' },
    @{ G='Npcs';          E='TVR_Demon_Actor_ConjureTempleGrim';                    F='Voice';                   From='011681:Dawnguard.esm';  To='01F180:Skyrim.esm' },
    @{ G='Npcs';          E='TVR_Demon_Actor_ConjureTempleGrim_Potent';             F='Voice';                   From='011681:Dawnguard.esm';  To='01F180:Skyrim.esm' },
    @{ G='Npcs';          E='TVR_Demon_Actor_ConjureTempleGrim';                    F='Class';                   From='0145DC:Dawnguard.esm';  To='0131E6:Skyrim.esm' },
    @{ G='Npcs';          E='TVR_Demon_Actor_ConjureTempleGrim_Potent';             F='Class';                   From='0145DC:Dawnguard.esm';  To='0131E6:Skyrim.esm' },
    @{ G='Npcs';          E='TVR_Primal_Actor_CallRaven';                           F='CombatStyle';             From='005AA2:Dawnguard.esm';  To='05A832:Skyrim.esm' },

    @{ G='Races';         E='TVR_Demon_Race_ConjureTempleGrim';                     F='Male';                    From='011681:Dawnguard.esm';  To='01F180:Skyrim.esm' },
    @{ G='Races';         E='TVR_Demon_Race_ConjureRavagor';                        F='Male';                    From='024C3E:Dragonborn.esm'; To='01F1CE:Skyrim.esm' },
    @{ G='Races';         E='TVR_Primal_Race_CallHoundOfHircine';                   F='Male';                    From='024C3E:Dragonborn.esm'; To='01F6A7:Skyrim.esm' },
    @{ G='Races';         E='TVR_Primal_Race_CallRaven';                            F='BodyPartData';            From='005205:Dawnguard.esm';  To='059060:Skyrim.esm' },
    @{ G='Races';         E='TVR_Primal_Race_CallRaven';                            F='BaseMovementDefaultWalk'; From='0051FC:Dawnguard.esm';  To='064113:Skyrim.esm' },
    @{ G='Races';         E='TVR_Primal_Race_CallRaven';                            F='BaseMovementDefaultRun';  From='0051FC:Dawnguard.esm';  To='064113:Skyrim.esm' },

    @{ G='SoundDescriptors'; E='TVR_Geist_Descriptor_Hazard';                       F='OutputModel';             From='01333C:Dawnguard.esm';  To='0E363A:Skyrim.esm' },
    @{ G='SoundDescriptors'; E='TVR_Geist_Descriptor_Projectile';                   F='OutputModel';             From='01333C:Dawnguard.esm';  To='0E363A:Skyrim.esm' },
    @{ G='SoundDescriptors'; E='TVR_Senua_Descriptor_CrowCall';                     F='OutputModel';             From='01333C:Dawnguard.esm';  To='0E363A:Skyrim.esm' },
    @{ G='SoundDescriptors'; E='TVR_Violence_Descriptor_Release_Roar_Big';          F='OutputModel';             From='01333C:Dawnguard.esm';  To='0E363A:Skyrim.esm' },
    @{ G='SoundDescriptors'; E='TVR_Senua_Descriptor_FXS';                          F='OutputModel';             From='014BCB:Dawnguard.esm';  To='08F3E4:Skyrim.esm' },
    @{ G='SoundDescriptors'; E='TVR_Violence_Descriptor_Worldshatter_Hazard';       F='OutputModel';             From='01686B:Dawnguard.esm';  To='0F11FD:Skyrim.esm' },

    @{ G='VisualEffects'; E='TVR_Demon_VFX_ConjureGremlin_Empowered';               F='Shader';                  From='002947:Dawnguard.esm';  To='0ABEFF:Skyrim.esm' },
    @{ G='VisualEffects'; E='TVR_Demon_VFX_ConjureOathbreaker_Empowered';           F='Shader';                  From='019AB3:Dawnguard.esm';  To='03B6CB:Skyrim.esm' },

    @{ G='MagicEffects';  E='TVR_Shaman_Violence_Effect_Worldshatter_Hazard_AshShell'; F='MenuDisplayObject';    From='027BF9:Dragonborn.esm'; To='109AC2:Skyrim.esm' },
    @{ G='Spells';        E='TVR_Shaman_Spell_Worldshatter_Hazard_AshSpirit';       F='MenuDisplayObject';       From='027BF9:Dragonborn.esm'; To='109AC2:Skyrim.esm' }
)

Write-Host "  substitutions:"
foreach ($s in $subs) {
    $path = Get-Record -Group $s.G -EditorID $s.E
    $n = Set-Field -Path $path -Field $s.F -From $s.From -To $s.To
    if ($n -gt 0) {
        Write-Host ("    {0,-56} {1,-24} {2} -> {3}" -f $s.E, $s.F, $s.From, $s.To)
        $changes += $n
    }
}

# ---------------------------------------------------------------- field removals
$removals = @(
    @{ G='MagicEffects'; E='TVR_Cleric_Auras_Effect_Aura_1_Proc';      F='ImageSpaceModifier'; V='00AE9D:Dawnguard.esm' },
    @{ G='MagicEffects'; E='TVR_Shadow_Diviner_Effect_RevealSecrets';  F='ImageSpaceModifier'; V='01A3F8:Dawnguard.esm' },
    @{ G='Projectiles';  E='TVR_Violence_Projectile_Fissure';          F='Explosion';          V='00AEB4:Dawnguard.esm' }
)

Write-Host "  field removals:"
foreach ($r in $removals) {
    $path = Get-Record -Group $r.G -EditorID $r.E
    $n = Remove-Field -Path $path -Field $r.F -Value $r.V
    if ($n -gt 0) {
        Write-Host ("    {0,-56} -{1}" -f $r.E, $r.F)
        $changes += $n
    }
}

# ---------------------------------------------------------------- sequence-item removals
$items = @(
    @{ G='ImpactDataSets'; E='TVR_Geist_ImpactSet_SpiritFire';                            P='^\s*-?\s*Material: 018C9C:Dragonborn\.esm\s*$'; L='MaterialAsh impact entry' },
    @{ G='ImpactDataSets'; E='TVR_Verdant_ImpactSet_ImpenetrableGrove';                   P='^\s*-?\s*Material: 018C9C:Dragonborn\.esm\s*$'; L='MaterialAsh impact entry' },
    @{ G='ImpactDataSets'; E='TVR_Violence_ImpactSet_Fissure';                            P='^\s*-?\s*Material: 018C9C:Dragonborn\.esm\s*$'; L='MaterialAsh impact entry' },

    @{ G='MagicEffects';   E='TVR_Shadow_Possess_Effect_TraitorousShadow';                P='^\s*Keyword: 01269F:Dawnguard\.esm\s*$';        L='ActorTypeDLC1Boss exclusion' },
    @{ G='MagicEffects';   E='TVR_Shadow_Possess_Effect_Possession_Turn_Rally';           P='^\s*Keyword: 01269F:Dawnguard\.esm\s*$';        L='ActorTypeDLC1Boss exclusion' },
    @{ G='MagicEffects';   E='TVR_Shaman_Violence_Effect_Bloodlust_CloakProc_Rally';      P='^\s*Keyword: 01269F:Dawnguard\.esm\s*$';        L='ActorTypeDLC1Boss exclusion' },
    @{ G='MagicEffects';   E='TVR_Shaman_Violence_Effect_Worldshatter_Hazard_AshShell';   P='^\s*Keyword: 028FDE:Dragonborn\.esm\s*$';       L='DLC2AshSpawnKeyword exclusion' },
    @{ G='MagicEffects';   E='TVR_Shaman_Violence_Effect_Worldshatter_Hazard_IceForm';    P='^\s*Keyword: 028FDE:Dragonborn\.esm\s*$';       L='DLC2AshSpawnKeyword exclusion' },

    @{ G='MagicEffects';   E='TVR_Shaman_Violence_Effect_Worldshatter_Hazard_AshShell';   P='^\s*Object: 0177B4:Dragonborn\.esm\s*$';        L='DLC2AshShellDmgPerk script property' },
    @{ G='Quests';         E='TVR_PopulateSpellBooks2_Quest';                             P='^\s*Object: [0-9A-Fa-f]{6}:(Dawnguard|Dragonborn)\.esm\s*$'; L='DLC merchant-chest script properties' }
)

Write-Host "  sequence-item removals:"
foreach ($it in $items) {
    $path = Get-Record -Group $it.G -EditorID $it.E
    $n = Remove-SequenceItemContaining -Path $path -Inner $it.P
    if ($n -gt 0) {
        Write-Host ("    {0,-56} -{1,-3} lines  ({2})" -f $it.E, $n, $it.L)
        $changes += $n
    }
}

if ($changes -eq 0) {
    Write-Host "  nothing to do - already applied"
}

# ---------------------------------------------------------------- prove it
$left = @()
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.yaml') {
    foreach ($line in (Get-YamlLines $file.FullName)) {
        if ($line -match '[0-9A-Fa-f]{6}:(Dawnguard|HearthFires|Dragonborn)\.esm') {
            $left += ("{0}: {1}" -f $file.Name, $line.Trim())
        }
    }
}
if ($left.Count -gt 0) {
    $left | Select-Object -First 20 | ForEach-Object { Write-Host "    remaining: $_" }
    throw "$($left.Count) DLC reference(s) still present - 05 cannot drop the masters."
}

Write-Host "04 - done; no DLC FormID references remain anywhere in the tree"
