Git-sync utilities — minimal set for safe upstream sync + backup

This folder contains a minimal, safe workflow for syncing an upstream repository into your deployed branch while creating backups/snapshots first.

Defaults

- Default upstream repository: <https://github.com/lobehub/lobe-chat.git> (branch: main)
- Default deployed branch: main

You can override these defaults by passing arguments to `full-merge.sh` or by setting the environment variables `DEFAULT_UPSTREAM_URL`, `DEFAULT_UPSTREAM_BRANCH`, or `DEFAULT_DEPLOY_BRANCH` in your shell.

Kept scripts

- config.sh
  - Shared configuration and helpers used by all scripts. Set `DRY_RUN=true` to preview operations.

- add-upstream.sh
  - Add (or verify) an `upstream` remote and fetch it. Usage: `./add-upstream.sh <upstream_git_url>`

- snapshot.sh
  - Create a backup branch and tag of the deployed branch on `origin` and push them. Usage: `./snapshot.sh [deployed_branch]`

- create-merge-branch.sh
  - Create a safe local merge branch based on the deployed branch (does not modify the deployed branch). Usage: `./create-merge-branch.sh [deployed_branch]`

- merge-upstream.sh
  - Merge from `upstream/<branch>` into the merge branch. Usage: `./merge-upstream.sh [upstream_branch] [merge_branch]`

- run-ci-and-build.sh
  - Run tests (and optionally build) to verify the merge. This script auto-detects pnpm/yarn/npm and runs the test target. Usage: `./run-ci-and-build.sh`

- full-merge.sh
  - Orchestrator that runs: snapshot -> add-upstream -> create-merge-branch -> merge-upstream -> optional tests & push. Usage: `./full-merge.sh [upstream_git_url] [upstream_branch] [deployed_branch]`

Quick usage

2. Preview actions (dry run):

```bash
DRY_RUN=true ./scripts/git-sync/full-merge.sh
# or with explicit upstream
DRY_RUN=true ./scripts/git-sync/full-merge.sh https://github.com/upstream/repo.git main
```

1. Use defaults (no args):

```bash
# Uses upstream=https://github.com/lobehub/lobe-chat.git (main) and deployed branch 'main'
./scripts/git-sync/full-merge.sh
```

Notes & safety

- All operations that modify the repository check for a clean working tree before proceeding.
- The scripts avoid overwriting your deployed branch; instead they create backups and merge into a separate merge branch.
- After a successful merge, review and run tests locally before pushing the merge branch and creating a PR.
