---
name: sync-upstream
description: Merge the latest (or a specified) upstream rusEFI snapshot tag into the Spark EMS Amiral tree, resolve conflicts, validate, and report. Use when the user asks to sync/merge/pull upstream rusEFI changes, or on the scheduled periodic sync.
---

# Sync upstream rusEFI into Spark EMS Amiral

Delegate this to the `upstream-sync` agent unless the user explicitly asks you to do
it inline. The agent definition carries the full procedure and reporting format.

```
Agent(subagent_type: "upstream-sync",
      prompt: "Run the upstream sync. <tag if the user named one, otherwise: use the newest dated tag>")
```

## Context the agent needs and you should confirm first

- **Which tag.** rusEFI publishes daily snapshot tags named `YYYY-MM-DD` (no `v`
  prefix). There are no semantic releases. `tools/spark-ems/sync-upstream.sh` with no
  argument picks the newest.
- **Last synced tag** is recorded in `.spark-ems-upstream-tag` at the repo root.
- **Main branch name.** The script defaults to `main`; override with
  `SPARK_EMS_MAIN_BRANCH`. Check what the repo actually uses before running.

## What the sync does NOT do automatically

Our board `firmware/config/boards/spark-ems/amiral/` is a **copy** of
`hellen/alphax-8chan`, not a reference to it. Upstream fixes to the seed board, to
`hellen_mm176_meta.h`, or to the `hellen-common*.mk` chain do not reach us on their
own. The script prints a diffstat of exactly those paths - that list is manual porting
work, and skipping it silently is how the two boards drift apart.

## Definition of done

A sync is finished when: the merge is committed on a `sync/rusefi-<tag>` branch, unit
tests pass, config generation for `amiral` ends in `Happy amiral!`, seed-board changes
are either ported or explicitly listed as deliberately skipped, and the report says
which validation steps did not run and why.

Never push and never open a pull request - hand the branch to the human.
