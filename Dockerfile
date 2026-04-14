# === Stage 1: Build tokei with Rust on Alpine 3.22 ===
FROM rust:alpine AS tokei-builder

RUN apk add --no-cache musl-dev

RUN cargo install tokei


# === Stage 2: Build Crystal app on Alpine ===
FROM crystallang/crystal:alpine AS crystal-builder

RUN apk add --no-cache git postgresql-client

WORKDIR /app

COPY shard.yml shard.lock ./
RUN shards install --production

COPY . .
RUN crystal build --release src/main.cr -o /app/tokei-api


# === Final Stage: Minimal runtime ===
FROM alpine:latest

RUN apk add --no-cache git libpq libgcc libgc++ pcre2 \
	rsvg-convert fontconfig freetype ttf-dejavu

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
