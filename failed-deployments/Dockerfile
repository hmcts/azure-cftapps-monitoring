FROM alpine:3.20.2

ENV PIP_BREAK_SYSTEM_PACKAGES 1

RUN apk add curl coreutils yq jq openssl uuidgen bash helm

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

COPY failed-deployments.sh /
COPY send-json-to-cosmos.py /
COPY send-notification-to-slack.py /

RUN apk update && \
    apk add python3 py3-pip && \
    pip3 install azure-cosmos

CMD ["/failed-deployments.sh"]
