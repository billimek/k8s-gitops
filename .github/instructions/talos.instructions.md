# GitHub Copilot Instructions for Talos Configuration

## When to Apply These Instructions

These instructions should be applied when working with Talos OS configuration files, including:
- Files in `/setup/talos/` directories
- Files named `talconfig.yaml`
- Any files related to Talos machine configuration
- When configuring Kubernetes on Talos OS nodes

## Talos Configuration Structure

1. Follow the Talos configuration schema:
  ```yaml
  # yaml-language-server: $schema=https://raw.githubusercontent.com/budimanjojo/talhelper/master/pkg/config/schemas/talconfig.json
  ```

2. Use YAML anchors for repeated values:
  ```yaml
  clusterName: &clusterName ${clusterName}
  endpoint: "https://${clusterName}.${domainName}:6443"
  ```

3. Pin Talos and Kubernetes versions using Renovate annotations:
  ```yaml
  # renovate: depName=ghcr.io/siderolabs/installer datasource=docker
  talosVersion: v1.10.x
  # renovate: depName=ghcr.io/siderolabs/kubelet datasource=docker
  kubernetesVersion: v1.33.x
  ```

4. Always include API server certificate SANs:
  ```yaml
  additionalApiServerCertSans: &sans
    - &talosControlplaneVip ${clusterEndpointIP}
    - ${clusterName}.${domainName}
    - "127.0.0.1"
  additionalMachineCertSans: *sans
  ```

## Node Configuration

1. Define node configurations under the `nodes` section:
  ```yaml
  nodes:
    - hostname: node-name.domain
      controlPlane: true|false
      ipAddress: x.x.x.x
      installDisk: /dev/xxx
  ```

2. Configure network interfaces:
  ```yaml
  networkInterfaces:
        deviceSelectors:
          - hardwareAddr: xx:xx:xx:xx:xx:xx
            driver: driver-name
      dhcp: true
  ```

## Talos Machine Configuration

1. Use `talhelper` for generating machine configurations:
  - Use the task command: `task talos:generate-clusterconfig`
  - Apply with: `task talos:apply-clusterconfig`

2. Always version control the Talos configuration files.

3. For patches and customizations, use the `patches` section:
  ```yaml
  patches:
    - global: true
      patch:
        - op: add
          path: /machine/files/-
          value:
            content: |
              # File content here
            permissions: 0644
            path: /path/to/file
  ```

4. For Cilium networking:
  ```yaml
  cniConfig:
    name: none
  ```

5. Configure node labels and taints:
  ```yaml
  nodeLabels:
    key: value
  taints:
    - key: key
      value: value
      effect: NoSchedule|NoExecute|PreferNoSchedule
  ```
