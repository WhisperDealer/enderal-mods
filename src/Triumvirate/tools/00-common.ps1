# Shared helpers for the Triumvirate -> Enderal conversion generators.
#
# Dot-source this from each numbered script. Everything here is deliberately assertive: the
# Spriggit YAML is CRLF and PowerShell 5.1 has no YAML parser, so these are line-oriented edits
# and the only defence against a silent no-op is to count what changed and throw on zero.
# See CLAUDE.md guardrails 4 and 11.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:EspRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'TriumvirateESP'

function Get-EspRoot {
    if (-not (Test-Path $script:EspRoot)) {
        throw "Serialized plugin folder not found: $script:EspRoot"
    }
    return $script:EspRoot
}

# Spriggit writes UTF-8 without BOM and CRLF line endings. PowerShell 5.1's
# `Set-Content -Encoding utf8` would add a BOM and re-encode non-ASCII, so read and write
# explicitly. (CLAUDE.md: "Never rewrite a UTF-8 doc with Set-Content -Encoding utf8".)
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-YamlText {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-YamlText {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    [System.IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

function Get-YamlLines {
    param([Parameter(Mandatory)][string]$Path)
    # -split on \r?\n keeps this correct whichever endings a file happens to carry.
    return (Read-YamlText $Path) -split "`r?`n"
}

function Set-YamlLines {
    param(
        [Parameter(Mandatory)][string]$Path,
        # AllowEmptyString matters: a file ending in a newline splits to a trailing '' element,
        # and a mandatory [string[]] validates each element, so binding fails without it.
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines
    )
    Write-YamlText -Path $Path -Text ($Lines -join "`r`n")
}

# Every record file in the plugin, indexed by its own FormKey.
# Returns a hashtable: 'HEX:Triumvirate - Mage Archetypes.esp' -> @{ EditorID; Path }
function Get-RecordIndex {
    $root  = Get-EspRoot
    $index = @{}
    foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
        $text = Read-YamlText $file.FullName
        $fk = [regex]::Match($text, '(?m)^FormKey: ([0-9A-Fa-f]{6}:Triumvirate - Mage Archetypes\.esp)')
        if (-not $fk.Success) { continue }
        $ed = [regex]::Match($text, '(?m)^EditorID: (.+?)(?=\r?$)')
        $index[$fk.Groups[1].Value] = @{
            EditorID = if ($ed.Success) { $ed.Groups[1].Value.Trim() } else { '' }
            Path     = $file.FullName
        }
    }
    return $index
}

# Record files whose EditorID contains any of $Patterns (case-insensitive).
function Get-RecordsMatching {
    param(
        [Parameter(Mandatory)][string[]]$Patterns,
        [hashtable]$Index
    )
    if (-not $Index) { $Index = Get-RecordIndex }
    $hits = @()
    foreach ($key in $Index.Keys) {
        $ed = $Index[$key].EditorID
        foreach ($p in $Patterns) {
            if ($ed -and $ed.ToLowerInvariant().Contains($p.ToLowerInvariant())) {
                $hits += [pscustomobject]@{
                    FormKey  = $key
                    EditorID = $ed
                    Path     = $Index[$key].Path
                }
                break
            }
        }
    }
    # The leading comma stops PowerShell unrolling an empty result to $null, which would make
    # every caller's .Count throw under Set-StrictMode once the script is run a second time.
    return ,@($hits | Sort-Object EditorID)
}

function Remove-RecordFiles {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Records,
        [Parameter(Mandatory)][string]$Label
    )
    $removed = 0
    foreach ($r in $Records) {
        if (Test-Path $r.Path) {
            Remove-Item -LiteralPath $r.Path -Force
            Write-Host ("    - {0}" -f $r.EditorID)
            $removed++
        }
    }
    Write-Host ("  {0}: removed {1} record(s)" -f $Label, $removed)
    return $removed
}

# Drop entries from a YAML sequence whose line references any of $FormKeys.
# Returns the number of lines removed. Idempotent: a second run removes nothing.
function Remove-YamlListEntries {
    param(
        [Parameter(Mandatory)][string]$Path,
        # AllowEmptyCollection so a re-run with nothing left to prune is a no-op, not an error.
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$FormKeys
    )
    if ($FormKeys.Count -eq 0) { return 0 }
    $lines = Get-YamlLines $Path
    $keep  = @()
    $dropped = 0
    foreach ($line in $lines) {
        $isEntry = $false
        foreach ($fk in $FormKeys) {
            # Match a bare sequence entry ("- HEX:Plugin.esp") only, so a property line that
            # merely mentions the FormKey is never silently mangled.
            if ($line -match ('^\s*-\s+' + [regex]::Escape($fk) + '\s*$')) { $isEntry = $true; break }
        }
        if ($isEntry) { $dropped++ } else { $keep += $line }
    }
    if ($dropped -gt 0) {
        # Spriggit omits a collection key entirely when the collection is empty, and Mutagen's
        # reader throws "Expected 'SequenceStart', got 'Scalar'" on a bare "Items:" with nothing
        # under it. So if the last entry just went, the key has to go too.
        $keep = Remove-EmptyCollectionKeys -Lines $keep
        Set-YamlLines -Path $Path -Lines $keep
    }
    return $dropped
}

# Drop any "Key:" line whose collection is now empty.
#
# The test is NOT simply "is the next line more indented". A YAML block sequence sits at the SAME
# indentation as the key that owns it:
#
#     Flags:
#     - IgnoreResistance
#
# so treating same-indent lines as unrelated deletes live keys. A key is empty only when the next
# non-blank line is neither more indented nor a sequence item ('- ') at the same indent.
function Remove-EmptyCollectionKeys {
    param([Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines)
    $out = @()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^(\s*)[A-Za-z0-9_]+:\s*$') {
            $indent = $Matches[1].Length
            $nextLine = $null
            for ($j = $i + 1; $j -lt $Lines.Count; $j++) {
                if ($Lines[$j].Trim() -eq '') { continue }
                $nextLine = $Lines[$j]; break
            }
            if ($null -eq $nextLine) { continue }   # key at end of file - nothing under it
            $nextIndent = ($nextLine -replace '^(\s*).*$', '$1').Length
            $isOwnedSequence = ($nextIndent -eq $indent -and $nextLine -match '^\s*-\s')
            if ($nextIndent -le $indent -and -not $isOwnedSequence) { continue }
        }
        $out += $Lines[$i]
    }
    return ,$out
}

# Remove a YAML block that starts at the line matching $StartPattern and runs until the next
# line whose indentation is less than or equal to the start line's. Used for VMAD script and
# property blocks, which have no other reliable delimiter.
function Remove-YamlBlock {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$StartPattern
    )
    $lines = Get-YamlLines $Path
    $startIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $StartPattern) { $startIdx = $i; break }
    }
    if ($startIdx -lt 0) { return 0 }

    $startIndent = ($lines[$startIdx] -replace '^(\s*).*$', '$1').Length
    $endIdx = $lines.Count
    for ($i = $startIdx + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '') { continue }
        $indent = ($lines[$i] -replace '^(\s*).*$', '$1').Length
        if ($indent -le $startIndent) { $endIdx = $i; break }
    }

    $keep = @()
    if ($startIdx -gt 0) { $keep += $lines[0..($startIdx - 1)] }
    if ($endIdx -lt $lines.Count) { $keep += $lines[$endIdx..($lines.Count - 1)] }
    Set-YamlLines -Path $Path -Lines $keep
    return ($endIdx - $startIdx)
}

function Assert-Changed {
    param(
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][string]$What
    )
    if ($Count -le 0) {
        throw "Nothing changed for '$What'. Either the tree was already edited, or a pattern stopped matching - do not ignore this."
    }
}

# --- helpers added for the archetype passes (WD-11..WD-15) ---------------------------------------

# Remove the sequence item ("- ..." plus its indented/continuation lines) that CONTAINS a line
# matching $ContainsPattern. Walks back from the match to the owning "- " line, then forward to
# the next line whose indentation is <= the item's. Returns lines removed; 0 if no match.
function Remove-SequenceItemContaining {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ContainsPattern
    )
    $lines = Get-YamlLines $Path
    $hit = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $ContainsPattern) { $hit = $i; break }
    }
    if ($hit -lt 0) { return 0 }
    $start = -1
    for ($i = $hit; $i -ge 0; $i--) {
        if ($lines[$i] -match '^(\s*)-\s') { $start = $i; break }
    }
    if ($start -lt 0) { throw "Remove-SequenceItemContaining: no owning '- ' item above '$ContainsPattern' in $Path" }
    $itemIndent = ($lines[$start] -replace '^(\s*).*$', '$1').Length
    $end = $lines.Count
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '') { continue }
        $indent = ($lines[$i] -replace '^(\s*).*$', '$1').Length
        if ($indent -le $itemIndent) { $end = $i; break }
    }
    $keep = @()
    if ($start -gt 0) { $keep += $lines[0..($start - 1)] }
    if ($end -lt $lines.Count) { $keep += $lines[$end..($lines.Count - 1)] }
    $keep = Remove-EmptyCollectionKeys -Lines $keep
    Set-YamlLines -Path $Path -Lines $keep
    return ($end - $start)
}

# Remove a TOP-LEVEL key and its block, correctly ending at the next line that is neither
# indented NOR a '- ' sequence item at column 0. (A YAML block sequence sits at the SAME
# indentation as the key that owns it - see CLAUDE.md and 07's local copy of this.)
function Remove-TopLevelKeyBlock {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Key)
    $lines = Get-YamlLines $Path
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('^' + [regex]::Escape($Key) + ':\s*$')) { $start = $i; break }
    }
    if ($start -lt 0) { return 0 }
    $end = $lines.Count
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '') { continue }
        if ($lines[$i] -match '^\s') { continue }
        if ($lines[$i] -match '^-\s') { continue }
        $end = $i; break
    }
    $keep = @()
    if ($start -gt 0) { $keep += $lines[0..($start - 1)] }
    if ($end -lt $lines.Count) { $keep += $lines[$end..($lines.Count - 1)] }
    Set-YamlLines -Path $Path -Lines $keep
    return ($end - $start)
}

# Replace literal $Old -> $New in every yaml under the ESP root. Returns occurrences replaced.
# Idempotency contract: the CALLER decides what a zero means - pass -MustExistAfter to assert the
# rename is present in the tree either way (fresh run or re-run), so a typo'd pattern still throws.
function Update-TreeStrings {
    param(
        [Parameter(Mandatory)][string]$Old,
        [Parameter(Mandatory)][string]$New,
        [switch]$MustExistAfter
    )
    $root = Get-EspRoot
    $n = 0
    foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
        $text = Read-YamlText $file.FullName
        if ($text.Contains($Old)) {
            $count = ([regex]::Matches($text, [regex]::Escape($Old))).Count
            Write-YamlText -Path $file.FullName -Text ($text.Replace($Old, $New))
            $n += $count
        }
    }
    if ($MustExistAfter -and $n -eq 0) {
        $found = $false
        foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
            if ((Read-YamlText $file.FullName).Contains($New)) { $found = $true; break }
        }
        if (-not $found) { throw "Rename '$Old' -> '$New' matched nothing and the target string is absent - pattern is wrong." }
    }
    return $n
}

# ------------------------------------------------------------------ the vendor map
# ONE merchant per archetype LINE (archetype + school, e.g. Druid_Alteration). Each merchant sells
# every tier of its lines, Novice to Master, plus those lines' staves. 15-distribution.ps1 writes the
# Novice/Apprentice/Adept parent bundles and the staves into each hook; 17-tier-gating.ps1 adds the
# Expert/Master tier bundles to the SAME hook. Both read this table, so they cannot disagree.
#
# `Archetypes` gives a merchant every line of those archetypes EXCEPT the ones in
# $script:TvrUnhomedLines below.
#
# `File` is the merchant's SureAI `*_CustomMerchandise` hook (an empty UseAll FS record - see the
# header of 15). The hook<->chest pairing was read out of each chest's own Items list and each chest
# was resolved to its cell by its placed ref, never guessed from a name:
#   SisterEnvy_          -> _00E_Merchant_Rhalata_SisterEnvyContainer 01E893  (FSNQR03RhalataTemple)
#   Wildmage_Undercity_  -> _00E_FS_Merchant_Wildmage_UndercityBarracks1 01E900 (UndercityBarracks1)
#   TuriousFlammentrunk_ -> _00E_Merchant_STTurious 118050                     (SuntempleAlchemy)
#
# SHARED GROUND: Torius's hook is also written by Apocalypse. Two plugins overriding one hook = the
# later-loading one's stock wins outright for a player running both. Accepted for now (Apocalypse is
# due its own redistribution). Halda Stronghand's hook (Holy Templar Magic's) is no longer used.
$script:TvrVendors = @(
    @{ File = 'SisterEnvy_CustomMerchandise - 0302ED_Enderal - Forgotten Stories.esm.yaml'
       Merchant = 'Sister Envy, the Rhalata';               Archetypes = @('Shadow') }
    @{ File = 'Wildmage_Undercity_CustomMerchandise - 0302F0_Enderal - Forgotten Stories.esm.yaml'
       Merchant = 'Shrouded Mage, Undercity';               Archetypes = @('Warlock') }
    @{ File = 'TuriousFlammentrunk_CustomMerchandise - 0302FE_Enderal - Forgotten Stories.esm.yaml'
       Merchant = 'Torius Flameling, Sun Temple alchemist'; Archetypes = @('Druid', 'Shaman', 'Cleric') }
)

# Entropy (Conjuration) and Psionics (Illusion) are illegal in Enderal, so the Druid/Shaman/Cleric
# lines in them are kept off Torius Flameling (a Sun Temple merchant).
#
# STASHES: lines placed once, as the tomes themselves, in a hidden non-merchant chest instead of a
# vendor. The chest does not respawn, so it holds Book records directly - NOT the tier bundles,
# whose authored ChanceNone 1 would lose a tome for good 1% of the time. Overriding this chest is
# the plugin's one container override; nothing else in Enderal or reference/mods touches it, and no
# NQ29 script reads or empties it.
#   _00E_NQ29_BossChest 14BECE:Skyrim.esm, placed as 14BECF in UndercityBarracks2ApothekariUpper
#   ("House of the Apothecarii", Undercity), in the room behind the Expert-locked door 0DE7AC. It
#   holds the "Old Ban Totem" blueprint (_00E_CraftingPlan_NQ29_ProtectionTotem 14BEC9).
#
# A stash with a Template is a NEW chest of our own: the template container is copied under our
# FormKey/EditorID, and placed by overriding Cell (copied from CellMaster, the winning plugin, with
# its NavigationMeshes and every existing ref dropped - CLAUDE.md's add-one-object recipe) with one
# Temporary ref. Keep lists the master items an overridden stash must still hold.
#   Cleric Psionics: Yero's secret vault under the Sun Temple (FSSuntempleYeroCave 03E73A, "Sun
#   Temple, Secret Vault"). Yero was a Holy Order magister taken by the Red Madness; the chest sits
#   at the north end of his unholy altar (MS11UnholyAltar01 ref 043DFE). Reached through FS's
#   "Secrets" quest (FS_NQ04): the key from Yero's strongbox opens the trap door in Yero's Tower.
#   No plugin in reference/mods and nothing in EGO touches the cell; FS overrides it, so FS's copy
#   is the one we carry.
$script:TvrStashes = @(
    @{ File = '_00E_NQ29_BossChest - 14BECE_Skyrim.esm.yaml'; Master = 'Skyrim'
       Where = 'House of the Apothecarii, Undercity (Expert-locked room)'
       Lines = @('Druid_Conjuration', 'Shaman_Conjuration'); Keep = @('14BEC9:Skyrim.esm')
       Notes = @('TVR_Note_ApothecariiConfiscation') }
    @{ File = 'TVR_Cleric_Container_PsionicsStash - 4C0D60_Triumvirate - Mage Archetypes.esp.yaml'
       Template = 'ChestLarge01EMPTY - 08EA5D_Skyrim.esm.yaml'; Master = 'Skyrim'
       FormKey = '4C0D60:Triumvirate - Mage Archetypes.esp'; EditorID = 'TVR_Cleric_Container_PsionicsStash'
       Cell = 'Cells\2\0\FSSuntempleYeroCave - 03E73A_Skyrim.esm'; CellMaster = 'EnderalFS'
       Ref = '4C0D61:Triumvirate - Mage Archetypes.esp'
       Position = '-2985, 1530, 1343'; Rotation = '0, 0, 4.9062448'
       Where = "Sun Temple, Secret Vault (Yero's unholy altar)"
       Lines = @('Cleric_Illusion'); Keep = @()
       Notes = @('TVR_Note_YeroFourthLetter') }
)

# NOTES: lore letters our own, one in each stash, built by 15 step 4c from Template (Dal'Galar's
# plain bordered letter, FS's copy: no script, no Teaches) with the text in tools/notes/<EditorID>.txt.
#   Yero's Fourth Letter sits between FS's Third Letter (Sira's death) and his Memorial Book (MQ02):
#   why he bent Light Magic into Psionics, before the Red Madness took him.
#   The Apothecarii's record of what they seized from Samael Dal'Galar when he left Ark (MQ11a:
#   "Healer of the Poor", quarrel with the League), and what the Old Ban Totem does to the Blind
#   Miner (_00E_NQ29_MythsAndLegends_Volume_01: "a Psionic totem may break the invulnerability ...
#   Solely the Apothecarii could have access to this knowledge"). It deliberately says nothing of
#   Maya, the Black Stone or Calia - MQ11a's spoilers.
$script:TvrNoteTemplate = '_00E_MQ11a_DalGalarFinalLetter - 036743_Skyrim.esm.yaml'
$script:TvrNotes = @(
    @{ EditorID = 'TVR_Note_YeroFourthLetter'; FormKey = '4C0D62:Triumvirate - Mage Archetypes.esp'
       Title = "Yero's Diary (Fourth Letter)" }
    @{ EditorID = 'TVR_Note_ApothecariiConfiscation'; FormKey = '4C0D63:Triumvirate - Mage Archetypes.esp'
       Title = 'Note from the Apothecarii' }
)
# Lines nobody sells or stashes yet: UNOBTAINABLE until homed. The proofs in 15/17 assert exactly
# that, so homing one is a deliberate edit here.
$script:TvrUnhomedLines = @()
# Every line NOT stocked by a merchant hook - 15/17 keep these out of every hook.
$script:TvrNonVendorLines = @($script:TvrUnhomedLines) + @($script:TvrStashes | ForEach-Object { $_.Lines })
$script:TvrSchoolLetter = @{ A = 'Alteration'; C = 'Conjuration'; D = 'Destruction'; I = 'Illusion'; R = 'Restoration' }

# Tomes deliberately kept off every vendor (20-withhold-force-of-nature.ps1). The distribution
# proofs allow these to be reachable or not, so 15/17 stay correct whichever side of 20 they run.
$script:TvrWithheldTomes = @(
    '41EC7C:Triumvirate - Mage Archetypes.esp'   # TVR_Druid_A025_Book_ForceOfNature
)
$script:TvrWithheldTierBundles = @(
    '43820F:Triumvirate - Mage Archetypes.esp'   # TVR_Druid_025_Alteration - holds only the tome above
)
