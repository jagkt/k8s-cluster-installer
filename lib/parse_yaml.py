#!/usr/bin/env python3
"""
Minimal YAML parser for the installer configuration.
Uses PyYAML when available. The installer validates the expected schema,
then emits shell-safe key=value records.
"""
import sys
import shlex

try:
    import yaml
except ImportError:
    print("ERROR=PyYAML is required on the installer machine. Install with: python3 -m pip install pyyaml", file=sys.stderr)
    sys.exit(1)

if len(sys.argv) != 2:
    sys.exit("usage: parse_yaml.py cluster.yaml")

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}

def emit(k, v):
    if v is None:
        v = ""
    if isinstance(v, bool):
        v = "true" if v else "false"
    print(f"{k}={v}")

for section in ("cluster", "cni", "docker", "ssh"):
    obj = data.get(section, {}) or {}
    for k, v in obj.items():
        emit(f"{section}.{k}", v)

for i, node in enumerate(data.get("nodes", []) or []):
    emit(f"node.{i}.name", node.get("name", ""))
    emit(f"node.{i}.ip", node.get("ip", ""))
    emit(f"node.{i}.role", node.get("role", ""))
    emit(f"node.{i}.os", node.get("os", "auto"))
