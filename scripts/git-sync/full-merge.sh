#!/usr/bin/env bash
# full-merge.sh
# Orchestrates a safe upstream sync + backup workflow.
# Usage: full-merge.sh <upstream_git_url> [upstream_branch] [deployed_branch]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <upstream_git_url> [upstream_branch] [deployed_branch]"
  exit 2
fi

UPSTREAM_URL="$1"
UPSTREAM_BRANCH="${2:-main}"
DEPLOY_BRANCH="${3:-${DEFAULT_DEPLOY_BRANCH}}"

print_config

read -p "Proceed with snapshot of ${DEPLOY_BRANCH} and merging from ${UPSTREAM_URL} (${UPSTREAM_BRANCH})? [y/N] " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted by user."; exit 1
fi

# 1) Snapshot the deployed branch (safe backup)
"${SCRIPT_DIR}/snapshot.sh" "${DEPLOY_BRANCH}"

# 2) Ensure upstream remote exists and is fetched
"${SCRIPT_DIR}/add-upstream.sh" "${UPSTREAM_URL}"

# 3) Create a safe local merge branch from the deployed branch
"${SCRIPT_DIR}/create-merge-branch.sh" "${DEPLOY_BRANCH}"

# 4) Detect the newly created merge branch
MERGE_BRANCH=$(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/ | grep "${MERGE_PREFIX}" | head -n1 || true)
if [ -z "${MERGE_BRANCH}" ]; then
  echo "Could not find merge branch. Exiting."; exit 3
fi

echo "Merge branch to use: ${MERGE_BRANCH}"

# 5) Merge upstream into the merge branch
"${SCRIPT_DIR}/merge-upstream.sh" "${UPSTREAM_BRANCH}" "${MERGE_BRANCH}"

# 6) After merge: offer to push the merge branch to origin (optional)
read -p "Push merge branch ${MERGE_BRANCH} to origin now? [y/N] " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  run_cmd git push "${ORIGIN_REMOTE}" "${MERGE_BRANCH}"
  echo "Pushed ${MERGE_BRANCH} to ${ORIGIN_REMOTE}. Create a PR on your hosting provider to merge into ${DEPLOY_BRANCH}."
else
  echo "Skipping push. You can push later with: git push ${ORIGIN_REMOTE} ${MERGE_BRANCH}"
fi

echo "full-merge.sh finished. Review the merge branch, run tests locally, and when ready create a PR."

