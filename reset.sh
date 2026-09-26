#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/config.sh"
source "$ROOT_DIR/lib/ssh.sh"
source "$ROOT_DIR/lib/validation.sh"

CONFIG="${1:-}"
[[ -n "$CONFIG" ]] || { echo "Usage: $0 cluster.yaml"; exit 2; }
[[ -f "$CONFIG" ]] || die "Configuration file not found: $CONFIG"

load_config "$CONFIG"
validate_config
check_all_ssh

warn "This will reset Kubernetes on ALL configured nodes."
read -r -p "Type RESET to continue: " answer
[[ "$answer" == "RESET" ]] || die "Reset cancelled."

for node in "${NODE_NAMES[@]}"; do
  log "Resetting $node..."
  remote "$node" 'if command -v kubeadm >/dev/null 2>&1; then kubeadm reset -f || true; fi
    systemctl stop kubelet 2>/dev/null || true
    rm -rf /etc/kubernetes /var/lib/kubelet /etc/cni/net.d /var/lib/cni
    rm -rf /var/lib/etcd
    ip link delete cni0 2>/dev/null || true
    ip link delete flannel.1 2>/dev/null || true
    ip link delete vxlan.calico 2>/dev/null || true
    true'
done

log "Kubernetes reset completed. Docker/containerd packages were left installed."
