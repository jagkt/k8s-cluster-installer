#!/usr/bin/env bash

require_local_commands() {
  require_cmd ssh
  require_cmd python3
  require_cmd awk
  require_cmd sed
  require_cmd grep
}

validate_config() {
  [[ "${#NODE_NAMES[@]}" -gt 0 ]] || die "No nodes defined."
  [[ -n "$K8S_VERSION" ]] || die "cluster.kubernetes_version is required."
  [[ "$CNI_NAME" == "flannel" || "$CNI_NAME" == "calico" ]] || die "CNI must be flannel or calico."

  local masters=0 workers=0 n
  declare -A seen_ips=()

  for n in "${NODE_NAMES[@]}"; do
    [[ -n "${NODE_IP[$n]:-}" ]] || die "Missing IP for node $n"
    [[ -n "${NODE_ROLE[$n]:-}" ]] || die "Missing role for node $n"

    case "${NODE_ROLE[$n]}" in
      master) masters=$((masters+1)) ;;
      worker) workers=$((workers+1)) ;;
      *) die "Invalid role for $n: ${NODE_ROLE[$n]}" ;;
    esac

    [[ -z "${seen_ips[${NODE_IP[$n]}]:-}" ]] || die "Duplicate IP: ${NODE_IP[$n]}"
    seen_ips["${NODE_IP[$n]}"]=1
  done

  [[ "$masters" -eq 1 ]] || die "v1 requires exactly one master/control-plane node."
  [[ "$workers" -ge 1 ]] || warn "No worker nodes configured."

  case "$CNI_NAME" in
    flannel)
      [[ "$POD_CIDR" == "10.244.0.0/16" ]] || warn "Flannel commonly uses 10.244.0.0/16; verify your selected manifest."
      ;;
  esac
}

cluster_status() {
  local master
  master="$(get_master_node)"
  log "Cluster status from $master:"
  remote "$master" "export KUBECONFIG=/etc/kubernetes/admin.conf; kubectl get nodes -o wide; echo; kubectl get pods -A"
}
