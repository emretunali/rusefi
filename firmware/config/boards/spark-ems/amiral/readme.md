# Spark EMS Amiral

Spark EMS product ECU, built on the rusEFI firmware base.

| Property | Value |
|---|---|
| Short board name | `amiral` |
| MCU | STM32F767 (`ARCH_STM32F7`, 2 MB flash) |
| Hardware base | Hellen Mega-Module 176, AlphaX-8chan derived open hardware |
| Bootloader | OpenBLT (`USE_OPENBLT=yes`) |
| Product define | `HW_SPARK_EMS_AMIRAL=1` |
| Compatibility define | `HW_HELLEN_8CHAN=1` (keeps shared 8chan code paths alive) |

## Build

```bash
cd firmware/config/boards/spark-ems/amiral
./compile_amiral.sh            # firmware only
./compile_amiral_bundle.sh     # firmware + OpenBLT bundle
```

Outputs land in `firmware/deliver/`.

## Derivation from AlphaX-8chan

This board was seeded from `firmware/config/boards/hellen/alphax-8chan` (F7 variant only)
and is now maintained independently. It is a **copy, not a fork by reference**: upstream
changes to `alphax-8chan` do NOT flow here automatically.

When the weekly upstream sync lands changes under `config/boards/hellen/alphax-8chan/`,
review them and port anything relevant here by hand. The `upstream-sync` agent flags such
changes explicitly (see `docs/spark-ems/upstream-sync.md`).

### Deliberate deviations from the seed

| Item | AlphaX-8chan | Amiral | Why |
|---|---|---|---|
| MCU variants | F4 + F7 | F7 only | Single product SKU, no F4 flash squeeze |
| `TRIGGER_SCOPE` | F4 only | not built | F7 branch never had it |
| Board init symbols | `alphax_8chan_*` | `amiral_*` | Product naming |
| `set8chanDefaultETBPins` | same | **unchanged on purpose** | `config/engines/gm_sbc.cpp` forward-declares and calls this symbol across translation units - renaming it breaks the link |
| `MAIN_HELP_URL` | rusefi.com/s/8chan | sparkems.com/amiral | Product support URL - **TODO: confirm final URL** |
| `BOARD_SERIAL` | inherited | inherited placeholder | **TODO: assign a Spark EMS serial range** |

## Files

| File | Purpose |
|---|---|
| `board.mk` | Compile-time defines, F7 guard, mega-176 include |
| `meta-info-amiral.env` | Build variant descriptor consumed by `bin/compile.sh` |
| `board_configuration.cpp` | Pin defaults, hardware init, board override hooks |
| `board_config.txt` | Board-specific config fields appended to `engine_configuration_s` |
| `prepend.txt` | Board-level TS/config overrides (all variants) |
| `prepend_amiral.txt` | `amiral` variant sizing (Lua script size, table dimensions) |
| `board_*.ini` | TunerStudio menu / options / commands fragments |
| `connectors/*.yaml` | Connector pin maps - source for the generated pin-name headers |
| `connectors/generated_*` | Build artifacts, regenerated from the YAMLs by `rusefi_config.mk` |

## Pinout status

The connector YAMLs are currently **inherited verbatim from AlphaX-8chan** and describe
the seed hardware, not the final Amiral PCB. They must be reworked once the Amiral
schematic is frozen - see `docs/spark-ems/roadmap.md`.
