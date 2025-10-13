#!/usr/bin/env bash
# Merge upstream/<upstream_branch> into a merge branch.
# Usage: merge-upstream.sh [upstream_branch] [merge_branch]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

UPSTREAM_BRANCH=${1:-main}
MERGE_BRANCH=${2:-}

if [ -z "${MERGE_BRANCH}" ]; then
  echo "No merge branch provided. Attempting to auto-detect the most recent merge branch..."
  MERGE_BRANCH=$(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/ | grep "${MERGE_PREFIX}" || true)
  MERGE_BRANCH=$(echo "${MERGE_BRANCH}" | head -n1)
  if [ -z "${MERGE_BRANCH}" ]; then
    echo "Could not auto-detect a merge branch. Create one with create-merge-branch.sh or pass it as the second argument."
    exit 2
  fi
fi

print_config

echo "Preparing to merge ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} into ${MERGE_BRANCH}"

# Ensure working tree is clean
if [ "${DRY_RUN}" != "true" ] && [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: your working tree has uncommitted changes. Please commit or stash them before running this script."
  exit 1
fi

# Fetch latest from upstream (will be echoed in DRY_RUN)
run_cmd git fetch "${UPSTREAM_REMOTE}"

# Verify upstream branch exists (skip check in dry-run)
if [ "${DRY_RUN}" != "true" ]; then
  if ! git show-ref --verify --quiet "refs/remotes/${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}"; then
    echo "ERROR: upstream branch ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} not found. Aborting."
    exit 2
  fi
else
  echo "DRY_RUN: skipping verification of upstream remote branch refs/remotes/${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}"
fi

# Verify merge branch exists (skip check in dry-run)
if [ "${DRY_RUN}" != "true" ]; then
  if ! git show-ref --verify --quiet "refs/heads/${MERGE_BRANCH}"; then
    echo "ERROR: local merge branch ${MERGE_BRANCH} not found. Did you run create-merge-branch.sh?"
    exit 3
  fi
else
  echo "DRY_RUN: skipping verification of local merge branch refs/heads/${MERGE_BRANCH}"
fi

# Create a safety backup of the merge branch before merging
BACKUP_BEFORE_MERGE="${MERGE_BRANCH}-pre-merge-${DATE_SUFFIX}"
run_cmd git branch "${BACKUP_BEFORE_MERGE}" "${MERGE_BRANCH}"

echo "Created safety backup: ${BACKUP_BEFORE_MERGE} -> ${MERGE_BRANCH}"

# Checkout merge branch
run_cmd git checkout "${MERGE_BRANCH}"

# Perform merge with --no-ff to preserve history
if git merge --no-ff "${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}" -m "Merge ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} into ${MERGE_BRANCH}"; then
  echo "Merge completed cleanly. Review changes, run tests, then push a PR."
else
  echo "Merge produced conflicts. The repo is left in a conflicted state on branch ${MERGE_BRANCH}."
  echo "Resolve conflicts in files listed by 'git status', then run:"
  echo "  git add <resolved-files>"
  echo "  git commit "
  echo "After resolving, test and push the branch to origin."
  exit 1
fi
