# Demo for GKE Istio Add-On

## Prerequisites

To run the following demo, you will need the following command line tools:

* [gcloud](https://cloud.google.com/sdk/docs/quickstarts)
* [kubectl](https://cloud.google.com/kubernetes-engine/docs/quickstart#local-shell)
* [istioctl](https://github.com/istio/istio/releases)
    * **Note**: This is mostly to verify mTLS settings, so it's optional otherwise.

## 1. Create Istio Cluster

```bash
gcloud beta container clusters create "istio-cluster-1" \
    --addons="Istio" --istio-config=auth="MTLS_STRICT" \
    --enable-network-policy \
    --enable-binauthz \
    --cluster-version="1.16.9-gke.6" \
    --machine-type="n1-standard-2" \
    --num-nodes="4" \
    --zone="us-central1-a";
```

If using an existing cluster, then use the following commands to enable Network Policy:

```bash
gcloud container clusters update "istio-cluster-1" --update-addons=NetworkPolicy=ENABLED;
gcloud container clusters update "istio-cluster-1" --enable-network-policy;
```

## 2. Deploy the BookInfo App

```bash
# Get cluster credentials
gcloud container clusters get-credentials istio-cluster-1;

# Set default namespace as default
kubectl config set-context --current --namespace=default
kubectl config view --minify | grep namespace:

# Enable automatic sidecar injection on default namespace
kubectl label namespace default istio-injection=enabled;

# Deploy BookInfo
kubectl apply -f gke-istio/bookinfo.yaml;

# Apply destination rules to define all available versions
kubectl apply -f gke-istio/destination-rule-all-mtls.yaml;

# Deploy Gateway
kubectl apply -f gke-istio/bookinfo-gateway.yaml;
```

### 2a. Test the application

To get the application URL, run the following commands:

```bash
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}');
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}');
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT;

echo "http://${GATEWAY_URL}/productpage";
```

Now open a new browser window and enter the URL printed above.

## 3. Verify MTLS Settings

```bash
APP="productpage";
POD=$(kubectl get pod -l app=${APP} -o jsonpath={.items..metadata.name});
istioctl authn tls-check ${POD} ${APP}.default.svc.cluster.local;
```

If done correctly, you should expect the following output:

```bash
HOST:PORT                                      STATUS     SERVER     CLIENT           AUTHN POLICY     DESTINATION RULE
productpage.default.svc.cluster.local:9080     OK         STRICT     ISTIO_MUTUAL     /default         default/productpage
```

## 4. Test Logging, Metrics, and Tracing

Open the URL and refresh the page multiple times so that you can generate metrics, tracing, and logging information.

### a. Logging Queries

```java
resource.labels.project_id="jccb-ariba-gke" AND
resource.labels.cluster_name="istio-cluster-1" AND
resource.type="k8s_container" AND
resource.labels.namespace_name="default" AND
resource.labels.container_name="productpage"

resource.labels.project_id="jccb-ariba-gke" AND
resource.labels.cluster_name="istio-cluster-1" AND
resource.type="k8s_container" AND
resource.labels.namespace_name="default" AND
labels.destination_workload: "reviews-v2"

resource.labels.container_name="reviews"
```

## 5. Setup Network Policies

```bash
# Secure Istio Ingress Gateway
kubectl apply -f pci-0-network-policy-istio-ingress.yaml;

# Allow traffic from Istio Namespace
kubectl apply -f pci-1-network-policy-deny-ingress-namespace.yaml;

# Allow traffic from productpage to details and reviews
kubectl apply -f pci-2-network-policy-istio-to-productpage.yaml;

# Allow traffic for all other services
kubectl apply -f pci-3-network-policy-productpage-to-all.yaml;
```

## 6. Setup Istio Authorization Policies

```bash
# Deny all traffic to default namespace
kubectl apply -f istio-1-auth-policy-deny-all.yaml;

# Allow traffic from Istio Ingress Gateway to productpage
kubectl apply -f istio-2-auth-policy-istio-to-productpage.yaml;

# Allow traffic for all other services
kubectl apply -f istio-3-auth-policy-productpage-to-all.yaml;
```

## 7. Cleaup

```bash
# Remove Istio Authorization Policies
kubectl delete -f gke-istio/istio-1-auth-policy-deny-all.yaml;
kubectl delete -f gke-istio/istio-2-auth-policy-istio-to-productpage.yaml;
kubectl delete -f gke-istio/istio-3-auth-policy-productpage-to-all.yaml;

# Remove Network Policies
kubectl delete -f gke-istio/pci-0-network-policy-istio-ingress.yaml;
kubectl delete -f gke-istio/pci-1-network-policy-deny-ingress-namespace.yaml;
kubectl delete -f gke-istio/pci-2-network-policy-istio-to-productpage.yaml;
kubectl delete -f gke-istio/pci-3-network-policy-productpage-to-all.yaml;

# Delete Gateway
kubectl delete -f gke-istio/bookinfo-gateway.yaml;

# Delete destination rules
kubectl delete -f gke-istio/destination-rule-all-mtls.yaml;

# Delete BookInfo
kubectl delete -f gke-istio/bookinfo.yaml;

# Disable automatic sidecar injection on default namespace
kubectl label namespace default istio-injection-;
```
