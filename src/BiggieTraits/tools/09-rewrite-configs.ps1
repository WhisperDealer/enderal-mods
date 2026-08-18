# 09 - Rewrite the KID / SPID / FLM distribution files and the MCM config for Enderal.
#
# Every EditorID named in the stock inis was resolved against reference/base/ on 2026-08-05. What
# survives here is only what actually exists in Enderal; everything else was Creation Club content,
# a Skyrim-only mod integration (Wintersun, Triumvirate, Lost Grimoire, Bruma, Vigilant...), or a
# trait this conversion cut.
#
# Two results worth noting:
#
#   * The FLM file becomes EMPTY. Every one of its 17 lines was dead - the alcoholic-drinks lists
#     are for Skyrim worldspace mods, and the rest belonged to Disbeliever, Autodidact, Giantkin's
#     CC exclusion and the CC fishing gear. So FormList Manipulator is NOT a dependency of the
#     Enderal build at all, and the file is deleted rather than shipped empty.
#
#   * The Druid trait's Apocalypse integration is kept, repointed. The stock ini names
#     WB_R025_LeechSeed_Effect, which is an older Apocalypse EditorID; this repo's Enderal
#     conversion of Apocalypse calls it WB_Res_Poison2_Effect_LeechSeed.
#
# SPID targets verified live: MudcrabRace is used by 5 Enderal NPCs (_03E_Crab, the kingscrabs),
# SprigganRace by 7 and SprigganMatronRace by 1. SprigganEarthMotherRace and DLC2SprigganBurntRace
# do not exist in Enderal and are dropped.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "09 - rewriting distribution and MCM config"

$modRoot = Split-Path -Parent $PSScriptRoot

# --- KID -----------------------------------------------------------------------------------------
$kid = @'
; Biggie Traits - Enderal conversion.
; Only keywords and forms that exist in Enderal are distributed here; see tools/09-rewrite-configs.ps1.

; Old Fashioned trait
; ArmorMaterialForsworn and ArmorMaterialBearStormcloak do not exist in Enderal and are omitted.
Keyword = Traits_OldFashionWeapon|Weapon|WeapMaterialWood,WeapMaterialIron,WeapMaterialSteel,WeapMaterialImperial
Keyword = Traits_OldFashionArmor|Armor|ArmorMaterialHide,ArmorMaterialScaled,ArmorMaterialIron,ArmorMaterialLeather,ArmorMaterialSteel,ArmorMaterialSteelPlate,ArmorMaterialStormcloak,ArmorMaterialImperialLight,ArmorMaterialImperialHeavy,ArmorMaterialImperialStudded,ArmorMaterialIronBanded,ArmorMaterialStudded

; Lurker trait
; The Creation Club fish are gone; Enderal keeps FoodSalmon. The weight filter is unaffected.
Keyword = Traits_GollumFood|Potion|FoodSalmon
Keyword = Traits_GollumWeaponHeavy|Weapon|NONE|W(10/1000)

; Druid trait
; SummonFamiliar, MagicSummonFamiliar, ArmorFFSelf100 and ParalysisFFSelfArea are absent in Enderal.
Keyword = Traits_DruidicSpell|Magic Effect|ArmorFFSelf0,ArmorFFSelf25,ArmorFFSelf50,ArmorFFSelf75,ParalysisFFAimed,WaterbreathingFFSelf

; Druid trait & Apocalypse - Magic of Skyrim (this repo's Enderal conversion)
Keyword = Traits_DruidicSpell|Magic Effect|WB_Res_Poison2_Effect_LeechSeed

; Glutton trait
Keyword = Traits_GluttonFoodItem|Potion|VendorItemFood,VendorItemFoodRaw
'@

# --- SPID ----------------------------------------------------------------------------------------
$distr = @'
; Biggie Traits - Enderal conversion.

; Angler mudcrabs - Enderal's own crabs (_03E_Crab, _05E_/_08E_Kingscrab) sit on MudcrabRace
Faction = Traits_MudcrabFaction||MudcrabRace

; Druid spriggans - SprigganEarthMotherRace and DLC2SprigganBurntRace do not exist in Enderal
Faction = Traits_SpriggansFaction||SprigganRace,SprigganMatronRace
'@

$files = @{
    'Biggie Traits_KID.ini'   = $kid
    'Biggie Traits_DISTR.ini' = $distr
}
foreach ($name in $files.Keys) {
    $path = Join-Path $modRoot $name
    Write-YamlText -Path $path -Text (($files[$name] -split "`r?`n") -join "`r`n")
    Write-Host ("  wrote {0}" -f $name)
}

# FLM has nothing left to do in Enderal.
$flm = Join-Path $modRoot 'Biggie Traits_FLM.ini'
if (Test-Path $flm) {
    Remove-Item -Force $flm
    Write-Host "  removed Biggie Traits_FLM.ini - every line was dead, so FLM is not a dependency"
} else {
    Write-Host "  Biggie Traits_FLM.ini already absent"
}

# --- MCM -----------------------------------------------------------------------------------------
# Drop the Homeowner and Autodidact pages; both traits are cut. The Papyrus script keeps its
# now-unreachable branches so the shipped .psc and .pex stay in sync - CI cannot compile Papyrus,
# and a stale .pex is the failure mode CLAUDE.md warns about.
#
# The `$schema` key is also REMOVED. It is an editor hint with no runtime meaning, but MCM Helper
# **1.3.0** — the version installed in `thepath` — rejects the whole config on an unknown root key:
#
#     Json/IHandler.inl(50): [warning] Invalid key: $schema
#     ConfigStore.cpp(114): [warning] Failed to parse config for Biggie Traits
#
# read out of MCMHelper.log after the first real launch, 2026-08-05. That is the entire cause of the
# in-game "Invalid config: $schema" error; MCM Helper's own bundled SkyUI config carries no `$schema`
# either. Updating MCM Helper would fix it too, but dropping one editor-only key is the smaller
# change and costs nothing. Note this does NOT affect the settings values: those come from
# settings.ini through a separate store, which the same log shows loading fine.
$cfgPath = Join-Path $modRoot 'MCM/Config/Biggie Traits/config.json'
if (Test-Path $cfgPath) {
    $json = Get-Content -Path $cfgPath -Raw | ConvertFrom-Json
    if ($json.PSObject.Properties.Name -contains '$schema') {
        $json.PSObject.Properties.Remove('$schema')
        Write-Host "  MCM config.json: removed the `$schema key (MCM Helper 1.3 rejects it)"
    }
    # `minMcmVersion: 13` is the next gate behind $schema:
    #
    #     Json/IHandler.inl(50): [warning] Config requires MCMHelper plugin version: 13
    #     ConfigStore.cpp(114): [warning] Failed to parse config for Biggie Traits
    #
    # MCM Helper refuses the config outright on that number, without ever looking at the content.
    # It is safe to drop here because the TRIMMED config uses nothing 1.3.0 lacks - checked against
    # the installed DLL's own strings: slider, toggle, input, header, valueOptions, sourceType,
    # ModSettingInt/Float/String and cursorFillMode are all present in it. The stock config declared
    # 13 for the Homeowner and Autodidact pages this conversion removed. MCM Helper's own bundled
    # SkyUI config omits the key entirely, so absent is a supported shape.
    if ($json.PSObject.Properties.Name -contains 'minMcmVersion') {
        $json.PSObject.Properties.Remove('minMcmVersion')
        Write-Host "  MCM config.json: removed minMcmVersion (nothing left in the config needs v13)"
    }
    $dropIds = @('fHomeownerPriceMult:Main', 'iAutodidactSpell:Main', 'iAutodidactCount:Main')
    $dropHeaders = @('$BIGTRAIT_HOMEOWNERHEADER', '$BIGTRAIT_ADH')
    $kept = @()
    foreach ($item in $json.content) {
        $id = if ($item.PSObject.Properties.Name -contains 'id') { $item.id } else { $null }
        $tx = if ($item.PSObject.Properties.Name -contains 'text') { $item.text } else { $null }
        if ($id -and $dropIds -contains $id) { continue }
        if ($item.type -eq 'header' -and $tx -and $dropHeaders -contains $tx) { continue }
        $kept += $item
    }
    $removed = $json.content.Count - $kept.Count
    $json.content = $kept
    $out = $json | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($cfgPath, $out, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ("  MCM config.json: removed {0} entry/entries, {1} remain" -f $removed, $kept.Count)
}

$iniPath = Join-Path $modRoot 'MCM/Config/Biggie Traits/settings.ini'
if (Test-Path $iniPath) {
    $lines = Get-YamlLines $iniPath
    $keep = @($lines | Where-Object { $_ -notmatch '^\s*(fHomeownerPriceMult|iAutodidactSpell|iAutodidactCount)\s*=' })
    $dropped = $lines.Count - $keep.Count
    Set-YamlLines -Path $iniPath -Lines $keep
    Write-Host ("  MCM settings.ini: removed {0} setting(s)" -f $dropped)
}

Write-Host "09 - done"
