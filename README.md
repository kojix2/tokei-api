# tokei-api

tokei-api は、指定された Git リポジトリのソースコードを取得し、[tokei](https://github.com/XAMPPRocky/tokei)コマンドを実行して、その結果を JSON 形式で返す API を提供するウェブアプリケーションです。また、取得したコードの統計情報をウェブページで可視化する機能も提供します。

## 機能

### API

- `POST /api/analyze` - 指定された Git リポジトリのソースコードを解析し、結果を JSON で返します

  ```json
  {
    "repo_url": "https://github.com/crystal-lang/crystal.git"
  }
  ```

- `GET /api/analysis/:id` - 特定の解析結果を取得します

### Web インターフェース

- トップページでリポジトリ URL を入力して解析
- 結果をグラフと表で可視化
- 過去の解析結果の閲覧

## インストール

### 必要条件

- [Crystal](https://crystal-lang.org/) 1.15.1 以上
- [tokei](https://github.com/XAMPPRocky/tokei) コマンド
- [Git](https://git-scm.com/)
- PostgreSQL（Neon 等）

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

### API の使用例

```bash
# リポジトリを解析
curl -X POST -H "Content-Type: application/json" -d '{"repo_url":"https://github.com/crystal-lang/crystal.git"}' http://localhost:3000/api/analyze

# 特定の解析結果を取得
curl http://localhost:3000/api/analysis/[analysis-id]
```

### Web インターフェース

ブラウザで http://localhost:3000 にアクセスし、フォームにリポジトリ URL を入力して解析を実行します。

## 開発

```bash
# 開発モードで起動（自動リロード）
crystal run src/tokei-api.cr
```

## デプロイ

### Koyeb へのデプロイ

1. Koyeb アカウントを作成
2. 新しいアプリケーションを作成
3. GitHub リポジトリを連携
4. 環境変数を設定（DATABASE_URL 等）
5. デプロイを実行

## Docker での実行

### 単一コンテナでの実行

```bash
# Dockerイメージのビルド
docker build -t tokei-api .

# コンテナの実行
docker run -p 3000:3000 --env-file .env tokei-api
```

### Docker Compose での実行（推奨）

Docker Compose を使用すると、アプリケーションと PostgreSQL データベースを一緒に起動できます。

```bash
# コンテナのビルドと起動
docker-compose up -d

# ログの確認
docker-compose logs -f

# コンテナの停止
docker-compose down

# データベースボリュームも含めて完全に削除
docker-compose down -v
```

#### 環境の切り替え

`.env`ファイルの`DATABASE_PROVIDER`を変更することで、ローカルの PostgreSQL と Neon を切り替えることができます：

```
# ローカル開発用（Docker Compose内のPostgreSQL）
DATABASE_PROVIDER=local
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/tokei-api

# Neon接続用（koyebデプロイ時）
# DATABASE_PROVIDER=neon
# DATABASE_URL=postgresql://username:password@hostname/database?sslmode=require
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
