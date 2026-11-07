# Stage 2: translate remaining lines with a local model (LM Studio, OpenAI-compatible API)
# Save this file as UTF-8 WITH BOM (Windows PowerShell 5 reads files without BOM as ANSI).
param(
    [string]$Root  = "D:\exanima-ru",
    [string]$Url   = "http://127.0.0.1:1234/v1/chat/completions",
    [string]$Model = "gigachat3.1-10b-a1.8b",
    [string]$Glossary = "$PSScriptRoot\..\data\glossary.tsv"
)
$dir     = "$Root\game\patcher"
$enc     = [Text.Encoding]::GetEncoding(1251)
$utf8    = New-Object Text.UTF8Encoding($false)
$resFile = "$dir\results_stage2.tsv"
$tokRe   = '\\r\\n|\\x[0-9A-Fa-f]{2}|\[[^\]]*\]|\{[^}]*\}|@WEAR\d+:|<[A-Z_]+>'
$edgeRe  = '^((?:\s*(?:\\r\\n|\\x20|\[[^\]]*\]))*)(.*?)((?:\s*(?:\\r\\n|\\x20|\[[^\]]*\]))*\s*)$'
$tagRe   = '<\s*t\s*(\d+)\s*/?\s*>'

function Mask([string]$s) {
    $script:toks = New-Object System.Collections.Generic.List[string]
    [regex]::Replace($s, $tokRe, [Text.RegularExpressions.MatchEvaluator]{
        param($x) $script:toks.Add($x.Value); "<t$($script:toks.Count - 1)/>" })
}
function WordSet([string]$s) {
    $set = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($w in ([regex]::Replace($s, $tokRe, ' ').ToLower() -split '[^a-z]+')) {
        if ($w.Length -gt 2) { [void]$set.Add($w) } }
    return ,$set
}
function Sim($a, $b) {
    if ($a.Count -eq 0 -or $b.Count -eq 0) { return 0.0 }
    $i = [System.Collections.Generic.HashSet[string]]::new($a); $i.IntersectWith($b)
    return $i.Count / ($a.Count + $b.Count - $i.Count)
}
function Ask($sys, $user, $temp) {
    $body = @{ model = $Model; temperature = $temp; messages = @(
        @{ role = 'system'; content = $sys }, @{ role = 'user'; content = $user }) } | ConvertTo-Json -Depth 5
    $r = Invoke-WebRequest $Url -Method Post -ContentType 'application/json; charset=utf-8' `
         -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing
    ($utf8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json).choices[0].message.content.Trim()
}
function MatchCase([string]$src, [string]$dst) {
    if (-not $src -or -not $dst) { return $dst }
    if (-not [char]::IsLetter($src[0]) -or -not [char]::IsLetter($dst[0])) { return $dst }
    if ([char]::IsUpper($src[0])) { $f = [char]::ToUpper($dst[0]) } else { $f = [char]::ToLower($dst[0]) }
    return "$f" + $dst.Substring(1)
}

$G = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($l in [IO.File]::ReadAllLines($Glossary, [Text.Encoding]::UTF8)) {
    if ($l -match '^\s*#' -or $l -notmatch "`t") { continue }
    $k, $v = $l -split "`t", 2
    $G[$k.Trim()] = $v.Trim()
}

$sys = @"
Ты переводишь игру Exanima (мрачное фэнтези) с английского на русский.
Правила:
- Метки вида <t0/>, <t1/> переноси в перевод без изменений, каждую ровно один раз, на соответствующее место.
- Отвечай только переводом, одной строкой, без кавычек, пояснений и префиксов.
- Переводи всё полностью, каждое предложение. Ничего не сокращай и не пропускай.
- Описания способностей пиши в повелительном наклонении на «вы»: «Скройте свой разум…», «Заставьте цель…». Названия способностей — существительные: «Исчезновение», «Разряд».
- Если даны обязательные термины, используй именно их.
- Стиль как в образцах: живой литературный русский, без канцелярита.
"@

$en  = [IO.File]::ReadAllLines("$dir\resource_EN.txt", $enc)
$ru  = [IO.File]::ReadAllLines("$dir\resource_RU.txt", $enc)
$old = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $en.Count; $i++) {
    if ($en[$i] -like 'file\*' -or $ru[$i] -ceq $en[$i] -or $en[$i] -notmatch '[A-Za-z]{2}') { continue }
    $old.Add([pscustomobject]@{ en = $en[$i]; ru = $ru[$i]; w = (WordSet $en[$i]) })
}

$done = @{}
if (Test-Path $resFile) { foreach ($l in [IO.File]::ReadAllLines($resFile, $utf8)) {
    $p = $l -split "`t"; if ($p[1] -ne 'FAIL') { $done[$p[0]] = 1 } } }

$cache = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
$todo  = [IO.File]::ReadAllLines("$dir\todo_stage2.txt", [Text.Encoding]::UTF8)
$n = 0
foreach ($line in $todo) {
    $n++
    $num, $src = $line -split "`t", 2
    if (-not $src -or $done.ContainsKey($num)) { continue }
    Write-Progress -Activity "Перевод" -Status "$n / $($todo.Count)" -PercentComplete ($n * 100 / $todo.Count)

    $m    = [regex]::Match($src, $edgeRe, 'Singleline')
    $pre  = $m.Groups[1].Value; $core = $m.Groups[2].Value; $post = $m.Groups[3].Value
    $key  = $core.Trim().TrimEnd('.')
    $status = 'FAIL'; $outCore = ''

    if ($cache.ContainsKey($core)) {
        $status, $outCore = $cache[$core] -split "`t", 2
    }
    elseif ($G.ContainsKey($key)) {
        $outCore = $G[$key]
        if ($core.Trim().EndsWith('.') -and -not $outCore.EndsWith('.')) { $outCore += '.' }
        $outCore = MatchCase $core.Trim() $outCore
        $status  = 'GLOSS'
    }
    else {
        $w    = WordSet $core
        $best = $old | ForEach-Object { [pscustomobject]@{ p = $_; s = (Sim $w $_.w) } } |
                Sort-Object s -Descending | Select-Object -First 4
        $ex   = ($best | Where-Object { $_.s -gt 0 } | ForEach-Object {
                  "EN: " + (Mask $_.p.en) + "`nRU: " + (Mask $_.p.ru) }) -join "`n`n"
        $terms = @($G.Keys | Where-Object { $core -match ('\b' + [regex]::Escape($_) + '\b') } |
                   ForEach-Object { "$_ — $($G[$_])" })
        $hint = ""
        if ($terms.Count) { $hint += "Обязательные термины:`n" + ($terms -join "`n") + "`n`n" }
        if ($best[0].s -ge 0.75) { $hint += "Первый образец почти совпадает с новой строкой: возьми его перевод за основу и измени только то, что отличается.`n`n" }

        $masked = Mask $core
        $toks   = $script:toks.ToArray()
        $user   = "Образцы из перевода игры:`n`n$ex`n`n$hint" + "Переведи:`nEN: $masked`nRU:"

        foreach ($try in 1..3) {
            try { $o = Ask $sys $user (0.2 + 0.2 * ($try - 1)) } catch { Start-Sleep 2; continue }
            $o = ($o -replace '^\s*RU:\s*', '').Trim().Trim('"')
            if ($o -match "[`r`n]" -or $o -notmatch '[А-Яа-яЁё]') { continue }
            $ids  = @([regex]::Matches($o, $tagRe) | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object)
            $need = @(if ($toks.Count) { 0..($toks.Count - 1) })
            if (($ids -join ',') -ne ($need -join ',')) { continue }
            $o = [regex]::Replace($o, $tagRe, [Text.RegularExpressions.MatchEvaluator]{
                param($x) $toks[[int]$x.Groups[1].Value] })
            $outCore = MatchCase $core.Trim() $o
            if ($core.Trim() -match '[.!?]$' -and $outCore -notmatch '[.!?]$') { $outCore += $core.Trim()[-1] }
            $status  = 'OK'
            if ($core.Length -gt 300) { $status = 'REVIEW' }
            if ($core.Length -gt 120 -and $outCore.Length -lt 0.8 * $core.Length) { $status = 'SHORT' }
            break
        }
    }

    if ($status -ne 'FAIL') { $cache[$core] = "$status`t$outCore" }
    $outText = if ($status -eq 'FAIL') { '' } else { $pre + $outCore + $post }
    [IO.File]::AppendAllText($resFile, "$num`t$status`t$src`t$outText`r`n", $utf8)
}
"Готово: $resFile"
