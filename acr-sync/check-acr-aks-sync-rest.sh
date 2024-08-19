#!/usr/bin/env sh
set -e

[[ "$ACR_SYNC_DEBUG" == "true" ]] && set -x

aks_cluster=${1:-$CLUSTER_NAME}
slack_webhook=${2:-$SLACK_WEBHOOK}
slack_channel=${3:-$SLACK_CHANNEL}
slack_icon=${4:-$SLACK_ICON}
acr_max_results=${5:-$ACR_MAX_RESULTS}
hmctsprivate_token_password=${6:-$HMCTSPRIVATE_TOKEN_PASSWORD}

skip_namespaces="admin default kube-node-lease kube-public kube-system neuvector"
sa_token=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
[[ "$sa_token" == "" ]] && echo "Error: cannot get service account token." && exit 1
all_namespaces=$(curl -k -H "Authorization: Bearer $sa_token" https://kubernetes.default.svc.cluster.local/api/v1/namespaces/ \
  |jp -u 'join(`"\n"`, items[].metadata.name)')

for _ns in $all_namespaces
do
  for _skip_ns in $skip_namespaces; do [ "$_skip_ns" == "$_ns" ] && continue 2; done
  images=$(curl -k -H "Authorization: Bearer $sa_token" https://kubernetes.default.svc.cluster.local/api/v1/namespaces/${_ns}/pods/ --insecure \
    | jp -u 'join(`"\n"`, items[?status.phase!=`"Succeeded"`].spec.containers[].image)' |grep 'prod-' |grep -v 'test:prod-' | sort |uniq)
  echo "** Namespace $_ns hosts $(echo $images |wc -w) unique images to check..."
  acr_token=""
  for _image in ${images}
  do
    acr="$(echo $_image |cut -d / -f 1)"
    rt="$(echo $_image |cut -d / -f 2,3)"
    repo="$(echo $rt |cut -d : -f 1)"
    tag="$(echo $rt |cut -d : -f 2)"

    now_ts=$(date '+%s')
    # acr access tokens are valid for 60secs 
    if [[ "$acr_token" == "" ]] || [[ $(($now_ts - $acr_token_ts)) > 45 ]]
    then
      token_retries=0