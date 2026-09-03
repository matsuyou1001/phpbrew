# phpbrew アーキテクチャ

phpbrew は Windows 専用の PHP バージョンマネージャーです。外部ランタイムに依存せず、
Windows 標準の PowerShell（5.1 以降）だけで動作する PowerShell スクリプト群として実装されています。
本ドキュメントは、リポジトリのディレクトリ構造と各ファイルの役割、実行時のデータ配置、
コマンドがどのように処理されるかをまとめたものです。

## リポジトリのディレクトリ構造

```
phpbrew/
├── README.md               利用者向けドキュメント（セットアップ・コマンド一覧・使用例）
├── ARCHITECTURE.md          本ドキュメント（開発者向け設計資料）
├── Setup.ps1                初回セットアップスクリプト
└── bin/
    ├── phpbrew.cmd          cmd.exe / PATH から呼び出すための薄いシム
    ├── phpbrew.ps1           エントリポイント（コマンドのディスパッチ・ヘルプ表示）
    └── lib/
        ├── Common.ps1        共通ヘルパー（パス定義、config 読み書き、バージョン名解決など）
        ├── Config.ps1        `config` コマンド
        ├── Exec.ps1          `exec` コマンド
        ├── Install.ps1       `install` / `uninstall` / `protect` / `unprotect` / `prune`
        ├── Remote.ps1        リモート（windows.php.net）のバージョン一覧取得・解決
        ├── SelfUpdate.ps1    `selfupdate` コマンド
        └── Use.ps1           `use` / `list` / `current`
```

`bin/` 以下がそのまま `%USERPROFILE%\.phpbrew\bin` にコピーされ、実行時の本体になります
（`Setup.ps1` および `selfupdate` が行うコピー処理）。リポジトリ直下の `README.md` /
`ARCHITECTURE.md` / `Setup.ps1` はコピー対象外です。

## 各ファイルの役割

### Setup.ps1
初回セットアップ用スクリプト。`bin\` 以下一式を `%USERPROFILE%\.phpbrew\bin` にコピーし、
そのディレクトリをユーザー環境変数 `PATH` に追加します。`Common.ps1` と `Use.ps1` を
dot-source して `Initialize-PhpbrewHome` / `Add-ToUserPath` を再利用しています。

### bin/phpbrew.cmd
PATH 上から `phpbrew` として直接実行できるようにするための cmd シム。実体は
`powershell -File phpbrew.ps1 %*` の呼び出しのみです。

### bin/phpbrew.ps1
エントリポイント。`lib/*.ps1` をすべて dot-source した後、`Invoke-Phpbrew` で
サブコマンド（`install` / `use` / `config` など）を解析し、対応する関数へディスパッチします。
`--ts` / `--nts` フラグの抽出（`Get-ThreadingFlag`）と `phpbrew help` の本文もここにあります。

### bin/lib/Common.ps1
全コマンドから参照される共通基盤です。

- パス定義: `$Script:PhpbrewHome`（`%USERPROFILE%\.phpbrew`）配下の `bin` / `versions` /
  `cache` / `current` / `config.json` の各パスをスクリプトスコープ変数として定義
- `Initialize-PhpbrewHome`: 必要なディレクトリと既定の `config.json` を作成
- `Get-PhpbrewConfig` / `Save-PhpbrewConfig`: `config.json` の読み書き
- `Get-ProtectedVersions` / `Save-ProtectedVersions`: `prune` 対象から除外するバージョンの管理
- `Assert-ValidThreading` / `Assert-ValidIniTemplate`: 入力値のバリデーション
- `Get-Sha256Hex`: ダウンロードした zip のチェックサム検証用
- `Get-InstalledVersionDirs`: `versions\` 配下のインストール済みバージョンディレクトリ一覧
- `Resolve-LocalVersionName`: コマンド引数のバージョン文字列をローカルディレクトリ名
  （`X.Y.Z-ts` / `X.Y.Z-nts`）へ解決。フル指定・`-ts`/`-nts` 付きフル指定のほか、
  `-AllowBranch` を指定した呼び出し元（`use` のみ）に限り `X.Y` のブランチ指定も受け付ける
- `Resolve-LocalBranchVersionName`: `X.Y` ブランチ指定をインストール済みバージョンの中から
  解決するための内部ヘルパー（後述「バージョン解決の設計」参照）
- `Get-CurrentVersionName`: `current` ジャンクションのリンク先からバージョン名を取得

### bin/lib/Config.ps1
`phpbrew config [threading|ini-template] [値]` を処理します。値を省略すると現在の設定を表示、
指定するとバリデーション後に `config.json` へ保存します。

### bin/lib/Exec.ps1
`phpbrew exec [code]` を処理します。`current` ジャンクション配下の `php.exe` を実行し、
引数があれば `php -r <code>`、無ければ `php -a`（対話シェル）を起動して終了コードを引き継ぎます。

### bin/lib/Install.ps1
バージョンのインストール・削除・保護に関する処理をまとめています。

- `Install-PhpVersion`: `Resolve-RemoteVersion`（Remote.ps1）でダウンロード先を解決し、
  zip を `cache\` にダウンロード（キャッシュがあれば再利用）、SHA-256 検証（現行ブランチのみ）、
  `versions\<local-name>\` へ展開し、`Initialize-PhpIni` で php.ini を用意
- `Find-TemplatePhpIni` / `Initialize-PhpIni`: 同じマイナーバージョン・threading の
  既存インストールから php.ini を引き継ぐか、`config ini-template` のテンプレートから新規作成
- `Uninstall-PhpVersion`: 使用中でなければバージョンディレクトリを削除
- `Protect-PhpVersion` / `Unprotect-PhpVersion`: `config.json` の `protected` リストを更新
- `Invoke-Prune`: マイナーバージョン・threading ごとにグループ化し、最新パッチ以外
  （使用中・保護中を除く）を確認の上で一括削除

### bin/lib/Remote.ps1
windows.php.net からのリモートバージョン情報取得・解決を担当します。

- `Get-RemoteCurrentReleases`: `releases.json`（現行ブランチの最新パッチ、SHA-256 付き）を取得
- `Get-RemoteArchivedReleases`: `releases/archives/` の HTML ディレクトリ一覧をパースして
  EOL 版も含めた過去バージョンを取得（チェックサムなし）
- `Get-AllRemoteReleases`: 上記 2 つを統合（現行ブランチを優先し、重複を除外）
- `Resolve-RemoteVersion`: `install` に渡されたバージョン文字列（フル指定 / ブランチ指定 /
  `latest`）をリモートのリリース情報 1 件に解決

### bin/lib/SelfUpdate.ps1
`phpbrew selfupdate` を処理します。GitHub リポジトリの `main` ブランチを zip で取得・展開し、
中の `bin\` を `%USERPROFILE%\.phpbrew\bin` に上書きコピーします（PATH 設定は変更しません）。

### bin/lib/Use.ps1
現在使用中バージョンの切り替え・参照に関する処理です。

- `Add-ToUserPath` / `Remove-CurrentLink`: User PATH への登録、`current` ジャンクションの削除
- `Set-CurrentPhpVersion`: `Resolve-LocalVersionName -AllowBranch` でバージョン名を解決し、
  `current` ジャンクションを張り替える（`use` の実体。ブランチ指定を許可する唯一の呼び出し元）
- `Show-VersionList` / `Show-CurrentVersion`: `list`（`ls`）/ `current` の表示処理

## 実行時のデータ配置（%USERPROFILE%\.phpbrew）

```
%USERPROFILE%\.phpbrew\
  bin\        phpbrew 本体（PATH に登録される。リポジトリの bin\ のコピー）
  config.json 既定の threading / ini-template 設定、prune から保護するバージョン一覧
  versions\   インストール済みの PHP 本体（例: versions\8.3.12-nts\、php.ini を含む）
  cache\      ダウンロード済み zip のキャッシュ
  current     使用中バージョンを指すディレクトリジャンクション（PATH に登録される）
```

`current` はディレクトリジャンクションであるため、`use` によるリンク先の切り替えは
既に開いているターミナルにも即座に反映されます。

## コマンドディスパッチの流れ

1. `phpbrew.cmd`（または PATH 上の `phpbrew`）→ `phpbrew.ps1` を呼び出し
2. `phpbrew.ps1` が `lib/*.ps1` を dot-source し、`Invoke-Phpbrew` が第一引数（サブコマンド）で
   分岐
3. `--ts` / `--nts` を含むコマンドは `Get-ThreadingFlag` でフラグと残り引数を分離してから
   各コマンド関数（`Install-PhpVersion` / `Set-CurrentPhpVersion` など）へ渡す
4. 各コマンド関数は `Common.ps1` の共通ヘルパー（config 読み書き・バージョン名解決・
   インストール済み一覧取得）を介して `versions\` ディレクトリと `config.json` を操作する

## バージョン解決の設計

ローカルにインストール済みのバージョンは `versions\<version>-<threading>\`
（例: `8.3.12-nts`）というディレクトリ名で管理されます。コマンド引数からこの
ディレクトリ名を導く処理が `Resolve-LocalVersionName` です。

| 入力形式 | 例 | 解決方法 |
|---|---|---|
| フル指定 + threading | `8.3.12-nts` | そのまま利用 |
| フル指定 | `8.3.12` | `--ts`/`--nts` 指定、なければ `config threading` を末尾に付与 |
| ブランチ指定（`use` のみ） | `8.3` | 下記参照 |

`use` コマンドのみ `-AllowBranch` を付けて呼び出しており、`X.Y` 形式のブランチ指定を
`Resolve-LocalBranchVersionName` で解決します。

1. `versions\` から `X.Y.*-(ts|nts)` にマッチするディレクトリを収集し、無ければエラー
2. `--ts`/`--nts` が明示されていれば、その threading に絞った上で最新リビジョンを選択
3. 明示が無ければ、まずブランチ内の最新リビジョンを求め、
   - そのリビジョンが TS/NTS 片方のみなら、それを採用
   - TS/NTS 両方あれば `config threading` の設定値で選択

`uninstall` / `protect` / `unprotect` は `-AllowBranch` を付けずに呼び出しており、
ブランチ指定や `latest` は受け付けず、フル指定のみを許可します
（誤って複数バージョンをまとめて操作してしまうことを防ぐため）。

リモートのバージョン解決（`install` が使う `Resolve-RemoteVersion`）は上記とは別の関数で、
windows.php.net 上のリリース一覧に対してフル指定 / ブランチ指定 / `latest` を解決します。
こちらはローカルの `versions\` を参照しません。
