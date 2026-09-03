# phpbrew - Windows専用 PHP バージョンマネージャー エントリポイント

$LibDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $LibDir 'Common.ps1')
. (Join-Path $LibDir 'Remote.ps1')
. (Join-Path $LibDir 'Install.ps1')
. (Join-Path $LibDir 'Use.ps1')
. (Join-Path $LibDir 'Config.ps1')
. (Join-Path $LibDir 'Exec.ps1')
. (Join-Path $LibDir 'SelfUpdate.ps1')

function Show-Help {
    $lines = @(
        'phpbrew - Windows専用 PHP バージョンマネージャー',
        '',
        '使い方:',
        '  phpbrew help                              このヘルプを表示',
        '  phpbrew ls-remote                         インストール可能な PHP バージョン一覧を表示',
        '  phpbrew install <version> [--ts|--nts]    指定バージョンをインストール (例: 8.3.12, 8.3, latest)',
        '  phpbrew uninstall <version> [--ts|--nts]  指定バージョンをアンインストール',
        '  phpbrew use <version> [--ts|--nts]        使用する PHP バージョンを切り替え',
        '  phpbrew list, phpbrew ls                  インストール済みバージョン一覧を表示',
        '  phpbrew current                           現在使用中のバージョンを表示',
        '  phpbrew prune [--dry-run]                 各ブランチの最新パッチ以外の古いバージョンをまとめて削除（使用中のバージョンは保護、削除前に確認）',
        '  phpbrew exec [code]                       現在のバージョンで対話シェルを起動、または引数のコードを実行 (php -a / php -r)',
        '  phpbrew config threading [ts|nts]                既定の Thread Safe / Non-Thread Safe 設定を取得・変更',
        '  phpbrew config ini-template [development|production]  インストール時に php.ini の元にするテンプレートを取得・変更',
        '  phpbrew selfupdate                        phpbrew 本体を GitHub の最新版に更新',
        '',
        "<version> は '8.3.12' のようなフル指定の他、'8.3' のようなブランチ指定（最新パッチに解決）や",
        "'latest' も指定できます。--ts / --nts を省略した場合は 'phpbrew config threading' の設定値が使われます。",
        '',
        "install 時、同じマイナーバージョン・threading の php.ini が既にインストール済みならそれを引き継ぎ、",
        "無ければ 'phpbrew config ini-template' で指定したテンプレート (既定: development) から php.ini を作成します。"
    )
    foreach ($line in $lines) { Write-PhpbrewInfo $line }
}

function Get-ThreadingFlag {
    param([string[]]$Arguments)
    $threading = $null
    $rest = @()
    foreach ($a in $Arguments) {
        switch ($a) {
            '--ts'  { $threading = 'ts' }
            '--nts' { $threading = 'nts' }
            default { $rest += $a }
        }
    }
    [PSCustomObject]@{ Threading = $threading; Rest = $rest }
}

function Invoke-Phpbrew {
    param([string[]]$Arguments)

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        Show-Help
        return
    }

    $command = $Arguments[0]
    $rest = @()
    if ($Arguments.Count -gt 1) { $rest = $Arguments[1..($Arguments.Count - 1)] }

    switch ($command) {
        'help' { Show-Help }
        'ls-remote' { Show-RemoteVersionList }
        'install' {
            if ($rest.Count -lt 1) { Exit-WithError "使用法: phpbrew install <version> [--ts|--nts]" }
            $parsed = Get-ThreadingFlag -Arguments $rest
            if ($parsed.Rest.Count -lt 1) { Exit-WithError "使用法: phpbrew install <version> [--ts|--nts]" }
            Install-PhpVersion -VersionArg $parsed.Rest[0] -ThreadingFlag $parsed.Threading
        }
        'uninstall' {
            if ($rest.Count -lt 1) { Exit-WithError "使用法: phpbrew uninstall <version> [--ts|--nts]" }
            $parsed = Get-ThreadingFlag -Arguments $rest
            if ($parsed.Rest.Count -lt 1) { Exit-WithError "使用法: phpbrew uninstall <version> [--ts|--nts]" }
            Uninstall-PhpVersion -VersionArg $parsed.Rest[0] -ThreadingFlag $parsed.Threading
        }
        'use' {
            if ($rest.Count -lt 1) { Exit-WithError "使用法: phpbrew use <version> [--ts|--nts]" }
            $parsed = Get-ThreadingFlag -Arguments $rest
            if ($parsed.Rest.Count -lt 1) { Exit-WithError "使用法: phpbrew use <version> [--ts|--nts]" }
            Set-CurrentPhpVersion -VersionArg $parsed.Rest[0] -ThreadingFlag $parsed.Threading
        }
        'list' { Show-VersionList }
        'ls' { Show-VersionList }
        'current' { Show-CurrentVersion }
        'prune' {
            $dryRun = $rest -contains '--dry-run'
            Invoke-Prune -DryRun:$dryRun
        }
        'exec' { Invoke-PhpExec -CodeArgs $rest }
        'config' { Invoke-ConfigCommand -Arguments $rest }
        'selfupdate' { Invoke-SelfUpdate }
        default {
            Write-PhpbrewError "不明なコマンドです: $command"
            Show-Help
            exit 1
        }
    }
}

Invoke-Phpbrew -Arguments $args
