# GitHub Copilot Instructions for HelmRelease Resources

## When to Apply These Instructions

These instructions should be applied when working with HelmRelease resources, including:
- Files named `<app-name>.yaml` in any directory
- Any YAML file containing `kind: HelmRelease`
- When creating or modifying Helm chart deployments via FluxCD
- When setting up application values for Helm charts

## HelmRelease Structure

1. Always use the latest stable HelmRelease API version:
  ```yaml
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  ```

2. Use YAML anchors for better readability and DRY principle:
  ```yaml
  metadata:
    name: &app application-name
  ```

3. Follow this general structure:
  ```yaml
  spec:
    interval: 15m
    chart:
      spec:
        chart: app-template  # Prefer app-template for most applications
        version: 1.x.x  # Always pin chart versions
        sourceRef:
          kind: HelmRepository
          name: repository-name
          namespace: flux-system
    install:
      createNamespace: true
      remediation:
        retries: -1
    upgrade:
      cleanupOnFail: true
      remediation:
        retries: 3
    values:
      # Application values
  ```

## Values Best Practices

1. For app-template charts, prefer this structure:
  ```yaml
  values:
    image:
      repository: image/repository  # Full path including registry
      tag: vX.Y.Z  # Pin to specific version tag
    
    env:
      TZ: "America/New_York"
      # Application-specific env vars
    
    service:
      main:
        ports:
          http:
            port: 80  # Or application-specific port
    
    ingress:
      main:
        enabled: true
        ingressClassName: "nginx"
        hosts:
          - host: "{{ .Release.Name }}.${SECRET_DOMAIN}"
            paths:
              - path: /
                pathType: Prefix
        tls:
          - hosts:
              - "{{ .Release.Name }}.${SECRET_DOMAIN}"
    
    persistence:
      config:
        storageClass: "ceph-block"
        accessMode: ReadWriteOnce
        size: "2Gi" # or appropriate size
      # Additional persistence volumes
    
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        memory: 512Mi
  ```

2. Always define resource limits and requests for all applications but avoid CPU limits

3. Configure health probes where possible:
  ```yaml
  probes:
    liveness: &probes
      enabled: true
      custom: true
      spec:
        httpGet:
          path: /health
          port: http
        initialDelaySeconds: 0
        periodSeconds: 10
        timeoutSeconds: 1
        failureThreshold: 3
    readiness: *probes
    startup:
      enabled: false
  ```

4. Use variables for repeated values:
  ```yaml
  hosts:
    - host: &host "{{ .Release.Name }}.${SECRET_DOMAIN}"
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - *host
  ```

5. Always use persistence for configuration data:
  ```yaml
  persistence:
    config:
      storageClass: "ceph-block"
      accessMode: ReadWriteOnce
      size: "2Gi" # or appropriate size
  ```

## Schema Validation

Always include a schema reference at the top of the HelmRelease file for validation and improved editor support:

For bjw-s app-template charts:
```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v4.schema.json
```

For standard HelmRelease resources:
```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/helmrelease-helm-v2.json
```

This schema validation helps catch errors early and provides documentation about available options directly in your editor.
