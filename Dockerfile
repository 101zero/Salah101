FROM projectdiscovery/nuclei:latest

USER root
RUN apt-get update -y && apt-get install -y wget unzip ca-certificates bash && \
    wget -q -O /tmp/notify.zip "https://github.com/projectdiscovery/notify/releases/latest/download/notify-linux-amd64.zip" && \
    unzip -o /tmp/notify.zip -d /usr/local/bin || true && \
    chmod +x /usr/local/bin/notify || true && \
    rm -rf /tmp/notify.zip /var/lib/apt/lists/*

COPY run.sh /usr/local/bin/run-nuclei.sh
RUN chmod +x /usr/local/bin/run-nuclei.sh

ENTRYPOINT [ "/usr/local/bin/run-nuclei.sh" ]
