# Git-sync — single-file workflow

This directory now contains a single authoritative script to safely sync an upstream repository into your deployed branch while creating backups and handling lockfile updates.

Primary file

- `full-merge-single.sh` — single orchestrator that:
  1. Creates a timestamped backup branch and tag of the deployed branch on `origin`.
  2. Ensures `upstream` remote is added and fetched.
  3. Creates a separate git worktree and a merge branch to perform the merge so your main working tree is never checked out/modified.
  4. Performs the merge inside the worktree.
  5. Attempts a `pnpm install --frozen-lockfile --prefer-offline` inside the worktree; on `ERR_PNPM_OUTDATED_LOCKFILE` it runs `pnpm install --no-frozen-lockfile`, commits an updated `pnpm-lock.yaml` to the merge branch, and pushes it.
  6. Optionally runs tests inside the worktree.
  7. Pushes the merge branch to `origin` and offers to create a Pull Request (via `gh` if available, otherwise provides a GitHub PR URL).

Design notes

- The script uses a temporary git worktree so checking out remote branches does not remove local files (prevents the earlier issue where checking out a remote branch removed `scripts/git-sync/` files).
- Default upstream: `https://github.com/lobehub/lobe-chat.git` (branch `main`). Default deployed branch: `main`.
- Dry run: set `DRY_RUN=true` to print planned commands instead of executing them.

Quick usage

Preview (dry-run):

```bash
DRY_RUN=true ./scripts/git-sync/full-merge-single.sh
```

Run with defaults interactively:

```bash
./scripts/git-sync/full-merge-single.sh
```

Run with explicit upstream and branch:

```bash
./scripts/git-sync/full-merge-single.sh https://github.com/upstream/repo.git main production
```

Notes

- The script will create backup branches and tags before merging.
- If `pnpm` shows `ERR_PNPM_OUTDATED_LOCKFILE` after the merge, the script will update the lockfile in the merge branch and push the updated lockfile.
- If you prefer the older helper scripts, they can be recovered from git history.
