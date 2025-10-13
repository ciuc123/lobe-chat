#!/usr/bin/env bash
# Add an upstream remote (if missing) and fetch it.
# Usage: add-upstream.sh <upstream_url>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <upstream_git_url>"
  exit 2
fi

UPSTREAM_URL="$1"

print_config

echo "Checking for existing remote '${UPSTREAM_REMOTE}'..."
if git remote get-url "${UPSTREAM_REMOTE}" >/dev/null 2>&1; then
  EXISTING_URL=$(git remote get-url "${UPSTREAM_REMOTE}")
  echo "Remote '${UPSTREAM_REMOTE}' already exists -> ${EXISTING_URL}"
  if [ "${EXISTING_URL}" != "${UPSTREAM_URL}" ]; then
    echo "WARNING: existing upstream URL differs from provided URL. Use git remote set-url to change it, or remove the remote first."
  fi
else
  echo "Adding upstream remote: ${UPSTREAM_URL}"
  run_cmd git remote add "${UPSTREAM_REMOTE}" "${UPSTREAM_URL}"
fi

echo "Fetching '${UPSTREAM_REMOTE}'..."
run_cmd git fetch "${UPSTREAM_REMOTE}" --tags

echo "Upstream fetched. Run 'git remote -v' to inspect."

