# SPDX-License-Identifier: GPL-3.0-or-later
# Deterministic PNG-to-ICO conversion; the source logo is never modified.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$project = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Image]::FromFile((Join-Path $project 'lib/assets/logo.png'))
$images = @()
try {
  foreach ($size in @(16,24,32,48,64,128,256)) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $stream = [System.IO.MemoryStream]::new()
    try {
      $graphics.Clear([System.Drawing.Color]::Transparent)
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $scale = [Math]::Min($size / $source.Width, $size / $source.Height)
      $width = [single]($source.Width * $scale)
      $height = [single]($source.Height * $scale)
      $graphics.DrawImage($source, [single](($size-$width)/2), [single](($size-$height)/2), $width, $height)
      $graphics.Flush()
      # Circular avatar mask with a one-pixel antialiased edge. Transparent
      # corners belong to the ICO frames, not to the user's source artwork.
      $center = $size / 2.0
      $radius = $center - 0.5
      for ($y = 0; $y -lt $size; $y++) {
        for ($x = 0; $x -lt $size; $x++) {
          $distance = [Math]::Sqrt([Math]::Pow($x + 0.5 - $center, 2) + [Math]::Pow($y + 0.5 - $center, 2))
          $coverage = [Math]::Max(0, [Math]::Min(1, $radius - $distance + 0.5))
          if ($coverage -lt 1) {
            $pixel = $bitmap.GetPixel($x, $y)
            $alpha = [int][Math]::Round($pixel.A * $coverage)
            $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, $pixel.R, $pixel.G, $pixel.B))
          }
        }
      }
      $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
      $images += @{ Size=$size; Bytes=$stream.ToArray() }
    } finally { $stream.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
  }
} finally { $source.Dispose() }
$output = Join-Path $project 'windows/runner/resources/app_icon.ico'
$file = [System.IO.File]::Create($output)
$writer = [System.IO.BinaryWriter]::new($file)
try {
  $writer.Write([uint16]0)
  $writer.Write([uint16]1)
  $writer.Write([uint16]$images.Count)
  $offset = 6 + 16 * $images.Count
  foreach ($entry in $images) {
    $dimension = if ($entry.Size -eq 256) { 0 } else { $entry.Size }
    $writer.Write([byte]$dimension)
    $writer.Write([byte]$dimension)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]32)
    $writer.Write([uint32]$entry.Bytes.Length)
    $writer.Write([uint32]$offset)
    $offset += $entry.Bytes.Length
  }
  foreach ($entry in $images) { $writer.Write([byte[]]$entry.Bytes) }
} finally { $writer.Dispose(); $file.Dispose() }
Write-Output "Updated multi-resolution app icon: $output"
