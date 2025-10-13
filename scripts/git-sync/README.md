Git-sync utilities — minimal set for safe upstream sync + backup

This folder contains a minimal, safe workflow for syncing an upstream repository into your deployed branch while creating backups/snapshots first.

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

- full-merge.sh
  - Orchestrator that runs: snapshot -> add-upstream -> create-merge-branch -> merge-upstream. Usage: `./full-merge.sh <upstream_git_url> [upstream_branch] [deployed_branch]`

Design goals

- Minimal: only the scripts needed for the "sync upstream + backup" flow are kept.
- Safe: snapshot creates backups before any merge, and merge operations create pre-merge backups.
- Dry-run support: set `DRY_RUN=true` to make scripts print commands instead of executing them.

Quick usage

1. Preview actions (dry run):

```bash
DRY_RUN=true ./full-merge.sh https://github.com/upstream/repo.git main
```

2. Run the full flow interactively:

```bash
./full-merge.sh https://github.com/upstream/repo.git main
```

What was removed

- Any helper scripts that were unrelated to the upstream sync + backup flow were deleted (for a minimal repo). If you need any of those later, they can be recovered from git history.

Notes & safety

- All operations that modify the repository check for a clean working tree before proceeding.
- The scripts avoid overwriting your deployed branch; instead they create backups and merge into a separate merge branch.
- After a successful merge, review and run tests locally before pushing the merge branch and creating a PR.
