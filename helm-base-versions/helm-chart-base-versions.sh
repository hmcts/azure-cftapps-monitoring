#!/usr/bin/env bash
set -e

[[ "$SCRIPT_DEBUG" == "true" ]] && set -x

CLUSTER_NAME=${1:-$CLUSTER_NAME}
ARTIFACT_URL=${2:-$ARTIFACT_URL}
API_SERVER_URL=${3:-$API_SERVER_URL}
SLACK_WEBHOOK=${5:-$SLACK_WEBHOOK}
MODE=${6:-$MODE}


DEPRECATION_CONFIG=$(curl -s https://raw.githubusercontent.com/hmcts/cnp-deprecation-map/master/nagger-versions.yaml | yq e '.helm' -o=json)
SA_TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
[[ "$SA_TOKEN" == "" ]] && echo "Error: cannot get service account token." && exit 1

NAMESPACES=$(curl -k -s -H "Authorization: Bearer $SA_TOKEN" "$API_SERVER_URL"/api/v1/namespaces/)
HELM_CHARTS=$(curl -k -s -H "Authorization: Bearer $SA_TOKEN" "$API_SERVER_URL"/apis/source.toolkit.fluxcd.io/v1beta2/helmcharts)


function ver { printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
function jq_decode() { echo "${1}" | base64 --decode | jq -r "${2}"; }

SKIP_NAMESPACES="admin default kube-node-lease kube-public kube-system neuvector monitoring"

#Iterate through all namespaces
for NAMESPACE_ROW in $(echo "${NAMESPACES}" | jq -r '.items[] | @base64' ); do
    NAMESPACE=$(jq_decode "$NAMESPACE_ROW" '.metadata.name')
    TEAM_SLACK_CHANNEL=$(jq_decode "$NAMESPACE_ROW" '.metadata.labels.slackChannel')
    NOTIFICATION_ARRAY=()

    if [[ $MODE == "notify" ]]; then
      python3 send-notification-to-slack.py --slack_webhook "$SLACK_WEBHOOK" --namespace "$NAMESPACE" --slack_channel "$TEAM_SLACK_CHANNEL"
    else

      echo "processing $NAMESPACE"
      for SKIP_NS in $SKIP_NAMESPACES; do [ "$SKIP_NS" == "$NAMESPACE" ] && continue 2; done

      # Iterate through Helm chart CRDs per namespace, fux saves helm charts with starting on namespace
      for HR_NAME in $(echo "$HELM_CHARTS" | jq -r '.items[] | select(.metadata.name | startswith("'$NAMESPACE-'")) | .metadata.name'); do

        echo "Processing $HR_NAME"

        #Get artifact path from helm chart stats
        CHART_PATH=$(echo "$HELM_CHARTS" | jq -r '.items[] | select(.metadata.name == "'$HR_NAME'") | .status.artifact.path')

        if [ -n "$CHART_PATH" ] && [ "$CHART_PATH" != "null" ]; then

          #Chart name can be different to HR name in some cases where multiple HRs use same charts like camunda, logstash
          CHART_NAME=$(echo "$CHART_PATH" | cut -f4 -d"/" | sed 's/\(.*\)-.*/\1/')

          curl -Ls "$ARTIFACT_URL/$CHART_PATH" -o "/tmp/$CHART_NAME.tar.gz"
          tar -xf "/tmp/$CHART_NAME.tar.gz" -C /tmp/

          for DEPRECATED_CHART_NAME in $( echo "${DEPRECATION_CONFIG}" | jq -r 'keys | .[]' ); do
            echo "checking $DEPRECATED_CHART_NAME"
            CURRENT_VERSION=$(helm dependency ls /tmp/"$CHART_NAME" | grep "^${DEPRECATED_CHART_NAME} " |awk '{ print $2}' | sed "s/~//g" | sed 's/v//' | sed "s/\^//g")

            # Check only if chart is present
            if [[ -n $CURRENT_VERSION ]] ; then
              IS_DEPRECATED=false
              for row in $(echo "${DEPRECATION_CONFIG}" | jq -r ".$DEPRECATED_CHART_NAME | @base64" ); do
                    DEPRECATED_CHART_VERSION=$(jq_decode "$row" '.version')
                    #echo "checking $CURRENT_VERSION and $DEPRECATED_CHART_VERSION for $CHART_NAME "
                    if [ $(ver "$CURRENT_VERSION") -lt $(ver "$DEPRECATED_CHART_VERSION") ]; then
                        IS_DEPRECATED=true
                        WARNING_MESSAGE="*$CHART_NAME* chart on *$CLUSTER_NAME* cluster has base chart *$DEPRECATED_CHART_NAME* version *$CURRENT_VERSION* which is deprecated, please upgrade to at least *${DEPRECATED_CHART_VERSION}*"
                        echo "$WARNING_MESSAGE"
                        if [[ ! " ${NOTIFICATION_ARRAY[*]} " =~ ${CHART_NAME} ]]; then
                          NOTIFICATION_ARRAY+=("$CHART_NAME")
                            python3 send-json-to-cosmos.py --chartName "$CHART_NAME" --namespace "$NAMESPACE" --clusterName "$CLUSTER_NAME" --deprecatedChartName "$DEPRECATED_CHART_NAME" --currentVersion "$CURRENT_VERSION" --isDeprecated true --flag true
                          fi
                        break
                    fi
              done
            fi
          done

          rm -rf "/tmp/$CHART_NAME.tar.gz"
          rm -rf /tmp/"$CHART_NAME"

        else
          CHART_NAME=$(echo "$HR_NAME"|sed "s/$NAMESPACE-//")
            echo "$HR_NAME chart not loaded, marking as error"
            python3 send-json-to-cosmos.py --chartName "$CHART_NAME" --namespace "$NAMESPACE" --clusterName "$CLUSTER_NAME" --deprecatedChartName "$DEPRECATED_CHART_NAME" --currentVersion "$CURRENT_VERSION" --isDeprecated true --flag true --isError true
        fi
      done
    fi
done
