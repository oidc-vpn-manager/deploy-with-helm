#!/bin/bash
set -e

CLUSTER_NAME="openvpn-test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_CHART_DIR="$(dirname ${SCRIPT_DIR})"

echo "🚀 Setting up complete Kubernetes test environment for OpenVPN Manager..."
echo ""

# Install dependencies if not present
echo "📦 Installing dependencies..."

# Install kubectl if not present
if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Install kind if not present
if ! command -v kind &> /dev/null; then
    echo "Installing kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
fi

# Install helm if not present
if ! command -v helm &> /dev/null; then
    echo "Installing helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "✅ Dependencies installed"
echo ""

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "🗑️  Cluster ${CLUSTER_NAME} already exists. Deleting it first..."
    echo "💻  kind delete cluster --name ${CLUSTER_NAME}"
    kind delete cluster --name ${CLUSTER_NAME}
fi

# Create kind cluster
echo "🏗️  Creating kind cluster: ${CLUSTER_NAME} (Kubernetes v1.31.0)"
echo "💻  kind create cluster --config=\"${SCRIPT_DIR}/kind-cluster.yaml\" --name ${CLUSTER_NAME}"
kind create cluster --config="${SCRIPT_DIR}/kind-cluster.yaml" --name ${CLUSTER_NAME}

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
echo "💻  kubectl wait --for=condition=Ready nodes --all --timeout=300s"
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install NGINX Ingress Controller
echo "🌐 Installing NGINX Ingress Controller..."
echo "💻  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller to be ready
echo "⏳ Waiting for NGINX Ingress Controller to be ready..."
echo "💻  kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s"
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s

# Fix nginx ingress for Kind - move to control-plane and use NodePort
echo "🔧 Configuring NGINX Ingress for Kind compatibility..."
echo "💻  kubectl patch deployment ingress-nginx-controller -n ingress-nginx (move to control-plane)"
kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p "{\"spec\":{\"template\":{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"${CLUSTER_NAME}-control-plane\"}}}}}"
echo "💻  kubectl patch svc ingress-nginx-controller -n ingress-nginx (change to NodePort)"
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"NodePort"}}'
echo "⏳ Waiting for ingress controller to restart on control-plane..."
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
echo "✅ NGINX Ingress configured for Kind with high ports (8080/8443)"

# Load environment variables from .env file
echo "🔐 Loading environment variables from .env file..."
if [ -f "${SCRIPT_DIR}/.env" ]; then
    source "${SCRIPT_DIR}/.env"
    echo "✅ Environment variables loaded"
else
    echo "⚠️  Warning: .env file not found at ${SCRIPT_DIR}/.env"
    echo "    Create .env file with GITHUB_USERNAME and GITHUB_TOKEN"
    echo "    Copy from .env.example and fill in your values"
    exit 1
fi

# Create pull secret for private registries using environment variables
echo "🔐 Creating pull secret for private registries..."
if [ -n "${GITHUB_USERNAME}" ] && [ -n "${GITHUB_TOKEN}" ]; then
    # Create auth string and base64 encode it
    AUTH_STRING=$(echo -n "${GITHUB_USERNAME}:${GITHUB_TOKEN}" | base64 -w 0)
    
    # Create dockerconfigjson
    DOCKERCONFIG_JSON="{\"auths\":{\"ghcr.io\":{\"auth\":\"${AUTH_STRING}\"}}}"
    
    echo "💻  kubectl create secret generic ghcr-pull-secret --from-literal=.dockerconfigjson='${DOCKERCONFIG_JSON}' --type=kubernetes.io/dockerconfigjson"
    kubectl create secret generic ghcr-pull-secret --from-literal=.dockerconfigjson="${DOCKERCONFIG_JSON}" --type=kubernetes.io/dockerconfigjson || echo "Pull secret already exists"
    echo "✅ Pull secret created in default namespace"
else
    echo "⚠️  Warning: GITHUB_USERNAME or GITHUB_TOKEN not set in .env file"
    exit 1
fi

# Create PKI Secret with base64 encoded certificates (will be created in openvpn-manager namespace later)
echo "🔑 Preparing PKI Secret with test certificates..."
# Use dynamic path resolution relative to this script
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
PKI_DIR="${REPO_ROOT}/tests/deploy/pki"
if [ -d "$PKI_DIR" ]; then
    echo "✅ PKI certificates found at $PKI_DIR"
else
    echo "⚠️  Warning: PKI directory not found at $PKI_DIR"
    echo "    Signing service will fail to start without PKI certificates"
fi

# Deploy the Helm charts separately in different namespaces
echo "🎯 Deploying separate Helm charts..."
cd "${HELM_CHART_DIR}"

# Create namespaces
echo "🏗️  Creating namespaces..."
echo "💻  kubectl create namespace postgresql --dry-run=client -o yaml | kubectl apply -f -"
kubectl create namespace postgresql --dry-run=client -o yaml | kubectl apply -f -
echo "💻  kubectl create namespace oidc --dry-run=client -o yaml | kubectl apply -f -"
kubectl create namespace oidc --dry-run=client -o yaml | kubectl apply -f -
echo "💻  kubectl create namespace openvpn-manager --dry-run=client -o yaml | kubectl apply -f -"
kubectl create namespace openvpn-manager --dry-run=client -o yaml | kubectl apply -f -

# Copy pull secret to all namespaces
echo "🔐 Copying pull secret to all namespaces..."
for namespace in postgresql oidc openvpn-manager; do
    echo "💻  kubectl get secret ghcr-pull-secret -o yaml | sed 's/namespace: default/namespace: ${namespace}/' | kubectl apply -f -"
    kubectl get secret ghcr-pull-secret -o yaml | sed "s/namespace: default/namespace: ${namespace}/" | kubectl apply -f -
    echo "✅ Pull secret copied to ${namespace} namespace"
done

# Create PKI Secret in openvpn-manager namespace
echo "🔑 Creating PKI Secret in openvpn-manager namespace..."
if [ -d "$PKI_DIR" ]; then
    # Create PKI Secret YAML with base64 encoded files in the openvpn-manager namespace
    cat > /tmp/pki-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: pki-certs
  namespace: openvpn-manager
  labels:
    app.kubernetes.io/name: openvpn-manager
    app.kubernetes.io/instance: openvpn-test
    app.kubernetes.io/component: pki
type: Opaque
data:
  intermediate-ca.crt: $(base64 -w 0 "$PKI_DIR/intermediate-ca.crt")
  intermediate-ca.key: $(base64 -w 0 "$PKI_DIR/intermediate-ca.key")
  root-ca.crt: $(base64 -w 0 "$PKI_DIR/root-ca.crt")
EOF
    
    echo "💻  kubectl apply -f /tmp/pki-secret.yaml"
    kubectl apply -f /tmp/pki-secret.yaml
    rm -f /tmp/pki-secret.yaml
    echo "✅ PKI Secret created in openvpn-manager namespace"
else
    echo "⚠️  PKI directory not found - skipping PKI Secret creation"
fi

# Deploy PostgreSQL chart
echo "🗄️  Deploying PostgreSQL chart..."
echo "💻  helm install postgresql-test ./test/postgresql --namespace postgresql --values ./test/postgresql-values.yaml"
helm install postgresql-test ./test/postgresql --namespace postgresql --values ./test/postgresql-values.yaml

# Deploy Tiny OIDC chart
echo "🔐 Deploying Tiny OIDC chart..."  
echo "💻  helm install oidc-test ./test/tiny-oidc --namespace oidc --values ./test/tiny-oidc-values.yaml"
helm install oidc-test ./test/tiny-oidc --namespace oidc --values ./test/tiny-oidc-values.yaml

# Deploy OpenVPN Manager main chart (without PostgreSQL and tiny-oidc)
echo "🚀 Deploying OpenVPN Manager chart..."
echo "💻  helm install openvpn-test ./openvpn-manager --namespace openvpn-manager --values ./test/test-values.yaml"
helm install openvpn-test ./openvpn-manager --namespace openvpn-manager --values ./test/test-values.yaml

# Clean up temporary PKI Secret after post-install hooks complete
echo "🧹 Cleaning up temporary PKI Secret after deployment..."
echo "💻  kubectl wait --for=condition=Complete job/openvpn-test-openvpn-manager-pki-setup --namespace openvpn-manager --timeout=300s"
kubectl wait --for=condition=Complete job/openvpn-test-openvpn-manager-pki-setup --namespace openvpn-manager --timeout=300s || echo "PKI setup job timeout - continuing anyway"
echo "💻  kubectl delete secret pki-certs --namespace openvpn-manager"
kubectl delete secret pki-certs --namespace openvpn-manager || echo "PKI Secret already deleted or not found"
echo "✅ PKI Secret cleanup completed"

# Configure CoreDNS to resolve tinyoidc.localhost to tiny-oidc service
echo "🔧 Configuring CoreDNS for tinyoidc.localhost resolution..."
echo "💻  kubectl patch configmap coredns -n kube-system --type merge"
kubectl patch configmap coredns -n kube-system --type merge -p '{"data":{"Corefile":".:53 {\n    errors\n    health {\n       lameduck 5s\n    }\n    ready\n    rewrite name tinyoidc.localhost oidc-test-tiny-oidc.oidc.svc.cluster.local\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n       ttl 30\n    }\n    prometheus :9153\n    forward . /etc/resolv.conf {\n       max_concurrent 1000\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}"}}'
echo "💻  kubectl rollout restart deployment/coredns -n kube-system"
kubectl rollout restart deployment/coredns -n kube-system
echo "💻  kubectl rollout status deployment/coredns -n kube-system --timeout=60s"
kubectl rollout status deployment/coredns -n kube-system --timeout=60s
echo "✅ CoreDNS configured successfully"

# Wait for pods to be ready in all namespaces
echo "⏳ Waiting for pods to be ready..."
echo "💻  kubectl wait --for=condition=ready pod --all --namespace postgresql --timeout=300s"
kubectl wait --for=condition=ready pod --all --namespace postgresql --timeout=300s || echo "PostgreSQL pods may still be starting..."
echo "💻  kubectl wait --for=condition=ready pod --all --namespace oidc --timeout=300s"
kubectl wait --for=condition=ready pod --all --namespace oidc --timeout=300s || echo "OIDC pods may still be starting..."
echo "💻  kubectl wait --for=condition=ready pod --all --namespace openvpn-manager --timeout=600s"
kubectl wait --for=condition=ready pod --all --namespace openvpn-manager --timeout=600s || echo "OpenVPN Manager pods may still be starting..."

echo ""
echo "🎉 OpenVPN Manager test environment is ready!"
echo ""
echo "📊 Cluster Status:"
kubectl get nodes
echo ""
echo "🏃 Running Services:"
echo "PostgreSQL namespace:"
kubectl get pods --namespace postgresql
echo "OIDC namespace:"
kubectl get pods --namespace oidc
echo "OpenVPN Manager namespace:"
kubectl get pods --namespace openvpn-manager
echo ""
echo "🌐 Ingress Routes:"
kubectl get ingress --all-namespaces
echo ""
echo "🔗 Access URLs (configured for high ports 8080/8443):"
echo "  👤 User frontend:  http://user.localhost:8080"
echo "  🔧 Admin frontend: http://admin.localhost:8080" 
echo "  🔐 Tiny OIDC:      http://tinyoidc.localhost:8080"
echo ""
echo "🐛 Troubleshooting commands:"
echo "  kubectl get pods                    # Check pod status"
echo "  kubectl logs -l app.kubernetes.io/name=openvpn-manager  # View logs"
echo "  kubectl get ingress                 # Check ingress status"
echo ""
echo "🧹 To clean up when done:"
echo "  kind delete cluster --name ${CLUSTER_NAME}"