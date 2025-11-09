FROM golang:1.21-bullseye AS build

# 1) نثبت nuclei و notify باستخدام go install أثناء الـ build stage
RUN mkdir -p /build
WORKDIR /build

# ensure modules download cache won't fail
ENV GO111MODULE=on
RUN go env -w GOPATH=/go

# install binaries
RUN go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
RUN go install -v github.com/projectdiscovery/notify/cmd/notify@latest

# create a minimal runtime image
FROM debian:bookworm-slim

# copy binaries from build
COPY --from=build /go/bin/nuclei /usr/local/bin/nuclei
COPY --from=build /go/bin/notify /usr/local/bin/notify

# install wget/unzip/curl if needed
RUN apt-get update -y && apt-get install -y wget unzip ca-certificates curl && rm -rf /var/lib/apt/lists/*

# Copy the run script
COPY run.sh /usr/local/bin/run-nuclei.sh
RUN chmod +x /usr/local/bin/run-nuclei.sh

# Working dir where /data will be mounted
WORKDIR /data

ENTRYPOINT ["/usr/local/bin/run-nuclei.sh"]
