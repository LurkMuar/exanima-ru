# Full rebuild after extract.bat + stage1 (+ optional stage2): text -> Resource.rpk -> fonts -> install
param(
    [string]$Root = "D:\exanima-ru",
    [string]$Game = "D:\SteamLibrary\steamapps\common\Exanima",
    [int]$SpacingLatin = 3,
    [int]$SpacingCyr = 0,
    [string]$Stage2 = "$PSScriptRoot\..\data\stage2_ru.tsv",
    [switch]$NoInstall
)
$ErrorActionPreference = "Stop"
& "$PSScriptRoot\stage3.ps1" -Root $Root -Stage2 $Stage2
Copy-Item "$PSScriptRoot\..\patcher\pack.bat" "$Root\game\patcher\pack.bat" -Force
$rpk = "$Root\game\Resource.rpk"
$before = (Get-Item $rpk).LastWriteTimeUtc
cmd /c "`"$Root\game\patcher\pack.bat`" < nul > `"$Root\game\patcher\pack.log`" 2>&1"
if ((Get-Item $rpk).LastWriteTimeUtc -eq $before) { throw "pack.bat did not update $rpk, see $Root\game\patcher\pack.log" }
"pack.bat finished, log: $Root\game\patcher\pack.log"
& "$PSScriptRoot\fonts_patch.ps1" -Root $Root -SpacingLatin $SpacingLatin -SpacingCyr $SpacingCyr
if (-not $NoInstall) { & "$PSScriptRoot\install.ps1" -Root $Root -Game $Game }
