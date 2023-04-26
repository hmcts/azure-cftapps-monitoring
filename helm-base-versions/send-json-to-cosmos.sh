#!/usr/bin/env bash
set -e

COSMOS_KEY=$1
CHART_NAME=$2
NAMESPACE=$3
CLUSTER_NAME=$4
DEPRECATED_CHART_NAME=$5
CURRENT_VERSION=$6
IS_DEPRECATED=$7
IS_ERROR=$8

#Define COSMOS variables
VERB="POST"
RESOURCE_TYPE="docs"
RESOURCE_ID="dbs/platform-metrics/colls/app-helm-chart-metrics"
RESOURCE_LINK="$RESOURCE_ID/$RESOURCE_TYPE"
COSMOS_URL="https://pipeline-metrics.documents.azure.com/$RESOURCE_LINK"
NOW=$(TZ=GMT date '+%a, %d %b %Y %T %Z')

SIGNATURE="$(printf "%s" "$VERB\n$RESOURCE_TYPE\n$RESOURCE_ID\n$NOW" | tr '[A-Z]' '[a-z]')\n\n"
HEX_KEY=$(printf "$COSMOS_KEY" | base64 --decode | hexdump -v -e '/1 "%02x"')
hashedSignature=$(printf "$SIGNATURE" | openssl dgst -sha256 -mac hmac -macopt hexkey:$HEX_KEY -binary | base64)
AUTH_STRING="type=master&ver=1.0&sig=$hashedSignature"
URL_ENCODED_STRING=$(printf "$AUTH_STRING" | sed 's/=/%3d/g' | sed 's/&/%26/g' | sed 's/+/%2b/g' | sed 's/\//%2f/g')

echo "URL encoded auth string: $URL_ENCODED_STRING"

ID=$(uuidgen)

documentJson=$(jq --null-input ' .id="'$ID'" | .chartName="'$CHART_NAME'" | .namespace="'$NAMESPACE'" | .clusterName="'$CLUSTER_NAME'"
  |  .baseChart="'$DEPRECATED_CHART_NAME'" |  .baseChartVersion="'$CURRENT_VERSION'" | .isDeprecated="'$IS_DEPRECATED'" | .isError="'$IS_ERROR'" ')

curl -s -v --request $VERB \
  -H "x-ms-date: $NOW" -H "x-ms-version: 2020-07-15" \
  -H "x-ms-documentdb-partitionkey: [\"$ID\"]"	-H "Content-Type: application/json" \
  -d "$documentJson" \
  -H "Authorization: $URL_ENCODED_STRING" $COSMOS_URL
