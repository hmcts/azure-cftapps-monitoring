# azure-cftapps-monitoring
Collection of Azure monitoring tasks.

**Available task**:
- `acr-sync`: Checks that all applications deployed with a `prod-` image tag to an AKS cluster are running the latest release of that image
as found in Azure Container Registry. This check currently allows for a maximum delay of 180 seconds between the ACR timestamp and current time.
- `kuberhealthy-check`: Synthetic tests that run using [kuberhealthy](https://github.com/Comcast/kuberhealthy). See [how to configure](kuberhealthy-check/README.md)
