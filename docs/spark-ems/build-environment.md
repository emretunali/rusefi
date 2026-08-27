# Build environments

Three places Amiral gets built, with different capabilities. Know which one you are in
before trusting a number that comes out of it.

## 1. Claude Code managed container (this repo's web sessions)

Ephemeral. Nothing survives session end, so the toolchain has to be installed each time
and anything worth keeping must be committed and pushed.

Full firmware builds **do** work here. Verified 2026-08-27: a clean Amiral F7 build
completed and passed `check_illegal_conversion.sh`. Setup, roughly 4 minutes:

```bash
apt-get install -y openjdk-11-jdk-headless          # gradle toolchain pin, see CLAUDE.md
apt-get install -y gcc-arm-none-eabi binutils-arm-none-eabi libnewlib-arm-none-eabi
bash misc/actions/ubuntu-install-tools.sh           # 7z, mtools, dosfstools, colordiff, ...
```

`.claude/hooks/session-start.sh` automates exactly this. It is **not registered by
default** - registering a SessionStart hook lets the harness auto-run a script at every
session start, so that is the repo owner's call. To enable it, add to `.claude/settings.json`:

```json
"hooks": {
  "SessionStart": [
    { "hooks": [ { "type": "command",
                   "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh" } ] }
  ]
}
```

The hook is idempotent and best-effort: it skips anything already installed and logs a
warning rather than failing the session if an install does not work.

Two constraints that are not obvious:

- **`firmware/setup_linux_environment.sh` / `provide_gcc.sh` do NOT work here.** They
  fetch the pinned toolchain from `rusefi/build_support`, and the session proxy returns
  403 for any GitHub repo outside the session's own owner. `add_repo` refuses the add
  as a cross-owner request. So the managed container gets **Ubuntu's arm-none-eabi-gcc
  13.2.1**, not the **14.2.rel1** that CI and `provide_gcc.sh` pin.
- Consequence: builds here are good for catching compile and link errors, and for the
  float->int64 gate. They are **not** authoritative for flash-size comparisons or for
  compiler-version-specific warnings. Compare sizes only between builds from the same
  toolchain.
- `7z` missing shows up late and cryptically: the build gets all the way through
  compilation and then dies in `create_ini_image.sh` with `ERROR: create_ini_image.sh
  failed with 136`. That is a missing package, not a code problem.

## 2. GitHub Actions (`amiral-firmware.yaml`, `amiral-unit-tests.yaml`)

The authoritative gate. Pinned `arm-none-eabi-gcc` 14.2.Rel1 via
`carlosperate/arm-none-eabi-gcc-action`. This is what decides whether a change is
actually good.

Note that Actions minutes are metered on private repositories. An Amiral firmware build
plus a two-compiler unit-test matrix on every push is not free once this repo moves.

## 3. A dedicated Linux box (VDS, workstation, or bench machine)

For a bare Ubuntu 24.04 box, `tools/spark-ems/provision-build-server.sh` does the whole
thing - packages, JDK 11, the pinned toolchain, an unprivileged build user, ccache, and
the repo clone with submodules:

```bash
# as root on the server
bash provision-build-server.sh git@github.com:<owner>/<private-repo>.git
```

It prints a hardening checklist first and refuses to proceed until you acknowledge it -
a build server holds your source and, once it runs a CI runner, your repo credentials.

On an existing developer machine, rusEFI's own script is enough:

```bash
bash firmware/setup_linux_environment.sh   # JDK 11 + pinned 14.2.rel1 toolchain + tools
```

This is the only environment that gets the pinned toolchain with one command, keeps a
warm build cache between runs, and can host a self-hosted GitHub Actions runner.

A **cloud** VDS cannot do hardware-in-the-loop - there is no USB path to the ECU. HIL
needs a machine physically wired to the board; upstream's `hardware-ci.yaml` and
`.github/workflows/hw-ci/` show the shape of that setup.

### A web session cannot reach your server

Measured 2026-08-27 against a real host, so do not spend time retrying it:

| Path | Result |
|---|---|
| Outbound TCP/22 | timeout - filtered by the sandbox egress policy |
| Outbound TCP/80, 443 | TCP connects, but the **sandbox proxy** answers, not your host: `HTTP 403`, `x-deny-reason: host_not_allowed` |

Moving sshd to port 443 does **not** help: the proxy rejects the host, not the port.
No permission setting changes this - it is egress policy, enforced outside the agent.

So there are exactly two ways to have Claude work on that machine:

**A. Run Claude Code on the server.** `provision-build-server.sh` installs the CLI.
Then `tmux new -s amiral && cd <repo> && claude`, or VS Code Remote-SSH into the host
and use the Claude Code extension. Full interactive control, persistent session, pinned
toolchain, warm cache, and USB access to an attached ECU.

**B. Self-hosted GitHub Actions runner.** Register the server as a runner, point the
Amiral workflows at `runs-on: self-hosted`, and a web session can then dispatch
workflows and read their logs through the GitHub API. Not a shell, but real builds
executed on your hardware, driven from a web session. Only ever enable this on the
private repo - a self-hosted runner executes whatever a workflow says.

## Reference size

Amiral F7, arm-none-eabi-gcc 13.2.1, 2026-08-27, plain `compile_amiral.sh`:

| Section | Bytes |
|---|---|
| text | 431168 |
| rodata | 239112 |
| data | 1096 |
| bss | 120654 |

Treat this as a rough baseline only - it is off-toolchain. Also remember that the first
build after a `make clean` or `.dep` wipe measures several KB larger than an identical
follow-up build, so compare consecutive rebuilds, never a single post-wipe build.
