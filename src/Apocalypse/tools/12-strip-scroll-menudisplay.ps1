#requires -Version 5.1
<#
.SYNOPSIS
  Remove the dangling MenuDisplayObject from all 144 Apocalypse scrolls.

.DESCRIPTION
  Every one of Apocalypse's 144 scrolls carries:

      MenuDisplayObject: 076E8F:Skyrim.esm

  That FormID does not exist in Enderal - it is one of the vanilla statics Enderal's replacement
  Skyrim.esm dropped. CLAUDE.md names MenuDisplayObject specifically as a field that is commonly a
  vanilla FormID a ported mod assumes is there.

  The fix is to remove the field rather than repoint it, because that is Enderal's own archetype
  (guardrail 3): all 34 of Enderal's own Scroll records - 32 in Skyrim.esm, 2 in Forgotten
  Stories - carry no MenuDisplayObject at all. Inventing a substitute static would be an invented
  mechanism where a proven one exists.

  Idempotent.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo    = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
$scrolls = Join-Path $repo 'src\Apocalypse\ApocalypseESP\Scrolls'
if (-not (Test-Path -LiteralPath $scrolls)) { throw "Scrolls folder not found: $scrolls" }

$files = @(Get-ChildItem -LiteralPath $scrolls -File -Filter *.yaml)
Write-Host "scroll records: $($files.Count)"

# CRLF tree: anchor with (?=\r?$), never '$' (CLAUDE.md - '$' silently fails to match before \r).
$pattern = '(?m)^MenuDisplayObject: 076E8F:Skyrim\.esm\r?\n'

$changed = 0
$already = 0
foreach ($f in $files) {
    $text = [IO.File]::ReadAllText($f.FullName)
    if ($text -notmatch '(?m)^MenuDisplayObject:') { $already++; continue }
    $new = [regex]::Replace($text, $pattern, '')
    if ($new -eq $text) {
        # A MenuDisplayObject that is NOT the known-dangling one: report, do not guess.
        $null = $text -match '(?m)^(MenuDisplayObject: .+?)(?=\r?$)'
        throw "$($f.Name) has an unexpected '$($Matches[1])' - re-check before stripping."
    }
    [IO.File]::WriteAllText($f.FullName, $new, (New-Object Text.UTF8Encoding($false)))
    $changed++
}

Write-Host "stripped MenuDisplayObject from $changed records; $already already had none."

if ($changed -eq 0 -and $already -ne $files.Count) {
    throw "Nothing changed and not every record is clean - the pattern did not match. Check line endings."
}
if ($changed -gt 0 -and $changed -ne 144) {
    throw "Expected 144 strips, made $changed. The scroll set changed - re-derive before trusting this."
}
