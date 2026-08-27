# Repository setup

## Why the fork had to be replaced

GitHub does not allow a fork of a public repository to be made private. The Settings
page either greys the option out or asks you to detach the fork first (a support
request, measured in business days). The supported workaround is to mirror the fork
into a fresh private repository that is not a fork:

```bash
tools/spark-ems/migrate-to-private-repo.sh git@github.com:<owner>/<private-repo>.git
```

The target repo must be **created empty** - no README, no .gitignore, no licence.
A mirror push must be the first thing that lands in it.

What you give up by not being a fork: GitHub's "N commits behind upstream" banner and
the one-click "Sync fork" button. Neither is a loss, because upstream tracking is done
by `tools/spark-ems/sync-upstream.sh` against dated tags, which is more precise than
following `master`.

## Remotes

| Remote | URL | Purpose |
|---|---|---|
| `origin` | the private Spark EMS repo | everything we write |
| `upstream` | `https://github.com/rusefi/rusefi` | read-only, fetch tags for syncing |

`sync-upstream.sh` adds `upstream` automatically if it is missing.

Never push to `upstream`. Never push Amiral work to the old public fork.

## Branch model

```
upstream/master        rusEFI, fetched only, never written to
main                   Amiral product branch - what ships
sync/rusefi-<tag>      one per upstream sync; merged into main once CI is green
release/amiral-vX.Y    frozen shippable builds
claude/<topic>         agent working branches
```

The product branch is **`main`** - `master` is renamed during the migration.
`sync-upstream.sh` defaults to `main`, so `SPARK_EMS_MAIN_BRANCH` should never need to
be set.

Agents may commit and push `claude/*` and `sync/*`. `main` and `release/*` are
human-only. See `agents.md`.

`.spark-ems-upstream-tag` at the repo root records the last upstream tag merged into
`main`. `sync-upstream.sh` reads it to compute what is new and writes it on a clean
merge. It is the sync bookkeeping - keep it committed and accurate.

## CI

Upstream ships around thirty workflows, most of which build boards we do not have.
Running them on every Amiral push costs Actions minutes for no signal. Our own
workflows are named `.github/workflows/amiral-*.yaml`; disable or delete the upstream
ones you do not want in the private repo's Actions settings.

Keep at minimum: Amiral firmware build, unit tests. `custom-board-*` workflows are for
out-of-tree boards and do not apply to us - Amiral is in-tree.
