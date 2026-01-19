#!/usr/bin/env bash

[[ "$SCRIPT_DEBUG" == "true" ]] && set -x

CLUSTER_NAME=${1:-$CLUSTER_NAME}
ARTIFACT_URL=${2:-$ARTIFACT_URL}
API_SERVER_URL=${3:-$API_SERVER_URL}
SLACK_WEBHOOK=${4:-$SLACK_WEBHOOK}
MODE=${5:-$MODE}

# Validate required environment variables
[[ -z "$CLUSTER_NAME" ]] && echo "Error: CLUSTER_NAME is not set." && exit 1
[[ -z "$API_SERVER_URL" ]] && echo "Error: API_SERVER_URL is not set." && exit 1
[[ -z "$SLACK_WEBHOOK" ]] && echo "Error: SLACK_WEBHOOK is not set." && exit 1

SA_TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
[[ "$SA_TOKEN" == "" ]] && echo "Error: cannot get service account token." && exit 1

NAMESPACES=$(curl -k -s -H "Authorization: Bearer $SA_TOKEN" "$API_SERVER_URL"/api/v1/namespaces/)

function jq_decode() { echo "${1}" | base64 --decode | jq -r "${2}"; }

SKIP_NAMESPACES="admin azureserviceoperator-system cert-manager default flux-system kube-node-lease kube-public kube-system labs neuvector monitoring prometheus"

# Function to log failed deployment to Cosmos DB
log_failed_deployment_to_cosmos() {
    local cluster_name=$1
    local namespace=$2
    local deployment_name=$3
    local ready_replicas=$4
    local desired_replicas=$5
    local slack_channel=$6

    if ! python3 send-json-to-cosmos.py --clusterName "$cluster_name" --namespace "$namespace" --deploymentName "$deployment_name" --readyReplicas "$ready_replicas" --desiredReplicas "$desired_replicas" --slackChannel "$slack_channel"; then
        echo "Error: Failed to log deployment $deployment_name in namespace $namespace to Cosmos DB"
        return 1
    fi
}

# Iterate through all namespaces
for NAMESPACE_ROW in $(echo "${NAMESPACES}" | jq -r '.items[] | @base64'); do
    NAMESPACE=$(jq_decode "$NAMESPACE_ROW" '.metadata.name')
    TEAM_SLACK_CHANNEL=$(jq_decode "$NAMESPACE_ROW" '.metadata.labels.slackChannel')

    for SKIP_NS in $SKIP_NAMESPACES; do
        [ "$SKIP_NS" == "$NAMESPACE" ] && continue 2
    done

    DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" --no-headers=true)
    while read -r line; do
        deployment_name=$(echo "$line" | awk '{print $1}')
        ready_replicas=$(echo "$line" | awk '{print $2}' | awk -F'/' '{print $1}')
        desired_replicas=$(echo "$line" | awk '{print $2}' | awk -F'/' '{print $2}')

        # Check if the deployment has failed
        if [[ "$ready_replicas" != "$desired_replicas" ]]; then
            if ! log_failed_deployment_to_cosmos "$CLUSTER_NAME" "$NAMESPACE" "$deployment_name" "$ready_replicas" "$desired_replicas" "$TEAM_SLACK_CHANNEL"; then
                echo "Warning: Failed to log deployment $deployment_name to Cosmos DB, continuing with other deployments..."
            fi
        fi
    done <<<"$DEPLOYMENTS"
done

if [[ $MODE == "notify" ]]; then
    python3 send-notification-to-slack.py --slack_webhook "$SLACK_WEBHOOK"
fi
