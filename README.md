# Demo for GKE Istio Add-On

This repository is mainly intended to be a quick way to get up and running with Istio, Stackdriver Integration, Network Policies, and Istio Authorization Policies. We will not be going through every subject in great detail as this repo is mainly for demo purposes. To learn more about the above subjects, we recommend you click on their respective links below.

We will be covering the following topics:

* [Istio add-on for GKE](https://cloud.google.com/istio/docs/istio-on-gke/overview).
* [Istio Automatic Sidecar Injection](https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/#automatic-sidecar-injection).
* [Istio's BookInfo Sample App](https://istio.io/latest/docs/examples/bookinfo/).
* [Istio Mutual TLS](https://istio.io/latest/docs/concepts/security/#mutual-tls-authentication).
* [Istio Authorization Policies](https://istio.io/latest/docs/concepts/security/#authorization-policies).
* [Kubernetes Network Policies on GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/network-policy).

## Prerequisites

To run the following demo, you will need the following command line tools:

* [gcloud](https://cloud.google.com/sdk/docs/quickstarts)
* [kubectl](https://cloud.google.com/kubernetes-engine/docs/quickstart#local-shell)
* [istioctl](https://github.com/istio/istio/releases)

## 1. Create an Istio and Network Policy enabled GKE Cluster

For a more thorough installation guide on enabling Istio and Network Policies on GKE, read the following documents, respectively:

* <https://cloud.google.com/istio/docs/istio-on-gke/installing>
* <https://cloud.google.com/kubernetes-engine/docs/how-to/network-policy>

For the rest of the document we will assume the following:

* GKE cluster is named `istio-cluster-1`;
* Compute zone is `us-central1-a`;

The following command will create an Istio and Network Policy Enabled GKE cluster with `MTLS_STRICT` security option:

```bash
# Create Istio-enabled GKE Cluster
gcloud beta container clusters create "istio-cluster-1" \
    --addons="Istio" --istio-config=auth="MTLS_STRICT" \
    --enable-network-policy \
    --cluster-version="1.16.9-gke.6" \
    --machine-type="n1-standard-2" \
    --num-nodes="4" \
    --zone="us-central1-a";
```

If using an existing cluster, then use the following commands to enable Network Policy:

```bash
# Enable Istio on Existing GKE Cluster
gcloud beta container clusters update CLUSTER_NAME --update-addons=Istio=ENABLED --istio-config=auth=MTLS_STRICT;

# Enable Network Policy on Existing GKE Cluster
gcloud container clusters update "istio-cluster-1" --update-addons=NetworkPolicy=ENABLED;
gcloud container clusters update "istio-cluster-1" --enable-network-policy;
```

## 2. Deploy the BookInfo App

The [BookInfo Application](https://istio.io/latest/docs/examples/bookinfo/) is Istio's flagship demo application. It's implemented using 4 microservices that use completely different programming languages. Also, one of its microservices has 3 versions that run concurrently, which is used by Istio to demonstrate its routing and security capabilities. To learn more about BookInfo, we recommend you read the following document:

* <https://istio.io/latest/docs/examples/bookinfo/>

To deploy the BookInfo app into your GKE cluster, run the following commands

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

Now open a new browser window and enter the URL printed above. Refresh the page multiple times so that you can see the reviews service returning star ratings of different colors every time you refresh the page. This is thanks to Istio's [Destination Rules](https://istio.io/latest/docs/concepts/traffic-management/#destination-rules) where each version of the Reviews microservice is defined, which allows Istio to load balance traffic to all of review's versions.

## 3. Verify mTLS Settings

Because we turned on Strict Mutual TLS cluster-wide with the `MTLS_STRICT` security option for Istio and we turned on automatic sidecar injection for the `default` namespace, each microservice deployed in the `default` namespace will automatically have mTLS enabled.

Though we don't have an easy way to view actual traffic between the different microservices and confirm whether the traffic is encrypted or not, we can use `istioctl` to check on the TLS settings for a specific pod and confirm whether it's configured with mTLS. To do that, let's try and verify the mTLS settings for the `ratings` microservice with the following commands:

```bash
APP="ratings";
POD=$(kubectl get pod -l app=${APP} -o jsonpath={.items..metadata.name});
istioctl authn tls-check ${POD} ${APP}.default.svc.cluster.local;
```

If done correctly, you should expect the following output:

```bash
HOST:PORT                                  STATUS     SERVER     CLIENT           AUTHN POLICY     DESTINATION RULE
ratings.default.svc.cluster.local:9080     OK         STRICT     ISTIO_MUTUAL     /default         default/ratings
```

Notice the `ISTIO_MUTUAL` value under the `CLIENT` column, which indicates that clients for the `ratings` service are expected to use mTLS. Also, notice under the `STRICT` field under the `SERVER` column, which indicates that mTLS is strictly enforced.

## 4. Test Logging, Metrics, and Tracing

Open the BookInfo URL and refresh the page multiple times so that you can generate metrics, tracing, and logging information. Istio, through the [Stackdriver Adapter](https://istio.io/latest/docs/reference/config/policy-and-telemetry/adapters/stackdriver/), will send this information to Stackdriver Logging, Metrics, and Tracing.

### a. Get Application Logs with Logging Queries

To view, the application logs, open the [Logs Viewer](https://console.cloud.google.com/logs/query) and enter the following queries to view the logs for the `productpage` microservice:

```java
resource.labels.project_id="gke-istio-demo" AND
resource.labels.cluster_name="istio-cluster-1" AND
resource.type="k8s_container" AND
resource.labels.namespace_name="default" AND
resource.labels.container_name="productpage"
```

### b. Get Application Metrics from the Monitoring Dashboard

To view application metrics, open [Monitoring](https://console.cloud.google.com/monitoring) and search for the GKE dashboard, which gets automatically generated. Then click on the `Services` menu on the left to see, then feel free to click on any of the listed services to see metrics.

### c. Get Application Tracing form the Trace Viewer

To view application tracing information, open [Trace list](https://console.cloud.google.com/traces/list) from [Trace viewer](https://console.cloud.google.com/traces), click on any of the traces and you will be able to see a Trace Waterfall View to see that trace information visually.

## 5. Setup Istio Authorization Policies

Istio Authorization Policy enables access control on workloads in the mesh. Authorization policy supports both allow and deny policies. When allow and deny policies are used for a workload at the same time, the deny policies are evaluated first.

For the BookInfo App, we want to apply the following rules:

* Istio Ingress Gateway <-> productpage.
* productpage <-> reviews (all versions);
* productpage <-> details;
* reviews (all versions) <-> ratings;
* Deny all other traffic;

To implement the above rules, run the following commands:

```bash
# Deny all traffic to default namespace
kubectl apply -f gke-istio/istio-1-auth-policy-deny-all.yaml;

# Allow traffic from Istio Ingress Gateway to productpage
kubectl apply -f gke-istio/istio-2-auth-policy-istio-to-productpage.yaml;

# Allow traffic for all other services
kubectl apply -f gke-istio/istio-3-auth-policy-productpage-to-all.yaml;
```

Now open the application URL and refresh the application a couple of times to make sure that BookInfo shows different star colors for the reviews service.

## 6. Setup Network Policies

Network Policies are network rules between pods that are enforced in kernel-space at layer 4. Though Network Policies are very similar to Istio's Authorization Policies, Network Policies are enforced whether a service is in the service mesh or not. This is useful as an extra layer of defense to prevent pod from communicating to other pods that are not allowed to.

For the BookInfo App, we want to apply the following rules:

* Internet <-> Istio Ingress Gateway (port 80 and 443 only).
* istio-system namespace <-> default namespace. This is for the following:
  * Istio Ingress Gateway <-> productpage.
  * Workloads in default namespace <-> Istio components in istio-system namespace.
    * Without this, Istio won't be able to work with workloads in default namespace.
* productpage <-> reviews (all versions);
* productpage <-> details;
* reviews (all versions) <-> ratings;
* Deny all other traffic;

To implement the above rules, run the following commands:

```bash
# Secure Istio Ingress Gateway
kubectl apply -f gke-istio/pci-0-network-policy-istio-ingress.yaml;

# Allow traffic from Istio Namespace
kubectl apply -f gke-istio/pci-1-network-policy-deny-ingress-namespace.yaml;

# Allow traffic from productpage to details and reviews
kubectl apply -f gke-istio/pci-2-network-policy-istio-to-productpage.yaml;

# Allow traffic for all other services
kubectl apply -f gke-istio/pci-3-network-policy-productpage-to-all.yaml;
```

Now open the application URL and refresh the application a couple of times to make sure that BookInfo shows different star colors for the reviews service.

## 7. Cleanup

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
