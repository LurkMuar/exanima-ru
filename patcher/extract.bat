@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem === 1. Text from Exanima.exe (does not work on current game version) ===
tools\Parser_EXE_idHSA_Exanima.exe -e ..\Exanima.exe Exanima\
tools\SpliteCombiner.exe -p Exanima.txt Exanima\

rem === 2. Text from Resource.rpk ===
tools\unPacker_rpk.exe -u ..\resource.rpk resource\
for /R resource\ %%a in (exanima*.rfc) do tools\unPacker_rfc.exe -u "%%a"
for /R resource\ %%a in (0000DBC0*.db) do tools\unPacker_rfc.exe -u "%%a"
for /R resource\ %%a in (objstrings*.rdb;0000DBCD*.db) do tools\Parser_rdb.exe -e "%%a"
for /R resource\ %%a in (*.pwr) do tools\Parser_pwr.exe -e "%%a" "%%~dpa\pwr\%%~nxa.txt"
for /R resource\ %%a in (*.txt) do (
  set x=%%a
  set x=!x:\resource\=\txt_res\resource\!
  echo f|xcopy "%%a" "!x!" /Y /E >nul
)
tools\SpliteCombiner.exe -p resource.txt txt_res\

rem === 3. Match with the old ZoG translation ===
tools\Optimizer_and_Recover.exe -u Exanima.txt Exanima_EN.txt Exanima_RU.txt Exanima_RU_FULL.txt -rn
tools\Optimizer_and_Recover.exe -u resource.txt resource_EN.txt resource_RU.txt resource_RU_FULL.txt -rn

echo === Done ===
