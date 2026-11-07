@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem === 1. Text back into resource files ===
tools\SpliteCombiner.exe -u resource_RU_FULL.txt "%CD%\"
for /R resource\ %%a in (*.pwr) do tools\Parser_pwr.exe -i "%%a" "%%~dpa\pwr\%%~nxa.txt"
for /R resource\ %%a in (objstrings*.rdb;0000DBCD*.db) do tools\Parser_rdb.exe -i "%%a"
for /R resource\ %%a in (0000DBC0*.db) do tools\unPacker_rfc.exe -p "%%a"
for /R resource\ %%a in (exanima*.rfc) do tools\unPacker_rfc.exe -p "%%a"
tools\patcher_str32limit.exe resource\charroles.rdb charroles.rdb_EN.txt charroles.rdb_RU.txt
rem NOTE: do NOT copy ZoG titlefont.rfi - it remaps Latin capitals to Cyrillic and breaks the English menu.

rem === 2. Repack Resource.rpk (working copy one level up) ===
tools\unPacker_rpk.exe -p ..\resource.rpk resource\

echo === Done ===
