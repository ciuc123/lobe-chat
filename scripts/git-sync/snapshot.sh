#!/usr/bin/env bash
# Create a snapshot branch and tag for the currently deployed branch, then push to origin.
# Usage: snapshot.sh [deployed_branch]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

BRANCH=${1:-${DEFAULT_DEPLOY_BRANCH}}
BACKUP_BRANCH="deployed-backup-${DATE_SUFFIX}"
TAG_NAME="deployed-${DATE_SUFFIX}"

print_config

echo "Preparing snapshot for remote branch '${ORIGIN_REMOTE}/${BRANCH}'"

# Ensure working tree is clean (avoid overwriting uncommitted changes)
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: your working tree has uncommitted changes. Please commit, stash, or set DRY_RUN=true to continue."
  exit 1
fi

# Fetch latest from origin
run_cmd git fetch "${ORIGIN_REMOTE}" --tags

# Verify the remote branch exists
if ! git show-ref --verify --quiet "refs/remotes/${ORIGIN_REMOTE}/${BRANCH}"; then
  echo "ERROR: remote branch ${ORIGIN_REMOTE}/${BRANCH} not found. Aborting."
  exit 2
fi

# Create a backup branch that points at the remote branch commit (do not change current branch)
run_cmd git branch "${BACKUP_BRANCH}" "${ORIGIN_REMOTE}/${BRANCH}"

# Create a tag at the same remote commit
run_cmd git tag "${TAG_NAME}" "${ORIGIN_REMOTE}/${BRANCH}"

# Push the backup branch and tag to origin
run_cmd git push "${ORIGIN_REMOTE}" "${BACKUP_BRANCH}"
run_cmd git push "${ORIGIN_REMOTE}" --tags

echo "Snapshot complete: branch ${BACKUP_BRANCH}, tag ${TAG_NAME}"

echo "Note: this script did NOT checkout or overwrite any local branches."
