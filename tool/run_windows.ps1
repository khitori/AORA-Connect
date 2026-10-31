# SPDX-License-Identifier: GPL-3.0-or-later
# The interface runs with ordinary rights; changed service helpers request
# their own administrator approval during the build.
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
flutter run -d windows
