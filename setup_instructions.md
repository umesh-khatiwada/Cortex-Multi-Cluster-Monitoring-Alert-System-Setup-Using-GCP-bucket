# Setup Instructions

## 🔑 GCP Service Account Setup

### Step 1: Create GCP Service Account Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **IAM & Admin** > **Service Accounts**
3. Create a new service account or select existing one
4. Click **Keys** tab > **Add Key** > **Create New Key**
5. Choose **JSON** format and download the key file

### Step 2: Required GCP Permissions

Your service account needs these roles:
- `Storage Admin` or `Storage Object Admin`
- `Kubernetes Engine Admin` (if using GKE)

### Step 3: Create GCS Buckets

Create three GCS buckets in your project:
```bash
gsutil mb gs://cortex-blocks-dev
gsutil mb gs://cortex-alert-rules-dev
```

### Step 4: Configure Key File

```bash
# Copy the example template
cp main_cluster/key.json.example main_cluster/key.json

# Replace the content with your downloaded GCP key
# DO NOT commit key.json to git - it's gitignored for security
```

### Step 5: Update Configuration

Edit `main_cluster/env_variables.sh` with your bucket names:
```bash
GCP_Blocks_BucketName=your-cortex-blocks-bucket
GCP_Ruler_BucketName=your-cortex-rules-bucket
GCP_Alert_BucketName=your-cortex-alert-bucket
```

### Step 6: Run Deployment

```bash
cd main_cluster/
./cortexMainCluster.sh
```

## 🔐 Security Notes

- **NEVER** commit `key.json` to version control
- The file is automatically gitignored
- Rotate service account keys regularly
- Use least privilege principle for permissions

## 🧪 Testing

After deployment, test the setup:
```bash
# Check pods
kubectl get pods -n cortex

# Test API endpoint
curl -u openuser:openuser http://<nginx-ip>/ready
```
