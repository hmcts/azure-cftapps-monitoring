FROM alpine:3.18.0

RUN apk add curl coreutils yq jq openssl uuidgen bash helm

COPY helm-chart-base-versions.sh /
COPY send-json-to-cosmos.py /

RUN apk update && \
    apk add python3 py3-pip && \
    pip3 install azure-cosmos

CMD ["/helm-chart-base-versions.sh"]