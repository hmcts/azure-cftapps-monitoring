FROM alpine:3.18.5

RUN apk add curl coreutils yq jq openssl uuidgen bash helm

COPY helm-chart-base-versions.sh /
COPY send-json-to-cosmos.py /
COPY send-notification-to-slack.py /

RUN apk update && \
    apk add python3 py3-pip && \
    pip3 install azure-cosmos azure-identity

WORKDIR /app

COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .

ENV COSMOS_ACCOUNT="pipeline-metrics" \
    COSMOS_DB="platform-metrics" \
    COSMOS_CONTAINER="app-helm-chart-metrics" \
    COSMOS_DB_URI=""

CMD ["/helm-chart-base-versions.sh"]