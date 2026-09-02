# phpbrew - 共通ヘルパー
# パス定義・ホームディレクトリ初期化・config 読み書き・出力ユーティリティ

$Script:PhpbrewHome   = Join-Path $env:USERPROFILE '.phpbrew'
$Script:PhpbrewBinDir = Join-Path $Script:PhpbrewHome 'bin'
$Script:VersionsDir   = Join-Path $Script:PhpbrewHome 'versions'
$Script:CacheDir      = Join-Path $Script:PhpbrewHome 'cache'
$Script:CurrentLink   = Join-Path $Script:PhpbrewHome 'current'
$Script:ConfigPath    = Join-Path $Script:PhpbrewHome 'config.json'

$Script:DefaultConfig = @{ threading = 'nts' }

function Write-PhpbrewInfo {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Message)
    Write-Host $Message
}

function Write-PhpbrewError {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Exit-WithError {
    param([Parameter(Mandatory)][string]$Message)
    Write-PhpbrewError $Message
    exit 1
}

function Initialize-PhpbrewHome {
    foreach ($dir in @($Script:PhpbrewHome, $Script:VersionsDir, $Script:CacheDir)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    if (-not (Test-Path -LiteralPath $Script:ConfigPath)) {
        Save-PhpbrewConfig -Config $Script:DefaultConfig
    }
}

function Get-PhpbrewConfig {
    Initialize-PhpbrewHome
    $loaded = Get-Content -LiteralPath $Script:ConfigPath -Raw | ConvertFrom-Json
    $config = $Script:DefaultConfig.Clone()
    foreach ($prop in $loaded.PSObject.Properties) {
        $config[$prop.Name] = $prop.Value
    }
    return $config
}

function Save-PhpbrewConfig {
    param([Parameter(Mandatory)][hashtable]$Config)
    if (-not (Test-Path -LiteralPath $Script:PhpbrewHome)) {
        New-Item -ItemType Directory -Path $Script:PhpbrewHome -Force | Out-Null
    }
    $Config | ConvertTo-Json | Set-Content -LiteralPath $Script:ConfigPath -Encoding UTF8
}

function Assert-ValidThreading {
    param([Parameter(Mandatory)][string]$Threading)
    if ($Threading -notin @('ts', 'nts')) {
        Exit-WithError "threading は 'ts' または 'nts' を指定してください: $Threading"
    }
}

function Enable-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        # 古い .NET では Tls12 列挙値が無い場合があるため無視
    }
}

function Get-InstalledVersionDirs {
    Initialize-PhpbrewHome
    if (-not (Test-Path -LiteralPath $Script:VersionsDir)) {
        return @()
    }
    Get-ChildItem -LiteralPath $Script:VersionsDir -Directory | Sort-Object Name
}

function Resolve-LocalVersionName {
    param(
        [Parameter(Mandatory)][string]$VersionInput,
        [string]$ThreadingOverride
    )
    if ($VersionInput -match '^\d+\.\d+\.\d+-(ts|nts)$') {
        return $VersionInput
    }
    if ($VersionInput -match '^\d+\.\d+\.\d+$') {
        $threading = if ($ThreadingOverride) { $ThreadingOverride } else { (Get-PhpbrewConfig).threading }
        Assert-ValidThreading $threading
        return "$VersionInput-$threading"
    }
    Exit-WithError "バージョン指定の形式が不正です: $VersionInput (例: 8.3.12 または 8.3.12-nts)"
}

function Get-CurrentVersionName {
    if (-not (Test-Path -LiteralPath $Script:CurrentLink)) {
        return $null
    }
    $item = Get-Item -LiteralPath $Script:CurrentLink -Force
    if ($item.LinkType -ne 'Junction') {
        return $null
    }
    $target = $item.Target
    if ($target -is [array]) {
        $target = $target[0]
    }
    return Split-Path -Leaf $target
}
