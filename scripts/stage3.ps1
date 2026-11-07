# Stage 3: final resource_RU_FULL.txt = stage1 + stage2 translations + manual overrides
#   -Stage2: results_stage2.tsv from stage2.ps1 (num, status, en, ru)
#            or data\stage2_ru.tsv from this repo (num, status, ru)
param(
    [string]$Root = "D:\exanima-ru",
    [string]$Stage2 = "$PSScriptRoot\..\data\stage2_ru.tsv",
    [string]$Overrides = "$PSScriptRoot\..\data\overrides.tsv"
)
$dir  = "$Root\game\patcher"
$enc  = [Text.Encoding]::GetEncoding(1251)
$utf8 = New-Object Text.UTF8Encoding($false)

$out = [IO.File]::ReadAllLines("$dir\resource_RU_FULL.stage1.txt", $enc)
$cur = [IO.File]::ReadAllLines("$dir\resource.txt", $enc)
if ($out.Count -ne $cur.Count) { throw "Line count mismatch: stage1=$($out.Count) resource=$($cur.Count)" }

$nModel = 0; $nOv = 0
foreach ($l in [IO.File]::ReadAllLines($Stage2, $utf8)) {
    $p = $l -split "`t"
    if ($p.Count -lt 3 -or $p[1] -eq 'FAIL') { continue }
    $i = [int]$p[0] - 1
    if ($p.Count -ge 4) {
        if (-not $p[3]) { continue }
        if ($cur[$i] -cne $p[2]) { throw "Source mismatch at line $($p[0])" }
        $ru = $p[3]
    } else { $ru = $p[2] }
    $out[$i] = $ru; $nModel++
}
foreach ($l in [IO.File]::ReadAllLines($Overrides, $utf8)) {
    if ($l -match '^\s*#' -or $l -notmatch "`t") { continue }
    $num, $ru = $l -split "`t", 2
    $out[[int]$num - 1] = $ru; $nOv++
}

$left = 0
for ($i = 0; $i -lt $cur.Count; $i++) {
    if ($cur[$i] -notlike 'file\*' -and $cur[$i] -match '[A-Za-z]{2}' -and $out[$i] -ceq $cur[$i]) { $left++ }
}

if (-not (Test-Path "$dir\resource_RU_FULL.zog.txt")) { Copy-Item "$dir\resource_RU_FULL.txt" "$dir\resource_RU_FULL.zog.txt" }
[IO.File]::WriteAllLines("$dir\resource_RU_FULL.txt", $out, $enc)
"Stage2 lines: $nModel   Overrides: $nOv   Still English: $left"
