# OpenVPN Manager Helm Chart Testing

This directory contains tools for testing the OpenVPN Manager Helm chart in a local Kubernetes environment using kind (Kubernetes in Docker).

## Quick Start

1. **Setup the test cluster using Makefile:**
   ```bash
   make setup
   ```

2. **Or deploy individual components:**
   ```bash
   make deps cluster ingress coredns secrets postgresql openvpn status
   ```

3. **Access the services:**
   - User frontend: http://user.localhost:8000
   - Admin frontend: http://admin.localhost:8000  
   - External OIDC: https://tinyoidc.sprig.gs

4. **Clean up:**
   ```bash
   make clean
   ```

## Files

- `Makefile` - Modular deployment system replacing setup-test-cluster.sh  
- `kind-cluster.yaml` - Kind cluster configuration with ingress support on port 8000
- `test-values.yaml` - Helm values optimized for local testing
- `postgresql/` - Separate PostgreSQL Helm chart for database
- `tiny-oidc/` - Separate Tiny OIDC Helm chart (currently disabled)
- `README.md` - This file

## Configuration Notes

### Port Configuration
- The ingress is configured to use port 8000 instead of standard port 80
- This avoids port conflicts and works well in devcontainer environments
- Services redirect properly between user.localhost:8000 and admin.localhost:8000

### Test-Specific Settings
- Reduced resource requirements for all services  
- TLS disabled for simplicity
- Debug logging enabled
- External OIDC service (tinyoidc.sprig.gs) for authentication
- Separate database namespace for isolation
- Network policies configured to allow external OIDC connectivity

### Service Architecture
The test configuration deploys:
- **Frontend User Service**: Handles end-user VPN certificate requests with bounce to admin
- **Frontend Admin Service**: Administrative interface for managing users and certificates  
- **External OIDC Service**: External OIDC provider at tinyoidc.sprig.gs
- **Signing Service**: Certificate signing operations
- **Certificate Transparency Service**: CT log integration  
- **PostgreSQL**: External database deployed in separate namespace

### Authentication Flow
1. User accesses admin routes on user service (e.g., `/admin/psk`)
2. 403 handler redirects to bounce page with target admin URL
3. Admin service login_required decorator stores destination URL
4. OIDC authentication flow preserves intended destination
5. After auth, user is redirected to originally requested page
6. Permission-based 403 errors shown only for insufficient privileges

### Network Policies
- Egress network policies allow all outbound TCP traffic  
- Required for external OIDC service connectivity
- DNS resolution (port 53) and internal pod communication maintained

## Available Make Targets

- `make setup` - Complete test environment setup
- `make clean` - Delete existing cluster  
- `make deps` - Install kubectl, kind, helm
- `make cluster` - Create kind cluster
- `make ingress` - Install NGINX ingress controller
- `make coredns` - Configure DNS resolution  
- `make secrets` - Set up pull secrets from .env
- `make postgresql` - Deploy PostgreSQL database
- `make openvpn` - Deploy OpenVPN Manager
- `make status` - Show cluster status and URLs
- `make help` - Show available targets

## Troubleshooting

### Check pod status:
```bash
kubectl get pods -n oidc-vpn-manager
kubectl get pods -n postgresql  
kubectl get pods -n oidc
```

### View logs:
```bash
kubectl logs -l app.kubernetes.io/name=oidc-vpn-manager -n oidc-vpn-manager
```

### Check ingress and networking:
```bash
kubectl get ingress --all-namespaces
kubectl get networkpolicies -n oidc-vpn-manager
```

### Port forwarding (alternative to ingress):
```bash
kubectl port-forward -n oidc-vpn-manager svc/openvpn-test-oidc-vpn-manager-frontend-user 8080:8600
kubectl port-forward -n oidc-vpn-manager svc/openvpn-test-oidc-vpn-manager-frontend-admin 8081:8600
```

### Test external OIDC connectivity from pods:
```bash
kubectl exec -n oidc-vpn-manager deployment/openvpn-test-oidc-vpn-manager-frontend-user -- curl -s https://tinyoidc.sprig.gs/.well-known/openid-configuration
```