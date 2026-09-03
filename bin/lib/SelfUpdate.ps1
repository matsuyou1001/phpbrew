# phpbrew - selfupdate (GitHub リポジトリから本体を更新)

$Script:SelfUpdateRepoUrl    = 'https://github.com/matsuyou1001/phpbrew'
$Script:SelfUpdateArchiveUrl = $Script:SelfUpdateRepoUrl + '/archive/refs/heads/main.zip'

function Invoke-SelfUpdate {
    Enable-Tls12

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("phpbrew-selfupdate-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $zipPath = Join-Path $tempDir 'phpbrew.zip'

    try {
        Write-PhpbrewInfo "GitHub ($Script:SelfUpdateRepoUrl) から最新版を取得しています..."
        try {
            Invoke-WebRequest -Uri $Script:SelfUpdateArchiveUrl -OutFile $zipPath -UseBasicParsing
        } catch {
            Exit-WithError "最新版の取得に失敗しました: $($_.Exception.Message)"
        }

        $extractDir = Join-Path $tempDir 'extracted'
        try {
            Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
        } catch {
            Exit-WithError "取得したアーカイブの展開に失敗しました: $($_.Exception.Message)"
        }

        $rootDir = Get-ChildItem -LiteralPath $extractDir -Directory | Select-Object -First 1
        if (-not $rootDir) {
            Exit-WithError "取得したアーカイブの中身を確認できませんでした。"
        }

        $newBinDir = Join-Path $rootDir.FullName 'bin'
        if (-not (Test-Path -LiteralPath $newBinDir)) {
            Exit-WithError "取得したアーカイブに bin フォルダが見つかりませんでした。"
        }

        if (-not (Test-Path -LiteralPath $Script:PhpbrewBinDir)) {
            New-Item -ItemType Directory -Path $Script:PhpbrewBinDir -Force | Out-Null
        }
        Copy-Item -Path (Join-Path $newBinDir '*') -Destination $Script:PhpbrewBinDir -Recurse -Force

        Write-PhpbrewInfo "phpbrew を最新版に更新しました。"
    } finally {
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
