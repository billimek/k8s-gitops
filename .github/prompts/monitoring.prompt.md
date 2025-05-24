# Monitoring Application Deployment Prompt

Use this prompt to deploy monitoring, observability, or metrics collection tools to your Kubernetes cluster.

## Application Details

- **Application Name**: [APP_NAME]
- **Application Type**: [APP_TYPE] (e.g., Prometheus, Grafana, Loki, Thanos, Victoria Metrics)
- **Namespace**: monitoring

## Helm Configuration

- **Chart**: [CHART_NAME] (e.g., app-template, prometheus-community/prometheus)
- **Version**: [CHART_VERSION]
- **Interval**: [RECONCILIATION_INTERVAL] (e.g., 30m)

## Container Configuration

- **Image Repository**: [IMAGE_REPO]
- **Image Tag**: [IMAGE_TAG]
- **Container Port**: [CONTAINER_PORT]

## Resource Requirements

- **CPU Requests**: [CPU_REQUEST] (e.g., 100m)
- **Memory Requests**: [MEMORY_REQUEST] (e.g., 128Mi)
- **Memory Limits**: [MEMORY_LIMIT] (e.g., 512Mi)

## Storage Requirements

- **Persistent Storage Required**: [YES/NO]
  - If yes, provide details:
    - Size: [STORAGE_SIZE] (e.g., 10Gi)
    - Storage Class: [STORAGE_CLASS] (e.g., ceph-block)
    - Retention Period: [RETENTION_PERIOD] (e.g., 7d)

## Network Configuration

- **Ingress Required**: [YES/NO]
  - If yes, provide details:
    - Hostname: [HOSTNAME] (e.g., grafana.eviljungle.com)
    - Internal or External: [INTERNAL/EXTERNAL]
    - Authentication Required: [YES/NO]

## Monitoring Configuration

- **Service Monitor Required**: [YES/NO]
  - If yes, provide details:
    - Metrics Path: [METRICS_PATH] (e.g., /metrics)
    - Interval: [SCRAPE_INTERVAL] (e.g., 1m)
    - Timeout: [SCRAPE_TIMEOUT] (e.g., 10s)

- **Alert Rules Required**: [YES/NO]
  - If yes, provide details:
    - Alert Name: [ALERT_NAME]
    - Expression: [ALERT_EXPRESSION]
    - For Duration: [ALERT_DURATION]
    - Severity: [ALERT_SEVERITY]

## Integration Configuration

- **Integrations Required**:
  - [INTEGRATION_1]: [YES/NO]
  - [INTEGRATION_2]: [YES/NO]

## Security Context

- **Run As User**: [RUN_AS_USER]
- **Run As Group**: [RUN_AS_GROUP]
- **FS Group**: [FS_GROUP]

## Sample Request

"Please deploy Grafana to the monitoring namespace using the grafana/grafana Helm chart version 7.0.0. It should use 200m CPU requests and 512Mi memory limit with 5Gi persistent storage. Make it available at grafana.eviljungle.com through the internal ingress. Configure it to use Prometheus as a data source and Loki for logs. Enable service monitor on /metrics path with 30s scrape interval."
