# GitHub Copilot Instructions for External Secrets with 1Password

## When to Apply These Instructions

These instructions should be applied when working with external secrets management, including:
- Files with `externalsecret.yaml` in their name
- Resources using the `external-secrets.io` API group
- When configuring 1Password integration with Kubernetes
- When managing secrets in a GitOps workflow

## External Secrets Best Practices

1. Use the correct API version:
  ```yaml
  apiVersion: external-secrets.io/v1
  kind: ExternalSecret
  ```

2. Reference the 1Password ClusterSecretStore:
  ```yaml
  spec:
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword-connect
  ```

3. Specify target secret creation details:
  ```yaml
  spec:
    target:
      name: app-name-secret
      creationPolicy: Owner
      template:
        engineVersion: v2
        data:
          # Template data here
  ```

4. Use templated data with references to 1Password values:
  ```yaml
  data:
      APP_KEY: "{{ .APP_KEY }}"
      DB_PASSWORD: "{{ .DB_PASSWORD }}"
  ```

5. Use YAML anchors for repeated values:
  ```yaml
  spec:
    target:
      template:
        data:
          DB_HOST: &dbHost postgres-rw.db.svc.cluster.local
          DB_PORT: "5432"
          DB_USER: &dbUser "{{ .POSTGRES_USER }}"
          DB_PASSWORD: &dbPass "{{ .POSTGRES_PASS }}"
          # Use anchors elsewhere
          INIT_DB_HOST: *dbHost
          INIT_DB_USER: *dbUser
  ```

6. Define data sources with proper paths:
  ```yaml
  spec:
    dataFrom:
      - extract:
          key: app-name
  ```

## ClusterSecretStore Configuration

Configure 1Password integration with:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: onepassword-connect
  namespace: kube-system
spec:
  provider:
    onepassword:
      connectHost: http://onepassword-connect:8080
      vaults:
        kubernetes: 1
      auth:
        secretRef:
          connectTokenSecretRef:
            name: onepassword-secret
            key: token
            namespace: kube-system
```

## Security Considerations

1. Store the 1Password Connect token in a bootstrap secret
2. Use namespace-specific service accounts when necessary
3. Use template data to avoid exposing sensitive values in GitOps repositories
4. Set appropriate refresh intervals for sensitive secrets
5. Never hardcode secrets in manifests

## Common Patterns

1. For application secrets:
  ```yaml
  apiVersion: external-secrets.io/v1
  kind: ExternalSecret
  metadata:
    name: app-name
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
          key: op://kubernetes/item/field
  ```

2. For database credentials:
  ```yaml
  apiVersion: external-secrets.io/v1
  kind: ExternalSecret
  metadata:
    name: app-db
  spec:
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword-connect
    target:
      name: app-db-secret
      creationPolicy: Owner
      template:
        engineVersion: v2
        data:
          DB_HOST: postgres-rw.db.svc.cluster.local
          DB_PORT: "5432"
          DB_USER: "{{ .POSTGRES_USER }}"
          DB_PASSWORD: "{{ .POSTGRES_PASS }}"
          DB_DATABASE: app_database
    dataFrom:
      - extract:
          key: postgres-app-user
  ```

3. For API tokens and keys:
  ```yaml
  apiVersion: external-secrets.io/v1
  kind: ExternalSecret
  metadata:
    name: app-api
  spec:
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword-connect
    target:
      name: app-api-secret
      creationPolicy: Owner
    data:
      - secretKey: API_TOKEN
        remoteRef:
          key: op://API-Keys/app-name/api-token
      - secretKey: API_SECRET
        remoteRef:
          key: op://API-Keys/app-name/api-secret
  ```
