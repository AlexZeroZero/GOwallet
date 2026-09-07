param(
    [switch]$Release,
    [string]$Python = 'python',
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$BuildRoot = 'D:\electrum-wallet-build',
    [string]$TempRoot = 'D:\wallet-tmp',
    [string]$SigningDirectory = ''
)
$ErrorActionPreference = 'Stop'
$walletSource = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$walletSourceItem = Get-Item -LiteralPath $walletSource
if ($walletSourceItem.LinkType -eq 'Junction') {
    $walletSource = [IO.Path]::GetFullPath(@($walletSourceItem.Target)[0])
}
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
if (Test-Path -LiteralPath $BuildRoot) {
    $walletJunction = Get-Item -LiteralPath $BuildRoot
    if ($walletJunction.LinkType -ne 'Junction' -or
        ([IO.Path]::GetFullPath(@($walletJunction.Target)[0]) -ne $walletSource)) {
        throw "BuildRoot must be a junction to this source checkout: $walletSource"
    }
} else {
    New-Item -ItemType Junction -Path $BuildRoot -Target $walletSource | Out-Null
}
$env:JAVA_HOME = $JavaHome
if ($Release) {
    . (Join-Path $PSScriptRoot 'load_android_signing.ps1') -JavaHome $JavaHome -SigningDirectory $SigningDirectory
}
$walletTemp = $TempRoot.Replace('\', '/')
$env:JAVA_TOOL_OPTIONS = "-Djava.io.tmpdir=$walletTemp -Djdk.net.unixdomain.tmpdir=$walletTemp"
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'core.longpaths'
$env:GIT_CONFIG_VALUE_0 = 'true'
[Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_android.overridePathCheck', 'true', 'Process')
if ($env:HTTPS_PROXY) {
    $walletProxy = [uri]$env:HTTPS_PROXY
    if ($walletProxy.UserInfo) { throw 'Configure authenticated Gradle proxies separately.' }
    $env:GRADLE_OPTS = "-Dhttps.proxyHost=$($walletProxy.Host) -Dhttps.proxyPort=$($walletProxy.Port) -Dhttp.proxyHost=$($walletProxy.Host) -Dhttp.proxyPort=$($walletProxy.Port)"
}
$goDesktopFlags = @{}
foreach ($goFlag in @('FLUTTER_WINDOWS', 'FLUTTER_LINUX', 'FLUTTER_MACOS')) {
    $goDesktopFlags[$goFlag] = [Environment]::GetEnvironmentVariable($goFlag, 'Process')
    # This helper builds Android only; avoid unrelated desktop plugin symlinks.
    [Environment]::SetEnvironmentVariable($goFlag, 'false', 'Process')
}
Push-Location $BuildRoot
try {
    & $Python tool/configure_electrum_wallet.py
    if ($LASTEXITCODE) { throw 'Flavor generation failed' }
    & flutter pub get --enforce-lockfile *> wallet-pub-get.log
    if ($LASTEXITCODE) {
        throw 'Dependency/platform generation failed; see wallet-pub-get.log. Enable Windows Developer Mode if Flutter requires symlink support.'
    }
    $goMode = if ($Release) { 'release' } else { 'debug' }
    & flutter build apk "--$goMode" --no-pub --target-platform android-arm64,android-x64
    if ($LASTEXITCODE) { throw 'Android build failed' }
    New-Item -ItemType Directory -Path dist -Force | Out-Null
    $goApk = "gowallet-1.0.0-android-$goMode.apk"
    Copy-Item -LiteralPath "build/app/outputs/flutter-apk/app-$goMode.apk" -Destination "dist/$goApk"
    $walletHash = (Get-FileHash "dist/$goApk" -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content dist/GOWALLET-SHA256SUMS "$walletHash  $goApk"
} finally {
    Pop-Location
    $env:GOWALLET_KEY_PASSWORD = $null
    foreach ($goFlag in $goDesktopFlags.Keys) {
        [Environment]::SetEnvironmentVariable($goFlag, $goDesktopFlags[$goFlag], 'Process')
    }
}
