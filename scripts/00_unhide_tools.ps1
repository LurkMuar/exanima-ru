# ZoG tools ship with zeroed EXE headers (their magichide.bat). Restore "MZP\0" in the working copy.
param([string]$Root = "D:\exanima-ru")
Get-ChildItem "$Root\game\patcher\tools\*.exe" | Where-Object Name -ne "magicren.exe" | ForEach-Object {
    $fs = [IO.File]::OpenWrite($_.FullName)
    $fs.Write([byte[]](0x4D, 0x5A, 0x50, 0x00), 0, 4)
    $fs.Close()
    $_.Name
}
