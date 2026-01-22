# ACR-AKS Sync Monitor

A Kubernetes-native monitoring tool that verifies image deployments in AKS clusters are synchronized with their latest versions in Azure Container Registry (ACR).

## Overview

This project monitors whether AKS clusters are running the latest production-ready images from ACR. When a deployment lag is detected (image not updated within 3 minutes of ACR push), it sends an alert to Slack with details about the mismatch.

## Project Structure

```text
acr-sync/
├── check-acr-aks-sync-rest.sh    # Main monitoring script
├── Dockerfile                     # Container image definition
├── example-job.yaml              # Kubernetes Job example
└── README.md                      # This file
```

Note: Image building is managed by the GitHub Actions workflow (`.github/workflows/acr-sync.yaml`).

## Components

### 1. `check-acr-aks-sync-rest.sh`

The core monitoring script that:

- **Queries Kubernetes**: Retrieves all namespaces and running pods from the AKS cluster
- **Parses images**: Extracts registry, repository, and tag from container images
- **Authenticates with ACR**: Obtains OAuth2 tokens for both `hmctsprivate.azurecr.io` and `hmctsprod.azurecr.io`
- **Compares versions**: Queries ACR for the latest `prod-*` tag and compares it against deployed tags
- **Detects drift**: Identifies when AKS is running images older than 3 minutes
- **Alerts**: Sends Slack notifications for out-of-sync images to team-specific channels

#### Key Features

- **Token reuse**: Caches ACR tokens for 45 seconds to reduce API calls (tokens valid for 60 seconds)
- **Namespace filtering**: Skips system namespaces (`kube-system`, `admin`, etc.)
- **Dual registry support**: Handles both private and prod ACRs with separate credentials
- **Efficient parsing**: Uses bash parameter expansion instead of subshells for string parsing
- **Team-aware alerts**: Routes Slack notifications to team channels via namespace labels

#### Performance Optimizations

- Parameter expansion (`${var%%/*}`) instead of `echo | cut` piping
- Cached namespace timestamp instead of per-image `date` calls
- Single `jp` call to parse ACR response instead of multiple invocations
- Direct file piping to `jp` instead of `cat | jp`

### 2. `Dockerfile`

Alpine Linux-based container image with:

- **Base**: `alpine:3.22` (minimal footprint)
- **Dependencies**: `curl` and `coreutils` for HTTP requests and date manipulation
- **jp**: JMESPath CLI tool for JSON parsing (v0.2.1)
- **Entry point**: Runs `check-acr-aks-sync-rest.sh`

### 3. `example-job.yaml`

Kubernetes Job manifest showing how to deploy the monitor in a cluster:

- **Namespace**: `admin` (with proper RBAC permissions)
- **Image**: `hmcts/check-acr-sync:v1` (pulled with `Always` policy)
- **Configuration**: Via environment variables and Kubernetes Secrets
- **Execution**: One-off job with no restart policy

## Usage

### Prerequisites

- Access to an AKS cluster with service account token at `/run/secrets/kubernetes.io/serviceaccount/token`
- ACR credentials (tokens or basic auth)
- Slack webhook URL
- `jp` (JMESPath) CLI installed in the container

### Running the Script

```bash
./check-acr-aks-sync-rest.sh \
  <cluster-name> \
  <slack-webhook> \
  <slack-channel> \
  <slack-icon> \
  <acr-max-results> \
  <hmctsprivate-token> \
  <hmctsprod-token>
```

**Or via environment variables:**

```bash
export CLUSTER_NAME="prod-aks"
export SLACK_WEBHOOK="https://hooks.slack.com/..."
export SLACK_CHANNEL="alerts"
export SLACK_ICON="warning"
export ACR_MAX_RESULTS=100
export HMCTSPRIVATE_TOKEN_PASSWORD="token"
export HMCTSPROD_TOKEN_PASSWORD="token"

./check-acr-aks-sync-rest.sh
```

### Dual-Registry Support

The script supports image verification across multiple Azure Container Registries:

- **hmctsprivate.azurecr.io**: Uses `acrsync` username with private registry token
- **hmctsprod.azurecr.io**: Uses `acr-sync` username with prod registry token

The script automatically detects which registry an image originates from and uses the appropriate credentials for token generation. This allows monitoring of images from both private and production registries in the same cluster sync operation.

### As Kubernetes Job

Apply the example job manifest (after customizing):

```bash
kubectl apply -f example-job.yaml
```

## Configuration

### Script Parameters

| Param | Env Var | Required | Description |
|-------|---------|----------|-------------|
| 1 | `CLUSTER_NAME` | Yes | AKS cluster name (used in Slack messages) |
| 2 | `SLACK_WEBHOOK` | Yes | Slack incoming webhook URL |
| 3 | `SLACK_CHANNEL` | Yes | Default Slack channel for alerts |
| 4 | `SLACK_ICON` | Yes | Slack emoji icon for bot (without colons) |
| 5 | `ACR_MAX_RESULTS` | No | Max tags to query per repo (default: 100) |
| 6 | `HMCTSPRIVATE_TOKEN_PASSWORD` | No | ACR token for `hmctsprivate.azurecr.io` (if monitoring private registry images) |
| 7 | `HMCTSPROD_TOKEN_PASSWORD` | No | ACR token for `hmctsprod.azurecr.io` (required for monitoring prod registry images) |

### Namespace Labels

The script checks for a `slackChannel` label on namespaces:

```yaml
metadata:
  labels:
    slackChannel: "my-team-alerts"
```

If present, alerts for that namespace go to `#my-team-alerts`. Otherwise, uses the default channel.

## Alert Example

```
Warning: AKS cluster prod-aks is running my-repo/service:prod-456
instead of my-repo/service:prod-789 (2026-01-06T16:40:15.123456Z).
```

Sent to:
- Team-specific channel if namespace has `slackChannel` label
- Default channel otherwise

## Debugging

Enable debug output with:

```bash
export ACR_SYNC_DEBUG=true
./check-acr-aks-sync-rest.sh
```

This sets `set -x` to show all executed commands.

## Architecture Decisions

### Why Parameter Expansion?
Bash parameter expansion (`${var%%/*}`) is faster than spawning subshells for `echo | cut` operations. With potentially hundreds of images, this optimization provides measurable performance improvement.

### Why Token Caching?
ACR tokens are valid for 60 seconds. Caching at 45 seconds ensures we don't use expired tokens while reusing fresh tokens across multiple image checks, reducing API calls and latency.

### Why 3-Minute Threshold?
Provides a reasonable grace period for:
- Image builds in ACR
- Registry replication delays
- Network propagation
- Deployment scheduling

Alerts only trigger when deployments are genuinely lagging, reducing false positives.

## Building and Deployment

### Automated via GitHub Actions (Recommended)

Changes are automatically built and deployed via the GitHub Actions workflow (`.github/workflows/acr-sync.yaml`):

- **On Pull Requests**: Builds image with tag `pr-<number>-<short-sha>` and pushes to ACR
- **On Merge to Main**: Builds image with tag `prod-<short-sha>-<timestamp>` and pushes to ACR

The workflow uses Azure federated identity for authentication, eliminating the need for credential secrets.

### Build Image Locally (For Testing)

```bash
docker build -t check-acr-sync:latest .
```

### Push Manually to ACR (For Testing)

```bash
# Login to ACR
az acr login --name hmctsprod

# Tag and push
docker tag check-acr-sync:latest hmctsprod.azurecr.io/check-acr-sync:v1
docker push hmctsprod.azurecr.io/check-acr-sync:v1
```

## Kubernetes RBAC

The service account running this job requires:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: acr-sync-monitor
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["list", "get"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["list", "get"]
```

## Related Projects

- **ACR**: Azure Container Registry
- **AKS**: Azure Kubernetes Service
- **jp**: JMESPath CLI for JSON querying
- **Slack**: Notification delivery platform
