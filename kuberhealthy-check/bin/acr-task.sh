#!/usr/bin/env bash

export ACR_NAME=hmctspublic
export GIT_PAT=$(az keyvault secret show --vault-name infra-vault-prod --name hmcts-github-apikey --query value -o tsv)

az acr task create \
  --registry $ACR_NAME \
  --name kuberhealthy-check \
  --image monitoring/kuberhealthy-check:{{.Run.ID}} \
  --context https://github.com/hmcts/azure-cftapps-monitoring.git#master:kuberhealthy-check \
  --file Dockerfile \
  --git-access-token $GIT_PAT \
  --subscription DCD-CNP-PROD