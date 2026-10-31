param([string]$AndroidSdk = "$env:LOCALAPPDATA/Android/Sdk", [switch]$Check)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot/bootstrap_tv.ps1" -AndroidSdk $AndroidSdk
$Flutter = Join-Path $Root '.toolchains/flutter/bin/flutter.bat'
$Dart = Join-Path $Root '.toolchains/flutter/bin/cache/dart-sdk/bin/dart.exe'
Push-Location $Root
try {
  & $Flutter pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'Pinned dependency resolution failed.' }
  if ($Check) {
    & $Dart format --output=none --set-exit-if-changed lib test
    if ($LASTEXITCODE -ne 0) { throw 'Dart formatting differs.' }
    & $Flutter analyze --no-pub lib test
    if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
    & $Flutter test --no-pub test
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
  }
  & $Flutter build apk --release --no-pub --target-platform android-arm --split-per-abi
  if ($LASTEXITCODE -ne 0) { throw 'ARMv7 release build failed.' }
  $Version = ([regex]::Match([IO.File]::ReadAllText((Join-Path $Root 'pubspec.yaml')), '(?m)^version:\s*(\S+)')).Groups[1].Value.Split('+')[0]
  $Dist = Join-Path $Root "dist/$Version"
  New-Item -ItemType Directory -Force $Dist | Out-Null
  $Apk = Join-Path $Dist "AudioSubsReaderTV-$Version-android6-armeabi-v7a.apk"
  Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk' -Destination $Apk
  & "$AndroidSdk/build-tools/35.0.0/apksigner.bat" verify --verbose --print-certs --min-sdk-version 23 $Apk
  if ($LASTEXITCODE -ne 0) { throw 'Android23 signature verification failed.' }
  $Hash = (Get-FileHash -Algorithm SHA256 $Apk).Hash.ToLowerInvariant()
  [IO.File]::WriteAllText((Join-Path $Dist 'SHA256SUMS.txt'), "$Hash  $([IO.Path]::GetFileName($Apk))`n")
  Write-Host "TV ARMv7 release: $Apk"
  Write-Host "SHA256: $Hash"
} finally { Pop-Location }
