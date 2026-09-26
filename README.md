# Kubernetes Cluster Installer v1

A configuration-driven Bash installer for building multi-node Kubernetes clusters with `kubeadm`.

The project is designed for home labs, test environments, and repeatable Kubernetes provisioning. It supports:

- Multiple nodes defined in one YAML configuration
- Automatic OS detection over SSH
- Explicit OS override when required
- Master/control-plane and worker roles
- Separate Docker Engine installation
- Kubernetes using `containerd` as the CRI runtime
- `kubeadm`, `kubelet`, and `kubectl`
- Selectable CNI: Flannel or Calico
- Automatic worker join
- Cluster validation
- Dry-run configuration validation
- Cluster reset
- Logging

> **Important:** v1 targets Linux hosts and assumes SSH access from the machine running the installer. It is intended for lab/test use first. Test the exact Kubernetes/OS combination before production use.

## Architecture

```text
                         cluster.yaml
                              |
                       install.sh
                              |
             +----------------+----------------+
             |                |                |
          master01         worker01         worker02
             |                |                |
        +----+----+      +----+----+      +----+----+
        | Docker  |      | Docker  |      | Docker  |
        | Engine  |      | Engine  |      | Engine  |
        +---------+      +---------+      +---------+
        |                         |                 |
        +------ Kubernetes -------------------------+
                  |
              containerd
                  |
                 CRI
                  |
               kubelet
                  |
             +----+----+
             |  CNI   |
             |Flannel |
             | Calico |
             +--------+
```

Docker is installed independently. Kubernetes does **not** use Docker as its CRI runtime.

## Requirements

### Installer machine

- Linux, macOS, or WSL with Bash 4+
- `ssh`
- `scp`
- `awk`, `sed`, `grep`, `base64`
- `python3` recommended for YAML parsing
- SSH key authentication to all nodes
- A user with root access, or direct root SSH

### Target nodes

Supported v1:

- Ubuntu / Debian
- RHEL / Rocky Linux / AlmaLinux / CentOS Stream
- SUSE / openSUSE
- Alpine Linux (experimental)

The installer performs OS detection remotely.

### Kubernetes assumptions

The installer uses:

- `kubeadm`
- `kubelet`
- `kubectl`
- `containerd`
- `runc`
- Flannel or Calico

Kubernetes packages are installed from the Kubernetes community package repositories. Pin the Kubernetes version in `cluster.yaml` and test the selected version with your OS before using this for a production environment.

## Quick start

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/k8s-cluster-installer.git
cd k8s-cluster-installer
```

Copy the example configuration:

```bash
cp examples/cluster.yaml cluster.yaml
```

Edit the IP addresses and node roles:

```yaml
cluster:
  name: homelab
  kubernetes_version: "1.30"
  pod_cidr: "10.244.0.0/16"
  service_cidr: "10.96.0.0/12"

cni:
  name: flannel

docker:
  enabled: true

ssh:
  user: root
  port: 22

nodes:
  - name: master01
    ip: 192.168.56.10
    role: master

  - name: worker01
    ip: 192.168.56.11
    role: worker

  - name: worker02
    ip: 192.168.56.12
    role: worker
```

Validate:

```bash
./install.sh cluster.yaml --validate
```

Preview the operations:

```bash
./install.sh cluster.yaml --dry-run
```

Install:

```bash
./install.sh cluster.yaml
```

Validate the resulting cluster:

```bash
./install.sh cluster.yaml --status
```

## YAML configuration

Example:

```yaml
cluster:
  name: homelab
  kubernetes_version: "1.30"
  pod_cidr: "10.244.0.0/16"
  service_cidr: "10.96.0.0/12"
  endpoint: ""

cni:
  name: flannel

docker:
  enabled: true
  install_compose: false

ssh:
  user: root
  port: 22

nodes:
  - name: master01
    ip: 192.168.56.10
    role: master
    os: auto

  - name: worker01
    ip: 192.168.56.11
    role: worker
    os: auto
```

`os` may be:

- `auto`
- `ubuntu`
- `debian`
- `rhel`
- `rocky`
- `almalinux`
- `centos`
- `sles`
- `opensuse`
- `alpine`

If omitted, `auto` is used.

## CNI

### Flannel

```yaml
cni:
  name: flannel
```

The default Pod CIDR is:

```text
10.244.0.0/16
```

### Calico

```yaml
cni:
  name: calico
```

For Calico, the installer applies the upstream manifest and patches the IP pool to the configured Pod CIDR.

## Docker

Docker is optional:

```yaml
docker:
  enabled: true
```

or:

```yaml
docker:
  enabled: false
```

Docker is deliberately installed separately from Kubernetes.

Kubernetes uses:

```text
kubelet -> CRI -> containerd -> runc
```

Docker uses:

```text
docker CLI -> Docker Engine -> containerd
```

These are separate workloads/runtime paths.

## SSH

Password authentication is intentionally not automated by v1.

Configure key-based SSH:

```bash
ssh-copy-id root@192.168.56.10
ssh-copy-id root@192.168.56.11
ssh-copy-id root@192.168.56.12
```

If your nodes use a non-root account:

```yaml
ssh:
  user: ubuntu
  port: 22
```

The user must be able to run commands with `sudo`.

## Important network requirements

All Kubernetes nodes must be able to communicate with each other.

Typical requirements include:

- TCP 6443: Kubernetes API server
- TCP 10250: kubelet
- TCP 2379-2380: etcd on control-plane nodes
- TCP 10257: kube-controller-manager
- TCP 10259: kube-scheduler
- CNI-specific traffic
- Node-to-node pod networking

Check firewall/security-group rules before installation.

## Swap

Kubernetes requires swap to be disabled unless you deliberately configure supported swap behavior.

v1 disables swap with:

```bash
swapoff -a
```

and comments traditional swap entries in `/etc/fstab`.

## Container runtime

The installer configures containerd with the systemd cgroup driver.

The resulting runtime should report:

```bash
crictl info
```

and:

```bash
kubectl get nodes -o wide
```

## Commands

### Preparation

```bash
chmod 777 install.sh reset.sh
apt update && apt install -y python3 python3-pip python3-yaml  ##on debian
```

### Install

```bash
./install.sh cluster.yaml
```

### Validate configuration

```bash
./install.sh cluster.yaml --validate
```

### Dry run

```bash
./install.sh cluster.yaml --dry-run
```

### Cluster status

```bash
./install.sh cluster.yaml --status
```

### Reset cluster

```bash
./reset.sh cluster.yaml
```

Reset is destructive.

## Logs

Logs are stored under:

```text
logs/
```

Each run creates a timestamped log.

## Idempotency

v1 is designed to be reasonably re-runnable:

- Package installation checks whether packages already exist.
- Docker installation skips an existing installation.
- containerd is reconfigured when needed.
- `kubeadm init` is skipped if the control plane is already initialized.
- Worker join is skipped when the node is already part of the cluster.

However, this is **not a full declarative configuration-management system**. For repeated production provisioning, consider moving the same logic into Ansible/Terraform/Packer later.

## Alpine note

Alpine support is experimental.

Alpine uses `apk` and OpenRC rather than systemd. Kubernetes support on Alpine can differ from mainstream distro instructions, particularly around cgroups, service management, package availability, and repository versions.

For a first working cluster, Ubuntu 22.04/24.04 or Debian 12 are recommended.

## Versioning

v1 deliberately avoids dynamically selecting arbitrary Kubernetes versions from the Internet. Set the intended minor version explicitly:

```yaml
kubernetes_version: "1.30"
```

Before upgrading, review:

- Kubernetes release notes
- kubeadm upgrade documentation
- CNI compatibility
- containerd compatibility
- OS package compatibility

## Security

Do not commit:

- private SSH keys
- passwords
- kubeconfig files
- cloud credentials
- API tokens
- production IP inventories if sensitive

The sample configuration contains only example addresses.

## Roadmap

Potential v2 improvements:

- Ansible backend
- Multi-control-plane HA
- External etcd
- Cilium
- CRI-O
- air-gapped/offline installation
- proxy support
- custom Kubernetes repository mirrors
- configurable containerd registry mirrors
- SSH jump host/bastion support
- automatic kubeconfig export
- upgrade orchestration
- better Alpine support
- network/firewall preflight checks
- parallel node preparation
