# Build and check the package without Rtools. Run: powershell -ExecutionPolicy Bypass -File dev\check.ps1
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$tmp = 'D:\rtmp'
if (-not (Test-Path $tmp)) { New-Item -ItemType Directory -Path $tmp | Out-Null }
$env:TMPDIR = $tmp; $env:TEMP = $tmp; $env:TMP = $tmp
$r = 'D:\R-4.6.1\bin\R.exe'
Set-Location $tmp
Get-ChildItem $tmp -Filter 'plansize_*.tar.gz' | Remove-Item -Force
if (Test-Path "$tmp\plansize.Rcheck") { Remove-Item "$tmp\plansize.Rcheck" -Recurse -Force }

& $r CMD build $repo
if ($LASTEXITCODE -ne 0) { Write-Host 'R CMD build failed'; exit 1 }
$tar = Get-ChildItem $tmp -Filter 'plansize_*.tar.gz' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $tar) { Write-Host 'no tarball found'; exit 1 }

& $r CMD check --no-manual $tar.FullName
$code = $LASTEXITCODE

$log = Get-Content "$tmp\plansize.Rcheck\00check.log"
$log | Where-Object { $_ -like 'Status:*' } | Write-Host
$bad = $log | Where-Object { $_ -match '(WARNING|ERROR)\s*$' }
if ($bad) { Write-Host 'Problems:'; $bad | Write-Host }
if ($code -ne 0 -or $bad) { exit 1 }
exit 0
