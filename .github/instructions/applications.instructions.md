# GitHub Copilot Instructions for Kubernetes Applications

## When to Apply These Instructions

These instructions should be applied when working with Kubernetes application manifests, including:
- Files in `/kubernetes/<namespace>/<app-name>` directories
- When creating or modifying application deployments
- When working with namespace resources, PVCs, services, or other application-level Kubernetes objects
- When setting up application monitoring, networking, or security

## Application Structure

1. Place each application in its own directory under `/kubernetes/<namespace>/<app-name>/`:
  ```
  kubernetes/<namespace>/<app-name>/
  ├── app/                     # Directory containing application resources
      ├── externalsecret.yaml  # If using secrets
      ├── <app-name>.yaml      # The main Helm release definition
      └── volsync.yaml         # If using additional persistent storage
  ```

## Common Application Patterns

1. For namespaces, follow this pattern:
  ```yaml
  apiVersion: v1
  kind: Namespace
  metadata:
    name: namespace-name
    labels:
      kustomize.toolkit.fluxcd.io/prune: disabled
  ```

2. For PersistentVolumeClaims:
  ```yaml
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: app-name-data
    namespace: namespace-name
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 10Gi  # Adjust as needed
    storageClassName: ceph-block  # Or appropriate storage class
  ```

3. For external secrets:
  ```yaml
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: app-name
    namespace: namespace-name
  spec:
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword-connect
    target:
      name: app-name-secret
      creationPolicy: Owner
    data:
      - secretKey: key-name
        remoteRef:
          key: op://vault/item/field
  ```

## Security Considerations

1. Always use RBAC with least privilege:
  ```yaml
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: app-name
    namespace: namespace-name
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: app-name
    namespace: namespace-name
  rules:
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["get", "list", "watch"]
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: app-name
    namespace: namespace-name
  subjects:
    - kind: ServiceAccount
      name: app-name
  roleRef:
    kind: Role
    name: app-name
    apiGroup: rbac.authorization.k8s.io
  ```

## Monitoring and Health Checks

1. Add Prometheus ServiceMonitor:
  ```yaml
  apiVersion: monitoring.coreos.com/v1
  kind: ServiceMonitor
  metadata:
    name: app-name
    namespace: namespace-name
  spec:
    selector:
      matchLabels:
        app.kubernetes.io/name: app-name
    endpoints:
      - port: metrics
        interval: 1m
  ```

2. Configure health checks in Helm values:
  ```yaml
  probes:
    liveness:
      enabled: true
      custom: true
      spec:
        httpGet:
          path: /healthz
          port: http
        initialDelaySeconds: 10
        periodSeconds: 10
    readiness:
      enabled: true
      custom: true
      spec:
        httpGet:
          path: /readyz
          port: http
        initialDelaySeconds: 10
        periodSeconds: 10
  ```
