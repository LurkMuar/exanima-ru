# Cyrillic fonts for Exanima.exe (built from a clean copy):
#  1) ZoG font images (Font\Exanima_8..12.rfi) go into RCDATA resources RAYFORM06R..16R_RFI,
#     resource sizes are updated in the resource table;
#  2) the glyph table (records "Rayform06R_rfi"...) is rebuilt: the current game uses 608-byte
#     records, ZoG 0.8.3 used 588-byte ones. We keep the new layout and copy per-glyph values
#     (codes 0..255) and metrics from ZoG record by record.
#   -Fonts "06R,08R,10R,12R,16R"  which fonts to replace ("none" = no fonts)
#   -NoCord                        keep the original glyph table
#   -SpacingLatin / -SpacingCyr    extra width added to every Latin / Cyrillic glyph
param(
    [string]$Root = "D:\exanima-ru",
    [string]$Fonts = "06R,08R,10R,12R,16R",
    [switch]$NoCord,
    [int]$SpacingLatin = 3,
    [int]$SpacingCyr = 0
)
$ErrorActionPreference = "Stop"
$src  = "$Root\backup\Exanima.exe"
$dst  = "$Root\game\Exanima.exe"
$font = "$Root\game\patcher\Font"
$b = [IO.File]::ReadAllBytes($src)

# Offsets for the game build this was made on (see pe_res.ps1). Every write is checked first.
$slots = @(
    @{ File = "Exanima_8.rfi";  Name = "06R"; Off = 3851348; Size = 12769; Entry = 3720484 },
    @{ File = "Exanima_9.rfi";  Name = "08R"; Off = 3864120; Size = 16056; Entry = 3720500 },
    @{ File = "Exanima_10.rfi"; Name = "10R"; Off = 3880176; Size = 21809; Entry = 3720516 },
    @{ File = "Exanima_11.rfi"; Name = "12R"; Off = 3901988; Size = 27387; Entry = 3720532 },
    @{ File = "Exanima_12.rfi"; Name = "16R"; Off = 3929376; Size = 49083; Entry = 3720548 }
)
$want = if ($Fonts.Trim() -eq "none") { @() } else { @($Fonts -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
foreach ($w in $want) { if ($slots.Name -notcontains $w) { throw "Unknown font '$w'. Valid: $($slots.Name -join ',') or none" } }

foreach ($s in $slots) {
    if ($want -notcontains $s.Name) { continue }
    $f = [IO.File]::ReadAllBytes("$font\$($s.File)")
    if ($b[$s.Off] -ne 0xC6 -or $b[$s.Off+1] -ne 0x3D -or $b[$s.Off+2] -ne 0x2D -or $b[$s.Off+3] -ne 0x1D) { throw "$($s.Name): no font at $($s.Off)" }
    for ($k = 4; $k -lt 12; $k++) { if ($b[$s.Off + $k] -ne $f[$k]) { throw "$($s.Name): image size differs" } }
    if ([BitConverter]::ToUInt32($b, $s.Entry + 4) -ne $s.Size) { throw "$($s.Name): unexpected size in resource table" }
    if ($f.Length -gt $s.Size) { throw "$($s.File) is bigger than $($s.Name)" }
    [Array]::Clear($b, $s.Off, $s.Size)
    [Array]::Copy($f, 0, $b, $s.Off, $f.Length)
    [BitConverter]::GetBytes([uint32]$f.Length).CopyTo($b, $s.Entry + 4)
    "font {0} <- {1} ({2} of {3} bytes)" -f $s.Name, $s.File, $f.Length, $s.Size
}

if (-not $NoCord) {
    $CORD = 2795824; $NEW = 608; $OLD = 588
    if ([Text.Encoding]::ASCII.GetString($b, $CORD, 14) -ne 'Rayform06R_rfi') { throw "Glyph table not found at $CORD" }
    $zog = [IO.File]::ReadAllBytes("$font\Exanima_1.cord")
    for ($r = 0; $r -lt 5; $r++) {
        $n = $CORD + $r * $NEW; $z = $r * $OLD
        $nameN = [Text.Encoding]::ASCII.GetString($b, $n, 10); $nameZ = [Text.Encoding]::ASCII.GetString($zog, $z, 10)
        if ($nameN -ne $nameZ) { throw "Glyph table record ${r}: '$nameN' vs ZoG '$nameZ'" }
        [Array]::Copy($zog, $z + 16, $b, $n + 16, 512)                  # per-glyph values, codes 0..255
        if ($r -lt 4) { [Array]::Copy($zog, $z + 540, $b, $n + 552, 24) } # font metrics (6 x int32)
        for ($c = 33; $c -lt 256; $c++) {
            $add = if ($c -eq 168 -or $c -eq 184 -or $c -ge 192) { $SpacingCyr } else { $SpacingLatin }
            if ($add) { $p = $n + 16 + 2 * $c; $v = [BitConverter]::ToInt16($b, $p) + $add; [BitConverter]::GetBytes([int16]$v).CopyTo($b, $p) }
        }
    }
    "glyph table rebuilt: Latin +$SpacingLatin, Cyrillic +$SpacingCyr"
} else { "glyph table: original" }

[IO.File]::WriteAllBytes($dst, $b)
"Saved: $dst"
