#requires -Version 5.1
<#
.SYNOPSIS
  Read full 1MB ESP8285 flash twice and compare SHA256.
.DESCRIPTION
  READ ONLY. Requires SONOFF in UART ROM bootloader, physically disconnected
  from AC mains, with verified stable 3.3V supply and UART 3.3V logic.
  Saves sensitive factory backups outside the repository, in Downloads.
.EXAMPLE
  .\scripts\Backup-Sonoff.ps1 -Port COM8
#>
[CmdletBinding()]
param(
    [ValidatePattern('^COM\d+$')][string]$Port = 'COM8',
    [string]$OutputDir = (Join-Path $env:USERPROFILE 'Downloads\SONOFF_Backup')
)
$ErrorActionPreference = 'Stop'
$arguments = @('--chip','esp8266','--port',$Port,'--baud','115200',
  '--before','no-reset','--after','no-reset')
function Invoke-ESP([string[]]$Command) {
    & py -m esptool @arguments @Command
    if ($LASTEXITCODE -ne 0) { throw "esptool failed ($LASTEXITCODE): $($Command -join ' ')" }
}
Write-Host 'SAFETY: AC must be physically disconnected. Use only safe stable 3.3V.'
Write-Host 'SONOFF must already be in bootloader (hold button WHILE powering 3.3V).'
$ack = Read-Host 'Type YES to continue'
if ($ack -cne 'YES') { throw 'Cancelled' }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host 'Checking identity and detected flash size ...'
# Capture text while preserving output on screen.
$info = & py -m esptool @arguments flash-id 2>&1
$exitCode = $LASTEXITCODE
$info | ForEach-Object { Write-Host $_ }
if ($exitCode -ne 0) { throw 'flash-id failed' }
$infoText = $info -join [Environment]::NewLine
if ($infoText -notmatch 'ESP8285N08' -or $infoText -notmatch '(?i)(1\s*MB|1MB)') {
    throw 'Wrong or unconfirmed chip/flash size. Expected ESP8285N08 1MB. No backup performed.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$folder = Join-Path $OutputDir $stamp
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$a = Join-Path $folder 'sonoff_original.bin'
$b = Join-Path $folder 'sonoff_original_check.bin'
Invoke-ESP @('read-flash','0x0','0x100000',$a)
Invoke-ESP @('read-flash','0x0','0x100000',$b)

$fa = Get-Item $a
$fb = Get-Item $b
$ha = (Get-FileHash -LiteralPath $a -Algorithm SHA256).Hash
$hb = (Get-FileHash -LiteralPath $b -Algorithm SHA256).Hash
Write-Host "First:  $($fa.Length) bytes $ha"
Write-Host "Second: $($fb.Length) bytes $hb"
if ($fa.Length -ne 1048576 -or $fb.Length -ne 1048576 -or $ha -ne $hb) {
    throw 'BACKUP MISMATCH: do not erase flash.'
}
Write-Host "BACKUP VERIFIED - IDENTICAL! Stored locally in $folder" -ForegroundColor Green
Write-Host 'DO NOT commit BIN files to public GitHub.'
