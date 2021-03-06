#/bin/bash

##############################################################################
# k8s-minikube.sh
#
# This script can be used to help run Kubernetes via minikube.
# The typical order of commands used is the following:
#   up - starts the Kubernetes cluster via minikube
#   istio - installs Istio using Kiali's install hack script
#   docker - shows what is needed to put images in minikube's docker daemon
#   (at this point, you can install Kiali into your Kubernetes environment)
#   dashboard - shows the Kubernetes GUI console
#   ingress - shows the Ingress URL which can get you to the Kiali GUI
#   bookinfo - installs bookinfo demo into your cluster
#   down - shuts down the Kubernetes cluster, you can start it up again
#   delete - if you don't want your cluster anymore, this deletes it
#
##############################################################################

debug() {
  if [ "$_VERBOSE" == "true" ]; then
    echo "DEBUG: $1"
  fi
}

ensure_minikube_is_running() {
  if ! minikube status > /dev/null 2>&1 ; then
    echo 'Minikube must be running in order to continue. Aborting.'
    exit 1
  fi
}

get_gateway_url() {
  INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
  SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
  INGRESS_HOST=$(minikube ip)
  GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
  GATEWAY_URL_SECURE=$INGRESS_HOST:$SECURE_INGRESS_PORT
}

# Change to the directory where this script is and set our env
cd "$(dirname "${BASH_SOURCE[0]}")"

_CMD=""
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    up)
      _CMD="up"
      shift
      ;;
    down)
      _CMD="down"
      shift
      ;;
    status)
      _CMD="status"
      shift
      ;;
    delete)
      _CMD="delete"
      shift
      ;;
    docker)
      _CMD="docker"
      shift
      ;;
    dashboard)
      _CMD="dashboard"
      shift
      ;;
    ingress)
      _CMD="ingress"
      shift
      ;;
    istio)
      _CMD="istio"
      shift
      ;;
    bookinfo)
      _CMD="bookinfo"
      shift
      ;;
    gwurl)
      _CMD="gwurl"
      shift
      ;;
    -v|--verbose)
      _VERBOSE=true
      shift
      ;;
    -h|--help)
      cat <<HELPMSG

$0 [option...] command

Valid options:
  -v|--verbose
      Enable logging of debug messages from this script.

The command must be either:
  up:        starts the minikube cluster
  down:      stops the minikube cluster
  status:    gets the status of the minikube cluster
  delete:    completely removes the minikube cluster VM destroying all state
  docker:    information on the minikube docker environment
  dashboard: enables access to the Kubernetes GUI within minikube
  ingress:   enables access to the Kubernetes ingress URL within minikube
  istio:     installs Istio into the minikube cluster
  bookinfo:  installs Istio's bookinfo demo (make sure Istio is installed first)
  gwurl:     displays the Ingress Gateway URL
HELPMSG
      exit 1
      ;;
    *)
      echo "Unknown argument [$key]. Aborting."
      exit 1
      ;;
  esac
done

# If minikube is not in PATH, abort.
if ! which minikube > /dev/null 2>&1 ; then
  echo 'You do not have minikube installed in your $PATH. Aborting.'
  exit 1
fi

debug "This script is located at $(pwd)"
debug "minikube is located at $(which minikube)"

if [ "$_CMD" = "up" ]; then
  echo 'Starting minikube with 8gig RAM and 40gig disk space (disk space for docker images)'
  minikube start --memory=8216 --disk-size=40g --vm-driver=virtualbox
  echo 'Enabling the ingress addon'
  minikube addons enable ingress

elif [ "$_CMD" = "down" ]; then
  ensure_minikube_is_running
  echo 'Stopping minikube'
  minikube stop

elif [ "$_CMD" = "status" ]; then
  ensure_minikube_is_running
  echo 'Status report for minikube'
  minikube status

elif [ "$_CMD" = "delete" ]; then
  echo 'Deleting the entire minikube VM'
  minikube delete

elif [ "$_CMD" = "dashboard" ]; then
  ensure_minikube_is_running
  echo 'Accessing the Kubernetes console GUI. This runs in foreground, press Control-C to kill it.'
  minikube dashboard

elif [ "$_CMD" = "ingress" ]; then
  ensure_minikube_is_running
  echo 'Accessing the Kubernetes Ingress URL.'
  xdg-open "http://$(minikube ip)"

elif [ "$_CMD" = "istio" ]; then
  ensure_minikube_is_running
  echo 'Installing Istio'
  ./istio/install-istio-kiali-via-helm.sh -c kubectl

elif [ "$_CMD" = "bookinfo" ]; then
  ensure_minikube_is_running
  echo 'Installing Bookinfo'
  ./istio/install-bookinfo-demo.sh --mongo -tg -c kubectl
  get_gateway_url
  echo 'To access the Bookinfo application, access this URL:'
  echo "http://${GATEWAY_URL}/productpage"
  echo 'To push requests into the Bookinfo application, execute this command:'
  echo "watch -n 1 curl -o /dev/null -s -w '%{http_code}' http://${GATEWAY_URL}/productpage"

elif [ "$_CMD" = "gwurl" ]; then
  ensure_minikube_is_running
  get_gateway_url
  echo 'The Gateway URL is:'
  echo "${GATEWAY_URL}"
  echo 'The secure Gateway URL is:'
  echo "${GATEWAY_URL_SECURE}"

elif [ "$_CMD" = "docker" ]; then
  ensure_minikube_is_running
  echo 'Your current minikube docker environment is the following:'
  minikube docker-env
  echo 'Run the above command in your shell before building docker images so your images will go in the minikube docker daemon'

else
  echo "ERROR: Missing required command"
  exit 1
fi
