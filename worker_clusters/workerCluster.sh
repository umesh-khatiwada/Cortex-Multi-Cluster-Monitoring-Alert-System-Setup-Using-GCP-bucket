#!/bin/bash

echo "Starting Worker Cluster Setup..."
echo "This will create a monitoring cluster with Prometheus that sends data to Cortex"

# Check if Kind is installed
if ! command -v kind &> /dev/null; then
    echo "ERROR: Kind is not installed. Please install Kind first."
    echo "Visit: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if helm is installed  
if ! command -v helm &> /dev/null; then
    echo "ERROR: helm is not installed. Please install helm first."
    exit 1
fi

# Delete existing cluster if it exists
echo "Cleaning up existing monitoring cluster..."
kind delete cluster --name monitoring 2>/dev/null || true

# Creating Kubernetes cluster using Kind
echo "Creating Kind cluster named 'monitoring'..."
kind create cluster --name monitoring

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
kubectl config use-context kind-monitoring
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Adding Helm repository for Prometheus
echo "Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Installing Prometheus server using Helm
echo "Installing Prometheus server..."
helm install prometheus-server prometheus-community/prometheus \
  --wait --timeout=600s

# Wait for Prometheus to be ready
echo "Waiting for Prometheus to be ready..."
kubectl wait --for=condition=Available deployment/prometheus-server --timeout=300s

# Get current services
echo "Current services in the cluster:"
kubectl get services

# Asking user for the Cortex-nginx IP or Domain
echo ""
echo "============================================"
echo "CORTEX ENDPOINT CONFIGURATION"
echo "============================================"
echo "Enter the Cortex-nginx endpoint URL:"
echo "Examples:"
echo "  - http://192.168.1.100"
echo "  - http://cortex.example.com"
echo "  - http://8005.server.xyz.np"
echo ""
read -p "Cortex-nginx URL: " cortexNginx

# Validate URL format
if [[ ! $cortexNginx =~ ^https?:// ]]; then
    echo "WARNING: URL should start with http:// or https://"
    echo "Adding http:// prefix..."
    cortexNginx="http://$cortexNginx"
fi

echo ""
echo "============================================"
echo "BASIC AUTHENTICATION CONFIGURATION"
echo "============================================"
echo "Enter Basic Auth credentials for Cortex access:"
read -p "Username: " UserName
read -s -p "Password: " PasswordHttpAuth
echo ""

# Validate credentials
if [[ -z "$UserName" || -z "$PasswordHttpAuth" ]]; then
    echo "ERROR: Username and password cannot be empty!"
    exit 1
fi

echo ""
echo "============================================"
echo "CONFIGURATION SUMMARY"
echo "============================================"
echo "Cortex Endpoint: $cortexNginx/api/prom/push"
echo "Username: $UserName"
echo "Password: [HIDDEN]"
echo ""

# Creating the Prometheus custom values file
echo "Creating Prometheus configuration..."
cat << EOF > prometheus_values.yaml
# Prometheus Worker Cluster Configuration
# This configuration sends metrics to Cortex main cluster

server:
  # Remote write configuration to send data to Cortex
  remoteWrite:
  - url: $cortexNginx/api/prom/push
    basic_auth:
      username: $UserName
      password: $PasswordHttpAuth
    # Optional: Add queue configuration for better reliability
    queue_config:
      max_samples_per_send: 1000
      batch_send_deadline: 5s
      max_retries: 3
  
  # Retention policy (data will be sent to Cortex for long-term storage)
  retention: "15d"
  
  # Resource configuration
  resources:
    requests:
      memory: "512Mi"
      cpu: "100m"
    limits:
      memory: "1Gi" 
      cpu: "500m"

  # Service configuration
  service:
    type: LoadBalancer
    port: 9090

  # Persistence configuration
  persistentVolume:
    enabled: true
    size: 8Gi

# Alertmanager configuration (optional)
alertmanager:
  enabled: true
  service:
    type: LoadBalancer

# Node exporter for system metrics
nodeExporter:
  enabled: true

# kube-state-metrics for Kubernetes metrics
kubeStateMetrics:
  enabled: true

# Pushgateway for batch jobs (optional)
pushgateway:
  enabled: false
EOF

echo "Upgrading Prometheus with Cortex remote write configuration..."
# Upgrading Prometheus using the custom values file
helm upgrade -f prometheus_values.yaml prometheus-server prometheus-community/prometheus \
  --wait --timeout=600s

# Wait for upgrade to complete
echo "Waiting for Prometheus upgrade to complete..."
kubectl rollout status deployment/prometheus-server --timeout=300s

echo ""
echo "============================================"
echo "DEPLOYMENT COMPLETE!"
echo "============================================"

# Get service information
echo "Getting service endpoints..."
kubectl get services

# Get Prometheus server endpoint
PROMETHEUS_SERVICE=$(kubectl get service prometheus-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [[ -z "$PROMETHEUS_SERVICE" ]]; then
    PROMETHEUS_SERVICE=$(kubectl get service prometheus-server -o jsonpath='{.spec.clusterIP}')
fi

echo ""
echo "============================================"
echo "ACCESS INFORMATION"
echo "============================================"
echo "Prometheus Server: http://$PROMETHEUS_SERVICE:9090"
echo "Context: kind-monitoring"
echo "Remote Write URL: $cortexNginx/api/prom/push"
echo ""

# Test connectivity (optional)
echo "============================================"
echo "CONNECTIVITY TEST"
echo "============================================"
read -p "Do you want to test connectivity to Cortex? (y/N): " test_conn

if [[ $test_conn =~ ^[Yy]$ ]]; then
    echo "Testing connectivity to Cortex endpoint..."
    if curl -s -u "$UserName:$PasswordHttpAuth" "$cortexNginx/ready" >/dev/null 2>&1; then
        echo "✅ Successfully connected to Cortex!"
    else
        echo "⚠️  Warning: Could not connect to Cortex endpoint."
        echo "   This might be normal if Cortex is not yet fully deployed."
        echo "   You can test later with:"
        echo "   curl -u '$UserName:****' '$cortexNginx/ready'"
    fi
fi

echo ""
echo "============================================"
echo "NEXT STEPS"
echo "============================================"
echo "1. Check Prometheus is running:"
echo "   kubectl get pods"
echo ""
echo "2. View Prometheus logs:"
echo "   kubectl logs deployment/prometheus-server"
echo ""
echo "3. Access Prometheus UI:"
echo "   kubectl port-forward service/prometheus-server 9090:80"
echo "   Then visit: http://localhost:9090"
echo ""
echo "4. Check remote write status in Prometheus UI:"
echo "   Go to Status > Runtime & Build Information"
echo "   Look for remote write configuration"
echo ""
echo "5. Switch back to main cluster context:"
echo "   kubectl config use-context kind-openuser"
echo ""
echo "Worker cluster setup completed successfully! 🎉"
