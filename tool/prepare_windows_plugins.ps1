# SPDX-License-Identifier: GPL-3.0-or-later
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$links = [IO.Path]::GetFullPath((Join-Path $project 'windows/flutter/ephemeral/.plugin_symlinks'))
$plugins = Get-Content -LiteralPath (Join-Path $project '.flutter-plugins-dependencies') -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Path $links -Force | Out-Null
foreach ($plugin in $plugins.plugins.windows) {
  if ($plugin.name -notmatch '^[a-zA-Z0-9_]+$') { throw 'Invalid generated plugin name.' }
  $link = [IO.Path]::GetFullPath((Join-Path $links $plugin.name))
  if (!$link.StartsWith($links + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Plugin link escaped its generated directory.' }
  $existing = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
  if ($existing -and $existing.LinkType -eq 'SymbolicLink') { continue }
  if ($existing -and $existing.LinkType -ne 'Junction') { throw 'Refusing to replace a non-link plugin folder.' }
  if ($existing) { [IO.Directory]::Delete($link) }
  New-Item -ItemType SymbolicLink -Path $link -Target $plugin.path | Out-Null
}
