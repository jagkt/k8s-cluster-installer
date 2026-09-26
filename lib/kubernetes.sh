#!/usr/bin/env bash

install_kubernetes() {
  local node="$1"
  local os="${NODE_OS[$node]}"
  log "Installing Kubernetes $K8S_VERSION on $node ($os)"

  remote_bash "$node" "
set -e
case '$os' in
  ubuntu|debian)
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /' >/etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    ;;
  rhel|rocky|almalinux|centos)
    cat >/etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
    (dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes) || yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    ;;
  sles|opensuse*|suse)
    zypper --non-interactive install kubelet kubeadm kubectl || {
      echo 'Kubernetes packages are not available in the configured SUSE repositories.'
      exit 1
    }
    ;;
  alpine)
    echo 'Alpine Kubernetes package support is experimental and repository-dependent.'
    apk add --no-cache kubelet kubeadm kubectl || {
      echo 'Install kubelet/kubeadm/kubectl packages or configure an Alpine-compatible repository.'
      exit 1
    }
    ;;
esac

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable kubelet || true
  systemctl restart kubelet || true
else
  rc-update add kubelet default || true
  rc-service kubelet restart || rc-service kubelet start || true
fi
"
}

init_control_plane() {
  local master="$1"

  if remote "$master" "test -f /etc/kubernetes/admin.conf"; then
    log "$master is already initialized."
    return
  fi

  local endpoint_args=""
  [[ -n "$API_ENDPOINT" ]] && endpoint_args="--control-plane-endpoint=$API_ENDPOINT"

  remote "$master" "kubeadm init \
    --kubernetes-version=v${K8S_VERSION}.0 \
    --pod-network-cidr=${POD_CIDR} \
    --service-cidr=${SERVICE_CIDR} \
    ${endpoint_args}"

  remote "$master" "mkdir -p /root/.kube && cp -f /etc/kubernetes/admin.conf /root/.kube/config && chown root:root /root/.kube/config"
}

get_join_command() {
  local master="$1"
  remote "$master" "kubeadm token create --print-join-command"
}

join_worker() {
  local node="$1"
  local join_cmd="$2"

  if remote "$node" "test -f /etc/kubernetes/kubelet.conf"; then
    log "$node already appears to be joined."
    return
  fi

  remote "$node" "$join_cmd"
}

configure_kubectl() {
  local master="$1"
  remote "$master" "export KUBECONFIG=/etc/kubernetes/admin.conf; kubectl get nodes -o wide"
}
