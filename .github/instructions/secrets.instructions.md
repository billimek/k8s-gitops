# GitHub Copilot Instructions for Secrets Management

## When to Apply These Instructions

These instructions should be applied when working with secrets and sensitive data, including:
- Files in `/setup/bootstrap/` directories containing secrets
- When working with `Secret` resources in Kubernetes
- When using the ExternalSecrets operator
- When handling credentials, tokens, keys, or any sensitive information

## Secret Management Principles

1. Never commit plaintext secrets to the repository.
2. Use ExternalSecrets for retrieving secrets from external providers.

## External Secrets

1. Configure ClusterSecretStore:
  ```yaml
  apiVersion: external-secrets.io/v1
  kind: ClusterSecretStore
  metadata:
    name: provider-name
  spec:
    provider:
      # Provider-specific configuration
  ```

2. Create ExternalSecret resources:
  ```yaml
  apiVersion: external-secrets.io/v1
  kind: ExternalSecret
  metadata:
    name: app-secret
    namespace: app-namespace
  spec:
    secretStoreRef:
      kind: ClusterSecretStore
      name: provider-name
    target:
      name: app-secret
      creationPolicy: Owner
    data:
      - secretKey: DB_PASSWORD
        remoteRef:
          key: path/to/secret
          property: password
  ```

3. For OnePassword integration:
  ```yaml
  data:
    - secretKey: password
      remoteRef:
        key: op://kubernetes/item/field
  ```

## Sensitive Environment Variables

1. Reference secrets in HelmRelease values:
  ```yaml
  envFrom:
    - secretRef:
        name: app-secret
  ```

2. For individual environment variables:
  ```yaml
  env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: password
  ```
