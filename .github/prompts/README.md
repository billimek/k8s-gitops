# Kubernetes GitOps Deployment Prompts

This directory contains prompt templates to help you deploy various services to your Kubernetes clusters using GitOps with Flux.

## Available Prompt Templates

1. [**Generic App Template**](app-template.prompt.md) - For deploying basic applications using the app-template Helm chart.

2. [**Media Application**](media-app.prompt.md) - For deploying media management applications like Sonarr, Radarr, etc.

3. [**Database**](database.prompt.md) - For deploying database services like PostgreSQL, MySQL, Redis, etc.

4. [**Monitoring**](monitoring.prompt.md) - For deploying monitoring, observability, and metrics collection tools.

5. [**Home Automation**](home-automation.prompt.md) - For deploying home automation services like Home Assistant, Node-RED, etc.

6. [**Network Service**](network-service.prompt.md) - For deploying network-related services like ingress controllers, DNS, VPN, etc.

## How to Use These Prompts

1. Choose the appropriate prompt template for the type of service you want to deploy.

2. Copy the content of the template and fill in the placeholders with your specific requirements.

3. Submit the filled prompt to GitHub Copilot to generate the necessary Kubernetes manifests.

4. Review the generated manifests and apply them to your repository following the GitOps workflow.

## Example Usage

"Please use the Media Application template to deploy Radarr to my default namespace. It should use the ghcr.io/onedr0p/radarr-develop:5.2.6.8376 image on the develop branch. It needs a Postgres database named radarr_main. Use 100m CPU requests and 2Gi memory limit. It needs access to /data/media and /data/downloads paths. Make it available at radarr.eviljungle.com through the internal tailscale ingress."

## Repository Structure

Each deployed application typically follows this structure:

```
kubernetes/<namespace>/<app-name>/
├── namespace.yaml           # If creating a new namespace
├── app/
    ├── externalsecret.yaml  # If using external secrets
    ├── <app-name>.yaml      # The Helm release definition
    └── volsync.yaml         # If using additional persistent storage
```

## Best Practices

1. Always follow the repository's established patterns and conventions.
2. Use YAML schema validation as specified in the repository guidelines.
3. Pin Helm chart versions explicitly.
4. Configure resource limits and requests for all applications.
5. Use external secrets for sensitive information.
6. Configure proper health checks for all applications.
7. Follow appropriate security context settings for each application type.
