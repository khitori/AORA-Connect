# SPDX-License-Identifier: GPL-3.0-or-later
param([string]$Icon = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (!$Icon) { $Icon = Join-Path (Split-Path $PSScriptRoot -Parent) 'windows/runner/resources/app_icon.ico' }
$bytes = [IO.File]::ReadAllBytes($Icon)
$sizes = @(16,20,24,32,40,48,64,72,96,128,192,256)
if ([BitConverter]::ToUInt16($bytes, 2) -ne 1 -or [BitConverter]::ToUInt16($bytes, 4) -ne $sizes.Count) { throw 'Unexpected ICO header' }
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $size = $sizes[$i]
  $entry = 6 + 16 * $i
  $dimension = if ($bytes[$entry] -eq 0) { 256 } else { [int]$bytes[$entry] }
  if ($dimension -ne $size) { throw 'Unexpected icon frame size' }
  $length = [BitConverter]::ToUInt32($bytes, $entry + 8)
  $offset = [BitConverter]::ToUInt32($bytes, $entry + 12)
  if ($offset + $length -gt $bytes.Length) { throw 'Truncated icon frame' }
  $alpha = [byte[]]::new($size * $size)
  if ($size -eq 256) {
    $stream = [IO.MemoryStream]::new([byte[]]$bytes[$offset..($offset + $length - 1)])
    $bitmap = [Drawing.Bitmap]::new($stream)
    try {
      if ($bitmap.Width -ne $size -or $bitmap.Height -ne $size) { throw 'Invalid PNG dimensions' }
      for ($y = 0; $y -lt $size; $y++) {
        for ($x = 0; $x -lt $size; $x++) { $alpha[$y * $size + $x] = $bitmap.GetPixel($x, $y).A }
      }
    } finally { $bitmap.Dispose(); $stream.Dispose() }
  } else {
    $maskStride = [int]([Math]::Ceiling($size / 32.0) * 4)
    if ([BitConverter]::ToUInt32($bytes, $offset) -ne 40 -or [BitConverter]::ToInt32($bytes, $offset + 4) -ne $size -or [BitConverter]::ToInt32($bytes, $offset + 8) -ne 2 * $size -or [BitConverter]::ToUInt16($bytes, $offset + 14) -ne 32) { throw 'Invalid native icon bitmap' }
    if ($length -ne 40 + $size * $size * 4 + $maskStride * $size) { throw 'Invalid bitmap length' }
    for ($y = 0; $y -lt $size; $y++) {
      for ($x = 0; $x -lt $size; $x++) {
        $value = $bytes[$offset + 40 + (($size - 1 - $y) * $size + $x) * 4 + 3]
        $alpha[$y * $size + $x] = $value
        $maskByte = $bytes[$offset + 40 + $size * $size * 4 + ($size - 1 - $y) * $maskStride + [int][Math]::Floor($x / 8.0)]
        if ((($maskByte -band (128 -shr ($x % 8))) -ne 0) -ne ($value -eq 0)) { throw 'Legacy transparency mask differs from alpha' }
      }
    }
  }
  $partial = 0
  for ($y = 0; $y -lt $size; $y++) {
    for ($x = 0; $x -lt $size; $x++) {
      $value = $alpha[$y * $size + $x]
      if ($value -gt 0 -and $value -lt 255) { $partial++ }
      if ($value -ne $alpha[$y * $size + $size - 1 - $x] -or $value -ne $alpha[($size - 1 - $y) * $size + $x]) { throw 'Icon edge is not symmetric' }
    }
  }
  if ($alpha[0] -ne 0 -or $alpha[$size - 1] -ne 0 -or $alpha[$alpha.Length - 1] -ne 0 -or $alpha[$alpha.Length - $size] -ne 0) { throw 'Icon corners are not transparent' }
  if ($partial -eq 0) { throw "${size}px icon has a hard, aliased edge: no partial alpha values" }
}
Write-Output "Icon checks passed: $($sizes.Count) sizes, partial edge alpha, symmetric curves, and valid transparency masks."
