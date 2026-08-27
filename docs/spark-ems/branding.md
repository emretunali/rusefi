# Branding - what is possible, what it costs

Rebranding rusEFI is not a single switch. There are three separate layers, with very
different costs. This document exists so the decision is made deliberately.

## Layer 1 - free, already done

Things a board owns, changed with no upstream edits and no merge cost:

| Item | Where | Current value |
|---|---|---|
| Board / product name | `meta-info-amiral.env`, board directory | `amiral`, `spark-ems/amiral` |
| Product compile define | `board.mk` | `HW_SPARK_EMS_AMIRAL=1` |
| TS help URL | `prepend.txt` -> `MAIN_HELP_URL` | `https://sparkems.com/amiral` (**TODO: confirm**) |
| Board TS menus, dialogs, commands | `board_*.ini` fragments | inherited from seed |
| Generated ini filename | derived from short board name | `rusefi_amiral.ini` |

The TS signature already carries the product name:
`rusEFI <branch>.<date>.amiral.<hash>`

## Layer 2 - possible, but coupled

**The TS signature white label.** `firmware/gen_signature.sh` honours a
`signature_white_label` environment variable, defaulting to `rusEFI`. Any `KEY=VALUE`
line in `meta-info-amiral.env` is exported into the build, so setting it there would
produce `SparkEMS <branch>.<date>.amiral.<hash>`.

**Do not do this without also handling the console.** The Java console parses the
signature by a hardcoded prefix:

- `java_console/shared_io/.../SignatureHelper.java` - `private static final String PREFIX = "rusEFI ";`
  (carries a `todo: find a way to reference Fields.PROTOCOL_SIGNATURE_PREFIX`)
- `firmware/integration/ts_protocol.txt` - `#define PROTOCOL_SIGNATURE_PREFIX "rusEFI "`,
  which generates the constant in `VariableRegistryValues.java` and `Integration.java`

A signature that does not start with `rusEFI ` makes `SignatureHelper.parse()` return
null, which breaks ini lookup and the wizard catalog. So changing the white label means
shipping our own console build, and editing `ts_protocol.txt` - an upstream file, i.e.
a permanent merge conflict.

There is an existing white-label precedent to copy from:
`firmware/config/boards/hellen/uaefi121/shared_io.resources/shared_io.properties`
sets `signature_white_label`, `auto_update_root_url` and `firmware_rollback_root_url`
for the console/autoupdate side. That is the supported path if we go there.

**Current decision: leave the white label as `rusEFI`.** Stock TunerStudio and the
stock console work as-is. Revisit when we ship our own console.

## Layer 3 - expensive, deliberately not done

The shared `firmware/tunerstudio/tunerstudio.template.ini` contains dozens of literal
"rusEFI" strings in menu titles, dialog labels and help text. Rewriting them means
editing the single largest shared file in the project, guaranteeing a conflict on that
file on every future sync.

If full TS rebranding becomes a requirement, the right approach is a post-processing
step over the generated ini in our own build, not edits to the template. That keeps the
upstream file untouched and the substitution reviewable in one place.

## Not branding, but adjacent

- `BOARD_SERIAL` in `board.mk` is still the inherited placeholder
  (`000230000000000000000000`). Assign a Spark EMS serial range before production.
- The GPLv3 riders in `license.txt` (off-road only, not emissions compliant, not for
  manned aircraft) travel with the firmware and should be reflected in product
  documentation.
