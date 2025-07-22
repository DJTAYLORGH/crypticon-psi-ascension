#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# If CO_CLOUD_DIR is unset, assume the parent of this script is your repo root
: "${CO_CLOUD_DIR:=$(cd "$(dirname "$0")/.." && pwd)}"

# Old block you can remove:
/*
if [ -f /etc/profile.d/co_cloud.sh ]; then
  source /etc/profile.d/co_cloud.sh
elif [ -n "${CO_CLOUD_DIR:-}" ]; then
  export CO_CLOUD_DIR
else
  echo "ERROR: CO_CLOUD_DIR not set..."
  exit 1
fi
*/

# New smart default:
: "${CO_CLOUD_DIR:=$(cd "$(dirname "$0")/.." && pwd)}"

chmod +x scripts/print_all_status.sh
./scripts/print_all_status.sh