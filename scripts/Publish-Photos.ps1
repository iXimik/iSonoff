#requires -Version 5.1
<#
.SYNOPSIS
 Upload five user-owned SONOFF photos from a local ZIP to iXimik/iSonoff.
.DESCRIPTION
 Requires git with your GitHub credentials already configured. The archive
 iSonoff_photos_5_for_GitHub.zip must be downloaded from this conversation.
 The script preserves the original photographs (no image transformations).
.EXAMPLE
 .\scripts\Publish-Photos.ps1 -ZipPath "C:\Users\zhoric\Downloads\iSonoff_photos_5_for_GitHub.zip"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ZipPath,
  [string]$RepoUrl = "https://github.com/iXimik/iSonoff.git"
)
$ErrorActionPreference = "Stop"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git not installed" }
$zip = (Resolve-Path -LiteralPath $ZipPath).Path
$working = Join-Path $env:TEMP ("iSonoffPhotos-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $working | Out-Null
try {
  $repo = Join-Path $working "repo"
  & git clone --depth 1 $RepoUrl $repo
  if ($LASTEXITCODE -ne 0) { throw "git clone failed" }
  $unpack = Join-Path $working "unpack"
  Expand-Archive -LiteralPath $zip -DestinationPath $unpack
  $imagesDir = Join-Path $repo "images"
  New-Item -ItemType Directory -Path $imagesDir -Force | Out-Null
  $names = @("sonoff-pcb-front.jpg","sonoff-housing.jpg","sonoff-pcb-back.jpg","tasmota-off.jpg","tasmota-on.jpg")
  foreach($name in $names) {
    $src = Join-Path (Join-Path $unpack "images") $name
    if (-not (Test-Path -LiteralPath $src)) { throw "Not found in ZIP: $name" }
    Copy-Item -LiteralPath $src -Destination (Join-Path $imagesDir $name)
  }
  Push-Location $repo
  try {
    & git add -- images/sonoff-pcb-front.jpg images/sonoff-housing.jpg images/sonoff-pcb-back.jpg images/tasmota-off.jpg images/tasmota-on.jpg
    & git commit -m "docs: add five original SONOFF Basic photos"
    if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
    & git push origin HEAD:main
    if ($LASTEXITCODE -ne 0) { throw "git push failed: check GitHub credentials" }
  } finally { Pop-Location }
  Write-Host "Photos uploaded to GitHub successfully." -ForegroundColor Green
} finally {
  Remove-Item -LiteralPath $working -Recurse -Force -ErrorAction SilentlyContinue
}
