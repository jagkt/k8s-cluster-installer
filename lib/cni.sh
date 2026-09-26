#!/usr/bin/env bash

install_cni() {
  local master="$1"

  case "$CNI_NAME" in
    flannel)
      remote "$master" "kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
      ;;
    calico)
      remote "$master" "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml"
      # Best effort patch. Calico's manifest can change; verify after applying.
      remote "$master" "kubectl -n kube-system patch ippool default --type merge -p '{\"spec\":{\"cidr\":\"${POD_CIDR}\"}}' 2>/dev/null || true"
      ;;
    *)
      die "Unsupported CNI: $CNI_NAME. Supported: flannel, calico"
      ;;
  esac
}
