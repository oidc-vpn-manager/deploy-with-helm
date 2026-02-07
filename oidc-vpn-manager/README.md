# OIDC VPN Manager Helm Chart

This Helm chart deploys OIDC VPN Manager, a comprehensive certificate management system with OIDC authentication and Certificate Transparency logging, on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PostgreSQL database (can be deployed with this chart)
- OIDC provider
- Valid PKI materials (CA certificates and keys)

## Architecture

```
                   ┌───────────────┐
                   │   OIDC IDP    │
                   │   (Auth)      │
                   └───────────────┘
                           │
┌─────────────┐    ┌──────────────┐    ┌─────────────────────┐
│   Ingress   │────│   Frontend   │────│     Signing         │
│   (HTTPS)   │    │   (Web UI)   │    │   (Certificate      │
└─────────────┘    └──────────────┘    │    Generation)      │
                           │           └─────────────────────┘
                           │                      │
                           │   ┌───────────────────────────────┐
                           │   │ Certificate Transparency (CT) │
                           │   │ (Audit Logging)               │
                           │   └───────────────────────────────┘
                           │                      │
                   ┌───────────────┐     ┌───────────────┐
                   │  PostgreSQL   │     │  PostgreSQL   │
                   │ for Frontend  │     │ for CT Log    │
                   │  (Database)   │     │  (Database)   │
                   └───────────────┘     └───────────────┘
```

## Installation

### 1. Add Helm Repository Dependencies
(Optional) Alternatively use an external database provider.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### 2. Create Namespace

```bash
kubectl create namespace oidc-vpn-manager
```

### 3. Prepare PKI Materials

Create a Kubernetes secret with your PKI materials:

```bash
kubectl create secret generic oidc-vpn-manager-pki \
  --from-file=root-ca.crt=path/to/root-ca.crt \
  --from-file=intermediate-ca.crt=path/to/intermediate-ca.crt \
  --from-file=intermediate-ca.key=path/to/intermediate-ca.key \
  -n oidc-vpn-manager
```

### 4. Create Secrets

Create required secrets:

```bash
# OIDC client secret
kubectl create secret generic oidc-vpn-manager-oidc-client-secret \
  --from-literal=client-secret='your-oidc-client-secret' \
  -n oidc-vpn-manager

# CA key passphrase
kubectl create secret generic oidc-vpn-manager-ca-key-passphrase \
  --from-literal=passphrase='your-ca-key-passphrase' \
  -n oidc-vpn-manager
```

### 5. Install the Chart

```bash
helm install oidc-vpn-manager ./oidc-vpn-manager \
  --namespace oidc-vpn-manager \
  --set ingress.hosts[0].host=vpn.yourdomain.com \
  --set frontend.config.openvpnServerHostname=vpn.yourdomain.com \
  --set frontend.config.oidc.discoveryUrl=https://your-oidc-provider.com/.well-known/openid-configuration \
  --set frontend.config.oidc.clientId=your-client-id \
  --set webauth.config.oidc.discoveryUrl=https://your-oidc-provider.com/.well-known/openid-configuration \
  --set webauth.config.oidc.clientId=your-client-id \
  --set webauth.config.frontendServiceUrl=https://vpn.yourdomain.com
```

## Configuration

### Core Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.storageClass` | Global storage class | `""` |
| `image.registry` | Container registry | `ghcr.io` |
| `image.repository` | Repository base path | `oidc-vpn-manager` |
| `image.tag` | Image tag | `""` (uses appVersion) |

### Frontend Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `frontend.enabled` | Enable frontend service | `true` |
| `frontend.replicaCount` | Number of replicas | `2` |
| `frontend.config.openvpnServerHostname` | OpenVPN server hostname | `vpn.example.com` |
| `frontend.config.oidc.discoveryUrl` | OIDC discovery URL | Required |
| `frontend.config.oidc.clientId` | OIDC client ID | Required |
| `frontend.config.oidc.adminGroup` | Admin group name | `vpn-admins` |

### Database Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Deploy PostgreSQL | `true` |
| `postgresql.auth.postgresPassword` | PostgreSQL password | `changeme` |
| `postgresql.primary.persistence.size` | Database storage size | `8Gi` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class | `nginx` |
| `ingress.hosts[0].host` | Hostname | `vpn.example.com` |
| `ingress.tls[0].secretName` | TLS secret name | `oidc-vpn-manager-tls` |

### Security Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `networkPolicy.enabled` | Enable network policies | `true` |
| `podSecurityContext.runAsNonRoot` | Run as non-root | `true` |
| `podSecurityContext.runAsUser` | User ID | `1001` |
| `securityContext.allowPrivilegeEscalation` | Allow privilege escalation | `false` |

## Custom Values File

Create a `values-production.yaml` file:

```yaml
# Production configuration
global:
  storageClass: "gp3"

frontend:
  replicaCount: 3
  config:
    openvpnServerHostname: "vpn.yourcompany.com"
    oidc:
      discoveryUrl: "https://auth.yourcompany.com/.well-known/openid-configuration"
      clientId: "oidc-vpn-manager-prod"
      adminGroup: "vpn-administrators"

ingress:
  hosts:
    - host: vpn.yourcompany.com
      paths:
        - path: /
          pathType: Prefix
          service: frontend
        - path: /auth
          pathType: Prefix
          service: webauth
  tls:
    - secretName: vpn-yourcompany-com-tls
      hosts:
        - vpn.yourcompany.com

postgresql:
  primary:
    persistence:
      size: 20Gi
    resources:
      limits:
        cpu: 1
        memory: 2Gi
      requests:
        cpu: 500m
        memory: 1Gi

monitoring:
  serviceMonitor:
    enabled: true
    namespace: monitoring
```

Install with custom values:

```bash
helm install oidc-vpn-manager ./oidc-vpn-manager \
  --namespace oidc-vpn-manager \
  --values values-production.yaml
```

## Upgrading

```bash
helm upgrade oidc-vpn-manager ./oidc-vpn-manager \
  --namespace oidc-vpn-manager \
  --values values-production.yaml
```

## Uninstalling

```bash
helm uninstall oidc-vpn-manager --namespace oidc-vpn-manager
```

## Monitoring

If Prometheus operator is installed, enable ServiceMonitor:

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: monitoring
    labels:
      prometheus: kube-prometheus
```

Metrics are available at `/metrics` endpoint on each service.

## Security Considerations

### Network Policies
- Inter-service communication is restricted by NetworkPolicies
- Only required connections are allowed
- External OIDC and DNS traffic is permitted

### Secrets Management
- All sensitive data stored in Kubernetes secrets
- Secrets mounted as files, not environment variables
- Automatic secret generation for internal APIs

### Container Security
- Non-root containers with read-only root filesystem
- Security contexts enforce least privilege
- No privileged containers (except PKI init)

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n oidc-vpn-manager
```

### View Logs
```bash
kubectl logs -n oidc-vpn-manager deployment/oidc-vpn-manager-frontend
kubectl logs -n oidc-vpn-manager deployment/oidc-vpn-manager-signing
kubectl logs -n oidc-vpn-manager deployment/oidc-vpn-manager-certtransparency
kubectl logs -n oidc-vpn-manager deployment/oidc-vpn-manager-webauth
```

### Check Services
```bash
kubectl get services -n oidc-vpn-manager
```

### Verify Ingress
```bash
kubectl describe ingress -n oidc-vpn-manager
```

### Database Connection
```bash
kubectl exec -it -n oidc-vpn-manager deployment/oidc-vpn-manager-postgresql -- psql -U postgres
```

### Common Issues

1. **PKI Secret Missing**: Ensure PKI materials are properly created as secrets
2. **OIDC Configuration**: Verify OIDC discovery URL and client credentials
3. **Ingress Issues**: Check ingress controller and TLS certificates
4. **Database Connectivity**: Verify PostgreSQL is running and accessible

## Development

### Testing Locally

```bash
# Validate chart
helm lint ./oidc-vpn-manager

# Test template rendering
helm template test-release ./oidc-vpn-manager \
  --values values-production.yaml \
  --debug

# Dry run installation
helm install oidc-vpn-manager ./oidc-vpn-manager \
  --namespace oidc-vpn-manager \
  --dry-run --debug
```

### Chart Dependencies

Update dependencies:

```bash
helm dependency update ./oidc-vpn-manager
```

## Support

For issues and questions:
- Check pod logs for error details
- Verify all secrets are properly configured
- Ensure OIDC provider is accessible
- Validate ingress and DNS configuration