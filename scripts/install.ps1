# Copy the built Exanima.exe + Resource.rpk into the game folder (or -Restore the originals).
# The very first run saves the original game files to $Root\steam-original.
param(
    [string]$Root = "D:\exanima-ru",
    [string]$Game = "D:\SteamLibrary\steamapps\common\Exanima",
    [switch]$Restore
)
if (Get-Process Exanima -ErrorAction SilentlyContinue) { throw "Close the game first" }
$orig = "$Root\steam-original"
if (-not (Test-Path "$orig\Exanima.exe")) {
    New-Item -ItemType Directory $orig -Force | Out-Null
    Copy-Item "$Game\Exanima.exe", "$Game\Resource.rpk" $orig
    "Original game files saved to $orig"
}
if ($Restore) { Copy-Item "$orig\*" $Game -Force; "Original files restored"; return }
Copy-Item "$Root\game\Exanima.exe", "$Root\game\Resource.rpk" $Game -Force
"Installed into $Game"
