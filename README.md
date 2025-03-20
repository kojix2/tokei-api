# tokei-api

tokei-apiは、指定されたGitリポジトリのソースコードを取得し、[tokei](https://github.com/XAMPPRocky/tokei)コマンドを実行して、その結果をJSON形式で返すAPIを提供するウェブアプリケーションです。また、取得したコードの統計情報をウェブページで可視化する機能も提供します。

## 機能

### API

- `POST /analyze` - 指定されたGitリポジトリのソースコードを解析し、結果をJSONで返します
  ```json
  {
    "repo_url": "https://github.com/crystal-lang/crystal.git"
  }
  ```

- `GET /api/recent` - 最近の解析結果を取得します
- `GET /api/analysis/:id` - 特定の解析結果を取得します

### Webインターフェース

- トップページでリポジトリURLを入力して解析
- 結果をグラフと表で可視化
- 過去の解析結果の閲覧

## インストール

### 必要条件

- [Crystal](https://crystal-lang.org/) 1.15.1以上
- [tokei](https://github.com/XAMPPRocky/tokei) コマンド
- [Git](https://git-scm.com/)
- PostgreSQL（Neon等）

### セットアップ

1. リポジトリをクローン
   ```bash
   git clone https://github.com/kojix2/tokei-api.git
   cd tokei-api
   ```

2. 依存関係をインストール
   ```bash
   shards install
   ```

3. 環境変数を設定
   ```bash
   cp .env.example .env
   # .envファイルを編集してデータベース接続情報などを設定
   ```

4. データベースを準備
   ```bash
   # アプリケーションの初回起動時に自動的にテーブルが作成されます
   ```

5. アプリケーションを起動
   ```bash
   crystal run src/tokei-api.cr
   ```

## 使用方法

### APIの使用例

```bash
# リポジトリを解析
curl -X POST -H "Content-Type: application/json" -d '{"repo_url":"https://github.com/crystal-lang/crystal.git"}' http://localhost:3000/analyze

# 最近の解析結果を取得
curl http://localhost:3000/api/recent

# 特定の解析結果を取得
curl http://localhost:3000/api/analysis/[analysis-id]
```

### Webインターフェース

ブラウザで http://localhost:3000 にアクセスし、フォームにリポジトリURLを入力して解析を実行します。

## 開発

```bash
# 開発モードで起動（自動リロード）
crystal run src/tokei-api.cr
```

## デプロイ

### Koyebへのデプロイ

1. Koyebアカウントを作成
2. 新しいアプリケーションを作成
3. GitHubリポジトリを連携
4. 環境変数を設定（DATABASE_URL等）
5. デプロイを実行

## Dockerでの実行

```bash
# Dockerイメージのビルド
docker build -t tokei-api .

# コンテナの実行
docker run -p 3000:3000 --env-file .env tokei-api
```

## 技術スタック

- **言語:** Crystal
- **フレームワーク:** Kemal
- **データベース:** PostgreSQL (Neon)
- **フロントエンド:** Bootstrap, Chart.js
- **その他:** tokei, Git

## ライセンス

[MIT](LICENSE)

## 貢献

1. フォークする (<https://github.com/kojix2/tokei-api/fork>)
2. 機能ブランチを作成 (`git checkout -b my-new-feature`)
3. 変更をコミット (`git commit -am 'Add some feature'`)
4. ブランチをプッシュ (`git push origin my-new-feature`)
5. プルリクエストを作成

## 作者

- [kojix2](https://github.com/kojix2) - 作成者およびメンテナ
