# phpbrew - exec (現在のバージョンで対話シェル起動 / コード実行)

function Invoke-PhpExec {
    param([string[]]$CodeArgs)

    Initialize-PhpbrewHome
    if (-not (Test-Path -LiteralPath $Script:CurrentLink)) {
        Exit-WithError "現在使用中の PHP バージョンがありません。'phpbrew use <version>' を実行してください。"
    }
    $phpExe = Join-Path $Script:CurrentLink 'php.exe'
    if (-not (Test-Path -LiteralPath $phpExe)) {
        Exit-WithError "php.exe が見つかりません: $phpExe"
    }

    if (-not $CodeArgs -or $CodeArgs.Count -eq 0) {
        & $phpExe -a
    } else {
        $code = $CodeArgs -join ' '
        & $phpExe -r $code
    }
    exit $LASTEXITCODE
}
