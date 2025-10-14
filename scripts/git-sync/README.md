# Git-sync — single-file workflow

This directory now contains a single authoritative script to safely sync an upstream repository into your deployed branch while creating backups and handling lockfile updates.

Primary file

- STEP 0: Fetch remotes → Check for changes → Exit if up-to-date ✅
- STEP 1: Create backup branch and tag (only if changes exist)
- STEP 2: Create merge branch in worktree
- STEP 3: Create pre-merge backup
- STEP 4: Perform merge
- STEP 4b: Handle pnpm lockfile updates
- STEP 5: Optional tests
- STEP 6: Push and optionally create PR

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
