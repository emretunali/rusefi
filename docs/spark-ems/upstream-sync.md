# Upstream sync

## What upstream actually publishes

rusEFI has **no semantic releases**. It publishes a snapshot tag named `YYYY-MM-DD`
(no `v` prefix) essentially every day - 1250+ of them and counting. Older history also
carries `release_N`, `N.N.N_release` and similar tags; those are historical and do not
track master. Only the dated tags matter.

Lexicographic sort on `YYYY-MM-DD` is chronological, which is why
`git tag --list '20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' --sort=-refname` gives the newest
tag first.

Syncing to a dated tag rather than to `master` means every sync lands on a commit that
upstream's own CI has built, and gives us a stable name to record and to roll back to.

## Running a sync

```bash
tools/spark-ems/sync-upstream.sh              # newest tag
tools/spark-ems/sync-upstream.sh 2026-08-20   # a specific tag
```

The script fetches `upstream` (with retry/backoff), picks the tag, creates
`sync/rusefi-<tag>` off `main`, prints what is landing, and runs
`git merge --no-commit --no-ff`. It exits 2 with the conflicted paths listed if the
merge conflicts. It never pushes and never commits a conflicted tree.

Override the base branch with `SPARK_EMS_MAIN_BRANCH` if `main` is not the branch name.

Then, always:

```bash
cd unit_tests && ./test.sh
firmware/gen_config_board.sh config/boards/spark-ems/amiral amiral   # ends in "Happy amiral!"
firmware/config/boards/spark-ems/amiral/compile_amiral.sh            # needs arm-none-eabi-gcc
git commit -m "Sync upstream rusEFI <tag>"
```

Or hand the whole thing to the `upstream-sync` agent (`/sync-upstream`), which does the
above and writes a structured report.

## The part that is NOT automatic

`firmware/config/boards/spark-ems/amiral/` is a **copy** of `hellen/alphax-8chan`, not
a reference to it. A merge will never bring upstream's seed-board fixes into our board.

The script prints a diffstat over exactly the paths that matter:

- `firmware/config/boards/hellen/alphax-8chan/`
- `firmware/config/boards/hellen/hellen_mm176_meta.h`
- `firmware/config/boards/hellen/hellen-common-mega176.mk`
- `firmware/config/boards/hellen/hellen-common176.mk`
- `firmware/config/boards/hellen/hellen-common.mk`

Anything listed there is manual porting work. It is legitimate to decide not to port a
change - it is not legitimate to not look. Record deliberate divergences in the
"deliberate deviations" table in the board readme, otherwise the next sync has no way
to tell a decision from an oversight.

To see how far the two boards have drifted:

```bash
diff -ru firmware/config/boards/hellen/alphax-8chan firmware/config/boards/spark-ems/amiral
```

## Conflict handling notes

- **Generated files** (`firmware/controllers/generated/*`, `firmware/tunerstudio/generated/*`,
  `firmware/controllers/lua/generated/*`): never hand-resolve. Take either side and
  re-run the generator.
- Do not `git checkout` build-regenerated files to tidy the working tree. Some
  checked-in copies are stale relative to the checked-in config inputs, and the
  checkout stamps them newer than their generator inputs, so the next `make` skips
  regeneration and fails on missing struct members. Leave them modified; recover with
  `touch firmware/integration/rusefi_config.txt` or `make clean`.
- After a source file moves or is deleted upstream, incremental builds fail with
  `No rule to make target '<old path>.cpp'` until the stale dependency file is
  removed - `make clean` or `rm -rf .dep` in `firmware/` / `unit_tests/`. Wiping only
  `build/obj` does not fix it.

## Cadence

Weekly, on the newest dated tag. Weekly keeps each merge small enough that conflicts
are readable; monthly batches them into something much harder to reason about. If a
week is skipped, sync to the newest tag anyway rather than catching up tag by tag -
the intermediate tags add merge work without adding information.
