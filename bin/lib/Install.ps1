# phpbrew - install / uninstall

function Install-PhpVersion {
    param(
        [Parameter(Mandatory)][string]$VersionArg,
        [string]$ThreadingFlag
    )
    Initialize-PhpbrewHome
    $threading = if ($ThreadingFlag) { $ThreadingFlag } else { (Get-PhpbrewConfig).threading }
    Assert-ValidThreading $threading

    $release = Resolve-RemoteVersion -Version $VersionArg -Threading $threading
    $localName = "$($release.Version)-$threading"
    $targetDir = Join-Path $Script:VersionsDir $localName

    if (Test-Path -LiteralPath $targetDir) {
        Write-PhpbrewInfo "PHP $localName は既にインストールされています。"
        return
    }

    $cachePath = Join-Path $Script:CacheDir $release.FileName
    if (-not (Test-Path -LiteralPath $cachePath)) {
        Write-PhpbrewInfo "ダウンロード中: $($release.Url)"
        Enable-Tls12
        try {
            Invoke-WebRequest -Uri $release.Url -OutFile $cachePath -UseBasicParsing
        } catch {
            if (Test-Path -LiteralPath $cachePath) { Remove-Item -LiteralPath $cachePath -Force }
            Exit-WithError "ダウンロードに失敗しました: $($_.Exception.Message)"
        }
    } else {
        Write-PhpbrewInfo "キャッシュ済みの zip を使用します: $cachePath"
    }

    if ($release.Sha256) {
        $actualHash = (Get-FileHash -LiteralPath $cachePath -Algorithm SHA256).Hash
        if ($actualHash -ne $release.Sha256.ToUpperInvariant()) {
            Remove-Item -LiteralPath $cachePath -Force
            Exit-WithError "チェックサムが一致しません。ダウンロードをやり直してください。"
        }
    }

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    try {
        Expand-Archive -LiteralPath $cachePath -DestinationPath $targetDir -Force
    } catch {
        Remove-Item -LiteralPath $targetDir -Recurse -Force -ErrorAction SilentlyContinue
        Exit-WithError "展開に失敗しました: $($_.Exception.Message)"
    }

    Write-PhpbrewInfo "PHP $localName をインストールしました。'phpbrew use $($release.Version)' で切り替えられます。"
}

function Uninstall-PhpVersion {
    param(
        [Parameter(Mandatory)][string]$VersionArg,
        [string]$ThreadingFlag
    )
    Initialize-PhpbrewHome
    $localName = Resolve-LocalVersionName -VersionInput $VersionArg -ThreadingOverride $ThreadingFlag
    $targetDir = Join-Path $Script:VersionsDir $localName

    if (-not (Test-Path -LiteralPath $targetDir)) {
        Exit-WithError "PHP $localName はインストールされていません。"
    }

    $current = Get-CurrentVersionName
    if ($current -eq $localName) {
        Exit-WithError "PHP $localName は現在使用中のため削除できません。先に 'phpbrew use <別のバージョン>' で切り替えてください。"
    }

    Remove-Item -LiteralPath $targetDir -Recurse -Force
    Write-PhpbrewInfo "PHP $localName をアンインストールしました。"
}
