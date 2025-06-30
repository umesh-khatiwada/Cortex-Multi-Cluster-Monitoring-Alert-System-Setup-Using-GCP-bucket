#!/bin/bash
echo "
To install the cortex in the system please prepare the following requirement
1.ruler_storage & alertmanager_storage s3 buckets
2. blocks_storage GCP  buckets
3. Need Kind install on the System if the machine is loal"

# Source the env_variables.sh script to load the environment variables
echo "Applying envirnoment variable"
chmod +x env_variables.sh
. ./env_variables.sh

# Validate key.json file exists and is properly configured
echo "Validating GCP service account key..."
if [[ ! -f "${KEY_FILE}" ]]; then
    echo "❌ ERROR: ${KEY_FILE} not found!"
    echo ""
    echo "Please follow these steps:"
    echo "1. Copy the example: cp key.json.example key.json"
    echo "2. Download your GCP service account key from Google Cloud Console"
    echo "3. Replace the content of key.json with your actual credentials"
    echo ""
    echo "The key.json file is gitignored for security reasons."
    exit 1
fi

# Check if key.json contains example/placeholder values
if grep -q "your-gcp-project-id\|your-private-key-id\|your-service-account" "${KEY_FILE}"; then
    echo "❌ ERROR: ${KEY_FILE} contains placeholder values!"
    echo ""
    echo "Please replace key.json with your actual GCP service account credentials:"
    echo "1. Download your service account key from Google Cloud Console"
    echo "2. Replace the entire content of key.json with the downloaded JSON"
    echo ""
    exit 1
fi

# Validate JSON format
if ! jq empty "${KEY_FILE}" 2>/dev/null; then
    echo "❌ ERROR: ${KEY_FILE} is not valid JSON!"
    echo "Please ensure the file contains valid JSON format."
    exit 1
fi

echo "✅ GCP service account key validation passed!"

# Check if it's a server or local machine
echo "Check if it's a local or server  machine. Type 'Y' for local or 'N' for server:"
read checkData

if [[ $checkData == "Y" ]]; then
    echo "This is a local machine. Running Kind cluster setup..."
# Create the Kind cluster
  kind delete clusters openuser
  sleep 3
  kind create cluster --name openuser

else
  echo "This is a server. Skipping Kind cluster setup."
fi

# Install Prometheus with Helm chart
kubectl create namespace  ${NS}
helm repo add stable https://charts.helm.sh/stable
helm repo update
helm install stable prometheus-community/kube-prometheus-stack 

# Verify Prometheus installation
kubectl get pods 
echo "Waiting for Prometheus pod to be ready..."
kubectl wait --for=condition=Ready pod -l app=prom-app --timeout=3s

echo "Prometheus pod is up and running!"
echo "Prometheus installed on the Kind cluster using Helm chart!"

helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/consul
helm install consul hashicorp/consul --set global.name=consul --namespace cortex



#Helper File to setup "files contains yaml"
echo "Applying Prometheus values "
chmod +x helper.sh
. ./helper.sh
