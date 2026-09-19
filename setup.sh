#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="demo"
NAMESPACE="demo"
RELEASE_NAME="demo"
IMAGE_REPO="demo-service"
IMAGE_TAG="latest"
INGRESS_NAMESPACE="ingress-nginx"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed" >&2
  exit 1
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required but not installed" >&2
  exit 1
fi
if ! command -v helm >/dev/null 2>&1; then
  echo "helm is required but not installed" >&2
  exit 1
fi
if ! command -v kind >/dev/null 2>&1; then
  echo "kind is required but not installed" >&2
  exit 1
fi

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "==> creating kind cluster '$CLUSTER_NAME'"
  kind create cluster --name "$CLUSTER_NAME" --wait 180s
fi

kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null 2>&1 || true
kubectl create namespace "$INGRESS_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace "$INGRESS_NAMESPACE" \
  --create-namespace \
  --set controller.service.type=NodePort \
  --wait --timeout 5m

IMAGE_REF="${IMAGE_REPO}:${IMAGE_TAG}"

echo "==> building image ${IMAGE_REF}"
docker build -t "$IMAGE_REF" ./service
kind load docker-image "$IMAGE_REF" --name "$CLUSTER_NAME"

helm upgrade --install "$RELEASE_NAME" ./chart \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --set image.repository="$IMAGE_REPO" \
  --set image.tag="$IMAGE_TAG" \
  --set config.appName="demo" \
  --set config.version="1.0.0" \
  --set ingress.host="demo.local" \
  --wait --timeout 5m

echo "==> cluster is ready"

echo "verify with:"
echo "  kubectl -n demo get deploy,pods,svc,ingress"
echo "  kubectl -n demo port-forward svc/demo 18080:80 &"
echo "  curl http://127.0.0.1:18080/"
echo "  curl -i http://127.0.0.1:18080/healthz"
