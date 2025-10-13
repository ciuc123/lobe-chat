#!/usr/bin/env bash
# full-merge.sh
# Orchestrates a safe upstream sync + backup workflow with clear step echoing.
# Usage: full-merge.sh [upstream_git_url] [upstream_branch] [deployed_branch]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Allow optional args but fall back to defaults from config.sh
UPSTREAM_URL="${1:-${DEFAULT_UPSTREAM_URL}}"
UPSTREAM_BRANCH="${2:-${DEFAULT_UPSTREAM_BRANCH}}"
DEPLOY_BRANCH="${3:-${DEFAULT_DEPLOY_BRANCH}}"

# Print an easy-to-read header and config
echo "========================================"
echo "full-merge: safe upstream sync + backup"
echo "Defaults: upstream=${DEFAULT_UPSTREAM_URL}:${DEFAULT_UPSTREAM_BRANCH}, deploy_branch=${DEFAULT_DEPLOY_BRANCH}"
echo "Using: upstream=${UPSTREAM_URL}:${UPSTREAM_BRANCH}, deploy_branch=${DEPLOY_BRANCH}"
echo "========================================"
print_config

read -p "Proceed with the full flow (snapshot -> add upstream -> create merge branch -> merge)? [y/N] " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted by user."; exit 1
fi

# Step 1: Snapshot deployed branch
echo "\n== STEP 1: Snapshot deployed branch '${DEPLOY_BRANCH}' on ${ORIGIN_REMOTE} =="
echo "Will create a backup branch named 'deployed-backup-<timestamp>' and a tag 'deployed-<timestamp>' and push them to ${ORIGIN_REMOTE}."
"${SCRIPT_DIR}/snapshot.sh" "${DEPLOY_BRANCH}"

# Step 2: Add and fetch upstream remote
echo "\n== STEP 2: Ensure upstream remote is present and fetched =="
echo "Will add remote '${UPSTREAM_REMOTE}' -> ${UPSTREAM_URL} (if missing) and fetch tags."
"${SCRIPT_DIR}/add-upstream.sh" "${UPSTREAM_URL}"

# Step 3: Create merge branch
echo "\n== STEP 3: Create a safe merge branch from ${ORIGIN_REMOTE}/${DEPLOY_BRANCH} =="
echo "Will create a local branch named like '${MERGE_PREFIX}-${DEPLOY_BRANCH}-<timestamp>' pointing at ${ORIGIN_REMOTE}/${DEPLOY_BRANCH}."
"${SCRIPT_DIR}/create-merge-branch.sh" "${DEPLOY_BRANCH}"

# Step 4: Detect merge branch
MERGE_BRANCH=$(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/ | grep "${MERGE_PREFIX}" | head -n1 || true)
if [ -z "${MERGE_BRANCH}" ]; then
  echo "Could not find merge branch. Exiting."; exit 3
fi

echo "Merge branch to use: ${MERGE_BRANCH}"

# Step 5: Merge upstream into merge branch
echo "\n== STEP 4: Merge upstream ${UPSTREAM_BRANCH} into ${MERGE_BRANCH} =="
echo "Will fetch ${UPSTREAM_URL} and merge ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} into ${MERGE_BRANCH}."
"${SCRIPT_DIR}/merge-upstream.sh" "${UPSTREAM_BRANCH}" "${MERGE_BRANCH}"

# Step 6: Run tests/build (optional)
echo "\n== STEP 5: Optional tests/build to validate the merge =="
read -p "Run tests/build now? [y/N] " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  "${SCRIPT_DIR}/run-ci-and-build.sh"
else
  echo "Skipping tests/build step. You can run './scripts/git-sync/run-ci-and-build.sh' manually."
fi

# Step 7: Push merge branch (optional)
echo "\n== STEP 6: Push merge branch to ${ORIGIN_REMOTE} (optional) =="
read -p "Push merge branch ${MERGE_BRANCH} to ${ORIGIN_REMOTE} now? [y/N] " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  run_cmd git push "${ORIGIN_REMOTE}" "${MERGE_BRANCH}"
  echo "Pushed ${MERGE_BRANCH} to ${ORIGIN_REMOTE}. Create a PR on your hosting provider to merge into ${DEPLOY_BRANCH}."
else
  echo "Skipping push. You can push later with: git push ${ORIGIN_REMOTE} ${MERGE_BRANCH}"
fi

echo "\nfull-merge.sh finished. Review the merge branch, run any extra checks, and create a PR when ready."
