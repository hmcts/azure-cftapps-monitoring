## KuberHealthy Check

This a custom [kuberhealthy](https://github.com/Comcast/kuberhealthy) external check to perform synthetic tests on Kubernetes application.

#### How-to
To use the `Kuber Healthy Check` with Kuberhealthy, apply the configuration file [kuberhealthy-check.yaml](kuberhealthy-check.yaml) to your Kubernetes Cluster.

`kubectl apply -f kuberhealthy-check.yaml`

The `Kuber Healthy Check` container can be configured to perform 3 different checks.

- Checks whether a deployment has at least 1 replicas running. 
  ```yaml
  env:
    - name: DEPLOYMENT_NAME
      value: "flux"
    - name: TARGET_NAMESPACE
      value: "admin"
   ```
- Checks whether a service loadbalncer ip is set .
  ```yaml
  env:
    - name: SERVICE_NAME
      value: "traefik"
    - name: TARGET_NAMESPACE
      value: "admin"
   ```
- Checks whether a pod for a given label is running. 
  ```yaml
  env:
    - name: POD_LABEL
      value: "component=tunnel"
    - name: TARGET_NAMESPACE
      value: "kube-system"
   ```

