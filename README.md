# Cortex GCP Auto Deployment Scripts

This repository contains automated scripts for deploying Cortex (Prometheus long-term storage) on Google Cloud Platform (GCP) using Kubernetes clusters. The setup includes both main cluster (Cortex server) and worker clusters (Prometheus agents) configurations.

## 📁 Project Structure

```
GOOGLE_GCS/
├── main_cluster/
│   ├── cortexMainCluster.sh    # Main deployment script
│   ├── env_variables.sh        # Environment configuration
│   ├── helper.sh              # Helper functions and YAML generation
│   └── key.json              # GCP service account key
└── worker_clusters/
    └── workerCluster.sh       # Worker cluster setup script
```

## 🚀 Features

- **Automated Cortex Deployment**: Complete setup of Cortex with GCS backend storage
- **Multi-cluster Support**: Main cluster for Cortex and worker clusters for Prometheus agents
- **GCP Integration**: Uses Google Cloud Storage for blocks, rules, and alertmanager storage
- **NGINX Authentication**: Built-in basic authentication for secure access
- **Prometheus Integration**: Automatic Prometheus setup with remote write to Cortex
- **Consul Service Discovery**: Integrated Consul for service discovery
- **Monitoring**: ServiceMonitor configurations for complete observability

## 📋 Prerequisites

### Software Requirements
- **kubectl** - Kubernetes command-line tool
- **helm** - Kubernetes package manager
- **kind** - Kubernetes in Docker (for local development)
- **Docker** - Container runtime

### GCP Requirements
- Google Cloud Platform account with billing enabled
- Service account with appropriate permissions
- Three GCS buckets for storage:
  - `cortex-blocks-dev` (blocks storage)
  - `cortex-alert-rules-dev` (ruler and alertmanager storage)

### Required GCP Permissions
Your service account needs the following roles:
- `Storage Admin` or `Storage Object Admin`
- `Kubernetes Engine Admin` (if using GKE)

## 🛠️ Setup Instructions

### 1. Configure GCP Service Account

1. Create a service account in Google Cloud Console
2. Download the JSON key file
3. Replace the content in `main_cluster/key.json` with your service account key

**Current Configuration:**
- Project ID: `openuser-devops-labs`
- Service Account: `alertmanager@openuser-devops-labs.iam.gserviceaccount.com`

### 2. Configure Environment Variables

Edit `main_cluster/env_variables.sh`:

```bash
# Namespace for Cortex deployment
NS=cortex

# GCP bucket names (update with your bucket names)
GCP_Blocks_BucketName=your-cortex-blocks-bucket
GCP_Ruler_BucketName=your-cortex-rules-bucket
GCP_Alert_BucketName=your-cortex-alert-bucket

# Basic auth credentials (base64 encoded)
prometheus_users=your-base64-username
prometheus_password=your-base64-password

# NGINX users (generate from https://wtools.io/generate-htpasswd-online)
keyValuePairs["username"]="$apr1$hash$encryptedpassword"
```

**Default Values:**
- Namespace: `cortex`
- Default buckets: `cortex-blocks-dev`, `cortex-alert-rules-dev`
- Default credentials: `openuser` (base64: `YmVycnlieXRlcw==`)

### 3. Deploy Main Cluster

```bash
cd main_cluster/
chmod +x cortexMainCluster.sh
./cortexMainCluster.sh
```

The script will prompt you to choose between:
- **Y**: Local deployment (uses Kind cluster named `openuser`)
- **N**: Server deployment (uses existing Kubernetes cluster)

**Main Cluster Components Deployed:**
1. **Cortex**: Main long-term storage system with GCS backend
2. **Consul**: Service discovery (HashiCorp Consul)
3. **NGINX**: Load balancer with basic authentication
4. **Prometheus**: Monitoring with kube-prometheus-stack

### 4. Deploy Worker Clusters

```bash
cd worker_clusters/
chmod +x workerCluster.sh
./workerCluster.sh
```

The script will:
1. Create a Kind cluster named `monitoring`
2. Install Prometheus server using Helm
3. Prompt for:
   - Cortex-nginx IP or Domain (e.g., `http://192.168.1.100` or `http://cortex.example.com`)
   - Basic auth username and password

## 🔧 Configuration Details

### Main Cluster Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   NGINX Proxy   │────│  Cortex Stack   │────│   GCS Storage   │
│  (LoadBalancer) │    │   (Namespace:   │    │   - Blocks      │
│  Port: 80       │    │    cortex)      │    │   - Rules       │
│  Basic Auth     │    │                 │    │   - Alerts      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         │              ┌─────────────────┐
         │              │  Consul Server  │
         │              │  Service Disc.  │
         │              │  Port: 8500     │
         └──────────────┴─────────────────┘
```

### Storage Configuration

The system uses GCS storage with the following structure:
- **Blocks Storage**: `cortex-blocks-dev` - Time series data chunks
- **Ruler Storage**: `cortex-alert-rules-dev` - Recording and alerting rules
- **Alertmanager Storage**: `cortex-alert-rules-dev` - Alert configuration and state

### Authentication Configuration

**NGINX Basic Auth:**
- Default user: `openuser`
- Password hash generated via: https://wtools.io/generate-htpasswd-online
- Header injection: `X-Scope-OrgID: $remote_user`

**Prometheus Remote Write:**
- Endpoint: `http://cortex-nginx.cortex/api/prom/push`
- Uses basic auth with base64 encoded credentials
- Secret name: `openuser-secrets`

## 📊 Accessing Services

### Main Cluster Services

```bash
# Get all services in cortex namespace
kubectl get services -n cortex

# Check NGINX service (LoadBalancer)
kubectl get service cortex-nginx -n cortex

# Check Prometheus service (LoadBalancer on port 9092)
kubectl get service prometheus-app

# Access Cortex API with authentication
curl -u openuser:openuser http://<nginx-ip>/api/prom/push
```

### Default Service Ports
- **NGINX**: Port 80 (LoadBalancer with basic auth)
- **Prometheus**: Port 9092 (LoadBalancer)
- **Consul**: Port 8500 (Internal service discovery)
- **Cortex Components**: Various internal ports with ServiceMonitors

### Worker Cluster Services

```bash
# Check worker cluster services
kubectl config use-context kind-monitoring
kubectl get services

# Prometheus server endpoint
kubectl get service prometheus-server
```

## 🔍 Monitoring and Observability

### ServiceMonitor Configuration
All Cortex components include ServiceMonitor with label `release: prom`:
- Distributor
- Ingester
- Querier
- Query Frontend
- Ruler
- Alertmanager
- Store Gateway
- Compactor
- NGINX

### Prometheus Configuration
- **Main Cluster**: Uses kube-prometheus-stack
- **Worker Clusters**: Uses prometheus-community/prometheus
- **Remote Write**: Configured to send metrics to Cortex
- **Retention**: 10 days (configurable)

## 🛠️ Troubleshooting

### Common Issues

1. **Kind Cluster Issues**
   ```bash
   # Delete and recreate Kind cluster
   kind delete cluster --name openuser
   kind create cluster --name openuser
   
   # For worker clusters
   kind delete cluster --name monitoring
   kind create cluster --name monitoring
   ```

2. **GCS Permission Issues**
   ```bash
   # Verify service account key
   kubectl get secret gcp-sa -n cortex -o yaml
   
   # Check pod logs for GCS errors
   kubectl logs -n cortex deployment/cortex-distributor
   ```

3. **Authentication Issues**
   ```bash
   # Check NGINX secret
   kubectl get secret nginx-user-secrets -n cortex -o yaml
   
   # Test basic auth
   echo -n "openuser:openuser" | base64
   ```

4. **Consul Connectivity**
   ```bash
   # Check Consul leader
   kubectl exec -n cortex deployment/consul-server -- consul members
   
   # Test Consul API
   kubectl port-forward -n cortex service/consul-server 8500:8500
   curl http://localhost:8500/v1/status/leader
   ```

### Debug Commands

```bash
# Check all pods in cortex namespace
kubectl get pods -n cortex

# Describe problematic pods
kubectl describe pod <pod-name> -n cortex

# Check logs
kubectl logs -n cortex <pod-name> -f

# Check ConfigMaps
kubectl get configmap -n cortex cortex -o yaml

# Verify secrets
kubectl get secrets -n cortex
```

## 🧪 Testing the Setup

### Test Main Cluster

```bash
# 1. Check all services are running
kubectl get pods -n cortex
kubectl get services -n cortex

# 2. Test NGINX endpoint
NGINX_IP=$(kubectl get service cortex-nginx -n cortex -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -u openuser:openuser http://$NGINX_IP/ready

# 3. Test Prometheus access
PROM_IP=$(kubectl get service prometheus-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$PROM_IP:9092/api/v1/query?query=up
```

### Test Worker Cluster

```bash
# Switch to worker cluster context
kubectl config use-context kind-monitoring

# Check Prometheus is sending data
kubectl logs deployment/prometheus-server | grep "remote_write"
```

## 🔧 Customization

### Adding New Users

1. Generate htpasswd entry: https://wtools.io/generate-htpasswd-online
2. Add to `keyValuePairs` in `env_variables.sh`:
   ```bash
   keyValuePairs["newuser"]="$apr1$generated$hash"
   ```
3. Re-run the deployment

### Changing GCS Buckets

Update the bucket names in `env_variables.sh`:
```bash
GCP_Blocks_BucketName=your-new-blocks-bucket
GCP_Ruler_BucketName=your-new-rules-bucket
GCP_Alert_BucketName=your-new-alerts-bucket
```

### Scaling Components

Modify the `cortex-values.yaml` generation in `helper.sh` to add replicas and resources:
```yaml
ingester:
  replicas: 3
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
```

## 🗂️ File Descriptions

### Main Cluster Files

- **`cortexMainCluster.sh`**: Main deployment script that orchestrates the entire setup
- **`env_variables.sh`**: Contains all configuration variables and user credentials
- **`helper.sh`**: Generates Kubernetes YAML files and applies configurations
- **`key.json`**: GCP service account credentials

### Worker Cluster Files

- **`workerCluster.sh`**: Sets up worker clusters with Prometheus remote write to Cortex

## 📝 Maintenance

### Regular Tasks

1. **Monitor GCS Usage**: Check bucket sizes and costs regularly
2. **Update Helm Charts**: Keep Cortex and Prometheus charts updated
3. **Rotate Credentials**: Update service account keys and passwords periodically
4. **Check Logs**: Monitor component logs for errors

### Backup and Recovery

```bash
# Backup configurations
cp -r main_cluster/ backup/main_cluster_$(date +%Y%m%d)/

# Export Kubernetes resources
kubectl get all -n cortex -o yaml > cortex-backup.yaml
```

### Cleanup

```bash
# Delete Kind clusters
kind delete cluster --name openuser
kind delete cluster --name monitoring

# Delete Kubernetes resources
kubectl delete namespace cortex
helm uninstall cortex consul stable -n cortex
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Test thoroughly in a development environment
4. Submit a pull request with detailed description

## 🔒 Security Notes

- **Service Account Key**: Never commit actual GCP service account keys to version control
- **Passwords**: Use strong passwords and rotate them regularly
- **Network Security**: Consider using private clusters and VPC firewalls
- **RBAC**: Review and minimize Kubernetes permissions

## 📄 License

This project is licensed under [Your License] - see the LICENSE file for details.

## 📞 Support

For issues and questions:
- Create an issue in the repository
- Check logs using the troubleshooting commands above
- Review GCP and Kubernetes documentation

---

**⚠️ Important**: Always test deployments in a development environment before production use. Ensure proper backup and monitoring procedures are in place.
