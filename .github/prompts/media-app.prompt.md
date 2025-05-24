# Media Application Deployment Prompt

Use this prompt to deploy a new media management application (like Sonarr, Radarr, etc.) to your Kubernetes cluster.

## Application Details

- **Application Name**: [APP_NAME]
- **Application Type**: [APP_TYPE] (e.g., Sonarr, Radarr, Lidarr, Prowlarr, etc.)
- **Namespace**: media

## Helm Configuration

- **Chart**: app-template
- **Version**: [CHART_VERSION] (e.g., 3.5.1)
- **Interval**: 30m

## Container Configuration

- **Image Repository**: [IMAGE_REPO] (e.g., ghcr.io/onedr0p/sonarr-develop)
- **Image Tag**: [IMAGE_TAG] (e.g., 4.0.10.2656)
- **Branch**: [BRANCH] (e.g., develop, master, main)

## Database Configuration

- **Postgres Database Required**: [YES/NO]
  - If yes, provide details:
    - Database Names: [DB_NAMES] (e.g., sonarr_main sonarr_log)
    - Host: postgres-rw.db.svc.cluster.local
    - Port: 5432

## Resource Requirements

- **CPU Requests**: [CPU_REQUEST] (e.g., 100m)
- **Memory Limits**: [MEMORY_LIMIT] (e.g., 2Gi)

## Storage Requirements

- **Media Path**: [MEDIA_PATH] (e.g., /data/media)
- **Downloads Path**: [DOWNLOADS_PATH] (e.g., /data/downloads)
- **Config Size**: [CONFIG_SIZE] (e.g., 10Gi)

## Network Configuration

- **Ingress Hostname**: [HOSTNAME] (e.g., sonarr.eviljungle.com)
- **Internal or External**: [INTERNAL/EXTERNAL] (usually internal)
- **Container Port**: [CONTAINER_PORT] (usually 80)

## Notification Configuration

- **Pushover Notifications**: [YES/NO]
  - If yes, include Pushover token and user key in secrets

## Security Context

- **Run As User**: 1001
- **Run As Group**: 1001
- **FS Group**: 1001

## Sample Request

"Please deploy Radarr to the media namespace on cluster-0. It should use the ghcr.io/onedr0p/radarr-develop:5.2.6.8376 image on the develop branch. It needs a Postgres database named radarr_main. Use 100m CPU requests and 2Gi memory limit. It needs access to /data/media and /data/downloads paths. Make it available at radarr.eviljungle.com through the internal ingress. Set up Pushover notifications using the same keys as Sonarr."
