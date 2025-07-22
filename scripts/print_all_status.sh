#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# If CO_CLOUD_DIR is unset, assume the parent of this script is your repo root
: "${CO_CLOUD_DIR:=$(cd "$(dirname "$0")/.." && pwd)}"