# 15 - Rebuild vendor distribution onto Enderal merchants (WD-16).
#
# Triumvirate's original distribution is a StartGameEnabled quest whose script makes 76 runtime
# calls: AddToFaction on 10 named Skyrim NPCs (making priests barterable through satellite
# chests), AddItem of UseAll tome bundles into 14 vanilla merchant chests, and AddForm of 21
# staves into vanilla staff loot lists. Not one receiver exists in Enderal.
#
# The rebuild is RECORD-LEVEL and deterministic - the CLAUDE.md "place it directly" doctrine:
# override chosen Enderal merchants' chest CONT records and append the mod's own
# TVR_Tomes_Litem_<Arch>_<School> UseAll bundles as ordinary Items entries. A UseAll bundle
# yields EVERY tome behind it on every restock, so each archetype vendor deterministically
# stocks that archetype's full 15 tomes, forever, with no scripting.
#
# Vendor selection (documented in arch-docs/Triumvirate/vendor-mapping.md): every chest was
# checked against three claim sets and is FREE of all of them -
#   - EGO's 319 container overrides (arch-docs/EGO/conflict-index.md),
#   - Apocalypse's six chest overrides (src/Apocalypse/ApocalypseESP/Containers/),
#   - KataPUMB's three staff chests (CLAUDE.md - Tarhutie spared).
# Chest overrides are copied VERBATIM from the WINNING reference version (FS where FS overrides,
# guardrail 5) before our entries are appended.
#
# What dies: the 14 vanilla chest overrides, the 6 vanilla Services* faction overrides, the 8
# TVR satellite chests and the 9 TVR Services factions (37 records - after which the plugin
# overrides NOTHING of any master except the 10 new chest records). The populate quest keeps
# only the two live pieces of its script - starting the Conversion quest and the mod-ready
# message - via a stripped VMAD plus the loose replacement script in
# src/Triumvirate/Scripts/ (which beats the BSA's copy).
#
# Repricing: Enai's tome ladder is vanilla Skyrim's (~45/97/340/655/1370 by tier). Enderal's
# whole tome range is 20-350 [CLAUDE.md, verified], so the top three tiers rescale by per-tier
# ratio (preserving Enai's intra-tier ordering): Adept x0.43 -> ~145, Expert x0.35 -> ~230,
# Master x0.23 -> ~315. Novice/Apprentice (41-105) already sit inside Enderal's band and stay.
#
# Spriggit stays pinned at 0.40.0 - 0.41.0 silently corrupts COED leveled-list entries, and this
# is exactly leveled-list-heavy work. WD-16's byte-identical double build guards the same risk.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "15 - distribution rebuild (WD-16)"
$root = Get-EspRoot
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$refFS  = Join-Path $repo 'reference\base\EnderalFS\Containers'

# ------------------------------------------------------------------ the vendor mapping
# Src is always the FS reference tree: every chosen chest has an FS override, which is the
# winning version to copy (guardrail 5).
$vendors = @(
    @{ File = '_00E_Merchant_FlusshaimAdreyoContainer - 05BCD4_Skyrim.esm.yaml';                          Archetypes = @('Druid','Cleric');   Staves = $null }
    @{ File = '_00E_FS_Merchant_Wildmage_FrostcliffTavern - 01E904_Enderal - Forgotten Stories.esm.yaml'; Archetypes = @('Druid','Shaman');   Staves = 'Druid' }
    @{ File = '_00E_FS_Merchant_Wildmage_Duneville - 01E90A_Enderal - Forgotten Stories.esm.yaml';        Archetypes = @('Shaman','Druid');   Staves = 'Shaman' }
    @{ File = '_00E_Merchant_DunevilleSmithHunter - 02F2BF_Enderal - Forgotten Stories.esm.yaml';         Archetypes = @('Shaman');           Staves = $null }
    @{ File = '_00E_FS_Merchant_Wildmage_UndercityBarracks1 - 01E900_Enderal - Forgotten Stories.esm.yaml'; Archetypes = @('Warlock','Shadow'); Staves = $null }
    @{ File = '_00E_Merchant_Rhalata_SisterEnvyContainer - 01E893_Enderal - Forgotten Stories.esm.yaml';  Archetypes = @('Warlock','Shadow'); Staves = 'Warlock' }
    @{ File = '_00E_FS_UndercityBashHole_Merchant - 02F2F0_Enderal - Forgotten Stories.esm.yaml';         Archetypes = @('Warlock');          Staves = $null }
    @{ File = '_00E_Merchant_UCHehler02 - 030309_Enderal - Forgotten Stories.esm.yaml';                   Archetypes = @('Shadow');           Staves = 'Shadow' }
    @{ File = '_00E_Merchant_CCMarius - 046AEF_Skyrim.esm.yaml';                                          Archetypes = @('Cleric','Shadow');  Staves = 'Cleric' }
    @{ File = '_00E_Merchant_CCBlacksmithArkGuard - 02EFBD_Enderal - Forgotten Stories.esm.yaml';         Archetypes = @('Cleric');           Staves = $null }
)

# ------------------------------------------------------------------ record lookups
function Find-OwnRecords {
    param([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$Pattern)
    $dir = Join-Path $root $Group
    $hits = @{}
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.yaml') {
        $eid = ($f.Name -split ' - ')[0]
        if ($eid -match $Pattern) {
            $fk = [regex]::Match((Read-YamlText $f.FullName), '(?m)^FormKey: (.+?)(?=\r?$)').Groups[1].Value
            $hits[$eid] = $fk
        }
    }
    return $hits
}

# the 15 archetype/school parent bundles (each UseAll -> its 5 tier bundles -> the 15 tomes)
$bundles = Find-OwnRecords -Group 'LeveledItems' -Pattern '^TVR_Tomes_Litem_(Druid|Shadow|Warlock|Cleric|Shaman)_(Alteration|Conjuration|Destruction|Illusion|Restoration)$'
if ($bundles.Count -ne 15) { throw "expected 15 archetype/school tome bundles, found $($bundles.Count)" }
$staves = Find-OwnRecords -Group 'Weapons' -Pattern '^TVR_(Druid|Shadow|Warlock|Cleric|Shaman)_[ACDIR]\d{3}_Staff_'
if ($staves.Count -ne 26) { throw "expected 26 staves, found $($staves.Count)" }

function Get-ArchBundles { param([string]$Arch)
    return ,@($bundles.Keys | Where-Object { $_ -like "TVR_Tomes_Litem_${Arch}_*" } | Sort-Object | ForEach-Object { $bundles[$_] })
}
function Get-ArchStaves { param([string]$Arch)
    return ,@($staves.Keys | Where-Object { $_ -like "TVR_${Arch}_*" } | Sort-Object | ForEach-Object { $staves[$_] })
}

# ------------------------------------------------------------------ 1. delete the dead machinery
$deleted = 0
$deadEids = @()
$deadEids += Get-ChildItem (Join-Path $root 'Containers') -Filter '*.yaml' | Where-Object {
    $_.Name -match '^(Merchant|TGFence)' -or $_.Name -match '^TVR_(Cleric|Druid|Shaman)_Container_Merchant' } | ForEach-Object { $_.FullName }
$deadEids += Get-ChildItem (Join-Path $root 'Factions') -Filter '*.yaml' | Where-Object {
    $_.Name -match '^Services' -or $_.Name -match '^TVR_\w+_Faction_Services' } | ForEach-Object { $_.FullName }
$deadKeys = @()
foreach ($p in $deadEids) {
    $deadKeys += [regex]::Match((Read-YamlText $p), '(?m)^FormKey: (.+?)(?=\r?$)').Groups[1].Value
    Remove-Item -LiteralPath $p -Force
    $deleted++
}
if ($deleted -gt 0 -and $deleted -ne 37) { throw "expected to delete 37 records, deleted $deleted" }
Write-Host "  1. dead machinery deleted: $deleted records (14 vanilla chests, 6 vanilla factions, 8 TVR chests, 9 TVR factions)"

# 1b. The satellite chests were PLACED in the mod's own utility cell (TVR_Cell "Marker Storage
# Unit") - one placed ref per chest, plus one whose base is the vanilla Dravynea chest. Those
# refs must go with their bases. The first four refs in the cell (the linked marker pair, the
# hazard marker and TVR_Origin) are the holding-cell machinery for Hurl/Exile and stay.
$cellPath = Join-Path $root 'Cells\9\5\TVR_Cell - 2E99EB_Triumvirate - Mage Archetypes.esp\RecordData.yaml'
$chestBaseHexes = @('43D32C:Triumvirate - Mage Archetypes.esp', '43D32F:Triumvirate - Mage Archetypes.esp',
    '442432:Triumvirate - Mage Archetypes.esp', '442436:Triumvirate - Mage Archetypes.esp',
    '442439:Triumvirate - Mage Archetypes.esp', '44243C:Triumvirate - Mage Archetypes.esp',
    '442442:Triumvirate - Mage Archetypes.esp', '442446:Triumvirate - Mage Archetypes.esp',
    '0A3F02:Skyrim.esm')
# NOT Remove-SequenceItemContaining: a placed ref carries nested '- 0x400' flag items between its
# own '- MutagenObjectType' line and the 'Base:' line, and that helper walks back only to the
# NEAREST '- ' line - it would (and on one run did) eat the flags instead of the ref. Walk the
# top-level items explicitly.
$lines = Get-YamlLines $cellPath
$keep = New-Object System.Collections.Generic.List[string]
$refPruned = 0
$i = 0
while ($i -lt $lines.Count) {
    if ($lines[$i] -match '^- MutagenObjectType: Placed') {
        $end = $i + 1
        while ($end -lt $lines.Count -and $lines[$end] -match '^\s') { $end++ }
        $block = $lines[$i..($end - 1)] -join "`n"
        $isChest = $false
        foreach ($b in $chestBaseHexes) { if ($block.Contains("Base: $b")) { $isChest = $true; break } }
        if ($isChest) { $refPruned += ($end - $i) } else { $lines[$i..($end - 1)] | ForEach-Object { $keep.Add($_) } }
        $i = $end
    } else {
        $keep.Add($lines[$i]); $i++
    }
}
if ($refPruned -gt 0) { Set-YamlLines -Path $cellPath -Lines $keep.ToArray() }
$cellText = Read-YamlText $cellPath
foreach ($must in 'TVR_Origin', '2E99F7', '2E99F8', '3C38BC') {
    if ($cellText -notmatch $must) { throw "TVR_Cell lost holding-cell machinery '$must' - the prune took too much" }
}
if ($cellText -match '43D32C|0A3F02') { throw "TVR_Cell still holds a chest ref" }
Write-Host "  1b. chest placed-refs pruned from TVR_Cell: $refPruned lines (holding-cell markers kept)"

# ------------------------------------------------------------------ 2. strip the populate quest
$quest = Get-ChildItem (Join-Path $root 'Quests') -Filter 'TVR_PopulateSpellBooks2_Quest - *.yaml' | Select-Object -First 1
$qtext = Read-YamlText $quest.FullName
if (($qtext -split "`r?`n" | Where-Object { $_ -match '^\s+Name: ' }).Count -gt 4) {
    $lines = $qtext -split "`r?`n"
    # locate the VMAD block and the three property blocks we keep
    $vmadStart = [array]::IndexOf($lines, ($lines | Where-Object { $_ -match '^VirtualMachineAdapter:' } | Select-Object -First 1))
    $vmadEnd = $lines.Count
    for ($i = $vmadStart + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^[A-Za-z]') { $vmadEnd = $i; break }
    }
    $keepProps = @()
    foreach ($name in 'TVR_Conversion_Quest', 'TVR_Any_Message_ModReady', 'TVR_UpdateRate') {
        $idx = -1
        for ($i = $vmadStart; $i -lt $vmadEnd; $i++) {
            if ($lines[$i] -match ('^      Name: ' + [regex]::Escape($name) + '\s*$')) { $idx = $i; break }
        }
        if ($idx -lt 0) { throw "populate quest property '$name' not found" }
        # the property item runs from its '- MutagenObjectType' line to the line before the next one
        $start = $idx - 1
        if ($lines[$start] -notmatch '^\s+- MutagenObjectType: Script\w+Property') { throw "unexpected property shape at '$name'" }
        $end = $idx + 1
        while ($end -lt $vmadEnd -and $lines[$end] -notmatch '^\s+- MutagenObjectType') { $end++ }
        $keepProps += $lines[$start..($end - 1)]
    }
    $newVmad = @('VirtualMachineAdapter:', '  Scripts:', '  - Name: TVR_PopulateSpellBooks_Script', '    Properties:') + $keepProps
    $keep = @()
    if ($vmadStart -gt 0) { $keep += $lines[0..($vmadStart - 1)] }
    $keep += $newVmad
    $keep += $lines[$vmadEnd..($lines.Count - 1)]
    Set-YamlLines -Path $quest.FullName -Lines $keep
    Write-Host ("  2. populate quest VMAD stripped: {0} -> {1} lines, 3 properties kept" -f $lines.Count, $keep.Count)
} else {
    Write-Host "  2. populate quest already stripped"
}
$qtext = Read-YamlText $quest.FullName
foreach ($must in 'TVR_Conversion_Quest', 'TVR_Any_Message_ModReady', 'TVR_UpdateRate', 'StartGameEnabled', 'RunOnce') {
    if ($qtext -notmatch [regex]::Escape($must)) { throw "populate quest lost '$must'" }
}
foreach ($mustNot in 'LItemStaff', 'MerchantChest', 'Faction_Services', 'JobMerchantFaction') {
    if ($qtext -match $mustNot) { throw "populate quest still carries '$mustNot'" }
}

# ------------------------------------------------------------------ 3. declare the FS master
$hdr = Join-Path $root 'RecordData.yaml'
$htext = Read-YamlText $hdr
if ($htext -notmatch 'Master: Enderal - Forgotten Stories\.esm') {
    $htext = $htext -replace '(- Master: Update\.esm\r?\n    FileSize: 0)', ('$1' + "`r`n" + '  - Master: Enderal - Forgotten Stories.esm' + "`r`n" + '    FileSize: 0')
    if ($htext -notmatch 'Master: Enderal - Forgotten Stories\.esm') { throw "failed to add FS master" }
    Write-YamlText -Path $hdr -Text $htext
    Write-Host "  3. Enderal - Forgotten Stories.esm declared as master (after Update.esm)"
} else {
    Write-Host "  3. FS master already declared"
}

# ------------------------------------------------------------------ 4. create the chest overrides
function Add-ItemsEntries {
    param([string]$Path, [string[]]$FormKeys)
    $lines = Get-YamlLines $Path
    $itemsIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^Items:\s*$') { $itemsIdx = $i; break } }
    if ($itemsIdx -lt 0) { throw "no Items: block in $Path" }
    $end = $lines.Count
    for ($i = $itemsIdx + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^[A-Za-z]') { $end = $i; break }
    }
    $insert = @()
    foreach ($fk in $FormKeys) {
        $insert += '- Item:'
        $insert += "    Item: $fk"
        $insert += '    Count: 1'
    }
    $keep = $lines[0..($end - 1)] + $insert + $(if ($end -lt $lines.Count) { $lines[$end..($lines.Count - 1)] } else { @() })
    Set-YamlLines -Path $Path -Lines $keep
    return $insert.Count / 3
}

$created = 0
foreach ($v in $vendors) {
    $srcPath = Join-Path $refFS $v.File
    if (-not (Test-Path -LiteralPath $srcPath)) { throw "reference chest not found: $($v.File)" }
    $dst = Join-Path (Join-Path $root 'Containers') $v.File
    $adds = @()
    foreach ($arch in $v.Archetypes) { $adds += Get-ArchBundles -Arch $arch }
    if ($v.Staves) { $adds += Get-ArchStaves -Arch $v.Staves }
    if (Test-Path -LiteralPath $dst) {
        $t = Read-YamlText $dst
        $missing = @($adds | Where-Object { $t -notmatch [regex]::Escape($_) })
        if ($missing.Count -gt 0) { throw "$($v.File) exists but lacks $($missing.Count) entries - delete it and re-run" }
        Write-Host ("  4. {0}: already present" -f (($v.File -split ' - ')[0]))
        continue
    }
    Copy-Item -LiteralPath $srcPath -Destination $dst
    $n = Add-ItemsEntries -Path $dst -FormKeys $adds
    $created++
    Write-Host ("  4. {0}: +{1} entries ({2} tome bundles{3})" -f (($v.File -split ' - ')[0]), $n, (3 * $v.Archetypes.Count), $(if ($v.Staves) { ", $($v.Staves) staves" } else { '' }))
}

# ------------------------------------------------------------------ 5. reprice the top tiers
# Idempotency: a scaled value always lands under the tier threshold, an unscaled one never does.
$tiers = @{ '050' = @{ Ratio = 0.43; Threshold = 250 }; '075' = @{ Ratio = 0.35; Threshold = 300 }; '100' = @{ Ratio = 0.23; Threshold = 500 } }
$repriced = 0
foreach ($f in Get-ChildItem (Join-Path $root 'Books') -Filter 'TVR_*.yaml') {
    $m = [regex]::Match($f.Name, '^TVR_\w+_[ACDIR](\d{3})_Book_')
    if (-not $m.Success -or -not $tiers.ContainsKey($m.Groups[1].Value)) { continue }
    $tier = $tiers[$m.Groups[1].Value]
    $t = Read-YamlText $f.FullName
    $vm = [regex]::Match($t, '(?m)^Value: (\d+)')
    if (-not $vm.Success) { throw "no Value in $($f.Name)" }
    $val = [int]$vm.Groups[1].Value
    if ($val -le $tier.Threshold) { continue }
    $newVal = [math]::Round($val * $tier.Ratio)
    Write-YamlText -Path $f.FullName -Text ($t -replace '(?m)^Value: \d+', "Value: $newVal")
    $repriced++
}
if ($repriced -gt 0 -and $repriced -ne 45) { throw "expected 45 repriced tomes, got $repriced" }
Write-Host "  5. tomes repriced onto Enderal's ladder: $repriced (Adept x0.43, Expert x0.35, Master x0.23)"

# ------------------------------------------------------------------ prove it
# a. nothing references the deleted 37 (static list so the check is real on re-runs too)
$deadKeys = @(
    '0ABD9E:Skyrim.esm','09E129:Skyrim.esm','0A3F02:Skyrim.esm','0ACB6C:Skyrim.esm','09E0D7:Skyrim.esm',
    '09E469:Skyrim.esm','09DA56:Skyrim.esm','0B3FE0:Skyrim.esm','0A2989:Skyrim.esm','0EE9F7:Skyrim.esm',
    '0A298A:Skyrim.esm','0A3F1B:Skyrim.esm','0E7BCD:Skyrim.esm','0D882D:Skyrim.esm',
    '0ABD9C:Skyrim.esm','09E12B:Skyrim.esm','0ACB6E:Skyrim.esm','094382:Skyrim.esm','09E46B:Skyrim.esm','0B3FDF:Skyrim.esm',
    '43D32C:Triumvirate - Mage Archetypes.esp','43D32F:Triumvirate - Mage Archetypes.esp',
    '442432:Triumvirate - Mage Archetypes.esp','442436:Triumvirate - Mage Archetypes.esp',
    '442439:Triumvirate - Mage Archetypes.esp','44243C:Triumvirate - Mage Archetypes.esp',
    '442442:Triumvirate - Mage Archetypes.esp','442446:Triumvirate - Mage Archetypes.esp',
    '442441:Triumvirate - Mage Archetypes.esp','43D331:Triumvirate - Mage Archetypes.esp',
    '442434:Triumvirate - Mage Archetypes.esp','44243B:Triumvirate - Mage Archetypes.esp',
    '43D32E:Triumvirate - Mage Archetypes.esp','442438:Triumvirate - Mage Archetypes.esp',
    '442444:Triumvirate - Mage Archetypes.esp','442447:Triumvirate - Mage Archetypes.esp',
    '442435:Triumvirate - Mage Archetypes.esp')
$allText = @{}
foreach ($f in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') { $allText[$f.FullName] = Read-YamlText $f.FullName }
$left = @()
foreach ($p in $allText.Keys) {
    foreach ($fk in $deadKeys) {
        if ($fk -and $allText[$p].Contains($fk)) { $left += "$(Split-Path -Leaf $p) -> $fk" }
    }
}
if ($left.Count -gt 0) { $left | ForEach-Object { Write-Host "    remaining: $_" }; throw "$($left.Count) references to deleted records survive" }

# b. the only non-TVR-keyed records are the 10 new chests
$foreign = @()
foreach ($p in $allText.Keys) {
    if ((Split-Path -Leaf $p) -in 'RecordData.yaml', 'GroupRecordData.yaml') { continue }
    $fk = [regex]::Match($allText[$p], '(?m)^FormKey: (.+?)(?=\r?$)').Groups[1].Value
    if ($fk -and $fk -notmatch 'Triumvirate') { $foreign += (Split-Path -Leaf $p) }
}
$expected = @($vendors | ForEach-Object { $_.File })
$unexpected = @($foreign | Where-Object { $_ -notin $expected })
if ($unexpected.Count -gt 0 -or $foreign.Count -ne 10) {
    $unexpected | ForEach-Object { Write-Host "    unexpected override: $_" }
    throw "override set is wrong: $($foreign.Count) foreign-keyed records (want exactly the 10 chests)"
}

# c. every tome reachable from >=3 chests, every staff from >=1
$tierBundleOf = @{}   # parent bundle fk -> tier bundle fks
$tomeOf = @{}         # tier bundle fk -> tome fk
foreach ($f in Get-ChildItem (Join-Path $root 'LeveledItems') -Filter 'TVR_Tomes_*.yaml') {
    $t = Read-YamlText $f.FullName
    $fk = [regex]::Match($t, '(?m)^FormKey: (.+?)(?=\r?$)').Groups[1].Value
    $refs = @([regex]::Matches($t, '(?m)^    Reference: (.+?)(?=\r?$)') | ForEach-Object { $_.Groups[1].Value })
    $eid = ($f.Name -split ' - ')[0]
    if ($eid -match '^TVR_Tomes_Litem_\w+_\d{3}_') { if ($refs.Count -eq 1) { $tomeOf[$fk] = $refs[0] } }
    elseif ($eid -match '^TVR_Tomes_Litem_(Druid|Shadow|Warlock|Cleric|Shaman)_[A-Z]') { $tierBundleOf[$fk] = $refs }
}
$sources = @{}
foreach ($v in $vendors) {
    $t = Read-YamlText (Join-Path (Join-Path $root 'Containers') $v.File)
    $items = @([regex]::Matches($t, '(?m)^    Item: (.+?)(?=\r?$)') | ForEach-Object { $_.Groups[1].Value })
    foreach ($it in $items) {
        if ($tierBundleOf.ContainsKey($it)) {
            foreach ($tb in $tierBundleOf[$it]) {
                if ($tomeOf.ContainsKey($tb)) { $tome = $tomeOf[$tb]; if (-not $sources[$tome]) { $sources[$tome] = 0 }; $sources[$tome]++ }
            }
        }
        if ($it -in $staves.Values) { if (-not $sources[$it]) { $sources[$it] = 0 }; $sources[$it]++ }
    }
}
$tomes = @($tomeOf.Values | Sort-Object -Unique)
if ($tomes.Count -ne 75) { throw "tome chain resolves $($tomes.Count) tomes, want 75" }
$short = @($tomes | Where-Object { -not $sources[$_] -or $sources[$_] -lt 3 })
if ($short.Count -gt 0) { throw "$($short.Count) tomes have fewer than 3 vendor sources" }
$noStaff = @($staves.Values | Where-Object { -not $sources[$_] })
if ($noStaff.Count -gt 0) { throw "$($noStaff.Count) staves unplaced" }
$counts = $tomes | ForEach-Object { $sources[$_] } | Group-Object | Sort-Object Name
Write-Host ("  proof: 75/75 tomes at >=3 vendors (source counts: {0}); 26/26 staves placed" -f (($counts | ForEach-Object { "$($_.Count)x$($_.Name)" }) -join ', '))
Write-Host "15 - done"
