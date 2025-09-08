# OpenVPN Manager Helm Charts

This directory contains Helm charts for deploying OpenVPN Manager on Kubernetes clusters.

## 📊 Overview

OpenVPN Manager provides a comprehensive certificate management system with:
- **Frontend Web UI** - User-facing application for OpenVPN profile generation
- **Signing Service** - Secure certificate signing isolated from frontend
- **Certificate Transparency** - Audit logging for all issued certificates  
- **WebAuth Service** - OIDC authentication handler
- **PostgreSQL Database** - Persistent storage for all services

## 📁 Charts

### `openvpn-manager/`
The main Helm chart for deploying the complete OpenVPN Manager system.

**Features:**
- Production-ready PostgreSQL deployment via Bitnami chart
- Network policies for security isolation
- Ingress with HTTPS termination
- Horizontal Pod Autoscaling
- Prometheus monitoring integration
- Persistent storage for PKI materials
- Comprehensive secret management

**Quick Start:**
```bash
# Install with basic configuration
helm install openvpn-manager ./openvpn-manager \
  --namespace openvpn-manager \
  --create-namespace \
  --set ingress.hosts[0].host=vpn.yourdomain.com \
  --set frontend.config.oidc.discoveryUrl=https://your-oidc-provider.com/.well-known/openid-configuration \
  --set frontend.config.oidc.clientId=your-client-id
```

## 🛠️ Prerequisites

- **Kubernetes**: 1.19+
- **Helm**: 3.2.0+
- **Storage**: StorageClass for persistent volumes
- **Ingress**: Ingress controller (nginx recommended)
- **OIDC Provider**: For authentication
- **PKI Materials**: CA certificates and keys

## 📚 Documentation

Each chart includes comprehensive documentation:
- Installation instructions
- Configuration options
- Security considerations
- Troubleshooting guides
- Monitoring setup

## 🔐 Security Features

### Network Security
- **Network Policies**: Restrict inter-pod communication to required paths
- **Service Isolation**: Each service runs in isolated network segments
- **Ingress Control**: HTTPS termination with security headers

### Container Security
- **Non-root Containers**: All services run as unprivileged users
- **Read-only Filesystems**: Containers use read-only root filesystems
- **Security Contexts**: Enforce security policies at pod and container level
- **No Privileged Access**: Services run with minimal privileges

### Secret Management
- **Kubernetes Secrets**: All sensitive data stored securely
- **Auto-generation**: API keys generated automatically during deployment
- **File-based Secrets**: Secrets mounted as files, not environment variables
- **Rotation Support**: Secrets can be rotated without service restart

## 🚀 Deployment Options

### Production
```bash
helm install openvpn-manager ./openvpn-manager \
  --namespace openvpn-manager \
  --values values-production.yaml
```

### Development
```bash
helm install openvpn-manager ./openvpn-manager \
  --namespace openvpn-manager \
  --values openvpn-manager/values-dev.yaml
```

### Custom Configuration
```bash
# Create custom values file
cp openvpn-manager/values.yaml my-values.yaml
# Edit my-values.yaml with your settings
helm install openvpn-manager ./openvpn-manager \
  --namespace openvpn-manager \
  --values my-values.yaml
```

## 📈 Monitoring

The chart includes Prometheus ServiceMonitor resources for monitoring:

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: monitoring
    labels:
      prometheus: kube-prometheus
```

Metrics available:
- Application performance metrics
- Certificate issuance statistics
- Authentication success/failure rates
- Service health and availability

## 🔧 Customization

### Common Customizations

**Ingress Configuration:**
```yaml
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: vpn.yourcompany.com
      paths:
        - path: /
          service: frontend
        - path: /auth
          service: webauth
  tls:
    - secretName: vpn-tls
      hosts: ["vpn.yourcompany.com"]
```

**Resource Limits:**
```yaml
frontend:
  resources:
    limits:
      cpu: 1
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
```

**Autoscaling:**
```yaml
frontend:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
```

### Database Configuration

**External PostgreSQL:**
```yaml
postgresql:
  enabled: false

# Configure external database in each service
frontend:
  config:
    database:
      host: "external-postgres.example.com"
      port: 5432
      name: "frontend_db"
      user: "frontend_user"
```

**Storage Classes:**
```yaml
global:
  storageClass: "gp3"

postgresql:
  primary:
    persistence:
      storageClass: "gp3-encrypted"
      size: 50Gi
```

## 🐛 Troubleshooting

### Common Issues

**1. Pod Startup Issues**
```bash
# Check pod status
kubectl get pods -n openvpn-manager

# View pod logs
kubectl logs -n openvpn-manager deployment/openvpn-manager-frontend

# Check events
kubectl get events -n openvpn-manager --sort-by='.lastTimestamp'
```

**2. Database Connection Problems**
```bash
# Check PostgreSQL status
kubectl get pods -n openvpn-manager -l app.kubernetes.io/name=postgresql

# Test database connection
kubectl exec -it -n openvpn-manager deployment/openvpn-manager-postgresql -- psql -U postgres
```

**3. Ingress Issues**
```bash
# Check ingress configuration
kubectl describe ingress -n openvpn-manager

# Verify ingress controller
kubectl get pods -n ingress-nginx
```

**4. Secret Issues**
```bash
# List secrets
kubectl get secrets -n openvpn-manager

# Check secret content (be careful with sensitive data)
kubectl get secret openvpn-manager-oidc-client-secret -n openvpn-manager -o yaml
```

### Debug Mode

Enable debug logging:
```yaml
frontend:
  config:
    logLevel: DEBUG
```

## 🔄 Upgrades

### Upgrading the Chart
```bash
helm upgrade openvpn-manager ./openvpn-manager \
  --namespace openvpn-manager \
  --values my-values.yaml
```

### Database Migrations
Database migrations run automatically during upgrades via init containers.

### Rolling Back
```bash
helm rollback openvpn-manager 1 --namespace openvpn-manager
```

## 🧪 Testing

### Validate Chart
```bash
helm lint ./openvpn-manager
```

### Test Template Rendering
```bash
helm template test-release ./openvpn-manager \
  --values openvpn-manager/values-dev.yaml \
  --debug
```

### Dry Run Installation
```bash
helm install openvpn-manager ./openvpn-manager \
  --namespace openvpn-manager \
  --dry-run --debug
```

## 📞 Support

For questions and issues:
1. Check the chart-specific README in `openvpn-manager/README.md`
2. Review pod logs and Kubernetes events
3. Verify all prerequisites are met
4. Check OIDC provider configuration
5. Ensure all required secrets are created