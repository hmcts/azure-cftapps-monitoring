FROM alpine:3.17.3

RUN apk add curl coreutils yq jq openssl uuidgen bash helm

COPY helm-chart-base-versions.sh /
COPY send-json-to-cosmos.sh /

CMD ["/helm-chart-base-versions.sh"]