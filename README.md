# phpbrew

Windows 専用の PHP バージョンマネージャーです。[nodebrew](https://github.com/hokaccha/nodebrew) と同様のコマンド体系で、複数の PHP バージョンをダウンロードし、使用するバージョンを切り替えられます。

- 対応 OS: Windows のみ（クロスプラットフォーム非対応）
- 対応アーキテクチャ: x64 のみ
- ダウンロード元: [windows.php.net](https://windows.php.net/) の公式ビルド（`releases/` および `releases/archives/`）
- 追加ランタイム不要（Windows 標準の PowerShell 5.1 以降で動作）

## セットアップ

このリポジトリをクローンし、`Setup.ps1` を実行してください。

```powershell
git clone https://github.com/matsuyou1001/phpbrew.git
cd phpbrew
powershell -ExecutionPolicy Bypass -File .\Setup.ps1
```

`Setup.ps1` は以下を行います。

1. `%USERPROFILE%\.phpbrew\bin` に実行ファイル一式をコピー
2. `%USERPROFILE%\.phpbrew\bin` をユーザー環境変数 `PATH` に追加

セットアップ後、**新しいターミナルを開いて**（PATH の変更を反映させるため）`phpbrew help` を実行できることを確認してください。

## アップデート

`phpbrew selfupdate` を実行すると、[GitHub リポジトリ](https://github.com/matsuyou1001/phpbrew) の `main` ブランチ最新版を取得し、`%USERPROFILE%\.phpbrew\bin` の phpbrew 本体を更新します。

```powershell
phpbrew selfupdate
```

PATH の設定は変更されないため、更新後に新しいターミナルを開き直す必要はありません。

## 使い方

```
phpbrew help                              このヘルプを表示
phpbrew ls-remote                         インストール可能な PHP バージョン一覧を表示
phpbrew install <version> [--ts|--nts]    指定バージョンをインストール
phpbrew uninstall <version> [--ts|--nts]  指定バージョンをアンインストール
phpbrew use <version> [--ts|--nts]        使用する PHP バージョンを切り替え
phpbrew list, phpbrew ls                  インストール済みバージョン一覧を表示
phpbrew current                           現在使用中のバージョンを表示
phpbrew prune [--dry-run]                 各ブランチの最新パッチ以外の古いバージョンをまとめて削除（使用中・保護中のバージョンは保護、削除前に確認）
phpbrew protect <version> [--ts|--nts]    指定バージョンを prune の削除対象から保護
phpbrew unprotect <version> [--ts|--nts]  指定バージョンの保護を解除
phpbrew exec [code]                       現在のバージョンで対話シェルを起動、または引数のコードを実行 (php -a / php -r)
phpbrew config threading [ts|nts]                       既定の Thread Safe / Non-Thread Safe 設定を取得・変更
phpbrew config ini-template [development|production]    php.ini 作成に使うテンプレートを取得・変更
phpbrew selfupdate                        phpbrew 本体を GitHub の最新版に更新
```

`<version>` には以下の形式を指定できます。

- フル指定: `8.3.12`
- ブランチ指定: `8.3`（そのブランチの最新パッチに解決されます）
- `latest`（リモートで確認できる最新バージョン）

`--ts` / `--nts` を省略した場合は `phpbrew config threading` で設定した既定値が使われます（初期値は `nts`）。同じバージョンでも TS 版・NTS 版は別バージョンとして共存インストールできます。

`phpbrew protect` / `phpbrew unprotect` には `uninstall` と同様、インストール済みのフル指定バージョン（例: `8.3.10`）を指定してください（ブランチ指定・`latest` は不可）。保護したバージョンは `phpbrew prune` の削除対象から常に除外されます（使用中のバージョンと同様の扱い）。

### 例

```powershell
# インストール可能なバージョンを確認
phpbrew ls-remote

# PHP 8.3 系の最新パッチを NTS でインストール
phpbrew install 8.3

# TS 版が必要な場合
phpbrew install 8.3.12 --ts

# 使用するバージョンを切り替え
phpbrew use 8.3.12

# インストール済み一覧・現在のバージョンを確認
phpbrew list
phpbrew current

# 既定の threading を ts に変更
phpbrew config threading ts

# 各ブランチの最新パッチ以外の古いバージョンをまとめて削除（削除対象を表示し、確認後に実行。使用中のバージョンは保護）
phpbrew prune

# 削除対象の確認だけ行い、実際には削除しない
phpbrew prune --dry-run

# 8.3.10 を prune の削除対象から保護
phpbrew protect 8.3.10

# 保護を解除（次回の prune で削除対象になり得る）
phpbrew unprotect 8.3.10

# 現在のバージョンで PHP コードを実行 / 対話シェルを起動
phpbrew exec "echo phpversion();"
phpbrew exec

# phpbrew 本体を GitHub の最新版に更新
phpbrew selfupdate
```

## Thread Safe / Non-Thread Safe について

- **TS (Thread Safe)**: Apache の PHP モジュールとして使う場合に必要
- **NTS (Non-Thread Safe)**: CLI 実行や FastCGI/IIS で使う場合に推奨（本ツールの既定値）

`phpbrew config threading ts|nts` で既定値を切り替えるか、`install`/`uninstall`/`use` の各コマンドに `--ts`/`--nts` を付けて個別に指定できます。

## php.ini について

`install` 時、各バージョンのフォルダには `php.ini` が存在しない状態で展開されるため、phpbrew が自動的に作成します。

1. **同じマイナーバージョン（例: 8.3.x）・同じ threading が既にインストール済みで `php.ini` を持っている場合**は、それをコピーして引き継ぎます（同じ threading が無ければ他の threading のものを流用します）。
2. **引き継ぎ元が無い場合**は、`phpbrew config ini-template` で指定したテンプレート（`php.ini-development` または `php.ini-production`。既定は `development`）から作成します。

```powershell
# 本番相当のテンプレートを使いたい場合
phpbrew config ini-template production
```

拡張機能を有効化するには、対象バージョンの `php.ini`（`%USERPROFILE%\.phpbrew\current\php.ini` など）に `extension=拡張名` を追記してください（例: `extension=curl`）。`ext\` フォルダの DLL 名から `php_` 接頭辞と拡張子を除いたものが拡張名になります。

## データの保存場所

```
%USERPROFILE%\.phpbrew\
  bin\        phpbrew 本体（PATH に登録される）
  config.json 既定の threading / ini-template 設定、prune から保護するバージョン一覧
  versions\   インストール済みの PHP 本体（例: versions\8.3.12-nts\、php.ini を含む）
  cache\      ダウンロード済み zip のキャッシュ
  current     使用中バージョンを指すディレクトリジャンクション（PATH に登録される）
```

`current` はディレクトリジャンクションのため、`phpbrew use` でリンク先を切り替えると、**既に開いているターミナルにも即座に反映**されます（PATH の文字列自体は変わらないため）。PATH への新規登録（セットアップ時・初回 `use` 時）のみ、新しいターミナルを開く必要があります。

## 制限事項

- x86 (32bit) ビルドは非対応です
- アーカイブ済み（EOL）バージョンにはチェックサムが提供されないため、ダウンロード後の検証は行われません（現行ブランチの最新パッチは SHA-256 検証を行います）
