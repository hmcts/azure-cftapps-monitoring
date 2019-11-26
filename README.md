# azure-cftapps-monitoring
Collection of Azure monitoring tasks.

**Available task**:
- `acr-sync`: Checks that all applications deployed with a `prod-` image tag to an AKS cluster are running the latest release of that image
as found in Azure Container Registry. This check currently allows for a maximum delay of 180 seconds between the ACR timestamp and current time.
