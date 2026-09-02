# phpbrew セットアップスクリプト
# bin\ 以下を %USERPROFILE%\.phpbrew\bin にコピーし、User PATH に登録する

$RepoRoot = $PSScriptRoot
$SrcBinDir = Join-Path $RepoRoot 'bin'

. (Join-Path $SrcBinDir 'lib\Common.ps1')
. (Join-Path $SrcBinDir 'lib\Use.ps1')

Initialize-PhpbrewHome

if (-not (Test-Path -LiteralPath $Script:PhpbrewBinDir)) {
    New-Item -ItemType Directory -Path $Script:PhpbrewBinDir -Force | Out-Null
}
Copy-Item -Path (Join-Path $SrcBinDir '*') -Destination $Script:PhpbrewBinDir -Recurse -Force

Add-ToUserPath -PathToAdd $Script:PhpbrewBinDir

Write-PhpbrewInfo ''
Write-PhpbrewInfo "phpbrew のセットアップが完了しました。"
Write-PhpbrewInfo "新しいターミナルを開いて 'phpbrew help' を実行してください。"
