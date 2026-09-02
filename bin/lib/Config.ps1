# phpbrew - config (既定の TS/NTS 設定など)

function Show-Config {
    $config = Get-PhpbrewConfig
    Write-PhpbrewInfo "threading: $($config.threading)"
}

function Set-ConfigThreading {
    param([Parameter(Mandatory)][string]$Threading)
    Assert-ValidThreading $Threading
    $config = Get-PhpbrewConfig
    $config['threading'] = $Threading
    Save-PhpbrewConfig -Config $config
    Write-PhpbrewInfo "threading を $Threading に設定しました。"
}

function Invoke-ConfigCommand {
    param([string[]]$Arguments)
    if (-not $Arguments -or $Arguments.Count -eq 0) {
        Show-Config
        return
    }
    $key = $Arguments[0]
    if ($key -ne 'threading') {
        Exit-WithError "未知の設定キーです: $key (利用可能: threading)"
    }
    if ($Arguments.Count -ge 2) {
        Set-ConfigThreading -Threading $Arguments[1]
    } else {
        Write-PhpbrewInfo (Get-PhpbrewConfig).threading
    }
}
