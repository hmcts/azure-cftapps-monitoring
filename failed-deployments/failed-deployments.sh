#!/usr/bin/env bash
set -e

[[ "$SCRIPT_DEBUG" == "true" ]] && set -x

CLUSTER_NAME=${1:-$CLUSTER_NAME}
API_SERVER_URL=${2:-$API_SERVER_URL}
COSMOS_KEY=${3:-$COSMOS_KEY}
SLACK_WEBHOOK=${4:-$SLACK_WEBHOOK}
MODE=${5:-$MODE}

SA_TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
[[ "$SA_TOKEN" == "" ]] && echo "Error: cannot get service account token." && exit 1

NAMESPACES=$(curl -k -s -H "Authorization: Bearer $SA_TOKEN" "$API_SERVER_URL"/api/v1/namespaces/)

function jq_decode() { echo "${1}" | base64 --decode | jq -r "${2}"; }

SKIP_NAMESPACES="admin default kube-node-lease kube-public kube-system neuvector monitoring aac adoption am bar bsp camunda ccd civil cnp cpo cui dg disposer divorce dm-store docmosis dtsse dynatrace et et-pet ethos fact family-public-law fees-pay finacial-remedy fis help-with-fees hmc ia idam jps lau money-claims nfdiv pcq private-law probate rd rpts sptribs sscs tax-tribunals ts wa xui"

# Function to log failed deployment to Cosmos DB
log_failed_deployment_to_cosmos() {
    local cosmos_key=$1
    local cluster_name=$2
    local namespace=$3
    local deployment_name=$4
    local ready_replicas=$5
    local desired_replicas=$6
    local slack_channel=$7
    local slack_webhook=$8

    python3 send-json-to-cosmos.py "$cosmos_key" "$cluster_name" "$namespace" "$deployment_name" "$ready_replicas" "$desired_replicas" "$slack_channel" "$slack_webhook"
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
            log_failed_deployment_to_cosmos "$COSMOS_KEY" "$CLUSTER_NAME" "$NAMESPACE" "$deployment_name" "$ready_replicas" "$desired_replicas" "$TEAM_SLACK_CHANNEL" "$SLACK_WEBHOOK"
        fi
    done <<<"$DEPLOYMENTS"
done

python3 send-notification-to-slack.py "$COSMOS_KEY" "$SLACK_WEBHOOK"
