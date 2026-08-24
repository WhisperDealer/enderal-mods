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
