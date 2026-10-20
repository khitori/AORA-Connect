# SPDX-License-Identifier: GPL-3.0-or-later
# Deterministic multi-resolution icon generation; source artwork is never modified.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$project = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Image]::FromFile((Join-Path $project 'lib/assets/logo.png'))
$images = @()
try {
  foreach ($size in @(16,20,24,32,40,48,64,72,96,128,192,256)) {
    # Leave breathing room around the circle, including at desktop icon sizes.
    # Render artwork at 4x resolution, then apply a symmetric circle to the frame.
    $supersampling = 4
    $renderSize = $size * $supersampling
    $inset = [single]([Math]::Max(1.0, $size * 0.04) * $supersampling)
    $diameter = [single]($renderSize - 2 * $inset)
    $render = [System.Drawing.Bitmap]::new($renderSize, $renderSize)
    $renderGraphics = [System.Drawing.Graphics]::FromImage($render)
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $stream = [System.IO.MemoryStream]::new()
    try {
      $renderGraphics.Clear($source.GetPixel(0, 0))
      $renderGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $renderGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $scale = [Math]::Min($diameter / $source.Width, $diameter / $source.Height)
      $width = [single]($source.Width * $scale)
      $height = [single]($source.Height * $scale)
      $renderGraphics.DrawImage($source, [single](($renderSize-$width)/2), [single](($renderSize-$height)/2), $width, $height)
      $renderGraphics.Flush()

      $graphics.Clear([System.Drawing.Color]::Transparent)
      $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $graphics.DrawImage($render, 0, 0, $size, $size)
      $graphics.Flush()
      # Pixel-centred geometry keeps all four sides identical. A final alpha
      # mask avoids GDI's asymmetric ellipse clipping. A two-pixel smooth ramp
      # blends the rim with the desktop instead of leaving a hard pixel staircase.
      $center = $size / 2.0
      $radius = $diameter / (2.0 * $supersampling)
      for ($y = 0; $y -lt $size; $y++) {
        for ($x = 0; $x -lt $size; $x++) {
          $distance = [Math]::Sqrt([Math]::Pow($x + 0.5 - $center, 2) + [Math]::Pow($y + 0.5 - $center, 2))
          # Double bounds are required: integer bounds select integer overloads
          # in Windows PowerShell and discard all partial edge transparency.
          $coverage = [Math]::Max(0.0, [Math]::Min(1.0, 0.5 + ($radius - $distance) / 2.0))
          $coverage = $coverage * $coverage * (3.0 - 2.0 * $coverage)
          if ($coverage -lt 1) {
            $pixel = $bitmap.GetPixel($x, $y)
            $alpha = [int][Math]::Round($pixel.A * $coverage)
            $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, $pixel.R, $pixel.G, $pixel.B))
          }
        }
      }
      if ($size -eq 256) {
        $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
      } else {
        # Native 32-bit icon bitmaps retain partial edge alpha for the shell and
        # legacy icon readers. Keep the 256px frame PNG-compressed.
        $frameWriter = [System.IO.BinaryWriter]::new($stream, [System.Text.Encoding]::UTF8, $true)
        try {
          $maskStride = [int]([Math]::Ceiling($size / 32.0) * 4)
          $frameWriter.Write([uint32]40)
          $frameWriter.Write([int32]$size); $frameWriter.Write([int32]($size * 2))
          $frameWriter.Write([uint16]1); $frameWriter.Write([uint16]32)
          $frameWriter.Write([uint32]0); $frameWriter.Write([uint32]($size * $size * 4))
          $frameWriter.Write([int32]0); $frameWriter.Write([int32]0)
          $frameWriter.Write([uint32]0); $frameWriter.Write([uint32]0)
          for ($y = $size - 1; $y -ge 0; $y--) {
            for ($x = 0; $x -lt $size; $x++) {
              $pixel = $bitmap.GetPixel($x, $y)
              if ($pixel.A -eq 0) { $frameWriter.Write([uint32]0) }
              else { $frameWriter.Write([byte]$pixel.B); $frameWriter.Write([byte]$pixel.G); $frameWriter.Write([byte]$pixel.R); $frameWriter.Write([byte]$pixel.A) }
            }
          }
          for ($y = $size - 1; $y -ge 0; $y--) {
            $mask = [byte[]]::new($maskStride)
            for ($x = 0; $x -lt $size; $x++) {
              if ($bitmap.GetPixel($x, $y).A -eq 0) {
                $index = [int][Math]::Floor($x / 8.0)
                $mask[$index] = $mask[$index] -bor (128 -shr ($x % 8))
              }
            }
            $frameWriter.Write($mask)
          }
          $frameWriter.Flush()
        } finally { $frameWriter.Dispose() }
      }
      $images += @{ Size=$size; Bytes=$stream.ToArray() }
    } finally {
      $stream.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
      $renderGraphics.Dispose(); $render.Dispose()
    }
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
