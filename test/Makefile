# OpenVPN Manager Test Environment Makefile
# Converts functionality from setup-test-cluster.sh into Make targets

CLUSTER_NAME := openvpn-test
SCRIPT_DIR := $(shell pwd)
HELM_CHART_DIR := $(shell dirname $(SCRIPT_DIR))

.PHONY: all clean setup deps cluster ingress secrets postgresql openvpn coredns status help
.DEFAULT_GOAL := help

## Set up complete test environment (equivalent to original script)
setup: all
all: deps clean cluster ingress coredns secrets postgresql openvpn  status

## Install dependencies (kubectl, kind, helm)
deps:
	@echo "📦 Installing dependencies..."
	@if ! command -v kubectl >/dev/null 2>&1; then \
		echo "Installing kubectl..."; \
		curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
		chmod +x kubectl; \
		sudo mv kubectl /usr/local/bin/; \
	fi
	@if ! command -v kind >/dev/null 2>&1; then \
		echo "Installing kind..."; \
		curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64; \
		chmod +x ./kind; \
		sudo mv ./kind /usr/local/bin/kind; \
	fi
	@if ! command -v helm >/dev/null 2>&1; then \
		echo "Installing helm..."; \
		curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; \
	fi
	@echo "✅ Dependencies installed"

## Delete existing cluster if it exists
clean:
	@echo "🗑️  Cleaning up existing cluster..."
	@if kind get clusters 2>/dev/null | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "💻  kind delete cluster --name $(CLUSTER_NAME)"; \
		kind delete cluster --name $(CLUSTER_NAME); \
	else \
		echo "No existing cluster found"; \
	fi

## Create kind cluster with configuration
cluster:
	@echo "🏗️  Creating kind cluster: $(CLUSTER_NAME) (Kubernetes v1.31.0)"
	@echo "💻  kind create cluster --config=\"$(SCRIPT_DIR)/kind-cluster.yaml\" --name $(CLUSTER_NAME)"
	@kind create cluster --config="$(SCRIPT_DIR)/kind-cluster.yaml" --name $(CLUSTER_NAME)
	@echo "⏳ Waiting for cluster to be ready..."
	@echo "💻  kubectl wait --for=condition=Ready nodes --all --timeout=300s"
	@kubectl wait --for=condition=Ready nodes --all --timeout=300s

## Install and configure NGINX Ingress Controller
ingress:
	@echo "🌐 Installing NGINX Ingress Controller..."
	@echo "💻  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@echo "⏳ Waiting for NGINX Ingress Controller to be ready..."
	@echo "💻  kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s"
	@kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
	@echo "🔧 Configuring NGINX Ingress for Kind compatibility..."
	@echo "💻  kubectl patch deployment ingress-nginx-controller -n ingress-nginx (move to control-plane)"
	@kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p "{\"spec\":{\"template\":{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"$(CLUSTER_NAME)-control-plane\"}}}}}"
	@echo "💻  kubectl patch svc ingress-nginx-controller -n ingress-nginx (change to NodePort)"
	@kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"NodePort"}}'
	@echo "⏳ Waiting for ingress controller to restart on control-plane..."
	@kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
	@echo "✅ NGINX Ingress configured for Kind with high ports (8080/8443)"

## Create namespaces and distribute secrets
secrets:
	@echo "🎯 Setting up namespaces and secrets..."
	@echo "🏗️  Creating namespaces..."
	@echo "💻  kubectl create namespace postgresql --dry-run=client -o yaml | kubectl apply -f -"
	@kubectl create namespace postgresql --dry-run=client -o yaml | kubectl apply -f -
	@echo "💻  kubectl create namespace oidc --dry-run=client -o yaml | kubectl apply -f -"
	@kubectl create namespace oidc --dry-run=client -o yaml | kubectl apply -f -
	@echo "💻  kubectl create namespace openvpn-manager --dry-run=client -o yaml | kubectl apply -f -"
	@kubectl create namespace openvpn-manager --dry-run=client -o yaml | kubectl apply -f -
	@echo "🔐 Loading environment variables from .env file..."
	@if [ ! -f "$(SCRIPT_DIR)/.env" ]; then \
		echo "⚠️  Warning: .env file not found at $(SCRIPT_DIR)/.env"; \
		echo "    Create .env file with GITHUB_USERNAME and GITHUB_TOKEN"; \
		echo "    Copy from .env.example and fill in your values"; \
		exit 1; \
	fi
	@echo "🔐 Creating pull secret in all namespaces..."
	@echo "✅ Environment variables loaded"
	@. $(SCRIPT_DIR)/.env && \
	if [ -n "$$GITHUB_USERNAME" ] && [ -n "$$GITHUB_TOKEN" ]; then \
		AUTH_STRING=$$(echo -n "$$GITHUB_USERNAME:$$GITHUB_TOKEN" | base64 -w 0); \
		DOCKERCONFIG_JSON="{\"auths\":{\"ghcr.io\":{\"auth\":\"$$AUTH_STRING\"}}}"; \
		for namespace in default postgresql oidc openvpn-manager; do \
			echo "💻  kubectl create secret --namespace $$namespace generic ghcr-pull-secret --from-literal=.dockerconfigjson="-------SECRET-------" --type=kubernetes.io/dockerconfigjson"; \
			kubectl create secret --namespace $$namespace generic ghcr-pull-secret --from-literal=.dockerconfigjson="$$DOCKERCONFIG_JSON" --type=kubernetes.io/dockerconfigjson || echo "Pull secret already exists"; \
			echo "✅ Pull secret created in $$namespace namespace"; \
		done \
	else \
		echo "⚠️  Warning: GITHUB_USERNAME or GITHUB_TOKEN not set in .env file"; \
		exit 1; \
	fi

## Deploy PostgreSQL chart
postgresql:
	@echo "🗄️  Deploying PostgreSQL chart..."
	@cd $(HELM_CHART_DIR) && \
		echo "💻  helm install postgresql-test ./test/postgresql --namespace postgresql --values ./test/postgresql/test-values.yaml" && \
		helm install postgresql-test ./test/postgresql --namespace postgresql --values ./test/postgresql/test-values.yaml

## Deploy OpenVPN Manager chart
openvpn: secrets
	@echo "🚀 Deploying OpenVPN Manager chart..."
	@cd $(HELM_CHART_DIR) && \
		if helm ls --namespace openvpn-manager | grep -q 'openvpn-test' ; then \
			echo "💻  helm upgrade openvpn-test ./openvpn-manager --namespace openvpn-manager --values ./test/test-values.yaml" && \
			helm upgrade openvpn-test ./openvpn-manager --namespace openvpn-manager --values ./test/test-values.yaml --set-string secrets.pkiCert.intermediate=$$(base64 -w 0 "test/pki/intermediate-ca.crt"),secrets.pkiCert.root=$$(base64 -w 0 "test/pki/root-ca.crt"),secrets.pkiKey.intermediate=$$(base64 -w 0 "test/pki/intermediate-ca.key") ; \
		else \
			echo "💻  helm install openvpn-test ./openvpn-manager --namespace openvpn-manager --values ./test/test-values.yaml" && \
			helm install openvpn-test ./openvpn-manager --namespace openvpn-manager --values ./test/test-values.yaml --set-string secrets.pkiCert.intermediate=$$(base64 -w 0 "test/pki/intermediate-ca.crt"),secrets.pkiCert.root=$$(base64 -w 0 "test/pki/root-ca.crt"),secrets.pkiKey.intermediate=$$(base64 -w 0 "test/pki/intermediate-ca.key") ; \
		fi
	@echo "✅ OpenVPN Manager chart deployed successfully"

## Configure CoreDNS for tinyoidc.localhost resolution
coredns:
	@echo "🔧 Configuring CoreDNS for tinyoidc.localhost resolution..."
	@echo "💻  kubectl patch configmap coredns -n kube-system --type merge"
	@kubectl patch configmap coredns -n kube-system --type merge -p '{"data":{"Corefile":".:53 {\n    errors\n    health {\n       lameduck 5s\n    }\n    ready\n    rewrite name tinyoidc.localhost 172.17.0.2\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n       ttl 30\n    }\n    prometheus :9153\n    forward . /etc/resolv.conf {\n       max_concurrent 1000\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}"}}'
	@echo "💻  kubectl rollout restart deployment/coredns -n kube-system"
	@kubectl rollout restart deployment/coredns -n kube-system
	@echo "💻  kubectl rollout status deployment/coredns -n kube-system --timeout=60s"
	@kubectl rollout status deployment/coredns -n kube-system --timeout=60s
	@echo "✅ CoreDNS configured successfully"

## Wait for all pods to be ready and show status
status:
	@echo "⏳ Waiting for pods to be ready..."
	@echo "💻  kubectl wait --for=condition=ready pod --all --namespace postgresql --timeout=300s"
	@kubectl wait --for=condition=ready pod --all --namespace postgresql --timeout=300s || echo "PostgreSQL pods may still be starting..."
	@echo "💻  kubectl wait --for=condition=ready pod --all --namespace openvpn-manager --timeout=600s"
	@kubectl wait --for=condition=ready pod --all --namespace openvpn-manager --timeout=600s || echo "OpenVPN Manager pods may still be starting..."
	@echo ""
	@echo "🎉 OpenVPN Manager test environment is ready!"
	@echo ""
	@echo "📊 Cluster Status:"
	@kubectl get nodes
	@echo ""
	@echo "🏃 Running Services:"
	@echo "PostgreSQL namespace:"
	@kubectl get pods --namespace postgresql
	@echo "OpenVPN Manager namespace:"
	@kubectl get pods --namespace openvpn-manager
	@echo ""
	@echo "🌐 Ingress Routes:"
	@kubectl get ingress --all-namespaces
	@echo ""
	@echo "🔗 Access URLs (configured for high ports 8080/8443):"
	@echo "  👤 User frontend:  http://user.localhost:8080"
	@echo "  🔧 Admin frontend: http://admin.localhost:8080"
	@echo ""
	@echo "🐛 Troubleshooting commands:"
	@echo "  kubectl get pods                    # Check pod status"
	@echo "  kubectl logs -l app.kubernetes.io/name=openvpn-manager  # View logs"
	@echo "  kubectl get ingress                 # Check ingress status"
	@echo ""
	@echo "🧹 To clean up when done:"
	@echo "  make clean"

## Show help information
help:
	@echo "OpenVPN Manager Test Environment Makefile"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "Main workflows:"
	@echo "  make setup    - Complete test environment setup (equivalent to setup-test-cluster.sh)"
	@echo "  make clean    - Delete existing cluster"
	@echo "  make status   - Show cluster status and URLs"
	@echo ""
	@echo "Individual steps:"
	@echo "  make deps       - Install dependencies (kubectl, kind, helm)"  
	@echo "  make cluster    - Create kind cluster"
	@echo "  make ingress    - Install NGINX ingress controller"
	@echo "  make secrets    - Set up pull secrets from .env"
	@echo "  make namespaces - Create namespaces and PKI secrets"
	@echo "  make postgresql - Deploy PostgreSQL"
	@echo "  make oidc       - Deploy Tiny OIDC"
	@echo "  make openvpn    - Deploy OpenVPN Manager"
	@echo "  make coredns    - Configure DNS for tinyoidc.localhost"