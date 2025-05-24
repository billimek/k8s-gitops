# Network Service Deployment Prompt

Use this prompt to deploy network-related services (like ingress controllers, DNS, VPN, etc.) to your Kubernetes cluster.

## Application Details

- **Application Name**: [APP_NAME]
- **Application Type**: [APP_TYPE] (e.g., Ingress-Nginx, ExternalDNS, Cloudflare-DDNS, Tailscale)
- **Namespace**: network

## Helm Configuration

- **Chart**: [CHART_NAME] (e.g., app-template, ingress-nginx/ingress-nginx)
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

## Network Configuration

- **Service Type**: [SERVICE_TYPE] (e.g., ClusterIP, LoadBalancer)
- **Node Ports Required**: [YES/NO]
  - If yes, provide details:
    - HTTP Port: [HTTP_NODE_PORT]
    - HTTPS Port: [HTTPS_NODE_PORT]
- **Host Network Required**: [YES/NO]
- **External IPs**: [EXTERNAL_IPS]

## Secrets Configuration

- **API Tokens Required**: [YES/NO]
  - If yes, provide details:
    - One Password Item: [OP_ITEM]
    - Token Key: [TOKEN_KEY]

## Security Context

- **Run As User**: [RUN_AS_USER]
- **Run As Group**: [RUN_AS_GROUP]
- **FS Group**: [FS_GROUP]
- **Capabilities Required**: [YES/NO]
  - If yes, list capabilities:
    - [CAPABILITY_1] (e.g., NET_ADMIN)
    - [CAPABILITY_2] (e.g., NET_BIND_SERVICE)

## Additional Configuration

- **Custom ConfigMap Required**: [YES/NO]
  - If yes, provide details:
    - ConfigMap Name: [CONFIG_MAP_NAME]
    - Key-Value Pairs:
      - [KEY_1]: [VALUE_1]
      - [KEY_2]: [VALUE_2]

## Sample Request

"Please deploy ExternalDNS for Cloudflare to the network namespace using the bitnami/external-dns chart version 6.20.4. Configure it to manage DNS records for eviljungle.com on Cloudflare. It should use 100m CPU requests and 256Mi memory limit. Store the Cloudflare API token in a OnePassword item called 'cloudflare'. Configure it to use the 'external' annotation to determine which ingresses to expose externally."
