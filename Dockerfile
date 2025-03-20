FROM crystallang/crystal:1.15.1-alpine

# 必要なパッケージをインストール
RUN apk add --no-cache git postgresql-client

# tokeiのインストール
RUN apk add --no-cache cargo && \
    cargo install tokei && \
    apk del cargo && \
    mv /root/.cargo/bin/tokei /usr/local/bin/ && \
    rm -rf /root/.cargo

# アプリケーションディレクトリの作成
WORKDIR /app

# 依存関係のコピーとインストール
COPY shard.yml shard.lock ./
RUN shards install --production

# ソースコードのコピー
COPY . .

# アプリケーションのビルド
RUN crystal build --release src/tokei-api.cr

# 一時ディレクトリの作成
RUN mkdir -p /tmp/tokei-api

# ポートの公開
EXPOSE 3000

# アプリケーションの実行
CMD ["/app/tokei-api"]
