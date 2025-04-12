FROM crystallang/crystal:1.16.0-alpine

# Install required packages
RUN apk add --no-cache git postgresql-client

# Install tokei
RUN apk add --no-cache cargo && \
    cargo install tokei && \
    apk del cargo && \
    mv /root/.cargo/bin/tokei /usr/local/bin/ && \
    rm -rf /root/.cargo

# Create application directory
WORKDIR /app

# Copy and install dependencies
COPY shard.yml shard.lock ./
RUN shards install --production

# Copy source code
COPY . .

# Build application
RUN crystal build --release src/tokei-api.cr

# Create temporary directory
RUN mkdir -p /tmp/tokei-api

# Expose port
EXPOSE 3000

# Run application
CMD ["/app/tokei-api"]
