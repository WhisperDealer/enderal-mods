# 19 - The two Druid player transformations (WD-37).
#
# Triumvirate has exactly TWO player transformations, and both were reported broken in Enderal.
# They are the only two magic effects that bind TVR_Wildshape_Script:
#
#     TVR_Druid_Verdant_Effect_ForceOfNature              191250
#     TVR_Druid_Verdant_Effect_Wildshape_MorphEffect      29DA04
#
# So this is one subsystem failing, not two unrelated defects. Neither is a regression from our
# conversion: diffing both feature's records against reference/mods/Triumvirate/esp (CRLF-normalised)
# shows the only changes we ever made to them are the authored mana costs and one dropped
# Dawnguard keyword. Both are inherited upstream incompatibilities.
#
# What this script fixes is the RECORD half. The script half - stripping worn armour on transform -
# lives in src/Triumvirate/Scripts/source/TVR_Wildshape_Script.psc; see that file's header and
# Scripts/README.md.
#
# ------------------------------------------------------------------------------------------------
# Wildshape: the morph effect could essentially never apply.
#
# TVR_Druid_A050_Spell_Wildshape's SECOND effect is the one carrying the script. Upstream it is
# gated on six conditions, which group (CTDA's OR flag means "OR with the NEXT condition") as:
#
#     IsInCombat == 0
#     AND IsRunning == 1
#     AND (IsSprinting == 1 OR HasKeyword TVR_Verdant_Keyword_Wildshape_Race)
#     AND (HasKeyword ActorTypeNPC OR HasKeyword TVR_Verdant_Keyword_Wildshape_Race)
#
# On a FIRST cast the player is not yet a deer, so the third group reduces to IsSprinting == 1.
# The spell is EquipmentType 013F44 (EitherHand) - a hand-cast spell - and casting cancels a
# sprint, so that group can only pass inside a one-frame sprint-to-cast race window. The player
# therefore gets the first effect only, and the first effect (TVR_Druid_Verdant_Effect_Wildshape,
# 29DA05) is a Script-archetype MGEF with NO script attached: it is a display shell that carries the
# description and duration and does nothing. Cast the spell, nothing happens - which is the report
# verbatim.
#
# The fix keeps the design intent that survives ("out of combat") and drops the movement gate that
# cannot be satisfied. Kept:
#
#     IsInCombat == 0
#     AND (HasKeyword ActorTypeNPC OR HasKeyword TVR_Verdant_Keyword_Wildshape_Race)
#
# The second group is Enai's own re-entry guard - it lets the effect re-apply while the player is
# already a deer - and it costs nothing to keep, so it stays untouched.
#
# NOT chosen: keeping IsRunning and dropping only IsSprinting. It would preserve more of the
# original wording, but "IsRunning" is still a movement state sampled at the instant of the cast,
# and shipping a fix that is merely LESS flaky than the bug is not a fix. This is guardrail 3 -
# the archetype that works beats the mechanism that is closest to the original.
#
# The description string is rewritten to match, because it currently promises a sprint trigger that
# no longer exists. Enderal's own tomes describe what the spell does, not how it is timed.

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "19 - Druid player transformations (WD-37)"
$root = Get-EspRoot

function Get-Record {
    param([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$EditorID)
    $hit = Get-ChildItem -LiteralPath (Join-Path $root $Group) -Filter "$EditorID - *.yaml" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $hit) { throw "record not found: $Group\$EditorID" }
    return $hit.FullName
}

# --- 1. Wildshape morph conditions ---------------------------------------------------------------
$spell = Get-Record -Group 'Spells' -EditorID 'TVR_Druid_A050_Spell_Wildshape'
$lines = @(Get-YamlLines $spell)

# The morph effect is the LAST effect in the record and its Conditions: block runs to EOF, so the
# rewrite is "find that key, replace to the end". Anchored on the two-space indent that makes it an
# effect-item condition rather than a record-level one.
$start = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -eq '  Conditions:') { $start = $i }
}
if ($start -lt 0) { throw "no effect-item Conditions: block in $(Split-Path -Leaf $spell)" }

# Guard against re-running against an already-fixed tree, and against the block having moved.
$tail = ($lines[$start..($lines.Count - 1)] -join "`n")
if ($tail -notmatch 'IsSprintingConditionData') {
    if ($tail -match 'IsInCombatConditionData') {
        Write-Host "  1. Wildshape conditions already relaxed - skipping"
    } else {
        throw "unexpected Conditions: block shape - refusing to guess"
    }
} else {
    foreach ($needle in 'IsInCombatConditionData', 'IsRunningConditionData', 'HasKeywordConditionData') {
        if ($tail -notmatch [regex]::Escape($needle)) { throw "expected $needle in the upstream block; refusing to rewrite" }
    }

    $kept = @(
        '  Conditions:'
        '  - MutagenObjectType: ConditionFloat'
        '    Data:'
        '      MutagenObjectType: IsInCombatConditionData'
        '  - MutagenObjectType: ConditionFloat'
        '    Flags:'
        '    - OR'
        '    Data:'
        '      MutagenObjectType: HasKeywordConditionData'
        '      Keyword: 013794:Skyrim.esm'
        '    ComparisonValue: 1'
        '  - MutagenObjectType: ConditionFloat'
        '    Data:'
        '      MutagenObjectType: HasKeywordConditionData'
        '      Keyword: 29DA0D:Triumvirate - Mage Archetypes.esp'
        '    ComparisonValue: 1'
        ''
    )
    $new = @($lines[0..($start - 1)]) + $kept
    Set-YamlLines -Path $spell -Lines $new

    $check = Read-YamlText $spell
    foreach ($gone in 'IsRunningConditionData', 'IsSprintingConditionData') {
        if ($check -match [regex]::Escape($gone)) { throw "$gone survived the rewrite" }
    }
    $n = ([regex]::Matches($check, '(?m)^  - MutagenObjectType: ConditionFloat')).Count
    if ($n -ne 3) { throw "expected 3 effect-item conditions after the rewrite, found $n" }
    Write-Host "  1. Wildshape morph conditions: 6 -> 3 (movement gate removed)"
}

# --- 2. Wildshape description --------------------------------------------------------------------
# Scoped to the one MGEF rather than run over the tree: "while sprinting " is a phrase another
# record could plausibly use, and Update-TreeStrings would rewrite it there too.
$mgef = Get-Record -Group 'MagicEffects' -EditorID 'TVR_Druid_Verdant_Effect_Wildshape'
$text = Read-YamlText $mgef
$old  = 'Assume the form of a Deer while sprinting out of combat'
$new  = 'Assume the form of a Deer while out of combat'
if ($text -match [regex]::Escape($new)) {
    Write-Host "  2. Wildshape description already rewritten - skipping"
} elseif ($text -match [regex]::Escape($old)) {
    Write-YamlText -Path $mgef -Text ($text -replace [regex]::Escape($old), $new)
    Write-Host "  2. Wildshape description rewritten to drop the sprint trigger"
} else {
    throw "Wildshape description not in either expected form - refusing to guess"
}

Write-Host "19 - done"
