param([string]$SigningDirectory = "$env:USERPROFILE/.audiosubs-reader-tv")
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Keytool = Join-Path $Root '.toolchains/jdk-17.0.17+10/bin/keytool.exe'
if (!(Test-Path $Keytool)) { throw 'Run scripts/bootstrap_tv.ps1 first.' }
$SigningDirectory = [IO.Path]::GetFullPath($SigningDirectory)
if ($SigningDirectory.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) { throw 'Signing material must stay outside the repository.' }
$Properties = Join-Path $SigningDirectory 'signing.properties'
$Keystore = Join-Path $SigningDirectory 'audiosubs-reader-tv.p12'
if ((Test-Path $Properties) -and (Test-Path $Keystore)) {
  Write-Host 'Existing TV signing identity retained. Back up the entire private signing directory.'
  return
}
if ((Test-Path $Properties) -or (Test-Path $Keystore)) { throw 'Partial signing identity found; restore its backup instead of replacing it.' }
New-Item -ItemType Directory -Force $SigningDirectory | Out-Null
& icacls.exe $SigningDirectory /inheritance:r /grant:r "$($env:USERDOMAIN)\$($env:USERNAME):(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not restrict signing-directory access.' }
$Bytes = New-Object byte[] 32
$Rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $Rng.GetBytes($Bytes) } finally { $Rng.Dispose() }
$Password = ([BitConverter]::ToString($Bytes)).Replace('-','').ToLowerInvariant()
$env:AUDIOSUBS_TV_KEY_PASSWORD = $Password
try {
  & $Keytool -genkeypair -alias audiosubs-tv -keystore $Keystore -storetype PKCS12 -keyalg RSA -keysize 3072 -sigalg SHA256withRSA -validity 10000 -dname 'CN=AudioSubs Reader TV,O=AudioSubs' -storepass:env AUDIOSUBS_TV_KEY_PASSWORD -keypass:env AUDIOSUBS_TV_KEY_PASSWORD
  if ($LASTEXITCODE -ne 0) { throw 'TV signing key generation failed.' }
  $PathProperty = $Keystore.Replace('\','/')
  [IO.File]::WriteAllText($Properties, "storeFile=$PathProperty`nstorePassword=$Password`nkeyAlias=audiosubs-tv`nkeyPassword=$Password`n")
} finally { Remove-Item Env:AUDIOSUBS_TV_KEY_PASSWORD -ErrorAction SilentlyContinue; $Password = $null; [Array]::Clear($Bytes,0,$Bytes.Length) }
Write-Host 'Stable local TV signing identity created outside Git. Back it up securely; losing it prevents in-place updates.'
