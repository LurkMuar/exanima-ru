# Stage 1: fill untranslated lines with exact (case-sensitive) matches from the old ZoG translation
param([string]$Root = "D:\exanima-ru")
$dir = "$Root\game\patcher"
$enc = [Text.Encoding]::GetEncoding(1251)

$en   = [IO.File]::ReadAllLines("$dir\resource_EN.txt", $enc)
$ru   = [IO.File]::ReadAllLines("$dir\resource_RU.txt", $enc)
$cur  = [IO.File]::ReadAllLines("$dir\resource.txt", $enc)
$full = [IO.File]::ReadAllLines("$dir\resource_RU_FULL.txt", $enc)
if ($en.Count -ne $ru.Count) { throw "resource_EN.txt ($($en.Count)) and resource_RU.txt ($($ru.Count)) differ in line count" }
if ($cur.Count -ne $full.Count) { throw "resource.txt ($($cur.Count)) and resource_RU_FULL.txt ($($full.Count)) differ in line count" }

$tm = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
for ($i = 0; $i -lt $en.Count; $i++) {
    if ($en[$i] -like 'file\*') { continue }
    if ($ru[$i] -ceq $en[$i])   { continue }
    if (-not $tm.ContainsKey($en[$i])) { $tm[$en[$i]] = $ru[$i] }
}

$out = [string[]]$full.Clone()
$filled = 0
$left = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $cur.Count; $i++) {
    $s = $cur[$i]
    if ($s -like 'file\*' -or $s -notmatch '[A-Za-z]{2}' -or $s -cne $full[$i]) { continue }
    if ($tm.ContainsKey($s)) { $out[$i] = $tm[$s]; $filled++ }
    else { $left.Add("$($i+1)`t$s") }
}

[IO.File]::WriteAllLines("$dir\resource_RU_FULL.stage1.txt", $out, $enc)
[IO.File]::WriteAllLines("$dir\todo_stage2.txt", $left, [Text.Encoding]::UTF8)
"Filled from old translation: $filled"
"Left for the model: $($left.Count)  -> todo_stage2.txt"
