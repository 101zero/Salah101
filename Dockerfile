# Multi-stage Dockerfile for nuclei + notify scanner
# Stage 1: Build nuclei and notify binaries
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Build nuclei (v3)
RUN go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# Build notify
RUN go install -v github.com/projectdiscovery/notify/cmd/notify@latest

# Stage 2: Runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Copy binaries from builder
COPY --from=builder /go/bin/nuclei /usr/local/bin/nuclei
COPY --from=builder /go/bin/notify /usr/local/bin/notify

# Create necessary directories
RUN mkdir -p /data /secrets /nuclei-templates && \
    chmod 755 /data /secrets /nuclei-templates

# Copy run script
COPY run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

# Set working directory
WORKDIR /data

# Default entrypoint
ENTRYPOINT ["/usr/local/bin/run.sh"]

