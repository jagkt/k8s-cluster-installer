#!/usr/bin/env bash

install_containerd() {
  local node="$1"
  local os="${NODE_OS[$node]}"
  log "Installing/configuring containerd on $node ($os)"

  remote_bash "$node" "
set -e
case '$os' in
  ubuntu|debian)
    apt-get update
    apt-get install -y containerd
    ;;
  rhel|rocky|almalinux|centos)
    (dnf -y install containerd) || true
    if ! command -v containerd >/dev/null 2>&1; then
      dnf -y install containerd.io || true
    fi
    ;;
  sles|opensuse*|suse)
    zypper --non-interactive install containerd
    ;;
  alpine)
    apk add --no-cache containerd
    ;;
esac

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -ri 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload || true
  systemctl enable --now containerd
else
  rc-update add containerd default || true
  rc-service containerd restart || rc-service containerd start || true
fi
"
}
