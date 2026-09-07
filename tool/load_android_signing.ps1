param([Parameter(Mandatory=$true)][string]$JavaHome, [string]$SigningDirectory = '')
$ErrorActionPreference = 'Stop'
$goRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$goPrivate = if ($SigningDirectory) { (Resolve-Path -LiteralPath $SigningDirectory).Path } else { Join-Path $goRoot '.private\gowallet-signing' }
if ($SigningDirectory -and (!(Test-Path -LiteralPath (Join-Path $goPrivate 'password.dpapi')) -or !(Test-Path -LiteralPath (Join-Path $goPrivate 'gowallet-release.p12')))) {
    throw 'External signing directory must contain the existing key and protected password.'
}
New-Item -ItemType Directory -Path $goPrivate -Force | Out-Null
$goIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls $goPrivate /inheritance:r /grant:r "${goIdentity}:(OI)(CI)F" 'SYSTEM:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE) { throw 'Cannot restrict signing directory permissions' }
$goPassPath = Join-Path $goPrivate 'password.dpapi'
$goKeyPath = Join-Path $goPrivate 'gowallet-release.p12'
if (!(Test-Path -LiteralPath $goPassPath)) {
    if (Test-Path -LiteralPath $goKeyPath) { throw 'Signing password missing; restore backup. Do not replace the key.' }
    $goRandom = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Fill($goRandom)
    $goPlain = [Convert]::ToBase64String($goRandom)
    $goSecure = ConvertTo-SecureString $goPlain -AsPlainText -Force
    ConvertFrom-SecureString $goSecure | Set-Content -LiteralPath $goPassPath -Encoding ascii
} else {
    $goSecure = (Get-Content -LiteralPath $goPassPath -Raw).Trim() | ConvertTo-SecureString
}
$goPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($goSecure)
try { $env:GOWALLET_KEY_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($goPointer) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($goPointer) }
$env:GOWALLET_KEYSTORE = $goKeyPath
$env:GOWALLET_KEY_ALIAS = 'gowallet'
if (!(Test-Path -LiteralPath $goKeyPath)) {
    & (Join-Path $JavaHome 'bin\keytool.exe') -genkeypair -keystore $goKeyPath -storetype PKCS12 -storepass:env GOWALLET_KEY_PASSWORD -keypass:env GOWALLET_KEY_PASSWORD -alias gowallet -keyalg RSA -keysize 3072 -sigalg SHA256withRSA -validity 10000 -dname 'CN=GOwallet Local Signing'
    if ($LASTEXITCODE) { throw 'Signing key generation failed' }
}
$goPlain = $null
$goSecure = $null
Write-Host 'Local signing identity loaded; private material is excluded from source archives.'
