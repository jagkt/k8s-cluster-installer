#!/usr/bin/env bash

load_config() {
  CONFIG_FILE="$1"
  require_cmd python3

  mapfile -t CFG_LINES < <(python3 "$K8S_INSTALLER_ROOT/lib/parse_yaml.py" "$CONFIG_FILE")

  : "${NODE_NAMES:=}"
  NODE_NAMES=()
  declare -gA NODE_IP NODE_ROLE NODE_OS
  NODE_IP=(); NODE_ROLE=(); NODE_OS=()

  while IFS='=' read -r key value; do
    case "$key" in
      cluster.name) CLUSTER_NAME="$value" ;;
      cluster.kubernetes_version) K8S_VERSION="$value" ;;
      cluster.pod_cidr) POD_CIDR="$value" ;;
      cluster.service_cidr) SERVICE_CIDR="$value" ;;
      cluster.endpoint) API_ENDPOINT="$value" ;;
      cni.name) CNI_NAME="$value" ;;
      docker.enabled) DOCKER_ENABLED="$value" ;;
      docker.install_compose) DOCKER_COMPOSE="$value" ;;
      ssh.user) SSH_USER="$value" ;;
      ssh.port) SSH_PORT="$value" ;;
    esac
  done < <(printf '%s\n' "${CFG_LINES[@]}")

  local i=0 key value name
  while IFS='=' read -r key value; do
    case "$key" in
      node.*.name)
        name="$value"
        NODE_NAMES+=("$name")
        ;;
    esac
  done < <(printf '%s\n' "${CFG_LINES[@]}")

  i=0
  while IFS='=' read -r key value; do
    case "$key" in
      node.*.ip) NODE_IP["${NODE_NAMES[$i]}"]="$value" ;;
      node.*.role) NODE_ROLE["${NODE_NAMES[$i]}"]="$value" ;;
      node.*.os) NODE_OS["${NODE_NAMES[$i]}"]="$value"; i=$((i+1)) ;;
    esac
  done < <(printf '%s\n' "${CFG_LINES[@]}")

  : "${CLUSTER_NAME:=homelab}"
  : "${K8S_VERSION:=1.30}"
  : "${POD_CIDR:=10.244.0.0/16}"
  : "${SERVICE_CIDR:=10.96.0.0/12}"
  : "${API_ENDPOINT:=}"
  : "${CNI_NAME:=flannel}"
  : "${DOCKER_ENABLED:=true}"
  : "${DOCKER_COMPOSE:=false}"
  : "${SSH_USER:=root}"
  : "${SSH_PORT:=22}"
}

get_master_node() {
  local n
  for n in "${NODE_NAMES[@]}"; do
    [[ "${NODE_ROLE[$n]:-}" == "master" ]] && { echo "$n"; return; }
  done
  die "No node with role: master"
}

node_ip()   { echo "${NODE_IP[$1]:-}"; }
node_role() { echo "${NODE_ROLE[$1]:-}"; }
node_os()   { echo "${NODE_OS[$1]:-auto}"; }

show_plan() {
  echo
  echo "Cluster:       $CLUSTER_NAME"
  echo "Kubernetes:    $K8S_VERSION"
  echo "Pod CIDR:      $POD_CIDR"
  echo "Service CIDR:  $SERVICE_CIDR"
  echo "CNI:           $CNI_NAME"
  echo "Docker:        $DOCKER_ENABLED"
  echo "SSH:           $SSH_USER:$SSH_PORT"
  echo
  for n in "${NODE_NAMES[@]}"; do
    printf '  %-18s %-16s %-10s OS=%s\n' "$n" "${NODE_IP[$n]}" "${NODE_ROLE[$n]}" "${NODE_OS[$n]:-auto}"
  done
}
