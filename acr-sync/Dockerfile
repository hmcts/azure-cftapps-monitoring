FROM alpine:3.10.3

ARG jp_version=0.1.2

RUN apk add curl coreutils
RUN wget https://github.com/jmespath/jp/releases/download/${jp_version}/jp-linux-amd64 -O /usr/local/bin/jp && chmod +x /usr/local/bin/jp

COPY check-acr-aks-sync-rest.sh /
CMD ["/check-acr-aks-sync-rest.sh"]
