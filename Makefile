.SHELLFLAGS := -eu -o pipefail -c

VERSION?=0.0.1
DOCKER_TAG?=local
KOTLIN_BUILD_DIR="build/libs"
IMG_DIR="registry"
HELM_DEPLOY_DIR="deploy/helm"
DEMO_POD=""
PLATFORM="linux/arm64"
CLUSTER_NAME="demo"
CLUSTER_NODES="3"

.PHONY: minikube_start image compile docker_build push restart_demo deploy_addons deploy_demo istio kiali prometheus istio_01 istio_02 istio_03 istio_04 istio_05 istio_06 jaeger cert_mgr grafana load_circuit_breaker load_app1_external load_app2_self

minikube_start:
	minikube start --nodes $(CLUSTER_NODES) -p $(CLUSTER_NAME)

image: compile docker_build push
	@echo "building image for the version $(VERSION)"

compile:
	@echo "compiling project for the version $(VERSION)"
	THIS_DIR=$(pwd)
	rm -f $(KOTLIN_BUILD_DIR)/demo-$(VERSION).jar $(KOTLIN_BUILD_DIR)/demo-$(VERSION)-plain.jar
	./gradlew build && cd $(THIS_DIR)

docker_build:
	@echo "building image for the version $(VERSION)"
	docker build --build-arg=VERSION="$(VERSION)" --platform=$(PLATFORM) -t demo:$(DOCKER_TAG) -f Dockerfile .

push:
	@echo "pushing demo:$(DOCKER_TAG) to minikube"
	minikube image load demo:$(DOCKER_TAG) -p demo

restart_demo:
	@echo "Restarting demo app1 && app2"
	kubectl config use-context $(CLUSTER_NAME) && kubectl rollout restart deploy app1-v1 app2-v1 app2-v2 app2-v3 -n demo

deploy_demo:
	@echo "Deploying application"
	kubectl config use-context $(CLUSTER_NAME) && kubectl apply -f deploy/default/namespace.yaml
	kubectl config use-context $(CLUSTER_NAME) && kubectl apply -f deploy/default

deploy_addons: istio prometheus cert_mgr kiali jaeger grafana
	@kubectl config use-context $(CLUSTER_NAME) && kubectl rollout restart deploy app1-v1 app2-v1 app2-v2 app2-v3 -n demo

istio:
	@echo "installing istio"
	@kubectl config use-context $(CLUSTER_NAME) && helm repo add istio https://istio-release.storage.googleapis.com/charts
	@kubectl config use-context $(CLUSTER_NAME) && helm repo update
	@kubectl config use-context $(CLUSTER_NAME) && helm upgrade --install istio-base istio/base --namespace istio-system --create-namespace
	@kubectl config use-context $(CLUSTER_NAME) && helm upgrade --install istiod istio/istiod -n istio-system -f $(HELM_DEPLOY_DIR)/istiod-values.yaml --wait
	@kubectl config use-context $(CLUSTER_NAME) && helm upgrade --install istio-ingress istio/gateway -n istio-system

kiali:
	@echo "installing kiali"
	@kubectl config use-context $(CLUSTER_NAME) && helm upgrade --install --namespace istio-system --repo https://kiali.org/helm-charts -f $(HELM_DEPLOY_DIR)/kiali-values.yaml kiali-server kiali-server

prometheus:
	@echo "installing prometheus"
	@kubectl config use-context $(CLUSTER_NAME) && helm upgrade --install --repo https://prometheus-community.github.io/helm-charts --namespace istio-system -f $(HELM_DEPLOY_DIR)/prometheus-values.yaml prometheus prometheus

istio_01:
	@echo "installing istio resources for the default setup"
	@kubectl config use-context $(CLUSTER_NAME) && kubectl apply -f deploy/istio/01

istio_02:
	@echo "installing istio resources for the timeout test"
	@kubectl config use-context $(CLUSTER_NAME) && kubectl apply -f deploy/istio/02

istio_03:
	@echo "installing istio resources for the retry test"
	@kubectl config use-context $(CLUSTER_NAME) && kubectl apply -f deploy/istio/03

istio_04:
	@echo "installing istio resources for the circuit breaker test"
	@kubectl config use-context $(CLUSTER_NAME) && kubectl apply -f deploy/istio/04
	@kubectl config use-context $(CLUSTER_NAME) && kubectl -n demo scale deploy app2-v1 app2-v2 --replicas 0

istio_05:
	@echo "installing istio resources for the load balancing test"
	@Kkubectl config use-context $(CLUSTER_NAME) && kubectl apply -f deploy/istio/05

istio_06:
	@echo "installing istio resources for the fault injection test"
	@kubectl config use-context $(CLUSTER_NAME) && kubectl apply -f deploy/istio/06

istio_proxy_status:
	@echo "get istio proxy status"
	kubectl config use-context $(CLUSTER_NAME) && istioctl -n istio-system proxy-status

istio_cluster_config:
	@echo "get istio cluster config"
	Kkubectl config use-context $(CLUSTER_NAME) &&" istioctl -n istio-system proxy-config cluster $(DEMO_POD)

istio_envoy_stats:
	@echo "get istio envoy statistics"
	kubectl config use-context $(CLUSTER_NAME) && kubectl -n demo exec -it $(DEMO_POD) -c istio-proxy -- pilot-agent request GET stats

load_app1_external:
	kubectl config use-context $(CLUSTER_NAME)
	@$(eval FORTIO_POD=$(shell sh -c 'kubectl get pod -n demo -o name| grep fortio | awk "{ print $1 }"'))
	@echo POD is $(FORTIO_POD)
	@kubectl config use-context $(CLUSTER_NAME) && kubectl -n demo exec -it $(FORTIO_POD) -c fortio -- fortio load -c 5 -qps 0 -n 20 http://app1.demo.svc.cluster.local:80/api/external

load_circuit_breaker:
	kubectl config use-context $(CLUSTER_NAME)
	@$(eval FORTIO_POD=$(shell sh -c 'kubectl get pod -n demo -o name| grep fortio | awk "{ print $1 }"'))
	@echo POD is $(FORTIO_POD)
	@kubectl config use-context $(CLUSTER_NAME) && kubectl -n demo exec -it $(FORTIO_POD) -c fortio -- fortio load -c 1 -qps 0 -n 10 http://app1.demo.svc.cluster.local:80/api/external

load_app2_self:
	@$(eval FORTIO_POD=$(shell sh -c 'KUBECONFIG=".kubeconfig" kubectl get pod -n demo -o name| grep fortio | awk "{ print $1 }"'))
	@echo POD is $(FORTIO_POD)
	@kubectl config use-context $(CLUSTER_NAME) && kubectl -n demo exec -it $(FORTIO_POD) -c fortio -- fortio load -c 4 -qps 0 -n 10 http://app2.demo.svc.cluster.local:80/api/self

jaeger:
	@echo "installing jaeger"
	@kubectl config use-context $(CLUSTER_NAME) && kubectl apply -f https://raw.githubusercontent.com/jaegertracing/helm-charts/jaeger-operator-2.45.0/charts/jaeger-operator/crds/crd.yaml
	@kubectl config use-context $(CLUSTER_NAME) && helm upgrade --install --repo https://jaegertracing.github.io/helm-charts --namespace istio-system -f $(HELM_DEPLOY_DIR)/jaeger-values.yaml jaeger jaeger-operator

cert_mgr:
	@echo "Installing cert-manager"
	@kubectl config use-context $(CLUSTER_NAME) && kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.crds.yaml
	@kubectl config use-context $(CLUSTER_NAME) && helm upgrade --install --repo https://charts.jetstack.io --namespace istio-system cert-manager cert-manager

grafana:
	@echo "Installing grafana"
	@kubectl config use-context $(CLUSTER_NAME) && helm upgrade --install --repo https://grafana.github.io/helm-charts --namespace istio-system -f $(HELM_DEPLOY_DIR)/grafana-values.yaml grafana grafana
