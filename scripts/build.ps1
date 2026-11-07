# Full rebuild after extract.bat + stage1 (+ optional stage2): text -> Resource.rpk -> fonts -> install
param(
    [string]$Root = "D:\exanima-ru",
    [string]$Game = "D:\SteamLibrary\steamapps\common\Exanima",
    [int]$SpacingLatin = 3,
    [int]$SpacingCyr = 0,
    [switch]$NoInstall
)
$ErrorActionPreference = "Stop"
& "$PSScriptRoot\stage3.ps1" -Root $Root
Copy-Item "$PSScriptRoot\..\patcher\pack.bat" "$Root\game\patcher\pack.bat" -Force
cmd /c "`"$Root\game\patcher\pack.bat`" < nul > `"$Root\game\patcher\pack.log`" 2>&1"
"pack.bat finished, log: $Root\game\patcher\pack.log"
& "$PSScriptRoot\fonts_patch.ps1" -Root $Root -SpacingLatin $SpacingLatin -SpacingCyr $SpacingCyr
if (-not $NoInstall) { & "$PSScriptRoot\install.ps1" -Root $Root -Game $Game }
