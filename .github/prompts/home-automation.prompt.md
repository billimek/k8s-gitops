# Home Automation Deployment Prompt

Use this prompt to deploy home automation services (like Home Assistant, Node-RED, etc.) to your Kubernetes cluster.

## Application Details

- **Application Name**: [APP_NAME]
- **Application Type**: [APP_TYPE] (e.g., Home Assistant, Node-RED, Zigbee2MQTT, ESPHome)
- **Namespace**: home
- **Cluster**: [CLUSTER] (e.g., cluster-0, nas-1)

## Helm Configuration

- **Chart**: app-template
- **Version**: [CHART_VERSION] (e.g., 3.5.1)
- **Interval**: 30m

## Container Configuration

- **Image Repository**: [IMAGE_REPO] (e.g., ghcr.io/home-assistant/home-assistant)
- **Image Tag**: [IMAGE_TAG] (e.g., 2023.12.3)
- **Container Port**: [CONTAINER_PORT]

## Resource Requirements

- **CPU Requests**: [CPU_REQUEST] (e.g., 100m)
- **Memory Requests**: [MEMORY_REQUEST] (e.g., 128Mi)
- **Memory Limits**: [MEMORY_LIMIT] (e.g., 1Gi)

## Storage Requirements

- **Persistent Storage Required**: [YES/NO]
  - If yes, provide details:
    - Size: [STORAGE_SIZE] (e.g., 10Gi)
    - Storage Class: [STORAGE_CLASS] (e.g., ceph-block)
    - Mount Path: [MOUNT_PATH] (e.g., /config)

## Network Configuration

- **Ingress Required**: [YES/NO]
  - If yes, provide details:
    - Hostname: [HOSTNAME] (e.g., homeassistant.eviljungle.com)
    - Internal or External: [INTERNAL/EXTERNAL]
    - Authentication Required: [YES/NO]

## Device Access

- **Host Network Required**: [YES/NO]
- **Host Devices Required**: [YES/NO]
  - If yes, list devices:
    - [DEVICE_1] (e.g., /dev/ttyACM0)
    - [DEVICE_2] (e.g., /dev/ttyUSB0)

## Security Context

- **Run As User**: [RUN_AS_USER]
- **Run As Group**: [RUN_AS_GROUP]
- **FS Group**: [FS_GROUP]
- **Privileged Mode Required**: [YES/NO]

## Environment Configuration

- **Environment Variables**:
  - TZ: America/New_York
  - [ENV_VAR_1]: [VALUE_1]
  - [ENV_VAR_2]: [VALUE_2]

## External Secrets

- **Secrets Required**: [YES/NO]
  - If yes, provide details:
    - One Password Item: [OP_ITEM]
    - Secret Keys:
      - [KEY_1]: [VALUE_OR_TEMPLATE_1]
      - [KEY_2]: [VALUE_OR_TEMPLATE_2]

## Sample Request

"Please deploy Home Assistant to the default namespace. It should use the ghcr.io/home-assistant/home-assistant:2023.12.3 image on port 8123. It needs 500m CPU requests and 1Gi memory limit with 20Gi persistent storage at /config. Make it available at homeassistant.eviljungle.com through the external ingress. It needs host network access for device discovery and access to /dev/ttyACM0 for a Zwave stick. Run it in privileged mode with the America/New_York timezone."
