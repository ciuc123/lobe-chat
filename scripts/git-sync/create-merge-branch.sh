#!/usr/bin/env bash
# Create a safe local merge branch from your deployed branch.
# Usage: create-merge-branch.sh [deployed_branch]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

TARGET_BRANCH=${1:-${DEFAULT_DEPLOY_BRANCH}}

print_config

echo "Preparing to create a safe merge branch from remote ${ORIGIN_REMOTE}/${TARGET_BRANCH}"

# Ensure working tree is clean
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: your working tree has uncommitted changes. Please commit or stash them before running this script."
  exit 1
fi

# Fetch latest from origin
run_cmd git fetch "${ORIGIN_REMOTE}"

# Verify remote branch exists
if ! git show-ref --verify --quiet "refs/remotes/${ORIGIN_REMOTE}/${TARGET_BRANCH}"; then
  echo "ERROR: remote branch ${ORIGIN_REMOTE}/${TARGET_BRANCH} not found. Aborting."
  exit 2
fi

# Construct a unique merge branch name
BASE_NAME="${MERGE_PREFIX}-${TARGET_BRANCH}-${DATE_SUFFIX}"
MERGE_BRANCH="${BASE_NAME}"
COUNT=0
while git show-ref --verify --quiet "refs/heads/${MERGE_BRANCH}"; do
  COUNT=$((COUNT+1))
  MERGE_BRANCH="${BASE_NAME}-${COUNT}"
done

# Create the merge branch pointing at the remote branch commit (do not rewrite target branch)
run_cmd git branch "${MERGE_BRANCH}" "${ORIGIN_REMOTE}/${TARGET_BRANCH}"

# Checkout the new merge branch
run_cmd git checkout "${MERGE_BRANCH}"

echo "Merge branch created and checked out: ${MERGE_BRANCH}"

echo "To proceed, run: scripts/git-sync/merge-upstream.sh [upstream_branch] ${MERGE_BRANCH}"
