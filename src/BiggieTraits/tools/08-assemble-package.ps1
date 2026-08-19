# 08 - Assemble the loose files (scripts, interface, config, distribution inis) into src/.
#
# Which scripts survive is DERIVED, not listed by hand: start from the scripts named in the
# surviving records' VMAD blocks, then close over `extends` and `Import` so base classes and the
# natives library (Traits_Utils, Traits_BasePlayerScript) are never dropped by accident. Perk
# fragments are kept only when their parent perk still exists AND still has a VMAD - which is how
# PRKF_Traits_GollumPerk_08038393 gets dropped: the Gollum perk carries no script fragment at all,
# so that .pex is a leftover from the author's build, not something the plugin uses.
#
# Run AFTER 01-07, since the surviving record set is the input.
#
# The .pex files are copied as the author compiled them. Two scripts need source edits and a
# recompile - Traits_MCM and Traits_ResetMenuScript - and those are handled by 09.

[CmdletBinding()]
param(
    [string]$SourceRoot = "C:/Users/stefa/Downloads/Biggie Traits 136384 1.0.43 2026-07-27T03-20Z 4t2yDcbJ6/Biggie Traits"
)

. (Join-Path $PSScriptRoot '00-common.ps1')

Write-Host "08 - assembling package files"

if (-not (Test-Path $SourceRoot)) { throw "Source mod folder not found: $SourceRoot. Pass -SourceRoot." }

$root    = Get-EspRoot
$modRoot = Split-Path -Parent $PSScriptRoot

# --- work out which scripts survive --------------------------------------------------------------
$named = New-Object System.Collections.Generic.HashSet[string]
$perksWithFragments = New-Object System.Collections.Generic.HashSet[string]
foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.yaml') {
    $text = Read-YamlText $file.FullName
    foreach ($m in [regex]::Matches($text, '(?m)^\s*-?\s*Name: ([A-Za-z_][A-Za-z0-9_]*)\s*$')) {
        [void]$named.Add($m.Groups[1].Value)
    }
    if ($file.Directory.Name -eq 'Perks' -and $text -match 'ScriptFragments') {
        $ed = [regex]::Match($text, '(?m)^EditorID: (.+?)(?=\r?$)')
        if ($ed.Success) { [void]$perksWithFragments.Add($ed.Groups[1].Value.Trim()) }
    }
}

$srcScripts = Join-Path $SourceRoot 'Scripts'
$srcSource  = Join-Path $SourceRoot 'Source/Scripts'
$shipped = @(Get-ChildItem -Path $srcScripts -Filter '*.pex' | ForEach-Object { $_.BaseName })

$keep = New-Object System.Collections.Generic.HashSet[string]
foreach ($s in $shipped) {
    if ($named.Contains($s)) { [void]$keep.Add($s); continue }
    if ($s -like 'PRKF_*') {
        # PRKF_<perk editor id, truncated>_<hex>
        $stem = ($s -replace '^PRKF_', '') -replace '_[0-9A-Fa-f]+$', ''
        foreach ($p in $perksWithFragments) {
            if ($p.StartsWith($stem) -or $stem.StartsWith($p)) { [void]$keep.Add($s); break }
        }
    }
}

# close over 'extends' and 'Import'
$frontier = @($keep)
while ($frontier.Count -gt 0) {
    $cur = $frontier[0]
    $frontier = @($frontier | Select-Object -Skip 1)
    $psc = Join-Path $srcSource "$cur.psc"
    if (-not (Test-Path $psc)) { continue }
    $t = Get-Content -Path $psc -Raw
    $refs = @()
    $ext = [regex]::Match($t, '(?im)^\s*Scriptname\s+\S+\s+extends\s+(\w+)')
    if ($ext.Success) { $refs += $ext.Groups[1].Value }
    foreach ($m in [regex]::Matches($t, '(?im)^\s*Import\s+(\w+)')) { $refs += $m.Groups[1].Value }
    foreach ($r in $refs) {
        $match = $shipped | Where-Object { $_ -ieq $r } | Select-Object -First 1
        if ($match -and -not $keep.Contains($match)) { [void]$keep.Add($match); $frontier += $match }
    }
}

Write-Host ("  scripts: {0} shipped, {1} kept, {2} dropped" -f $shipped.Count, $keep.Count, ($shipped.Count - $keep.Count))

# --- copy the survivors ---------------------------------------------------------------------------
$outCompiled = Join-Path $modRoot 'Scripts/compiled'
$outSource   = Join-Path $modRoot 'Scripts/source'
foreach ($d in @($outCompiled, $outSource)) {
    if (Test-Path $d) { Remove-Item -Path (Join-Path $d '*') -Force -ErrorAction SilentlyContinue }
    else { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}
$copied = 0
foreach ($s in $keep) {
    Copy-Item -Path (Join-Path $srcScripts "$s.pex") -Destination $outCompiled -Force
    $psc = Join-Path $srcSource "$s.psc"
    if (Test-Path $psc) { Copy-Item -Path $psc -Destination $outSource -Force }
    $copied++
}
Write-Host ("  copied {0} .pex (+ matching .psc where shipped)" -f $copied)

# --- interface: keep only the menus the surviving traits use ---------------------------------------
# homeowner.swf / HomeownerPapers.swf belong to the cut mortgage UI (553 KB of the package), and
# masterofone_inject.swf injects into StatsMenu, which Enderal replaced with its own skill menu.
$dropSwf = @('homeowner.swf', 'HomeownerPapers.swf', 'masterofone_inject.swf')
$outIface = Join-Path $modRoot 'Interface'
if (Test-Path $outIface) { Remove-Item -Recurse -Force $outIface }
Copy-Item -Path (Join-Path $SourceRoot 'Interface') -Destination $outIface -Recurse -Force
$swfDropped = 0
foreach ($f in $dropSwf) {
    $p = Join-Path $outIface $f
    if (Test-Path $p) { Remove-Item -Force $p; $swfDropped++ }
}
Write-Host ("  interface: copied, dropped {0} cut-trait .swf" -f $swfDropped)

# --- MCM + SKSE plugin -----------------------------------------------------------------------------
foreach ($dir in @('MCM', 'SKSE')) {
    $dest = Join-Path $modRoot $dir
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Copy-Item -Path (Join-Path $SourceRoot $dir) -Destination $dest -Recurse -Force
}
Write-Host "  MCM/ and SKSE/ copied"

Write-Host "08 - done"
