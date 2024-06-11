FROM alpine:3.18.5

RUN apk add curl coreutils yq jq openssl uuidgen bash helm kubectl

COPY failed-deployments.sh /
COPY send-json-to-cosmos.py /
COPY send-notification-to-slack.py /

RUN apk update && \
    apk add python3 py3-pip && \
    pip3 install azure-cosmos

CMD ["/failed-deployments.sh"]
