#!/usr/bin/env bash
# Shared configuration for git-sync scripts. Env vars override these values.

# Default branch where your deployed code lives
DEFAULT_DEPLOY_BRANCH="main"

# Default upstream repository and branch (used when no args provided)
# Default upstream repo: lobehub/lobe-chat (HTTPS). You can override with env var DEFAULT_UPSTREAM_URL.
DEFAULT_UPSTREAM_URL="${DEFAULT_UPSTREAM_URL:-https://github.com/lobehub/lobe-chat.git}"
DEFAULT_UPSTREAM_BRANCH="${DEFAULT_UPSTREAM_BRANCH:-main}"

# Remote names
ORIGIN_REMOTE="origin"
UPSTREAM_REMOTE="upstream"

# Prefix for temporary merge branches
MERGE_PREFIX="merge/upstream-into"

# Date format suffix
DATE_SUFFIX="$(date +%Y%m%d_%H%M%S)"

# Dry run support: if DRY_RUN=true, scripts will only print commands
DRY_RUN=${DRY_RUN:-false}

# Helper to run or echo commands when dry run is enabled
run_cmd() {
  if [ "${DRY_RUN}" = "true" ]; then
    echo "DRY_RUN: $*"
  else
    echo "+ $*"
    eval "$@"
  fi
}

# Print config for debugging
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
