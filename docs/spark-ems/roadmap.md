# Roadmap

Ordered by what blocks what. Status as of the initial project setup, 2026-08-27.

## Done

- [x] Amiral board definition `firmware/config/boards/spark-ems/amiral/` (F7, seeded
      from AlphaX-8chan), validated through config generation (`Happy amiral!`)
- [x] Upstream sync tooling and the dated-tag model, tested end to end
- [x] Four project agents + `/sync-upstream` slash command
- [x] Project documentation
- [x] Amiral CI workflows

## Blocked on a human action

- [ ] **Create the private repo and mirror into it.** GitHub cannot make a fork
      private. `tools/spark-ems/migrate-to-private-repo.sh` does the push; the empty
      private repo has to be created by hand first. Everything else can proceed in
      the meantime, but Amiral-specific work is public until this lands.
- [ ] Rename `master` to `main` during the migration. Decided: the product branch is
      `main`, which is what `sync-upstream.sh` already defaults to, so
      `SPARK_EMS_MAIN_BRANCH` never needs to be set.
- [ ] Turn off the upstream CI workflows we do not need in the private repo's Actions
      settings.
- [ ] Arm the weekly upstream sync Routine. Decided: **after** the migration - arming
      it now would produce weekly reports against the fork being abandoned.

## Blocked on hardware

- [ ] **Rework the connector YAMLs to the real Amiral PCB.** They are currently
      inherited verbatim from AlphaX-8chan and describe the seed hardware. This is the
      single largest piece of remaining board work and it cannot start before the
      schematic is frozen. Everything downstream - pin defaults, TS pin lists,
      generated pin names - follows from these files.
- [ ] Verify the MM176 pin namespace still matches the Amiral module layout; if the
      PCB deviates from the mega-176 module, a board-specific meta header is needed
      rather than reusing `hellen_mm176_meta.h`.
- [ ] Assign a Spark EMS `BOARD_SERIAL` range (`board.mk`).
- [ ] Board ID strategy: the Hellen chain uses resistor-based board ID
      (`HELLEN_BOARD_ID_PIN_1/2` on `Gpio::F0`/`F1`). Decide whether Amiral keeps
      resistor-based identification or uses a static ID.
- [ ] First power-on bring-up with the `hw-validation` agent.

## Decisions to make, not blocked

- [ ] **Product support URL** - `MAIN_HELP_URL` in `prepend.txt` currently points at
      `https://sparkems.com/amiral`, which is a placeholder.
- [ ] **TS / console branding depth.** See `branding.md`. The signature white label is
      reachable but couples us to shipping our own console build; full ini rebranding
      means editing the largest shared upstream file. Neither is done, both are
      understood.
- [ ] **GPLv3 and the product.** Source disclosure attaches when a binary reaches a
      third party. Settle how that is satisfied (written offer, source with the
      product, public repo of the shipped revision) before first shipment, not after.
- [ ] Whether to keep the old public fork at all.

## Later

- [ ] Amiral-specific engine configurations under `firmware/config/engines/`, if any.
- [ ] Hardware-in-the-loop CI, if a test rig exists. Upstream has `hardware-ci.yaml`
      and a CAN QC protocol (`docs/AI/hardware-quality-control.md`) to build on.
- [ ] Production flashing / end-of-line test procedure.
