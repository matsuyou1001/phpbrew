# phpbrew - 共通ヘルパー
# パス定義・ホームディレクトリ初期化・config 読み書き・出力ユーティリティ

$Script:PhpbrewHome   = Join-Path $env:USERPROFILE '.phpbrew'
$Script:PhpbrewBinDir = Join-Path $Script:PhpbrewHome 'bin'
$Script:VersionsDir   = Join-Path $Script:PhpbrewHome 'versions'
$Script:CacheDir      = Join-Path $Script:PhpbrewHome 'cache'
$Script:CurrentLink   = Join-Path $Script:PhpbrewHome 'current'
$Script:ConfigPath    = Join-Path $Script:PhpbrewHome 'config.json'

$Script:DefaultConfig = @{ threading = 'nts'; 'ini-template' = 'development'; protected = @() }

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

function Get-ProtectedVersions {
    $config = Get-PhpbrewConfig
    if (-not $config.ContainsKey('protected') -or -not $config['protected']) {
        return @()
    }
    return @($config['protected'])
}

function Save-ProtectedVersions {
    param([string[]]$Versions)
    $config = Get-PhpbrewConfig
    $config['protected'] = @($Versions | Sort-Object -Unique)
    Save-PhpbrewConfig -Config $config
}

function Assert-ValidThreading {
    param([Parameter(Mandatory)][string]$Threading)
    if ($Threading -notin @('ts', 'nts')) {
        Exit-WithError "threading は 'ts' または 'nts' を指定してください: $Threading"
    }
}

function Assert-ValidIniTemplate {
    param([Parameter(Mandatory)][string]$IniTemplate)
    if ($IniTemplate -notin @('development', 'production')) {
        Exit-WithError "ini-template は 'development' または 'production' を指定してください: $IniTemplate"
    }
}

function Get-Sha256Hex {
    param([Parameter(Mandatory)][string]$Path)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $hashBytes = $sha256.ComputeHash($stream)
        } finally {
            $stream.Dispose()
        }
    } finally {
        $sha256.Dispose()
    }
    return -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
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

function Resolve-LocalBranchVersionName {
    param(
        [Parameter(Mandatory)][string]$Branch,
        [string]$ThreadingOverride
    )
    $pattern = "^$([regex]::Escape($Branch))\.\d+-(ts|nts)$"
    $candidates = @(Get-InstalledVersionDirs | Where-Object { $_.Name -match $pattern })
    if ($candidates.Count -eq 0) {
        Exit-WithError "PHP $Branch 系はインストールされていません。'phpbrew install $Branch' を実行してください。"
    }

    if ($ThreadingOverride) {
        Assert-ValidThreading $ThreadingOverride
        $candidates = @($candidates | Where-Object { $_.Name -like "*-$ThreadingOverride" })
        if ($candidates.Count -eq 0) {
            Exit-WithError "PHP $Branch 系の $ThreadingOverride 版はインストールされていません。"
        }
        return ($candidates | Sort-Object { [version]($_.Name -replace '-(ts|nts)$', '') } -Descending | Select-Object -First 1).Name
    }

    $latestVersion = $candidates | ForEach-Object { $_.Name -replace '-(ts|nts)$', '' } | Sort-Object { [version]$_ } -Descending | Select-Object -First 1
    $sameRevision = @($candidates | Where-Object { ($_.Name -replace '-(ts|nts)$', '') -eq $latestVersion })

    if ($sameRevision.Count -eq 1) {
        return $sameRevision[0].Name
    }

    $threading = (Get-PhpbrewConfig).threading
    Assert-ValidThreading $threading
    $match = $sameRevision | Where-Object { $_.Name -like "*-$threading" }
    if (-not $match) {
        Exit-WithError "PHP $latestVersion の $threading 版はインストールされていません。"
    }
    return $match.Name
}

function Resolve-LocalVersionName {
    param(
        [Parameter(Mandatory)][string]$VersionInput,
        [string]$ThreadingOverride,
        [switch]$AllowBranch
    )
    if ($VersionInput -match '^\d+\.\d+\.\d+-(ts|nts)$') {
        return $VersionInput
    }
    if ($VersionInput -match '^\d+\.\d+\.\d+$') {
        $threading = if ($ThreadingOverride) { $ThreadingOverride } else { (Get-PhpbrewConfig).threading }
        Assert-ValidThreading $threading
        return "$VersionInput-$threading"
    }
    if ($AllowBranch -and $VersionInput -match '^\d+\.\d+$') {
        return Resolve-LocalBranchVersionName -Branch $VersionInput -ThreadingOverride $ThreadingOverride
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
