# Project agents

Four agents, defined in `.claude/agents/`. They are deliberately narrow - each one
carries the domain knowledge that is expensive to rediscover, and nothing else.

| Agent | Owns | Invoke when |
|---|---|---|
| `upstream-sync` | merging rusEFI snapshot tags, conflict resolution, sync validation | weekly sync, or "pull in upstream changes" |
| `board-bringup` | `firmware/config/boards/spark-ems/amiral/` - pinout, defaults, board config | adapting Amiral to the real PCB, any board-definition change |
| `hw-validation` | live ECU work - bench tests, CAN QC, SD logging, sensor checks | a physical board is connected |
| `release-manager` | version stamping, BLT marker, bundle build, release branches | preparing a shippable build |

`/sync-upstream` is a slash command that dispatches to `upstream-sync`.

## Why these four and not more

They split along the lines where **context does not transfer**. Merging upstream needs
git and conflict judgment; bringing up a board needs the MM176 pin namespace and the
config generator; hardware validation needs USB/CDC and safety discipline; releases
need the two-place BLT marker rule and the flash-size measurement quirk. An agent that
tried to hold all four would carry three irrelevant contexts on every task.

## Shared rules every agent inherits

From `CLAUDE.md`, and they are not optional:

- **Commit and push on working branches only.** Agents may commit and push `claude/*`
  and `sync/*`. `main` and `release/*` are human-only - never commit to them, never push
  to them, never merge into them. Never open a pull request unless asked.

  The relaxation exists because remote sessions run in ephemeral containers: an
  uncommitted tree is lost when the container is reclaimed. It does not extend to the
  branch that ships.
- Stage new source files with `git add` as you create them, so nothing is lost.
- Never commit generated files. The one exception is `connectors/generated_*`, which
  upstream tracks in git for every board.
- Static allocation only in firmware. No heap, no exceptions, no RTTI.
- Unit test code must build on Linux GCC/Clang, macOS Clang, Windows MSVC and MinGW.

## Scheduled sync

The weekly sync runs as a scheduled Routine that starts a fresh session and invokes
`upstream-sync`. It reports; it does not push. If a sync conflicts, it stops and says
so rather than guessing - a wrong conflict resolution in a fuel or ignition path is
considerably worse than a late sync.
