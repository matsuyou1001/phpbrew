# phpbrew - install / uninstall

function Find-TemplatePhpIni {
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Threading,
        [Parameter(Mandatory)][string]$ExcludeDirName
    )
    $branch = ($Version -split '\.')[0..1] -join '.'
    $branchPattern = "^$([regex]::Escape($branch))\.\d+-(ts|nts)$"
    $candidates = Get-InstalledVersionDirs | Where-Object {
        $_.Name -ne $ExcludeDirName -and $_.Name -match $branchPattern
    }
    $sorted = $candidates | Sort-Object -Property `
        @{Expression = { if ($_.Name -like "*-$Threading") { 0 } else { 1 } } }, `
        @{Expression = { [version]($_.Name -replace '-(ts|nts)$', '') }; Descending = $true }
    foreach ($dir in $sorted) {
        $iniPath = Join-Path $dir.FullName 'php.ini'
        if (Test-Path -LiteralPath $iniPath) {
            return $iniPath
        }
    }
    return $null
}

function Initialize-PhpIni {
    param(
        [Parameter(Mandatory)][string]$TargetDir,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Threading,
        [Parameter(Mandatory)][string]$LocalName
    )
    $iniPath = Join-Path $TargetDir 'php.ini'
    if (Test-Path -LiteralPath $iniPath) { return }

    $template = Find-TemplatePhpIni -Version $Version -Threading $Threading -ExcludeDirName $LocalName
    if ($template) {
        Copy-Item -LiteralPath $template -Destination $iniPath -Force
        Write-PhpbrewInfo "同じマイナーバージョンの php.ini を引き継ぎました: $template"
        return
    }

    $iniTemplate = (Get-PhpbrewConfig).'ini-template'
    Assert-ValidIniTemplate $iniTemplate
    $templateIni = Join-Path $TargetDir "php.ini-$iniTemplate"
    if (Test-Path -LiteralPath $templateIni) {
        Copy-Item -LiteralPath $templateIni -Destination $iniPath -Force
        Write-PhpbrewInfo "php.ini-$iniTemplate から php.ini を作成しました。"
    }
}

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
        $actualHash = Get-Sha256Hex -Path $cachePath
        if ($actualHash -ne $release.Sha256.ToLowerInvariant()) {
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

    Initialize-PhpIni -TargetDir $targetDir -Version $release.Version -Threading $threading -LocalName $localName

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

function Protect-PhpVersion {
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

    $protected = Get-ProtectedVersions
    if ($protected -contains $localName) {
        Write-PhpbrewInfo "PHP $localName は既に保護されています。"
        return
    }

    Save-ProtectedVersions -Versions ($protected + $localName)
    Write-PhpbrewInfo "PHP $localName を保護しました。'phpbrew prune' の削除対象から除外されます。"
}

function Unprotect-PhpVersion {
    param(
        [Parameter(Mandatory)][string]$VersionArg,
        [string]$ThreadingFlag
    )
    Initialize-PhpbrewHome
    $localName = Resolve-LocalVersionName -VersionInput $VersionArg -ThreadingOverride $ThreadingFlag

    $protected = Get-ProtectedVersions
    if ($protected -notcontains $localName) {
        Write-PhpbrewInfo "PHP $localName は保護されていません。"
        return
    }

    Save-ProtectedVersions -Versions (@($protected | Where-Object { $_ -ne $localName }))
    Write-PhpbrewInfo "PHP $localName の保護を解除しました。"
}

function Invoke-Prune {
    param([switch]$DryRun)
    Initialize-PhpbrewHome
    $dirs = Get-InstalledVersionDirs
    if (-not $dirs -or $dirs.Count -eq 0) {
        Write-PhpbrewInfo "インストール済みの PHP バージョンはありません。"
        return
    }
    $currentName = Get-CurrentVersionName
    $protectedVersions = Get-ProtectedVersions

    $groups = $dirs | Group-Object {
        if ($_.Name -match '^(?<branch>\d+\.\d+)\.\d+-(?<th>ts|nts)$') {
            "$($Matches['branch'])-$($Matches['th'])"
        } else {
            $_.Name
        }
    }

    $toRemove = @()
    $skippedProtected = @()
    foreach ($g in $groups) {
        if ($g.Group.Count -le 1) { continue }
        $sorted = $g.Group | Sort-Object { [version]($_.Name -replace '-(ts|nts)$', '') } -Descending
        foreach ($d in ($sorted | Select-Object -Skip 1)) {
            if ($d.Name -eq $currentName) { continue }
            if ($protectedVersions -contains $d.Name) {
                $skippedProtected += $d
                continue
            }
            $toRemove += $d
        }
    }

    if ($skippedProtected.Count -gt 0) {
        Write-PhpbrewInfo "以下の $($skippedProtected.Count) 件は保護されているため削除対象から除外します:"
        foreach ($d in $skippedProtected) {
            Write-PhpbrewInfo "  $($d.Name)"
        }
        Write-PhpbrewInfo ''
    }

    if ($toRemove.Count -eq 0) {
        Write-PhpbrewInfo "削除対象の古いバージョンはありません（各ブランチの最新パッチのみがインストールされています）。"
        return
    }

    Write-PhpbrewInfo "以下の $($toRemove.Count) 件を削除します:"
    foreach ($d in $toRemove) {
        Write-PhpbrewInfo "  $($d.Name)"
    }

    if ($DryRun) {
        Write-PhpbrewInfo ''
        Write-PhpbrewInfo "--dry-run のため削除は行っていません。"
        return
    }

    Write-PhpbrewInfo ''
    $answer = Read-Host "削除してよろしいですか？ (y/N)"
    if ($answer -notin @('y', 'Y', 'yes', 'Yes')) {
        Write-PhpbrewInfo "キャンセルしました。"
        return
    }

    foreach ($d in $toRemove) {
        Remove-Item -LiteralPath $d.FullName -Recurse -Force
        Write-PhpbrewInfo "削除しました: $($d.Name)"
    }
    Write-PhpbrewInfo "$($toRemove.Count) 件の古いバージョンを削除しました。"
}
