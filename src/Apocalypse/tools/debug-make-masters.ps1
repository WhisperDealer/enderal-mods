#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Hand-build a TES4 plugin with a chosen master list and NO records.
# The load-crash bisect control from CLAUDE.md: it removes the toolchain as a variable, so a crash
# that survives this plugin cannot be caused by anything you authored.
#
#   debug-make-masters.ps1 <outPath.esp> [masters] [hedrVersion]
#   debug-make-masters.ps1 "D:\MO2\mods\MyTest\MyTest.esp" `
#       "Skyrim.esm,Update.esm,Enderal - Forgotten Stories.esm,Apocalypse - Magic of Skyrim.esp" 1.7
if ($args.Count -lt 1 -or -not $args[0]) { throw 'usage: debug-make-masters.ps1 <outPath.esp> [comma-separated masters] [hedrVersion]' }
$out = $args[0]
$masters = @()
if ($args.Count -ge 2 -and $args[1]) { $masters = @($args[1] -split ',' | Where-Object { $_ -ne '' }) }

$sub = New-Object IO.MemoryStream
$sw  = New-Object IO.BinaryWriter($sub)
$enc = [Text.Encoding]::GetEncoding(1252)

$sw.Write([Text.Encoding]::ASCII.GetBytes('HEDR'))
$ver=1.7; if ($args.Count -ge 3 -and $args[2]) { $ver=[single]$args[2] }
$sw.Write([uint16]12); $sw.Write([single]$ver); $sw.Write([int32]0); $sw.Write([uint32]0x800)

$a = $enc.GetBytes("debug`0")
$sw.Write([Text.Encoding]::ASCII.GetBytes('CNAM')); $sw.Write([uint16]$a.Length); $sw.Write($a)

foreach ($m in $masters) {
  $mb = $enc.GetBytes("$m`0")
  $sw.Write([Text.Encoding]::ASCII.GetBytes('MAST')); $sw.Write([uint16]$mb.Length); $sw.Write($mb)
  $sw.Write([Text.Encoding]::ASCII.GetBytes('DATA')); $sw.Write([uint16]8); $sw.Write([uint64]0)
}
$sw.Flush(); $subBytes = $sub.ToArray()

$ms = New-Object IO.MemoryStream
$bw = New-Object IO.BinaryWriter($ms)
$bw.Write([Text.Encoding]::ASCII.GetBytes('TES4'))
$bw.Write([uint32]$subBytes.Length); $bw.Write([uint32]0); $bw.Write([uint32]0)
$bw.Write([uint32]0); $bw.Write([uint16]0); $bw.Write([uint16]0)
$bw.Write($subBytes); $bw.Flush()

[IO.File]::WriteAllBytes($out, $ms.ToArray())
"wrote $out  (HEDR $ver, masters: $($masters.Count))"
$masters | ForEach-Object { "   $_" }
& (Join-Path $PSScriptRoot 'verify-plugin-structure.ps1') $out
