#!/usr/bin/env bash

detect_os() {
  local node="$1"
  local forced="${NODE_OS[$node]:-auto}"
  if [[ "$forced" != "auto" ]]; then
    echo "$forced"
    return
  fi

  remote "$node" "awk -F= '/^ID=/{gsub(/\"/,\"\",\$2); print \$2}' /etc/os-release"
}

prepare_node() {
  local node="$1"
  local os
  os="$(detect_os "$node")"
  NODE_OS["$node"]="$os"

  log "Preparing $node: detected OS=$os"

  case "$os" in
    ubuntu|debian)
      remote "$node" 'export DEBIAN_FRONTEND=noninteractive
        swapoff -a || true
        sed -ri "/^[[:space:]]*[^#].*[[:space:]]swap[[:space:]]/ s/^/#/" /etc/fstab
        apt-get update
        apt-get install -y curl ca-certificates gnupg apt-transport-https conntrack socat ebtables ethtool iptables'
      ;; #software-properties-common
    rhel|rocky|almalinux|centos)
      remote "$node" 'swapoff -a || true
        sed -ri "/^[[:space:]]*[^#].*[[:space:]]swap[[:space:]]/ s/^/#/" /etc/fstab
        (dnf -y install curl ca-certificates gnupg2 conntrack socat ebtables ethtool iptables) || (yum -y install curl ca-certificates conntrack socat ebtables ethtool iptables)'
      ;;
    sles|opensuse*|suse)
      remote "$node" 'swapoff -a || true
        zypper --non-interactive refresh
        zypper --non-interactive install curl ca-certificates conntrack socat ebtables ethtool iptables'
      ;;
    alpine)
      remote "$node" 'swapoff -a || true
        apk update
        apk add --no-cache bash curl ca-certificates iptables ip6tables conntrack-tools socat ebtables ethtool'
      ;;
    *)
      die "Unsupported OS on $node: $os"
      ;;
  esac

  remote_bash "$node" '
set -e
modprobe overlay 2>/dev/null || true
modprobe br_netfilter 2>/dev/null || true
mkdir -p /etc/modules-load.d /etc/sysctl.d
cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
cat >/etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF
sysctl --system >/dev/null || true
'
}
