param([Parameter(Mandatory=$true)][string]$Apk, [string]$AndroidSdk = "$env:LOCALAPPDATA/Android/Sdk")
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$env:JAVA_HOME = Join-Path $Root '.toolchains/jdk-17.0.17+10'
$env:PATH = "$env:JAVA_HOME/bin;$env:PATH"
$Apk = (Resolve-Path -LiteralPath $Apk).Path
$Badging = (& "$AndroidSdk/build-tools/35.0.0/aapt.exe" dump badging $Apk) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'aapt failed.' }
if ($Badging -notmatch "package: name='com.audiosubs.audiosubs_reader.tv'") { throw 'Not the separate TV application ID.' }
if ($Badging -notmatch "sdkVersion:'23'") { throw 'Effective minSdk is not 23.' }
if ($Badging -notmatch "native-code: 'armeabi-v7a'") { throw 'APK does not declare ARMv7.' }
if ($Badging -notmatch "leanback-launchable-activity:") { throw 'Missing Leanback launcher activity.' }
Write-Output $Badging
$Signatures = (& "$AndroidSdk/build-tools/35.0.0/apksigner.bat" verify --verbose --print-certs --min-sdk-version 23 $Apk) -join "`n"
if ($LASTEXITCODE -ne 0 -or $Signatures -notmatch 'Verified using v1 scheme.*true' -or $Signatures -notmatch 'Verified using v2 scheme.*true') { throw 'Both Android6 JAR and v2 signatures are required.' }
Write-Output $Signatures
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Zip = [IO.Compression.ZipFile]::OpenRead($Apk)
try {
  $Names = @($Zip.Entries | ForEach-Object { $_.FullName })
  foreach ($Name in @('lib/armeabi-v7a/libflutter.so','lib/armeabi-v7a/libapp.so')) {
    $Entry = $Zip.GetEntry($Name)
    if ($null -eq $Entry -or $Entry.Length -lt 1024) { throw "Missing complete ARMv7 runtime: $Name" }
  }
  foreach ($Entry in $Zip.Entries | Where-Object { $_.FullName -match '^lib/.+\.so$' }) {
    if ($Entry.FullName -notmatch '^lib/armeabi-v7a/') { throw 'Unexpected non-ARMv7 native library.' }
    $Reader = New-Object IO.BinaryReader ($Entry.Open())
    try { $Header = $Reader.ReadBytes(20) } finally { $Reader.Dispose() }
    if ($Header.Length -ne 20 -or $Header[0] -ne 127 -or $Header[1] -ne 69 -or $Header[2] -ne 76 -or $Header[3] -ne 70 -or $Header[4] -ne 1 -or $Header[5] -ne 1 -or $Header[18] -ne 40 -or $Header[19] -ne 0) { throw "Not little-endian ELF32 ARM: $($Entry.FullName)" }
    Write-Output "ELF32 ARM verified: $($Entry.FullName) ($($Entry.Length) bytes)"
  }
  if ($Names | Where-Object { $_ -match '\.abook$|\.py$|\.exe$|\.dll$|preparation_runtime|whisper|cublas|cudnn' }) { throw 'Non-player payload found.' }
} finally { $Zip.Dispose() }
Write-Output "APK bytes: $((Get-Item -LiteralPath $Apk).Length)"
Write-Output "SHA256: $((Get-FileHash -Algorithm SHA256 $Apk).Hash.ToLowerInvariant())"
