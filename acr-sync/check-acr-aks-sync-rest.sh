#!/usr/bin/env sh
set -e

[[ "$ACR_SYNC_DEBUG" == "true" ]] && set -x

aks_cluster=${1:-$AKS_CLUSTER}
slack_webhook=${2:-$SLACK_WEBHOOK}
slack_channel=${3:-$SLACK_CHANNEL} 
slack_icon=${4:-$SLACK_ICON}
acr_max_results=${5:-$ACR_MAX_RESULTS}


skip_namespaces="admin default kube-node-lease kube-public kube-system neuvector"
sa_token=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
[[ "$sa_token" == "" ]] && echo "Error: cannot get service account token." && exit 1
all_namespaces=$(curl -k --silent -H "Authorization: Bearer $sa_token" https://kubernetes.default.svc.cluster.local/api/v1/namespaces/ \
  |jp -u 'join(`"\n"`, items[].metadata.name)')

for _ns in $all_namespaces
do
  for _skip_ns in $skip_namespaces; do [ "$_skip_ns" == "$_ns" ] && continue 2; done
  images=$(curl -k --silent -H "Authorization: Bearer $sa_token" https://kubernetes.default.svc.cluster.local/api/v1/namespaces/${_ns}/pods/ --insecure \
    | jp -u 'join(`"\n"`, items[?status.phase!=`"Succeeded"`].spec.containers[].image)' |grep 'prod-' |grep -v 'test:prod-' | sort |uniq)
  echo "** Namespace $_ns hosts $(echo $images |wc -w) unique images to check..."
  for _image in ${images}
  do
    rt="$(echo $_image |cut -d / -f 2,3)"
    repo="$(echo $rt |cut -d : -f 1)"
    tag="$(echo $rt |cut -d : -f 2)"

    now_ts=$(date '+%s')
    # acr access tokens are valid for 60secs 
    if [[ "$acr_token" == "" ]] || [[ $(($now_ts - $acr_token_ts)) > 45 ]]
    then
      token_retries=0
      while true
      do
        [[ $token_retries -gt 2 ]] && echo "Error: cannot get acr token for repository ${repo}" && exit 1
        token_response=$(curl --silent "https://hmctspublic.azurecr.io/oauth2/token?scope=repository:${repo}:pull&service=hmctspublic.azurecr.io")
        [[ "$token_response" != "" ]] && break
        token_retries=$(($token_retries + 1))
      done    
      acr_token=$(echo "$token_response" |jp -u 'access_token')
      acr_token_ts=$(date '+%s')
    fi    
    
    [[ "$acr_token" == "" ]] && echo "Error: cannot get acr token." && exit 1
    # get latest 'prod-' tag and timestamp for repository from acr    
    curl --silent -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Authorization: Bearer $acr_token" \
      "https://hmctspublic.azurecr.io/acr/v1/${repo}/_tags?n=${ACR_MAX_RESULTS}" > /tmp/acr_repo.json
    if [[ -s /tmp/acr_repo.json ]]
    then
      acr_latest_prod=$(cat /tmp/acr_repo.json |jp "tags[?starts_with(name, \`\"prod-\"\`)]|max_by([*], &lastUpdateTime)|[lastUpdateTime,name]")
      if [[ "$acr_latest_prod" == "null" ]] || [[ "$acr_latest_prod" == "" ]]
      then
        echo "Error getting latest prod tag for ${repo} - empty response." && continue
      fi
    else
      echo "Error getting repository ${repo} - empty response." && continue
    fi
    acr_tag=$(echo $acr_latest_prod |jp -u '[1]')
    # if latest prod tag in acr is deployed to aks, registry and cluster are in sync
    [[ "$acr_tag" == "$tag" ]] && echo "ACR and AKS synced on tag ${repo}:${tag}" && continue
    acr_date=$(echo $acr_latest_prod |jp -u '[0]')
    acr_ts=$(date -d $acr_date '+%s')
    # if latest acr tag is older than 3min and still not deployed to aks, send notification
    sync_time_diff=$(($now_ts - $acr_ts))
    if [[ $sync_time_diff > 180 ]]
    then
      slack_message="Warning: AKS cluster $aks_cluster is running ${repo}:${tag} instead of ${repo}:${acr_tag} ($acr_date)."      
      echo "$slack_message"
      curl --silent -X POST \
        -d "payload={\"channel\": \"#${slack_channel}\", \"username\": \"${aks_cluster}\", \"text\": \"${slack_message}\", \"icon_emoji\": \":${slack_icon}:\"}" \
        "$slack_webhook"
      team_slack_channel=$(curl -k --silent -H "Authorization: Bearer $sa_token" https://kubernetes.default.svc.cluster.local/api/v1/namespaces/${_ns} |jp -u 'metadata.labels.slackChannel')
      if [[ "$team_slack_channel" != "null" ]]
      then
        curl --silent -X POST \
          -d "payload={\"channel\": \"#${team_slack_channel}\", \"username\": \"${aks_cluster}\", \"text\": \"${slack_message}\", \"icon_emoji\": \":${slack_icon}:\"}" \
          "$slack_webhook"
      fi
    fi
  
  done
done
