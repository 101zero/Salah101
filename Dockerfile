# Multi-stage Dockerfile for nuclei + notify scanner
# Stage 1: Build nuclei and notify binaries
FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make ca-certificates

# Set Go environment variables
ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64

# Ensure GOPATH is set and binaries go to /go/bin
ENV GOPATH=/go
ENV PATH=$PATH:/go/bin

# Build nuclei (v3) from source - more reliable than go install
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/projectdiscovery/nuclei.git && \
    cd nuclei && \
    cd v3 && \
    go mod download && \
    go build -ldflags="-s -w" -o /go/bin/nuclei ./cmd/nuclei && \
    rm -rf /tmp/nuclei

# Build notify from source
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/projectdiscovery/notify.git && \
    cd notify && \
    go mod download && \
    go build -ldflags="-s -w" -o /go/bin/notify ./cmd/notify && \
    rm -rf /tmp/notify

# Verify binaries exist and are executable
RUN ls -lh /go/bin/ && \
    test -f /go/bin/nuclei && \
    test -f /go/bin/notify && \
    test -x /go/bin/nuclei && \
    test -x /go/bin/notify && \
    echo "✓ Both binaries built and verified successfully"

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

