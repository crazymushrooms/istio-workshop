# Resilience Patterns with Istio

## Tooling
### k8s
* docker
* [minikube](https://minikube.sigs.k8s.io/docs/)
* [helm](https://helm.sh)

### microservice
* gradle v7.6.1
* kotlin, jdk-17

## Getting started
Use `make` for easier setup!

0. Prepare env variables
   Per default the following varibales are set:
```
VERSION?=0.0.1
DOCKER_TAG?=local
KOTLIN_BUILD_DIR="build/libs"
IMG_DIR="registry"
HELM_DEPLOY_DIR="deploy/helm"
DEMO_POD=""
PLATFORM="linux/arm64"
CLUSTER_NAME="demo"
CLUSTER_NODES="3"
```

1. install minikube
   Pay attention on your platform & container engine!

2. Start minikube
   As default minikube starts a `demo` cluster with 3 nodes
````
minikube_start
````

3. Depending on your installation build & push microservices images to the minikube cluster.

The images you can find in https://github.com/users/crazymushrooms/packages/container/package/istio-workshop%2Fdemo

4. Deploy demo application
   We deploy 2 services in ``demo`` namespace:
* app1 in version 1
* app2 in 3 versions
````
make demo_deploy
````
You can access the services through the `NodePort` or using:
````
kubectl -n demo port-forward svc/app1 88080:80
````

5. Deploy service-mesh & observability applications
   We deploy istiod, istio-ingress, jaeger (all-in-one), prometheus, kiali dashboard, grafana & cert-manager
````
make istio_addons
````

6. deploy app1 & app2 with istio annotations
   We deploy also the configuration for the Istio telemetry and virtualservices
````
make istio_01
````

## Testing istio timeout
We deploy the app2 in version 3 with the `local-2` image.
The applicaton has a response delay built in.
````
make istio_02
````

Produce some load with fortio, retrieve traces in jaeger & observe request handling in kiali.

## Testing istio retry
We configure retry for the app2 in order to force istio to retry delaying route.
````
make istio_03
````

Produce some load with fortio, retrieve traces in jaeger & observe request handling in kiali.

## Testing istio circuit breaking
We configure circuit breaking for the app2.
````
make istio_04
````

Produce some load with fortio, retrieve traces in jaeger & observe request handling in kiali.
