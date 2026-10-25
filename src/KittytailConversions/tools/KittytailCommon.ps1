# Shared helpers for the Kittytail Conversions generators and verifiers. Dot-source it.
#
# PowerShell 5.1, StrictMode, no YAML parser: everything is line-oriented and asserts what it
# changed (CLAUDE.md guardrails 10 and 11). Spriggit YAML is CRLF and UTF-8 without BOM.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:KtRepo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
if (-not (Test-Path (Join-Path $script:KtRepo 'CLAUDE.md'))) { throw "KittytailCommon: repo root not found from $PSScriptRoot" }
$script:KtUtf8 = New-Object System.Text.UTF8Encoding($false)

function Get-KtRepo { $script:KtRepo }
function Read-KtText([string]$Path) { [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
function Write-KtText([string]$Path, [string]$Text) {
    $d = Split-Path -Parent $Path
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force $d | Out-Null }
    [IO.File]::WriteAllText($Path, $Text, $script:KtUtf8)
}

# Every FormKey a reference tree defines, read off Spriggit's file/folder names
# ("<EditorID> - <hex>_<master>.yaml" or "<...>_<master>/RecordData.yaml"). Keyed by <hex>:<master>,
# never by hex alone (CLAUDE.md: hex-only keying inflates Skyrim.esm from 87k records to 786k).
#
# Returns @{ Enderal = @{fk -> group}; Real = @{fk -> full path} }. Enderal = the Skyrim, EnderalFS
# and Update trees (what the game actually has); Real = the *Real trees (Bethesda's originals,
# used as the source for records we copy). Cached in reference/kittytail-formkey-index.tsv, which
# is gitignored with the rest of reference/; pass -Rebuild after re-serializing reference/base.
function Get-KtFormKeyIndex {
    param([switch]$Rebuild)
    $base  = Join-Path $script:KtRepo 'reference\base'
    $cache = Join-Path $script:KtRepo 'reference\kittytail-formkey-index.tsv'
    if ($Rebuild -or -not (Test-Path $cache)) {
        $rows = New-Object System.Collections.Generic.List[string]
        foreach ($tree in 'Skyrim', 'EnderalFS', 'Update', 'SkyrimReal', 'UpdateReal', 'DawnguardReal', 'DragonbornReal', 'HearthFiresReal') {
            $root = Join-Path $base $tree
            if (-not (Test-Path $root)) { throw "reference/base/$tree missing - run /spriggit-decompile-reference" }
            foreach ($f in [IO.Directory]::EnumerateFiles($root, '*.yaml', 'AllDirectories')) {
                $name = [IO.Path]::GetFileNameWithoutExtension($f)
                if ($name -eq 'RecordData') { $name = [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($f)) }
                $m = [regex]::Match($name, '([0-9A-F]{6})_(.+\.(esm|esp|esl))$')
                if (-not $m.Success) { continue }
                $group = $f.Substring($root.Length + 1).Split('\')[0]
                $rows.Add("$($m.Groups[1].Value):$($m.Groups[2].Value)`t$tree`t$group`t$f")
            }
        }
        [IO.File]::WriteAllLines($cache, [string[]]$rows, $script:KtUtf8)
    }
    $enderal = @{}; $real = @{}
    foreach ($l in [IO.File]::ReadAllLines($cache)) {
        $c = $l.Split("`t")
        if ($c[1] -in 'Skyrim', 'EnderalFS', 'Update') { $enderal[$c[0]] = $c[2] }
        elseif (-not $real.ContainsKey($c[0])) { $real[$c[0]] = $c[3] }
    }
    $enderal['000014:Skyrim.esm'] = 'PlayerRef'   # valid, engine-hardcoded, absent from the tree (guardrail 11)
    return @{ Enderal = $enderal; Real = $real }
}

# Records serialized from Bethesda's LOCALIZED masters carry every string as a nine-language
# Values: list. Our patches are not localized, so collapse each to its English string, re-indented
# as a plain Value: (the shape Kittytail's own plugins use). Throws if a Values: block has no
# English entry.
function ConvertTo-KtUnlocalized([string]$Text) {
    $lines = $Text -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $lines.Count) {
        $l = $lines[$i]
        # A localized string with no text at all is just "TargetLanguage: English"; Spriggit writes
        # the unlocalized form back as Value: '', so emit that and the tree round-trips unchanged.
        $tl = [regex]::Match($l, '^(\s*)TargetLanguage: English$')
        if ($tl.Success) {
            $out.Add($l); $i++
            $nextIsValue = $i -lt $lines.Count -and $lines[$i] -match "^$([regex]::Escape($tl.Groups[1].Value))Values?:"
            if (-not $nextIsValue) { $out.Add("$($tl.Groups[1].Value)Value: ''") }
            continue
        }
        $m = [regex]::Match($l, '^(\s*)Values:$')
        if (-not $m.Success) { $out.Add($l); $i++; continue }
        $ind = $m.Groups[1].Value
        $item = "$ind- "
        $i++
        $english = $null
        while ($i -lt $lines.Count -and ($lines[$i].StartsWith($item) -or ($lines[$i].StartsWith("$ind  ") -and $lines[$i].Length -gt $ind.Length + 2))) {
            if ($lines[$i] -eq "${item}Language: English") {
                $i++
                $sm = [regex]::Match($lines[$i], "^$([regex]::Escape($ind))  String: ?(.*)$")
                if (-not $sm.Success) { throw "English Values item without a String line: '$($lines[$i])'" }
                $english = New-Object System.Collections.Generic.List[string]
                $english.Add("${ind}Value: $($sm.Groups[1].Value)".TrimEnd())
                $i++
                while ($i -lt $lines.Count -and $lines[$i].StartsWith("$ind    ")) { $english.Add($lines[$i].Substring(2)); $i++ }
                continue
            }
            $i++
        }
        if ($null -eq $english) { throw "Values: block with no English string" }
        foreach ($e in $english) { $out.Add($e) }
    }
    return ($out -join "`r`n")
}

# Remove every YAML list item whose first line contains $Needle, plus its continuation lines.
# Returns @(newText, removedCount). Block sequences sit at their key's indent (CLAUDE.md gotcha),
# so an item's continuation lines are the ones indented past its '- '.
function Remove-KtListItem([string]$Text, [string]$Needle) {
    $lines = $Text -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]
    $removed = 0; $i = 0
    while ($i -lt $lines.Count) {
        $m = [regex]::Match($lines[$i], '^(\s*)- ')
        if ($m.Success -and $lines[$i].Contains($Needle)) {
            $cont = $m.Groups[1].Value + '  '
            $removed++; $i++
            while ($i -lt $lines.Count -and $lines[$i].StartsWith($cont)) { $i++ }
            continue
        }
        $out.Add($lines[$i]); $i++
    }
    return @(($out -join "`r`n"), $removed)
}

# Remove a top-level key and everything indented under it.
function Remove-KtTopLevelBlock([string]$Text, [string]$Key) {
    $lines = $Text -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]
    $removed = 0; $skip = $false
    foreach ($l in $lines) {
        if ($l -eq "${Key}:" -or $l.StartsWith("${Key}: ")) { $skip = $true; $removed++; continue }
        if ($skip -and ($l -match '^\S')) { $skip = $false }
        if (-not $skip) { $out.Add($l) }
    }
    return @(($out -join "`r`n"), $removed)
}

# Copy dead records (DLC records Enderal stubs, or vanilla records it deleted) into a patch as new
# records, from reference/base/*Real. Follows each copied record's own references until nothing dead
# is left; refs to the copies are remapped; strings are de-localized; EditorIDs get $EdidPrefix.
# FormIDs are assigned from $FirstId in sorted source order, so an unchanged copy set regenerates
# the same IDs. Returns the old->new FormKey map; the caller applies it to its own records.
function Copy-KtDeadRecords {
    param(
        [Parameter(Mandatory)][string[]]$Seeds,
        [Parameter(Mandatory)][hashtable]$Index,
        [Parameter(Mandatory)][string]$OutDir,
        [Parameter(Mandatory)][string]$PatchKey,
        [Parameter(Mandatory)][string]$EdidPrefix,
        [int]$FirstId = 0x810,
        [hashtable]$Subst = @{}
    )
    $fkRx = '([0-9A-F]{6}):([^\r\n]+?\.(?:esm|esp|esl))(?=\r?\n|$)'
    $copy = [ordered]@{}
    $q = New-Object System.Collections.Queue
    foreach ($s in ($Seeds | Sort-Object -Unique)) { $q.Enqueue($s) }
    while ($q.Count) {
        $fk = $q.Dequeue()
        if ($copy.Contains($fk)) { continue }
        if (-not $Index.Real.ContainsKey($fk)) { throw "Dead record $fk has no source YAML in reference/base/*Real" }
        $t = Read-KtText $Index.Real[$fk]
        foreach ($s in $Subst.Keys) { $t = $t.Replace($s, $Subst[$s]) }
        $copy[$fk] = @{ Path = $Index.Real[$fk]; Text = $t }
        foreach ($m in [regex]::Matches($t, $fkRx)) {
            $ref = "$($m.Groups[1].Value):$($m.Groups[2].Value)"
            if ($ref -ne $fk -and -not $Index.Enderal.ContainsKey($ref)) { $q.Enqueue($ref) }
        }
    }
    $map = @{}; $n = $FirstId
    foreach ($fk in ($copy.Keys | Sort-Object)) { $map[$fk] = ('{0:X6}:{1}' -f $n, $PatchKey); $n++ }
    if ($n -gt 0x1000) { throw 'ESL FormID range exhausted' }
    foreach ($fk in $copy.Keys) {
        $src = $copy[$fk]
        $grp = ($src.Path -split '\\base\\')[1].Split('\')[1]
        $edid = [regex]::Match($src.Text, '(?m)^EditorID: (\S+)').Groups[1].Value
        if (-not $edid) { throw "$fk has no EditorID" }
        $t = $src.Text
        foreach ($k in $map.Keys) { $t = $t.Replace($k, $map[$k]) }
        $t = ConvertTo-KtUnlocalized $t
        $t = [regex]::Replace($t, '(?m)^EditorID: \S+', "EditorID: $EdidPrefix$edid")
        Write-KtText (Join-Path (Join-Path $OutDir $grp) "$EdidPrefix$edid - $($map[$fk].Substring(0, 6))_$PatchKey.yaml") $t
    }
    return $map
}

# Round to 5 above 20, to the unit below (Enderal's own costs and prices are mostly multiples of 5).
function Get-KtRound5([double]$v) { if ($v -le 20) { return [int][math]::Round($v) } return [int]([math]::Round($v / 5) * 5) }
