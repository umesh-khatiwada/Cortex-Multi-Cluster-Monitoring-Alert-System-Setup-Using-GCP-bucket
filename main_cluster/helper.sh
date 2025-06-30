#Dynamic userGenerator

# Validate key file before proceeding
if [[ ! -f "${KEY_FILE}" ]]; then
    echo "❌ ERROR: GCP service account key file (${KEY_FILE}) not found!"
    echo "Please ensure you have created key.json from key.json.example"
    exit 1
fi

rm -f nginx-secrets.txt
touch nginx-secrets.txt
# Loop through the associative array and process each key-value pair
for key in "${!keyValuePairs[@]}"
do

    value="${keyValuePairs[$key]}"
    echo  "$key:$value" >> nginx-secrets.txt
    # You can perform any other processing you need for each key-value pair here.
done


# Read the content of the "nginx-secrets.txt" file and assign it to the httPassword variable
httPassword=$(cat nginx-secrets.txt)

#set the username and password for the nginx
cat <<EOF  > nginx-user-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nginx-user-secrets
  namespace: cortex
stringData:
  .htpasswd: |
     $httPassword
EOF

kubectl apply -f nginx-user-secrets.yaml

#setup the prometheus values.yaml
cat << EOF > cortex-values.yaml
config:
  ruler:
    enable_api: true
    rule_path: /rules
  alertmanager:
    enable_api: true
    data_dir: /data

  auth_enabled: true
  api:
    prometheus_http_prefix: '/prometheus'
    response_compression_enabled: true
  ingester:
    lifecycler:
      join_after: 0s
      final_sleep: 0s
      num_tokens: 512
      ring:
        replication_factor: 2
        kvstore:
          store: consul
          prefix: 'collectors/'
          consul:
            host: 'consul-server:8500'
            http_client_timeout: '20s'
            consistent_reads: true
  ruler_storage:
    backend: gcs
    gcs:
      bucket_name: "${GCP_Ruler_BucketName}"

  alertmanager_storage:
    backend: gcs
    gcs:
      bucket_name: "${GCP_Alert_BucketName}"

  storage:
    engine: blocks
  blocks_storage:
    backend: gcs
    gcs:
      bucket_name: "${GCP_Blocks_BucketName}"

    bucket_store:
      sync_dir: "/data"
    tsdb:
      dir: "/data"

alertmanager:
  extraVolumes:
    - name: gcp-sa
      secret:
        secretName: gcp-sa
        items:
        - key: gcp-sa-file
          path: gcp-sa-file.json

  extraVolumeMounts:
    - name: gcp-sa
      mountPath: "/secrets"
      readOnly: true
  
  env:
    - name: GOOGLE_APPLICATION_CREDENTIALS
      value: /secrets/gcp-sa-file.json

  enabled: true
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

distributor:
  extraVolumes:
    - name: gcp-sa
      secret:
        secretName: gcp-sa
        items:
        - key: gcp-sa-file
          path: gcp-sa-file.json

  extraVolumeMounts:
    - name: gcp-sa
      mountPath: "/secrets"
      readOnly: true
  
  env:
    - name: GOOGLE_APPLICATION_CREDENTIALS
      value: /secrets/gcp-sa-file.json

  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

ingester:
  extraVolumes:
    - name: gcp-sa
      secret:
        secretName: gcp-sa
        items:
        - key: gcp-sa-file
          path: gcp-sa-file.json

  extraVolumeMounts:
    - name: gcp-sa
      mountPath: "/secrets"
      readOnly: true
  
  env:
    - name: GOOGLE_APPLICATION_CREDENTIALS
      value: /secrets/gcp-sa-file.json

  autoforget_unhealthy: true
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom


ruler:
  extraVolumes:
    - name: gcp-sa
      secret:
        secretName: gcp-sa
        items:
        - key: gcp-sa-file
          path: gcp-sa-file.json

  extraVolumeMounts:
    - name: gcp-sa
      mountPath: "/secrets"
      readOnly: true
  
  env:
    - name: GOOGLE_APPLICATION_CREDENTIALS
      value: /secrets/gcp-sa-file.json

  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

querier:
  extraVolumes:
    - name: gcp-sa
      secret:
        secretName: gcp-sa
        items:
        - key: gcp-sa-file
          path: gcp-sa-file.json

  extraVolumeMounts:
    - name: gcp-sa
      mountPath: "/secrets"
      readOnly: true
  
  env:
    - name: GOOGLE_APPLICATION_CREDENTIALS
      value: /secrets/gcp-sa-file.json

  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

query_frontend:
  extraVolumes:
    - name: gcp-sa
      secret:
        secretName: gcp-sa
        items:
        - key: gcp-sa-file
          path: gcp-sa-file.json

  extraVolumeMounts:
    - name: gcp-sa
      mountPath: "/secrets"
      readOnly: true
  
  env:
    - name: GOOGLE_APPLICATION_CREDENTIALS
      value: /secrets/gcp-sa-file.json

  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

nginx:
  enabled: true
  http_listen_port: 80 
  config:
    setHeaders: 
        X-Scope-OrgID: \$remote_user
    basicAuthSecretName: nginx-user-secrets
    verboseLogging: true
  service:
    type: LoadBalancer
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

store_gateway:
  extraVolumes:
    - name: gcp-sa
      secret:
        secretName: gcp-sa
        items:
        - key: gcp-sa-file
          path: gcp-sa-file.json

  extraVolumeMounts:
    - name: gcp-sa
      mountPath: "/secrets"
      readOnly: true
  
  env:
    - name: GOOGLE_APPLICATION_CREDENTIALS
      value: /secrets/gcp-sa-file.json

  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

compactor:
  extraVolumes:
    - name: gcp-sa
      secret:
        secretName: gcp-sa
        items:
        - key: gcp-sa-file
          path: gcp-sa-file.json

  extraVolumeMounts:
    - name: gcp-sa
      mountPath: "/secrets"
      readOnly: true
  
  env:
    - name: GOOGLE_APPLICATION_CREDENTIALS
      value: /secrets/gcp-sa-file.json

  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom
EOF


#g-secrets - Create GCP service account secret with error handling
echo "Creating GCP service account secret..."
if kubectl create secret generic gcp-sa --from-file=gcp-sa-file=${KEY_FILE} -n ${NS} --dry-run=client -o yaml | kubectl apply -f -; then
    echo "✅ GCP service account secret created successfully"
else
    echo "❌ ERROR: Failed to create GCP service account secret"
    echo "Please check if the key file exists and is readable: ${KEY_FILE}"
    exit 1
fi

helm repo add cortex-helm https://cortexproject.github.io/cortex-helm-chart
helm install cortex --namespace ${NS} -f cortex-values.yaml cortex-helm/cortex

#Helm set data on the template 
helm template cortex cortex-helm/cortex \
-f cortex-values.yaml \
--set config.blocks_storage.gcs.bucket_name=${GCP_Blocks_BucketName} \
--set config.ruler_storage.gcs.bucket_name=${GCP_Ruler_BucketName} \
--set config.alertmanager_storage.gcs.bucket_name=${GCP_Alert_BucketName} \
--namespace ${NS}  > tmp-cortex.yaml

kubectl apply -n ${NS} -f tmp-cortex.yaml



cat << EOF > rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/metrics
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: default

EOF


#prometheus-user secrets
cat << EOF > prometheus-users-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: openuser-secrets
  namespace: default
type: Opaque
data:
  user: "${prometheus_users}"
  password: "${prometheus_password}"
EOF
kubectl apply -f prometheus-users-secrets.yaml

#prometheus 
cat << EOF > prometheus.yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prom-app
  namespace: default
spec:
  enableAdminAPI: false
  image: quay.io/prometheus/prometheus:v2.28.1
  listenLocal: false
  logFormat: logfmt
  logLevel: info
  paused: false
  podMonitorNamespaceSelector: {}
  podMonitorSelector: {}
  portName: web
  probeNamespaceSelector: {}
  probeSelector: {}
  remoteWrite:
  - url: http://cortex-nginx.cortex/api/prom/push
    basicAuth:
        username:
          name: openuser-secrets
          key: user
        password:
          name: openuser-secrets
          key: password
  replicas: 1
  retention: 10d
  routePrefix: /
  ruleNamespaceSelector: {}
  ruleSelector: {}
  securityContext:
    fsGroup: 2000
    runAsGroup: 2000
    runAsNonRoot: true
    runAsUser: 1000
  serviceAccountName: prometheus
  serviceMonitorNamespaceSelector: {}
  serviceMonitorSelector: {}
  shards: 1
  version: v2.28.1
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-app
spec:
  type: LoadBalancer
  ports:
  - name: web
    port: 9092
    protocol: TCP
    targetPort: web
  selector:
    prometheus: prom-app
EOF
kubectl apply -f rbac.yaml
kubectl apply -f prometheus.yaml
