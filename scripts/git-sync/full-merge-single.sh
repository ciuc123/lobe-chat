#!/usr/bin/env bash
# Single-file orchestrator for safe upstream sync + backup using a dedicated git worktree.
# This script avoids checking out remote branches in your main working tree by performing merges inside a temporary git worktree.
# Usage: full-merge-single.sh [upstream_git_url] [upstream_branch] [deployed_branch]
# Defaults: upstream=https://github.com/lobehub/lobe-chat.git, upstream_branch=main, deployed_branch=main

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults (override with env variables or CLI args)
DEFAULT_DEPLOY_BRANCH="main"
DEFAULT_UPSTREAM_URL="https://github.com/lobehub/lobe-chat.git"
DEFAULT_UPSTREAM_BRANCH="main"
ORIGIN_REMOTE="origin"
UPSTREAM_REMOTE="upstream"
MERGE_PREFIX="merge/upstream-into"
DATE_SUFFIX="$(date +%Y%m%d_%H%M%S)"

DRY_RUN=${DRY_RUN:-false}

run_cmd() {
  if [ "${DRY_RUN}" = "true" ]; then
    printf 'DRY_RUN: %s\n' "$*"
  else
    printf '+ %s\n' "$*"
    "$@"
  fi
}

print_config() {
  cat <<EOF
CONFIG:
  DEFAULT_DEPLOY_BRANCH=${DEFAULT_DEPLOY_BRANCH}
  DEFAULT_UPSTREAM_URL=${DEFAULT_UPSTREAM_URL}
  DEFAULT_UPSTREAM_BRANCH=${DEFAULT_UPSTREAM_BRANCH}
  ORIGIN_REMOTE=${ORIGIN_REMOTE}
  UPSTREAM_REMOTE=${UPSTREAM_REMOTE}
  MERGE_PREFIX=${MERGE_PREFIX}
  DATE_SUFFIX=${DATE_SUFFIX}
  DRY_RUN=${DRY_RUN}
EOF
}

# Parse args
UPSTREAM_URL="${1:-${DEFAULT_UPSTREAM_URL}}"
UPSTREAM_BRANCH="${2:-${DEFAULT_UPSTREAM_BRANCH}}"
DEPLOY_BRANCH="${3:-${DEFAULT_DEPLOY_BRANCH}}"

# Support non-interactive mode via env vars
AUTO_PUSH="${AUTO_PUSH:-true}"
AUTO_CREATE_PR="${AUTO_CREATE_PR:-false}"

# Derived names
MERGE_BRANCH_BASE="${MERGE_PREFIX}-${DEPLOY_BRANCH}-${DATE_SUFFIX}"
MERGE_BRANCH="${MERGE_BRANCH_BASE}"
WORKTREE_DIR="$(pwd)/.git-sync-worktree-${DATE_SUFFIX}"
BACKUP_BRANCH="deployed-backup-${DATE_SUFFIX}"

# Safety: helper to ensure we're inside a git repo
ensure_git_repo() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: not a git repository. Run this from the repository root." >&2
    exit 2
  fi
}

ensure_git_repo
print_config

echo "\n==== full-merge-single: snapshot -> add-upstream -> create worktree -> merge -> tests (optional) ===="
read -p "Proceed? [y/N] " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted by user."; exit 1
fi

# STEP 1: Snapshot deployed branch on origin (backup branch + tag)
echo "\n== STEP 1: Snapshot ${ORIGIN_REMOTE}/${DEPLOY_BRANCH} -> branch ${BACKUP_BRANCH} and tag deployed-${DATE_SUFFIX} =="
# fetch origin to ensure ref exists
run_cmd git fetch "${ORIGIN_REMOTE}" --tags
# verify origin branch exists
if ! git show-ref --verify --quiet "refs/remotes/${ORIGIN_REMOTE}/${DEPLOY_BRANCH}"; then
  echo "ERROR: remote branch ${ORIGIN_REMOTE}/${DEPLOY_BRANCH} not found. Aborting."; exit 2
fi
run_cmd git branch "${BACKUP_BRANCH}" "${ORIGIN_REMOTE}/${DEPLOY_BRANCH}"
run_cmd git tag "deployed-${DATE_SUFFIX}" "${ORIGIN_REMOTE}/${DEPLOY_BRANCH}"
run_cmd git push "${ORIGIN_REMOTE}" "${BACKUP_BRANCH}"
run_cmd git push "${ORIGIN_REMOTE}" --tags

# STEP 2: Ensure upstream remote exists and is fetched
echo "\n== STEP 2: Add/fetch upstream remote (${UPSTREAM_REMOTE}) =="
if git remote get-url "${UPSTREAM_REMOTE}" >/dev/null 2>&1; then
  EXISTING_URL=$(git remote get-url "${UPSTREAM_REMOTE}")
  echo "Found existing remote ${UPSTREAM_REMOTE}: ${EXISTING_URL}"
  if [ "${EXISTING_URL}" != "${UPSTREAM_URL}" ]; then
    echo "WARNING: existing ${UPSTREAM_REMOTE} URL differs from requested ${UPSTREAM_URL}."
  fi
else
  echo "Adding upstream remote ${UPSTREAM_REMOTE} -> ${UPSTREAM_URL}"
  run_cmd git remote add "${UPSTREAM_REMOTE}" "${UPSTREAM_URL}"
fi
run_cmd git fetch "${UPSTREAM_REMOTE}" --tags

# STEP 3: Create a safe merge branch in a new worktree (does not change main working tree)
echo "\n== STEP 3: Create merge branch ${MERGE_BRANCH} in worktree ${WORKTREE_DIR} =="
# Make sure the worktree dir does not yet exist
if [ -d "${WORKTREE_DIR}" ]; then
  echo "Worktree dir ${WORKTREE_DIR} already exists. Please remove it and retry."; exit 3
fi

# Create the merge branch pointing at origin/deploy_branch and attach a new worktree
# We use --no-checkout behavior via worktree add which creates a new working tree instead of switching current one
run_cmd git fetch "${ORIGIN_REMOTE}" || true
run_cmd git worktree add -b "${MERGE_BRANCH}" "${WORKTREE_DIR}" "${ORIGIN_REMOTE}/${DEPLOY_BRANCH}"

# Verify the branch exists locally now
if ! git show-ref --verify --quiet "refs/heads/${MERGE_BRANCH}"; then
  echo "ERROR: failed to create merge branch ${MERGE_BRANCH}. Aborting."; exit 4
fi

# STEP 4: Create a pre-merge safety backup of the merge branch in the main repo
PRE_MERGE_BACKUP="${MERGE_BRANCH}-pre-merge-${DATE_SUFFIX}"
echo "\n== STEP 4: Create pre-merge backup branch ${PRE_MERGE_BACKUP} =="
run_cmd git branch "${PRE_MERGE_BACKUP}" "${MERGE_BRANCH}"

# STEP 5: Perform the merge inside the worktree
echo "\n== STEP 5: Merge ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} into ${MERGE_BRANCH} (inside worktree) =="
# fetch upstream inside worktree
run_cmd git -C "${WORKTREE_DIR}" fetch "${UPSTREAM_REMOTE}"

# perform merge
if [ "${DRY_RUN}" = "true" ]; then
  echo "DRY_RUN: would run inside worktree: git -C ${WORKTREE_DIR} merge --no-ff ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} -m 'Merge ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} into ${MERGE_BRANCH}'"
  echo "DRY_RUN: finish preview. No merge executed."
else
  if git -C "${WORKTREE_DIR}" merge --no-ff "${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH}" -m "Merge ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} into ${MERGE_BRANCH}"; then
    echo "Merge completed cleanly inside worktree."
  else
    echo "Merge produced conflicts inside worktree ${WORKTREE_DIR}. The worktree and main repo may be left in a conflicted state for branch ${MERGE_BRANCH}."
    echo "To recover:"
    echo "  - Inspect conflicts: (cd ${WORKTREE_DIR} && git status)"
    echo "  - Resolve conflicts in the worktree, then run: (cd ${WORKTREE_DIR} && git add <files> && git commit)"
    echo "  - Or abort merge: (cd ${WORKTREE_DIR} && git merge --abort) and then remove the worktree: git worktree remove ${WORKTREE_DIR}"
    exit 1
  fi
fi

# ---- NEW STEP: dependency install & pnpm lockfile handling ----
echo "\n== STEP 5b: Install dependencies and handle pnpm lockfile issues (if pnpm present) =="
if command -v pnpm >/dev/null 2>&1; then
  if [ "${DRY_RUN}" = "true" ]; then
    echo "DRY_RUN: would run: (cd \"${WORKTREE_DIR}\" && pnpm install --frozen-lockfile --prefer-offline)"
  else
    echo "Attempting: pnpm install --frozen-lockfile --prefer-offline inside worktree"
    set +e
    PNPM_OUTPUT=$(cd "${WORKTREE_DIR}" && pnpm install --frozen-lockfile --prefer-offline 2>&1)
    PNPM_RC=$?
    set -e
    if [ ${PNPM_RC} -eq 0 ]; then
      echo "pnpm install (frozen) succeeded."
    else
      echo "pnpm install failed. Output:"
      echo "${PNPM_OUTPUT}"
      if echo "${PNPM_OUTPUT}" | grep -q "ERR_PNPM_OUTDATED_LOCKFILE"; then
        echo "Detected ERR_PNPM_OUTDATED_LOCKFILE: lockfile is outdated compared to package.json."
        echo "Running pnpm install --no-frozen-lockfile to update pnpm-lock.yaml..."
        (cd "${WORKTREE_DIR}" && pnpm install --no-frozen-lockfile)

        # If the lockfile changed, commit it to the merge branch and push it
        if git -C "${WORKTREE_DIR}" status --porcelain | grep -q 'pnpm-lock.yaml' || true; then
          echo "pnpm-lock.yaml changed; committing updated lockfile to merge branch"
          git -C "${WORKTREE_DIR}" add pnpm-lock.yaml || true
          git -C "${WORKTREE_DIR}" commit -m "chore: update pnpm-lock.yaml after upstream merge" || true
          echo "Pushing updated merge branch with new lockfile"
          run_cmd git -C "${WORKTREE_DIR}" push "${ORIGIN_REMOTE}" HEAD
        else
          echo "pnpm-lock.yaml did not change after install; nothing to commit."
        fi
      else
        echo "pnpm install failed for an unrelated reason. Please inspect the output above."
      fi
    fi
  fi
else
  echo "pnpm not found; skipping pnpm install/lockfile handling."
fi

# STEP 6: Optional tests/build inside worktree or main repo
read -p "Run tests/build in worktree now? [y/N] " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  # prefer pnpm if available
  if [ -f pnpm-lock.yaml ]; then
    run_cmd bash -lc "(cd \"${WORKTREE_DIR}\" && pnpm -w test)"
  else
    run_cmd bash -lc "(cd \"${WORKTREE_DIR}\" && npm test)"
  fi
else
  echo "Skipping tests/build. You can run tests inside the worktree at: cd ${WORKTREE_DIR}"
fi

# STEP 7: Offer to push the merge branch to origin
# If AUTO_PUSH=true, skip interactive prompt and push automatically.
if [ "${AUTO_PUSH}" = "true" ]; then
  PUSH_REPLY="y"
else
  read -p "Push merge branch ${MERGE_BRANCH} to ${ORIGIN_REMOTE}? [y/N] " -r
  PUSH_REPLY="$REPLY"
fi
if [[ $PUSH_REPLY =~ ^[Yy]$ ]]; then
  run_cmd git push "${ORIGIN_REMOTE}" "${MERGE_BRANCH}"
  echo "Pushed ${MERGE_BRANCH} to ${ORIGIN_REMOTE}."

  # Offer to create a PR automatically (Option A)
  if [ "${AUTO_CREATE_PR}" = "true" ]; then
    PR_REPLY="y"
  else
    read -p "Create a pull request for ${MERGE_BRANCH} -> ${DEPLOY_BRANCH}? [Y/n] " -r
    PR_REPLY="$REPLY"
  fi

  if [[ $PR_REPLY =~ ^[Nn]$ ]]; then
    echo "Skipping PR creation. You can create a PR on your hosting provider."
  else
    # Try to use GitHub CLI (gh) first
    if command -v gh >/dev/null 2>&1; then
      echo "Creating PR via gh..."
      PR_TITLE="Sync: merge ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} into ${DEPLOY_BRANCH}"
      PR_BODY="This PR was created by scripts/git-sync/full-merge-single.sh. It merges ${UPSTREAM_REMOTE}/${UPSTREAM_BRANCH} into ${DEPLOY_BRANCH}. Please review and run CI before merging."
      if [ "${DRY_RUN}" = "true" ]; then
        echo "DRY_RUN: gh pr create --base ${DEPLOY_BRANCH} --head ${MERGE_BRANCH} --title \"${PR_TITLE}\" --body \"${PR_BODY}\""
      else
        gh pr create --base "${DEPLOY_BRANCH}" --head "${MERGE_BRANCH}" --title "${PR_TITLE}" --body "${PR_BODY}"
      fi
    else
      # Construct a GitHub PR URL from origin remote if possible
      ORIGIN_URL=$(git remote get-url "${ORIGIN_REMOTE}" 2>/dev/null || true)
      if [ -n "${ORIGIN_URL}" ]; then
        # Normalize git@ and https URLs to https://github.com/owner/repo
        if echo "${ORIGIN_URL}" | grep -q "github.com"; then
          # remove .git suffix
          REPO_PATH=$(echo "${ORIGIN_URL}" | sed -E 's#^(git@|https?://)([^/:]+)[:/]+([^/]+/[^/]+)(\.git)?$#\3#')
          PR_URL="https://github.com/${REPO_PATH}/pull/new/${MERGE_BRANCH}?base=${DEPLOY_BRANCH}"
          echo "Open this URL to create a PR:"
          echo "${PR_URL}"
          # Try to open in browser if xdg-open exists
          if command -v xdg-open >/dev/null 2>&1 && [ "${DRY_RUN}" != "true" ]; then
            xdg-open "${PR_URL}" || true
          fi
        else
          echo "Could not auto-construct PR URL from origin remote: ${ORIGIN_URL}"
          echo "Please create a PR from ${MERGE_BRANCH} into ${DEPLOY_BRANCH} on your hosting provider."
        fi
      else
        echo "No origin remote found; please create a PR manually from ${MERGE_BRANCH} into ${DEPLOY_BRANCH}."
      fi
    fi
  fi
else
  echo "Skipping push. To push later: git push ${ORIGIN_REMOTE} ${MERGE_BRANCH}";
fi

# Final note
cat <<EOF

FULL MERGE FINISHED (or previewed if DRY_RUN).
- Merge branch: ${MERGE_BRANCH}
- Pre-merge backup: ${PRE_MERGE_BACKUP}
- Deployed backup branch: ${BACKUP_BRANCH}
- Worktree dir: ${WORKTREE_DIR}

Notes:
- The merge was performed inside a separate git worktree to avoid modifying your main working tree.
- If you need to remove the worktree: git worktree remove "${WORKTREE_DIR}" (make sure no changes are needed).
EOF

