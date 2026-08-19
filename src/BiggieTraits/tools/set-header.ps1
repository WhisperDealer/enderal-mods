# Set the plugin header. RUN FIRST, immediately after re-serializing the stock plugin.
#
# Deliberately not numbered: it is not part of the conversion sequence, it is the thing you must do
# before any of it. Spriggit writes `Author: DEFAULT` and no `Stats` block, and **Mutagen's default
# form version is 1.71** - so a header that never mentions the field rebuilds itself invisible to
# Enderal. That failure is silent in every tool and only shows up as "the mod does nothing in game".
#
# Credit is not decoration here. This ships a modified copy of someone else's plugin under its
# original filename, so the author's name belongs in the header, the mod page and the readme.

. (Join-Path $PSScriptRoot '00-common.ps1')

$Author      = 'Shazdeh / Whisperdealer'
$Description = @'
    Biggie Traits by Shazdeh, converted for Enderal: Forgotten Stories. Form version lowered to
    1.70 so Enderal's 1.5.97 engine will load it, DLC masters removed, and the traits that
    target Skyrim-only content removed. Original mod and all assets are Shazdeh's.
'@

Write-Host "set-header - stamping form version and credit"

$header = Join-Path (Get-EspRoot) 'RecordData.yaml'
if (-not (Test-Path $header)) { throw "Header not found: $header" }

$lines  = Get-YamlLines $header
$out    = @()
$done   = $false
# Declare these up front: Set-StrictMode makes reading an unassigned variable a hard error.
$inDesc  = $false
$inStats = $false

foreach ($line in $lines) {
    # Drop a previous run's Author/Description so this is idempotent.
    if ($line -match '^\s{2}Author:') { continue }
    if ($line -match '^\s{2}Description: >-') { $inDesc = $true; continue }
    if ($inDesc) {
        if ($line -match '^\s{4}\S') { continue }   # still inside the folded block
        $inDesc = $false
    }
    # Drop a previous Stats block so we do not stack two of them.
    if ($line -match '^\s{2}Stats:\s*$') { $inStats = $true; continue }
    if ($inStats) {
        if ($line -match '^\s{4}\S') { continue }
        $inStats = $false
    }

    $out += $line

    if (-not $done -and $line -match '^ModHeader:\s*$') {
        $out += '  Stats:'
        $out += '    Version: 1.7'
        $done = $true
    }
}

if (-not $done) { throw "No 'ModHeader:' line found - is this a Spriggit RecordData.yaml?" }

# Author and Description go after the Flags block, matching Spriggit's own field order.
$final = @()
foreach ($line in $out) {
    $final += $line
    if ($line -match '^\s{2}- Small\s*$') {
        $final += "  Author: $Author"
        $final += '  Description: >-'
        foreach ($d in ($Description -split "`r?`n")) {
            if ($d.Trim()) { $final += $d.TrimEnd() }
        }
    }
}

Set-YamlLines -Path $header -Lines $final

# Prove it rather than trusting the loop.
$text = Read-YamlText $header
foreach ($needle in @('Version: 1.7', "Author: $Author")) {
    if ($text -notmatch [regex]::Escape($needle)) { throw "Header edit did not take: '$needle' is missing." }
}
if (([regex]::Matches($text, '(?m)^\s{2}Author:')).Count -ne 1) { throw "Header has more than one Author line." }
if (([regex]::Matches($text, '(?m)^\s{2}Stats:')).Count -ne 1)  { throw "Header has more than one Stats block." }

Write-Host "  form version 1.7, author '$Author'"
Write-Host "set-header - done"
