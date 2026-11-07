# Diagnostic: list PE sections and RCDATA resources of Exanima.exe (offsets and sizes).
param([string]$exe = "D:\exanima-ru\backup\Exanima.exe", [int]$From = 3700000)
$b = [IO.File]::ReadAllBytes($exe)
function U16($o) { [BitConverter]::ToUInt16($b, $o) }
function U32($o) { [BitConverter]::ToUInt32($b, $o) }
$pe = U32 0x3C; $nSec = U16 ($pe + 6); $optSize = U16 ($pe + 20); $magic = U16 ($pe + 24)
$ddOff = if ($magic -eq 0x20B) { $pe + 24 + 112 } else { $pe + 24 + 96 }
$rsrcRva = U32 ($ddOff + 2 * 8); $secOff = $pe + 24 + $optSize
$secs = for ($k = 0; $k -lt $nSec; $k++) {
    $o = $secOff + 40 * $k
    [pscustomobject]@{ Name = [Text.Encoding]::ASCII.GetString($b, $o, 8).Trim([char]0)
                       VA = U32 ($o + 12); VSize = U32 ($o + 8); Raw = U32 ($o + 20); RawSize = U32 ($o + 16) }
}
function RvaToOff($rva) {
    foreach ($s in $secs) { if ($rva -ge $s.VA -and $rva -lt $s.VA + [Math]::Max($s.VSize, $s.RawSize)) { return $rva - $s.VA + $s.Raw } }
    return -1
}
"== Sections =="; $secs | Format-Table Name, VA, VSize, Raw, RawSize -AutoSize | Out-String
$base = RvaToOff $rsrcRva
function NameOf($e) {
    $n = U32 $e
    if ($n -band 0x80000000) { $o = $base + ($n -band 0x7FFFFFFF); return [Text.Encoding]::Unicode.GetString($b, $o + 2, (U16 $o) * 2) }
    return "#$n"
}
function Walk($dirOff, $path) {
    $cnt = (U16 ($dirOff + 12)) + (U16 ($dirOff + 14))
    for ($k = 0; $k -lt $cnt; $k++) {
        $e = $dirOff + 16 + 8 * $k; $name = NameOf $e; $ptr = U32 ($e + 4)
        if ($ptr -band 0x80000000) { Walk ($base + ($ptr -band 0x7FFFFFFF)) "$path/$name" }
        else { $de = $base + $ptr; [pscustomobject]@{ Res = "$path/$name"; Offset = (RvaToOff (U32 $de)); Size = (U32 ($de + 4)); EntryOff = $de } }
    }
}
"== Resources from offset $From =="
Walk $base "" | Where-Object { $_.Offset -ge $From } | Sort-Object Offset | Format-Table -AutoSize | Out-String
