#!/usr/bin/env bash

install_docker() {
  local node="$1"
  local os="${NODE_OS[$node]}"
  log "Installing Docker on $node ($os)"

  remote_bash "$node" "
set -e
if command -v docker >/dev/null 2>&1; then
  echo 'Docker already installed'
  exit 0
fi
case '$os' in
  ubuntu|debian)
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/\$(. /etc/os-release && echo \"\$ID\")/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    . /etc/os-release
    echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/\$ID \$VERSION_CODENAME stable\" >/etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ;;
  rhel|rocky|almalinux|centos)
    (dnf -y install dnf-plugins-core && dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo) || true
    (dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin) || (yum -y install docker-ce docker-ce-cli containerd.io)
    systemctl enable --now docker
    ;;
  sles|opensuse*|suse)
    zypper --non-interactive install docker
    systemctl enable --now docker
    ;;
  alpine)
    apk add --no-cache docker docker-cli-compose
    rc-update add docker default
    rc-service docker start || true
    ;;
esac
"
}
