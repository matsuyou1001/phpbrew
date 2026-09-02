# phpbrew - use / list / current
# current ディレクトリジャンクションの管理と User PATH への登録

function Add-ToUserPath {
    param([Parameter(Mandatory)][string]$PathToAdd)
    $current = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $entries = @()
    if ($current) { $entries = $current -split ';' | Where-Object { $_ -ne '' } }
    $alreadyPresent = $entries | Where-Object { $_.TrimEnd('\') -ieq $PathToAdd.TrimEnd('\') }
    if (-not $alreadyPresent) {
        $entries += $PathToAdd
        [Environment]::SetEnvironmentVariable('PATH', ($entries -join ';'), 'User')
        Write-PhpbrewInfo "User PATH に追加しました: $PathToAdd (新しいシェルから有効になります)"
    }
    $processEntries = $env:Path -split ';' | Where-Object { $_ -ne '' }
    if (-not ($processEntries | Where-Object { $_.TrimEnd('\') -ieq $PathToAdd.TrimEnd('\') })) {
        $env:Path = "$env:Path;$PathToAdd"
    }
}

function Remove-CurrentLink {
    if (Test-Path -LiteralPath $Script:CurrentLink) {
        $item = Get-Item -LiteralPath $Script:CurrentLink -Force
        if ($item.LinkType -eq 'Junction') {
            [System.IO.Directory]::Delete($Script:CurrentLink, $false)
        } else {
            Remove-Item -LiteralPath $Script:CurrentLink -Recurse -Force
        }
    }
}

function Set-CurrentPhpVersion {
    param(
        [Parameter(Mandatory)][string]$VersionArg,
        [string]$ThreadingFlag
    )
    Initialize-PhpbrewHome
    $localName = Resolve-LocalVersionName -VersionInput $VersionArg -ThreadingOverride $ThreadingFlag
    $targetDir = Join-Path $Script:VersionsDir $localName

    if (-not (Test-Path -LiteralPath $targetDir)) {
        Exit-WithError "PHP $localName はインストールされていません。'phpbrew install $VersionArg' を実行してください。"
    }

    Remove-CurrentLink
    New-Item -ItemType Junction -Path $Script:CurrentLink -Target $targetDir | Out-Null
    Add-ToUserPath -PathToAdd $Script:CurrentLink

    Write-PhpbrewInfo "PHP $localName に切り替えました。"
}

function Show-VersionList {
    Initialize-PhpbrewHome
    $dirs = Get-InstalledVersionDirs
    if (-not $dirs -or $dirs.Count -eq 0) {
        Write-PhpbrewInfo "インストール済みの PHP バージョンはありません。'phpbrew install <version>' でインストールしてください。"
        return
    }
    $currentName = Get-CurrentVersionName
    foreach ($dir in $dirs) {
        if ($dir.Name -eq $currentName) {
            Write-PhpbrewInfo "* $($dir.Name)"
        } else {
            Write-PhpbrewInfo "  $($dir.Name)"
        }
    }
    Write-PhpbrewInfo ''
    if ($currentName) {
        Write-PhpbrewInfo "current: $currentName"
    } else {
        Write-PhpbrewInfo "current: (未設定)"
    }
}

function Show-CurrentVersion {
    Initialize-PhpbrewHome
    $currentName = Get-CurrentVersionName
    if ($currentName) {
        Write-PhpbrewInfo $currentName
    } else {
        Write-PhpbrewInfo "現在有効な PHP バージョンはありません。'phpbrew use <version>' で設定してください。"
    }
}
