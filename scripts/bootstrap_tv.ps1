param([string]$AndroidSdk = "$env:LOCALAPPDATA/Android/Sdk")
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Tools = Join-Path $Root '.toolchains'
$Flutter = Join-Path $Tools 'flutter'
$Commit = 'edada7c56edf4a183c1735310e123c7f923584f1'
$Jdk = Join-Path $Tools 'jdk-17.0.17+10'
New-Item -ItemType Directory -Force $Tools | Out-Null
if (!(Test-Path "$Flutter/bin/flutter.bat")) {
  & git clone --depth 1 --branch 3.32.8 https://github.com/flutter/flutter.git $Flutter
  if ($LASTEXITCODE -ne 0) { throw 'Flutter source download failed.' }
}
$ActualCommit = (& git -C $Flutter rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $ActualCommit -ne $Commit) { throw 'Unexpected Flutter commit. Do not upgrade this Android6 toolchain in place.' }
# The upstream Windows wrapper contains a literal $git typo. Correct only
# host revision lookup; the framework, Dart compiler and Android engine stay pinned.
$Wrapper = Join-Path $Flutter 'bin/internal/shared.bat'
$WrapperText = [IO.File]::ReadAllText($Wrapper)
if ($WrapperText.Contains('^& $git rev-parse HEAD')) {
  [IO.File]::WriteAllText($Wrapper, $WrapperText.Replace('^& $git rev-parse HEAD','^& git rev-parse HEAD'))
}
# Shallow clones otherwise report an epoch engine date during version inspection.
$Engine = ([IO.File]::ReadAllText((Join-Path $Flutter 'bin/internal/engine.version'))).Trim()
& git -C $Flutter cat-file -e "$Engine`^{commit}" 2>$null
if ($LASTEXITCODE -ne 0) {
  & git -C $Flutter fetch --depth 1 origin $Engine
  if ($LASTEXITCODE -ne 0) { throw 'Pinned engine metadata fetch failed.' }
}
if (!(Test-Path "$Jdk/bin/java.exe")) {
  $Zip = Join-Path $Tools 'temurin17.zip'
  $Url = 'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.17%2B10/OpenJDK17U-jdk_x64_windows_hotspot_17.0.17_10.zip'
  & curl.exe --fail --location --retry 2 --output $Zip $Url
  if ($LASTEXITCODE -ne 0) { throw 'JDK download failed.' }
  if ((Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLowerInvariant() -ne 'dcf0064efec7e515a5e3b56e7532f1a1c125510303c6c9e60af8878e3f7347fe') { throw 'JDK checksum mismatch.' }
  Expand-Archive -LiteralPath $Zip -DestinationPath $Tools
  Remove-Item -LiteralPath $Zip
}
if (!(Test-Path "$AndroidSdk/platform-tools/adb.exe")) { throw 'Pass -AndroidSdk pointing to an existing Android SDK.' }
$env:JAVA_HOME = $Jdk
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
# Keep Gradle transforms outside source indexing; cache identity is unique to this fork path.
$CacheHasher = [Security.Cryptography.SHA256]::Create()
try { $CacheHash = ([BitConverter]::ToString($CacheHasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($Root.ToLowerInvariant())))).Replace('-','').ToLowerInvariant().Substring(0,12) }
finally { $CacheHasher.Dispose() }
$env:GRADLE_USER_HOME = Join-Path "$env:LOCALAPPDATA/AudioSubsReaderTV/gradle-cache" $CacheHash
$env:PUB_CACHE = Join-Path $Tools 'pub-cache'
# Flutter prefers Android Studio's bundled Java over JAVA_HOME. Keep its
# Windows APPDATA-based configuration local instead of changing flutter config globally.
$env:APPDATA = Join-Path $Tools 'flutter-config'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$LocalFlutterSettings = @{ 'jdk-dir' = $Jdk; 'android-sdk' = $AndroidSdk } | ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $env:APPDATA '.flutter_settings'), $LocalFlutterSettings)
$env:CI = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:PATH = "$Jdk/bin;$Flutter/bin;$env:PATH"
$FlutterProperty = $Flutter.Replace('\','/')
$SdkProperty = $AndroidSdk.Replace('\','/')
[IO.File]::WriteAllText((Join-Path $Root 'android/local.properties'), "sdk.dir=$SdkProperty`nflutter.sdk=$FlutterProperty`n")
Push-Location $Root
try {
  & "$Flutter/bin/flutter.bat" --version
  if ($LASTEXITCODE -ne 0) { throw 'Pinned Flutter bootstrap failed.' }
} finally { Pop-Location }
Write-Host 'Project-local Flutter3.32.8 / Dart3.8.1 / JDK17 ready; global toolchains unchanged.'
