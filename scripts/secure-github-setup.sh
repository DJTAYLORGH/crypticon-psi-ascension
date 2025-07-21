#!/usr/bin/env bash
set -euo pipefail

# 1. Purge Exposed Password from Shell History
echo "▶ Purging plaintext credentials from shell history…"
HISTFILE="${HISTFILE:-$HOME/.bash_history}"
grep -v "TexasGarland75042!" "$HISTFILE" > "$HISTFILE.tmp" && mv "$HISTFILE.tmp" "$HISTFILE"
history -c

# 2. Remove any stored .netrc GitHub entries
echo "▶ Cleaning up .netrc entries…"
[ -f "$HOME/.netrc" ] && \
  sed -i '/machine github.com/,/^\s*$/d' "$HOME/.netrc" || true

# 3. Ensure GitHub CLI (gh) is installed
echo "▶ Checking for GitHub CLI…"
if ! command -v gh &> /dev/null; then
  echo "Installing GitHub CLI…"
  if command -v pkg &> /dev/null; then
    pkg update -y && pkg install -y gh
  elif command -v apt &> /dev/null; then
    sudo apt update && sudo apt install -y gh
  fi
fi

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
  echo "Installing jq…"
  if command -v pkg &> /dev/null; then
    pkg install -y jq
  elif command -v apt &> /dev/null; then
    sudo apt install -y jq
  fi
fi

# 4. Generate a new SSH key (if missing) and register it
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY" ]; then
  echo "▶ Generating new SSH key…"
  mkdir -p "$(dirname "$SSH_KEY")"
  ssh-keygen -t ed25519 -C "djtaylorgh@github" -f "$SSH_KEY" -N ""
  echo "▶ Uploading public key to GitHub…"
  gh auth login --with-token < /dev/null || true
  gh ssh-key add "${SSH_KEY}.pub" --title "Termux-$(hostname)-$(date +%Y%m%d)" --yes
fi

# 5. Create a new PAT scoped to repo/workflow/keys (non-expiring)
echo "▶ Creating Personal Access Token…"
PATJSON=$(gh auth refresh -h github.com \
  -s repo,workflow,read:org,admin:public_key,write:public_key \
  --json token,name,expiresAt)
NEW_PAT=$(jq -r .token <<< "$PATJSON")
TOKEN_NAME=$(jq -r .name <<< "$PATJSON")
echo "Generated PAT \"$TOKEN_NAME\"."

# 6. Configure Git credential helper to store the PAT securely
echo "▶ Configuring Git to use secure credential helper…"
git config --global credential.helper store
printf "https://djtaylorgh:%s@github.com\n" "$NEW_PAT" > ~/.git-credentials
chmod 600 ~/.git-credentials

# 7. Advise Manual 2FA Enablement
echo
echo "⚠️  Please enable Two-Factor Authentication manually:"
echo "   https://github.com/settings/security"
echo

echo "✅ Secure GitHub setup complete."