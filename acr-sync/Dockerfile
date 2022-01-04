FROM alpine:3.15

ARG jp_version=0.2.1
ARG TARGETARCH=amd64

RUN apk add curl coreutils
RUN wget https://github.com/jmespath/jp/releases/download/${jp_version}/jp-linux-${TARGETARCH} -O /usr/local/bin/jp \
    && chmod +x /usr/local/bin/jp \
    && jp --version

COPY check-acr-aks-sync-rest.sh /
CMD ["/check-acr-aks-sync-rest.sh"]
