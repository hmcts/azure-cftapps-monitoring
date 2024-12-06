FROM alpine:3.21.0

ENV PIP_BREAK_SYSTEM_PACKAGES 1

RUN apk add curl coreutils yq jq openssl uuidgen bash helm

COPY helm-chart-base-versions.sh /
COPY send-json-to-cosmos.py /
COPY send-notification-to-slack.py /

RUN apk update && \
    apk add python3 py3-pip && \
    pip3 install azure-cosmos azure-identity


CMD ["/helm-chart-base-versions.sh"]
