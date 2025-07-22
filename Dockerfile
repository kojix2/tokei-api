# === Stage 1: Build tokei with Rust on Alpine 3.22 ===
FROM rust:1-alpine AS tokei-builder

RUN apk add --no-cache musl-dev

RUN cargo install tokei


# === Stage 2: Build Crystal app on Alpine 3.20 ===
FROM crystallang/crystal:1-alpine AS crystal-builder

RUN apk add --no-cache git postgresql-client

WORKDIR /app

COPY shard.yml shard.lock ./
RUN shards install --production

COPY . .
RUN crystal build --release src/tokei-api.cr -o /app/tokei-api


# === Final Stage: Minimal runtime ===
FROM alpine:3

RUN apk add --no-cache git libpq libgcc libgc++ pcre2

WORKDIR /app

# Copy compiled Crystal binary
COPY --from=crystal-builder /app/tokei-api /app/tokei-api

# Copy static files (public directory)
COPY --from=crystal-builder /app/public /app/public

# Copy tokei binary built with newer Rust/Alpine
COPY --from=tokei-builder /usr/local/cargo/bin/tokei /usr/local/bin/tokei

# Create temp directory
RUN mkdir -p /tmp/tokei-api

EXPOSE 3000

CMD ["/app/tokei-api"]
