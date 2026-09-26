#!/usr/bin/env bash

ssh_target() {
  local node="$1"
  echo "${SSH_USER}@${NODE_IP[$node]}"
}

check_ssh() {
  local node="$1"
  log "Checking SSH: $node (${NODE_IP[$node]})"
  ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
      -p "$SSH_PORT" "$(ssh_target "$node")" "echo SSH_OK" >/dev/null ||
      die "SSH connection failed for $node"
}

check_all_ssh() {
  for n in "${NODE_NAMES[@]}"; do check_ssh "$n"; done
}
