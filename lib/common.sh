#!/usr/bin/env bash

RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"; NC="\033[0m"

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
debug(){ echo -e "${BLUE}[DEBUG]${NC} $*"; }

trap 'die "Command failed at line $LINENO: $BASH_COMMAND"' ERR

run() {
  log "+ $*"
  "$@"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

remote() {
  local node="$1"; shift
  local target
  target="$(ssh_target "$node")"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
      -p "$SSH_PORT" "$target" "$@"
}

remote_bash() {
  local node="$1"; shift
  local script="$1"
  remote "$node" "bash -s" <<< "$script"
}
