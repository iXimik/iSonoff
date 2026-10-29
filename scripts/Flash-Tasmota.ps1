#requires -Version 5.1
<#
.SYNOPSIS
  Safely verify firmware and two local backup files before optional destructive flash.
.DESCRIPTION
  This script DOES NOT make mains-powered UART programming safe.
  Use only with AC physically disconnected, stable 3.3V, correct GPIO0 bootloader.
  Without -IUnderstandThisErasesFlash it performs checks only.
.EXAMPLE
  .\scripts\Flash-Tasmota.ps1 -Port COM8 -Firmware "$env:USERPROFILE\Downloads\tasmota-RU.bin" -BackupDir "$env:USERPROFILE\Downloads\SONOFF_Backup\20261029-183901"
  .\scripts\Flash-Tasmota.ps1 -Port COM8 -Firmware "$env:USERPROFILE\Downloads\tasmota-RU.bin" -BackupDir "<FOLDER_WITH_2_BIN_FILES>" -IUnderstandThisErasesFlash
#>
[CmdletBinding()]
param(
    [ValidatePattern('^COM\d+$')][string]$Port = 'COM8',
    [Parameter(Mandatory=$true)][string]$Firmware,
    [Parameter(Mandatory=$true)][string]$BackupDir,
    [switch]$IUnderstandThisErasesFlash
)
$ErrorActionPreference = 'Stop'
$fw = (Resolve-Path -LiteralPath $Firmware).Path
$original = Join-Path $BackupDir 'sonoff_original.bin'
$check = Join-Path $BackupDir 'sonoff_original_check.bin'
if (-not (Test-Path -LiteralPath $original) -or -not (Test-Path -LiteralPath $check)) {
    throw 'Missing two local factory BIN backups. Stop.'
}
$a = Get-Item -LiteralPath $original
$b = Get-Item -LiteralPath $check
$hashA = (Get-FileHash $original -Algorithm SHA256).Hash
$hashB = (Get-FileHash $check -Algorithm SHA256).Hash
if ($a.Length -ne 1048576 -or $b.Length -ne 1048576 -or $hashA -ne $hashB) {
    throw 'Factory backups do not match. Refusing to erase.'
}
Write-Host "Backup verified: 1048576 bytes, SHA256=$hashA"

$fwSize = (Get-Item -LiteralPath $fw).Length
if ($fwSize -le 0 -or $fwSize -ge 1048576) {
    throw "Unexpected firmware image size: $fwSize"
}
$imageInfo = & py -m esptool --chip esp8266 image-info $fw 2>&1
$imageCode = $LASTEXITCODE
$imageInfo | ForEach-Object { Write-Host $_ }
if ($imageCode -ne 0) { throw 'image-info failed' }
$header = $imageInfo -join [Environment]::NewLine
if ($header -notmatch 'Flash size:\s*1MB' -or $header -notmatch 'Flash mode:\s*DOUT' -or $header -notmatch 'Checksum:\s*0x[0-9a-fA-F]+ \(valid\)') {
    throw 'Image does not match expected 1MB / DOUT / valid checksum.'
}
$base = @('--chip','esp8266','--port',$Port,'--baud','115200',
  '--before','no-reset','--after','no-reset')
$info = & py -m esptool @base flash-id 2>&1
$infoCode = $LASTEXITCODE
$info | ForEach-Object { Write-Host $_ }
if ($infoCode -ne 0) { throw 'flash-id failed' }
$infoText = $info -join [Environment]::NewLine
if ($infoText -notmatch 'ESP8285N08' -or $infoText -notmatch '(?i)(1\s*MB|1MB)') {
    throw 'Unexpected connected chip/flash size. Refusing to erase.'
}
if (-not $IUnderstandThisErasesFlash) {
    Write-Host 'PREFLIGHT OK. Flash NOT modified. Add -IUnderstandThisErasesFlash to ERASE AND WRITE.' -ForegroundColor Yellow
    exit 0
}
Write-Host 'WARNING: FLASH ERASE WILL DESTROY CURRENT ON-DEVICE FIRMWARE AND SETTINGS.' -ForegroundColor Red
Write-Host 'Confirm AC mains physically disconnected; no USB-UART is ever connected to mains-powered SONOFF.'
$ack = Read-Host 'Type ERASE-SONOFF exactly'
if ($ack -cne 'ERASE-SONOFF') { throw 'Cancelled by operator' }
& py -m esptool @base erase-flash
if ($LASTEXITCODE -ne 0) { throw 'Erase failed; DO NOT continue' }
& py -m esptool @base write-flash --flash-mode dout --flash-size 1MB 0x0 $fw
if ($LASTEXITCODE -ne 0) { throw 'Write failed; keep SONOFF off AC and recover using UART' }
Write-Host 'FLASH WRITTEN. Inspect esptool verification result.' -ForegroundColor Green
Write-Host 'Power cycle 3.3V WITHOUT holding GPIO0 to boot. Never run AC with UART attached.'
