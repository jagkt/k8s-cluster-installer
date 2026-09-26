#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export K8S_INSTALLER_ROOT="$ROOT_DIR"

source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/ssh.sh"
source "$ROOT_DIR/lib/os.sh"
source "$ROOT_DIR/lib/docker.sh"
source "$ROOT_DIR/lib/containerd.sh"
source "$ROOT_DIR/lib/kubernetes.sh"
source "$ROOT_DIR/lib/cni.sh"
source "$ROOT_DIR/lib/validation.sh"

CONFIG="${1:-}"
ACTION="install"

if [[ -z "$CONFIG" ]]; then
  echo "Usage: $0 <cluster.yaml> [--validate|--dry-run|--status]"
  exit 2
fi

shift || true
for arg in "$@"; do
  case "$arg" in
    --validate) ACTION="validate" ;;
    --dry-run) ACTION="dry-run" ;;
    --status) ACTION="status" ;;
    *) die "Unknown option: $arg" ;;
  esac
done

CONFIG="$(cd "$(dirname "$CONFIG")" && pwd)/$(basename "$CONFIG")"
[[ -f "$CONFIG" ]] || die "Configuration file not found: $CONFIG"

mkdir -p "$ROOT_DIR/logs"
LOG_FILE="$ROOT_DIR/logs/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

log "Kubernetes Cluster Installer v1"
log "Config: $CONFIG"
log "Log: $LOG_FILE"

load_config "$CONFIG"
validate_config

if [[ "$ACTION" == "validate" ]]; then
  log "Configuration validation passed."
  exit 0
fi

if [[ "$ACTION" == "dry-run" ]]; then
  show_plan
  exit 0
fi

if [[ "$ACTION" == "status" ]]; then
  cluster_status
  exit 0
fi

require_local_commands
check_all_ssh

log "Preparing nodes..."
for node in "${NODE_NAMES[@]}"; do
  prepare_node "$node"
done

log "Installing Docker independently..."
if [[ "$DOCKER_ENABLED" == "true" ]]; then
  for node in "${NODE_NAMES[@]}"; do
    install_docker "$node"
  done
else
  log "Docker installation disabled."
fi

log "Installing/configuring containerd..."
for node in "${NODE_NAMES[@]}"; do
  install_containerd "$node"
done

log "Installing Kubernetes packages..."
for node in "${NODE_NAMES[@]}"; do
  install_kubernetes "$node"
done

MASTER="$(get_master_node)"
log "Initializing control plane on $MASTER..."
init_control_plane "$MASTER"

log "Installing CNI: $CNI_NAME"
install_cni "$MASTER"

log "Joining workers..."
JOIN_CMD="$(get_join_command "$MASTER")"

for node in "${NODE_NAMES[@]}"; do
  role="$(node_role "$node")"
  [[ "$role" == "worker" ]] || continue
  join_worker "$node" "$JOIN_CMD"
done

configure_kubectl "$MASTER"
cluster_status

log "Installation completed."
log "Kubeconfig: /etc/kubernetes/admin.conf on $MASTER"
log "Run: ssh $(ssh_target "$MASTER") 'kubectl get nodes -o wide'"
