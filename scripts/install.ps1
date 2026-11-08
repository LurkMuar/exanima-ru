# Copy the built Exanima.exe + Resource.rpk into the game folder (or -Restore the originals).
# The very first run saves the original game files to $Root\steam-original.
param(
    [string]$Root = "D:\exanima-ru",
    [string]$Game = "D:\SteamLibrary\steamapps\common\Exanima",
    [switch]$Restore
)
$ErrorActionPreference = "Stop"
if (Get-Process Exanima -ErrorAction SilentlyContinue) { throw "Close the game first" }
$orig  = "$Root\steam-original"
$files = "Exanima.exe", "Resource.rpk"
$saved = -not ($files | Where-Object { -not (Test-Path "$orig\$_") })
if ($Restore) {
    if (-not $saved) { throw "No saved originals in $orig. Use Steam: Properties -> Installed Files -> Verify integrity" }
    foreach ($f in $files) { Copy-Item "$orig\$f" $Game -Force }
    "Original files restored"; return
}
if (-not $saved) {
    # Prefer the clean copy from backup\ - the game folder may already contain a patched build.
    $from = if (-not ($files | Where-Object { -not (Test-Path "$Root\backup\$_") })) { "$Root\backup" } else { $Game }
    New-Item -ItemType Directory $orig -Force | Out-Null
    foreach ($f in $files) { Copy-Item "$from\$f" $orig }
    "Original game files saved to $orig (from $from)"
}
Copy-Item "$Root\game\Exanima.exe", "$Root\game\Resource.rpk" $Game -Force
"Installed into $Game"
