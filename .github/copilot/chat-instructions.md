# Copilot Chat Instructions for k8s-gitops Repository

## Repository Overview
This repository contains a Kubernetes Flux GitOps configuration for managing a homelab Kubernetes cluster. It leverages Flux to automate cluster state management using code in this repository.

## Key Technologies and Patterns

### 1. Flux
- This repository heavily uses Flux for GitOps-based Kubernetes management
- HelmRelease resources are defined in `kubernetes/` directory, organized by namespace
- Understand Flux CRDs including `HelmRelease`, `HelmRepository`, and other Flux resources

### 2. YAML Configuration
- Most resources are defined in YAML 
- Many files include schema annotations like: `# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/helmrelease-helm-v2.json`
- The directory structure reflects the Kubernetes namespace organization

### 3. Task Runner
- Uses [Taskfile](https://taskfile.dev) for workflow automation
- Main `Taskfile.yaml` in the root directory includes task definitions from `.taskfiles/`
- Includes tasks for:
  - Kubernetes management (`k8s`)
  - Kubernetes bootstrap (`k8s-bootstrap`)
  - Talos management (`talos`)
  - VolSync operations (`volsync`)
- Environment variables are set in the Taskfile, including `KUBECONFIG` and `TALOSCONFIG` paths

### 4. MiniJinja Templating
- Uses MiniJinja for templating
- Configuration in `.taskfiles/.minijinja.toml`
- Template files use `.j2` extension

### 5. Renovate
- Automated dependency updates using Renovate
- Configuration in `.github/renovate.json5`
- Extends configurations from another repository
- Configured for Flux resources, Docker images, Helm charts, and other dependencies

### 6. Directory Structure
- `kubernetes/`: Contains all Kubernetes resources, organized by namespace
  - Each namespace has its own directory with applications as subdirectories
  - Each application typically has one or more YAML files defining its resources
- `setup/`: Contains cluster setup and bootstrap configurations
  - `setup/talos/`: Talos OS configuration for cluster nodes
  - `setup/flux/`: Flux bootstrap configuration
  - `setup/crds/`: Custom Resource Definitions
- `.taskfiles/`: Contains task definitions for the Taskfile runner

## Common Patterns and Conventions

### HelmRelease Pattern
```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/helmrelease-helm-v2.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: app-name
  namespace: namespace-name
spec:
  interval: 1h
  chart:
    spec:
      chart: chart-name
      version: chart-version
      sourceRef:
        kind: HelmRepository
        name: repo-name
        namespace: flux-system
      interval: 15m
  values:
    # Application-specific configuration values
```

### VolSync Pattern
VolSync is used for persistent volume backups and replication. Resources typically include:
- ReplicationSource for creating backups
- ReplicationDestination for restoring backups

### External Secrets
Many applications use `ExternalSecret` resources to securely inject secrets from external sources.

## Common Tasks

### Working with Tasks
- Run tasks using `task <taskname>`
- Use `task --list` to see available tasks
- Namespace tasks are referenced like `task k8s:apply`

### Adding a New Application
1. Create a new directory in the appropriate namespace directory
2. Add YAML files for the application (HelmRelease, etc.)
3. If needed, add persistent storage with VolSync
4. If needed, add ExternalSecret for sensitive data

### Updating an Application
1. Update the HelmRelease chart version or values
2. Flux will automatically apply the changes to the cluster

### Working with Secrets
- External Secrets are used to manage sensitive information
- Reference existing ExternalSecret patterns when creating new ones

## Best Practices

1. Follow the existing directory structure and patterns
2. Use schema annotations in YAML files where possible
3. Leverage Flux for declarative application management
4. Use tasks for common operations
5. Let Renovate handle dependency updates
6. Document changes and decisions in comments and README files
7. Avoid using unsightly kustomize files and kustomizations

## Important Files to Reference
- `kubernetes/*/README.md`: Documentation for specific namespaces
- `setup/README.md`: Setup and bootstrap instructions
- `Taskfile.yaml`: Main task definitions
- `.taskfiles/*.yaml`: Additional task definitions
