#!/usr/bin/env bash
# run-ci-and-build.sh
# Run the project's test suite (and optionally build) as part of the merge verification.
# Usage: run-ci-and-build.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

print_config

# Detect package manager by lockfile preference
if [ -f "pnpm-lock.yaml" ]; then
  PM="pnpm"
elif [ -f "yarn.lock" ]; then
  PM="yarn"
elif [ -f "package-lock.json" ]; then
  PM="npm"
else
  PM="npm"
fi

# Prefer workspace-wide pnpm test when available
if [ "${PM}" = "pnpm" ]; then
  CMD="${PM} -w test"
elif [ "${PM}" = "yarn" ]; then
  CMD="${PM} test"
else
  CMD="${PM} test"
fi

# Allow quick skip
if [ "${SKIP_CI_AND_BUILD:-false}" = "true" ]; then
  echo "SKIP_CI_AND_BUILD=true -> skipping tests/build step"
  exit 0
fi

echo "Running CI/test step with: ${CMD}"

# Run or echo the command depending on DRY_RUN
run_cmd ${CMD}

echo "Tests/build step finished. Check the output above for failures."

