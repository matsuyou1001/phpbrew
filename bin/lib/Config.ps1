# phpbrew - config (既定の TS/NTS 設定など)

function Show-Config {
    $config = Get-PhpbrewConfig
    Write-PhpbrewInfo "threading: $($config.threading)"
    Write-PhpbrewInfo "ini-template: $($config.'ini-template')"
}

function Set-ConfigThreading {
    param([Parameter(Mandatory)][string]$Threading)
    Assert-ValidThreading $Threading
    $config = Get-PhpbrewConfig
    $config['threading'] = $Threading
    Save-PhpbrewConfig -Config $config
    Write-PhpbrewInfo "threading を $Threading に設定しました。"
}

function Set-ConfigIniTemplate {
    param([Parameter(Mandatory)][string]$IniTemplate)
    Assert-ValidIniTemplate $IniTemplate
    $config = Get-PhpbrewConfig
    $config['ini-template'] = $IniTemplate
    Save-PhpbrewConfig -Config $config
    Write-PhpbrewInfo "ini-template を $IniTemplate に設定しました。"
}

function Invoke-ConfigCommand {
    param([string[]]$Arguments)
    if (-not $Arguments -or $Arguments.Count -eq 0) {
        Show-Config
        return
    }
    $key = $Arguments[0]
    switch ($key) {
        'threading' {
            if ($Arguments.Count -ge 2) {
                Set-ConfigThreading -Threading $Arguments[1]
            } else {
                Write-PhpbrewInfo (Get-PhpbrewConfig).threading
            }
        }
        'ini-template' {
            if ($Arguments.Count -ge 2) {
                Set-ConfigIniTemplate -IniTemplate $Arguments[1]
            } else {
                Write-PhpbrewInfo (Get-PhpbrewConfig).'ini-template'
            }
        }
        default {
            Exit-WithError "未知の設定キーです: $key (利用可能: threading, ini-template)"
        }
    }
}
