# phpbrew - リモートの PHP Windows ビルド一覧取得・解決
# 情報源:
#   現行ブランチの最新パッチ: https://downloads.php.net/~windows/releases/releases.json
#   過去バージョン(アーカイブ): https://downloads.php.net/~windows/releases/archives/ (HTMLディレクトリ一覧)

$Script:ReleasesBaseUrl  = 'https://downloads.php.net/~windows/releases/'
$Script:ReleasesJsonUrl  = $Script:ReleasesBaseUrl + 'releases.json'
$Script:ArchivesBaseUrl  = $Script:ReleasesBaseUrl + 'archives/'

function Get-RemoteCurrentReleases {
    Enable-Tls12
    $json = Invoke-RestMethod -Uri $Script:ReleasesJsonUrl -UseBasicParsing
    $results = @()
    foreach ($branchProp in $json.PSObject.Properties) {
        $entry = $branchProp.Value
        if (-not $entry.version) { continue }
        foreach ($variantProp in $entry.PSObject.Properties) {
            if ($variantProp.Name -notmatch '^(?<threading>ts|nts)-.*-x64$') { continue }
            $zip = $variantProp.Value.zip
            if (-not $zip -or -not $zip.path) { continue }
            $results += [PSCustomObject]@{
                Version   = $entry.version
                Threading = $Matches['threading']
                Url       = $Script:ReleasesBaseUrl + $zip.path
                FileName  = Split-Path -Leaf $zip.path
                Sha256    = $zip.sha256
                Source    = 'current'
            }
        }
    }
    return $results
}

function Get-RemoteArchivedReleases {
    Enable-Tls12
    $html = Invoke-WebRequest -Uri $Script:ArchivesBaseUrl -UseBasicParsing
    $results = @()
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($m in [regex]::Matches($html.Content, 'href="(?<name>php-[^"]+\.zip)"')) {
        $fileName = $m.Groups['name'].Value
        if ($fileName -match '(?i)(debug-pack|devel-pack|test-pack|-src\.zip$)') { continue }
        if ($fileName -notmatch '(?i)^php-(?<ver>\d+\.\d+\.\d+)(?<nts>-nts)?-Win32-(?:vc|vs)\d+-(?<arch>x86|x64)\.zip$') { continue }
        if ($Matches['arch'] -ne 'x64') { continue }
        if (-not $seen.Add($fileName)) { continue }
        $results += [PSCustomObject]@{
            Version   = $Matches['ver']
            Threading = $(if ($Matches['nts']) { 'nts' } else { 'ts' })
            Url       = $Script:ArchivesBaseUrl + $fileName
            FileName  = $fileName
            Sha256    = $null
            Source    = 'archive'
        }
    }
    return $results
}

function Get-AllRemoteReleases {
    $current = Get-RemoteCurrentReleases
    $archived = Get-RemoteArchivedReleases
    $known = New-Object 'System.Collections.Generic.HashSet[string]'
    $all = New-Object System.Collections.ArrayList
    foreach ($r in $current) {
        [void]$all.Add($r)
        [void]$known.Add("$($r.Version)|$($r.Threading)")
    }
    foreach ($r in $archived) {
        if ($known.Add("$($r.Version)|$($r.Threading)")) {
            [void]$all.Add($r)
        }
    }
    return $all
}

function Sort-VersionStrings {
    param([Parameter(Mandatory)][string[]]$Versions)
    $Versions | Sort-Object { [version]$_ }
}

function Resolve-RemoteVersion {
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Threading
    )
    Assert-ValidThreading $Threading
    $releases = Get-AllRemoteReleases | Where-Object { $_.Threading -eq $Threading }

    if ($Version -eq 'latest') {
        $best = $releases | Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1
        if (-not $best) { Exit-WithError "リモートで利用可能な PHP バージョンが見つかりませんでした。" }
        return $best
    }

    if ($Version -match '^\d+\.\d+\.\d+$') {
        $match = $releases | Where-Object { $_.Version -eq $Version } | Select-Object -First 1
        if (-not $match) {
            Exit-WithError "PHP $Version ($Threading) はリモートに見つかりませんでした。'phpbrew ls-remote' で確認してください。"
        }
        return $match
    }

    if ($Version -match '^\d+\.\d+$') {
        $branchMatches = $releases | Where-Object { $_.Version -like "$Version.*" }
        $best = $branchMatches | Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1
        if (-not $best) {
            Exit-WithError "ブランチ $Version の PHP はリモートに見つかりませんでした。'phpbrew ls-remote' で確認してください。"
        }
        return $best
    }

    Exit-WithError "バージョン指定の形式が不正です: $Version (例: 8.3.12, 8.3, latest)"
}

function Show-RemoteVersionList {
    $releases = Get-AllRemoteReleases
    $versions = $releases | Select-Object -ExpandProperty Version -Unique
    $grouped = $versions | Group-Object { ($_ -split '\.')[0..1] -join '.' } | Sort-Object { [version]("$($_.Name).0") }

    foreach ($group in $grouped) {
        $sorted = Sort-VersionStrings -Versions $group.Group
        Write-PhpbrewInfo ("{0,-6} {1}" -f $group.Name, ($sorted -join '  '))
    }
    Write-PhpbrewInfo ''
    Write-PhpbrewInfo "TS/NTS 各バージョンとも 'phpbrew install <version> [--ts|--nts]' でインストールできます。"
}
