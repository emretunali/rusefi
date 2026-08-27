# Spark EMS - Amiral

Spark EMS product ECU built on the rusEFI firmware base.

| | |
|---|---|
| Brand | Spark EMS |
| Product | Amiral |
| Board short name | `amiral` |
| MCU | STM32F767 (`ARCH_STM32F7`) |
| Hardware base | Hellen Mega-Module 176 / AlphaX-8chan derived open hardware |
| Upstream base | rusEFI, synced by dated snapshot tag |
| Last synced upstream tag | see `.spark-ems-upstream-tag` at the repo root |

## Documents

| Document | What it covers |
|---|---|
| [`repository-setup.md`](repository-setup.md) | Private repo migration, remotes, branch model |
| [`upstream-sync.md`](upstream-sync.md) | How the periodic rusEFI sync works and what it will not do for you |
| [`agents.md`](agents.md) | The four project agents and when to use which |
| [`branding.md`](branding.md) | What can be rebranded, what it costs, what is deliberately left alone |
| [`roadmap.md`](roadmap.md) | Open work, ordered |
| [`../../firmware/config/boards/spark-ems/amiral/readme.md`](../../firmware/config/boards/spark-ems/amiral/readme.md) | The board itself |

Upstream rusEFI's own AI-facing documentation lives in `docs/AI/` and is still the
best reference for the firmware internals - fueling, ignition, protection, sensors,
scheduling, Lua, SD logging. We inherit all of it.

## Build

```bash
# once per machine/container - the config generator needs a JDK 11 toolchain
./gradlew :config_definition:shadowJar

# firmware (needs arm-none-eabi-gcc)
cd firmware/config/boards/spark-ems/amiral && ./compile_amiral.sh

# config generation only - fast, no ARM toolchain needed, good smoke test
firmware/gen_config_board.sh config/boards/spark-ems/amiral amiral

# unit tests
cd unit_tests && ./test.sh
```

## The one architectural rule

**Keep Spark EMS code out of upstream files.** Every line we add to a shared rusEFI
file is a merge conflict on every future sync, forever. Our code belongs in:

```
firmware/config/boards/spark-ems/    board definition, pinout, defaults
docs/spark-ems/                      our documentation
tools/spark-ems/                     our scripts
.claude/agents/, .claude/skills/     our agents
.github/workflows/amiral-*.yaml      our CI
```

rusEFI deliberately provides extension points so a board never has to edit shared
code: `board_configuration.cpp` override hooks, `prepend.txt`, `board_config.txt`,
`board_engine_configuration.txt`, `board_*.ini` fragments, and board-scoped `.mk`
defines. Use them. When something genuinely cannot be expressed through a hook, note
the upstream edit in `roadmap.md` so the next sync knows to expect a conflict there.

## Licensing

rusEFI firmware is **GPLv3** (with off-road / non-automotive-regulation / non-aviation
riders - see `license.txt`). Private development is unrestricted. The source-disclosure
obligation attaches when a **binary is conveyed to a third party**: whoever receives an
Amiral ECU with this firmware on it is entitled to the corresponding source. This is a
product and business-model constraint, not a development one, and it should be settled
deliberately rather than discovered at first shipment.
