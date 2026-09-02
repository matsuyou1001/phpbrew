# phpbrew

Windows 専用の PHP バージョンマネージャーです。[nodebrew](https://github.com/hokaccha/nodebrew) と同様のコマンド体系で、複数の PHP バージョンをダウンロードし、使用するバージョンを切り替えられます。

- 対応 OS: Windows のみ（クロスプラットフォーム非対応）
- 対応アーキテクチャ: x64 のみ
- ダウンロード元: [windows.php.net](https://windows.php.net/) の公式ビルド（`releases/` および `releases/archives/`）
- 追加ランタイム不要（Windows 標準の PowerShell 5.1 以降で動作）

## セットアップ

このリポジトリをクローンし、`Setup.ps1` を実行してください。

```powershell
git clone <このリポジトリ> phpbrew
cd phpbrew
powershell -ExecutionPolicy Bypass -File .\Setup.ps1
```

`Setup.ps1` は以下を行います。

1. `%USERPROFILE%\.phpbrew\bin` に実行ファイル一式をコピー
2. `%USERPROFILE%\.phpbrew\bin` をユーザー環境変数 `PATH` に追加

セットアップ後、**新しいターミナルを開いて**（PATH の変更を反映させるため）`phpbrew help` を実行できることを確認してください。

## 使い方

```
phpbrew help                              このヘルプを表示
phpbrew ls-remote                         インストール可能な PHP バージョン一覧を表示
phpbrew install <version> [--ts|--nts]    指定バージョンをインストール
phpbrew uninstall <version> [--ts|--nts]  指定バージョンをアンインストール
phpbrew use <version> [--ts|--nts]        使用する PHP バージョンを切り替え
phpbrew list, phpbrew ls                  インストール済みバージョン一覧を表示
phpbrew current                           現在使用中のバージョンを表示
phpbrew config threading [ts|nts]         既定の Thread Safe / Non-Thread Safe 設定を取得・変更
```

`<version>` には以下の形式を指定できます。

- フル指定: `8.3.12`
- ブランチ指定: `8.3`（そのブランチの最新パッチに解決されます）
- `latest`（リモートで確認できる最新バージョン）

`--ts` / `--nts` を省略した場合は `phpbrew config threading` で設定した既定値が使われます（初期値は `nts`）。同じバージョンでも TS 版・NTS 版は別バージョンとして共存インストールできます。

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
```

## Thread Safe / Non-Thread Safe について

- **TS (Thread Safe)**: Apache の PHP モジュールとして使う場合に必要
- **NTS (Non-Thread Safe)**: CLI 実行や FastCGI/IIS で使う場合に推奨（本ツールの既定値）

`phpbrew config threading ts|nts` で既定値を切り替えるか、`install`/`uninstall`/`use` の各コマンドに `--ts`/`--nts` を付けて個別に指定できます。

## データの保存場所

```
%USERPROFILE%\.phpbrew\
  bin\        phpbrew 本体（PATH に登録される）
  config.json 既定の threading 設定
  versions\   インストール済みの PHP 本体（例: versions\8.3.12-nts\）
  cache\      ダウンロード済み zip のキャッシュ
  current     使用中バージョンを指すディレクトリジャンクション（PATH に登録される）
```

`current` はディレクトリジャンクションのため、`phpbrew use` でリンク先を切り替えると、**既に開いているターミナルにも即座に反映**されます（PATH の文字列自体は変わらないため）。PATH への新規登録（セットアップ時・初回 `use` 時）のみ、新しいターミナルを開く必要があります。

## 制限事項

- x86 (32bit) ビルドは非対応です
- アーカイブ済み（EOL）バージョンにはチェックサムが提供されないため、ダウンロード後の検証は行われません（現行ブランチの最新パッチは SHA-256 検証を行います）
