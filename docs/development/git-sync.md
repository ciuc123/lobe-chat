# Git-sync: safe upstream sync + backup

This document explains the minimal scripts under `scripts/git-sync/` used to safely sync an upstream repository into the deployed branch while creating backups.

Summary of the workflow

1. Create a snapshot (branch + tag) of the deployed branch on origin.
2. Ensure an `upstream` remote is configured and fetched.
3. Create a safe local merge branch based on the deployed branch.
4. Merge the upstream branch into the merge branch.
5. Run tests/build locally to verify the merge.

Files in `scripts/git-sync/`

- `config.sh` — shared config and helpers. Set `DRY_RUN=true` to print commands instead of running them.
- `add-upstream.sh` — add or validate `upstream` remote and fetch tags.
- `snapshot.sh` — create `deployed-backup-<timestamp>` branch and `deployed-<timestamp>` tag and push them to origin.
- `create-merge-branch.sh` — create a local merge branch pointing at the deployed branch commit.
- `merge-upstream.sh` — merge `upstream/<branch>` into the merge branch (creates a pre-merge backup branch automatically).
- `run-ci-and-build.sh` — run tests (detects pnpm/yarn/npm and runs the test target). Useful to validate the merge locally before pushing.
- `full-merge.sh` — orchestrator that runs snapshot -> add-upstream -> create-merge-branch -> merge-upstream -> optional tests & push.

Quick example

Dry run (preview):

```bash
DRY_RUN=true ./scripts/git-sync/full-merge.sh https://github.com/upstream/repo.git main
```

Full run:

```bash
./scripts/git-sync/full-merge.sh https://github.com/upstream/repo.git main
```

After a successful merge

- Review the merge branch locally.
- Run additional manual checks if required.
- Push the merge branch (`git push origin <merge-branch>`) and open a PR to merge into the deployed branch.

Notes

- Removed unrelated scripts to keep the workflow minimal; those can be recovered from git history if needed.
- These scripts assume you have `git` and the relevant package manager (`pnpm`, `yarn`, or `npm`) available.
