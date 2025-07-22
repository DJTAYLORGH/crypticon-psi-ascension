chmod +x scripts/run_main_and_federal_setup.sh

#!/usr/bin/env bash
#
# scripts/run_main_and_federal_setup.sh
#
# 1. Bootstrap your main environment
# 2. Ingest / scan / restart Sentinel
# 3. Provision & push “root” to federal‐level bare repositories

set -euo pipefail
IFS=$'\n\t'

# ────────────────────────────────────────────────────────────────────────────────
# 1. Main Environment Provisioning
# ────────────────────────────────────────────────────────────────────────────────
echo "▶ Provisioning main environment…"
scripts/setup_main_environment.sh

# ────────────────────────────────────────────────────────────────────────────────
# 2. Ingest Ellipses, Scan HannahAI™, Restart Sentinel
# ────────────────────────────────────────────────────────────────────────────────
echo "▶ Running ellipses ingestion & sentinel orchestration…"
scripts/run_ellipses_and_sentinel.py

# ────────────────────────────────────────────────────────────────────────────────
# 3. Provision Federal “Root” Repositories & Push Initial Commit
# ────────────────────────────────────────────────────────────────────────────────

FEDERAL_NODES=(fema-relay dhs-quantum)
FEDERAL_USER="co-admin"
REPO_NAME="federal-cloud-root.git"
REPO_PATH="/srv/git/${REPO_NAME}"
LOCAL_REPO_DIR="$(pwd)"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

for node in "${FEDERAL_NODES[@]}"; do
  echo "▶ Setting up bare repo on federal node: $node"
  ssh $SSH_OPTS ${FEDERAL_USER}@${node} bash <<EOF
    sudo mkdir -p ${REPO_PATH}
    sudo chown ${FEDERAL_USER}:${FEDERAL_USER} ${REPO_PATH}
    if [ ! -f "${REPO_PATH}/HEAD" ]; then
      git init --bare ${REPO_PATH}
      cd ${REPO_PATH}
      git config receive.denyNonFastForwards true
    fi
EOF

  echo "▶ Adding remote & pushing to $node"
  git -C "${LOCAL_REPO_DIR}" remote remove federal_${node} 2>/dev/null || true
  git -C "${LOCAL_REPO_DIR}" remote add federal_${node} \
      "ssh://${FEDERAL_USER}@${node}${REPO_PATH}"
  git -C "${LOCAL_REPO_DIR}" push federal_${node} main:root --force
done

echo "✅ All steps complete. Main environment live, Sentinel restarted, federal roots in place."