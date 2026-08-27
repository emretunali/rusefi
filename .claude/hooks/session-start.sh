#!/bin/bash
#
# Spark EMS Amiral - SessionStart hook
#
# Installs what a Claude Code web session needs to actually BUILD this project:
# the ARM cross-compiler, JDK 11, and rusEFI's own tool list. Without these a session
# can only generate configs and read code - it cannot compile firmware.
#
# Best-effort by design: a failed install logs loudly but must not stop the session
# from starting. Reading code is still useful even if the toolchain did not come up.
#
# See docs/spark-ems/build-environment.md for what each environment can and cannot do.

set -uo pipefail

# Web sessions only. A developer machine uses firmware/setup_linux_environment.sh,
# which installs the PINNED toolchain instead of the distro one.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

log() { echo "[session-start] $*"; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

export DEBIAN_FRONTEND=noninteractive
APT_UPDATED=0

apt_update_once() {
  if [ "$APT_UPDATED" -eq 0 ]; then
    $SUDO apt-get update -qq >/dev/null 2>&1
    APT_UPDATED=1
  fi
}

apt_install() {
  apt_update_once
  $SUDO apt-get install -y -qq "$@" >/dev/null 2>&1
}

# --- JDK 11 -----------------------------------------------------------------
# The root build.gradle pins JavaLanguageVersion.of(11) [tag:java8]. With only a newer
# JDK present, gradle fails and then fails again trying to fetch one from foojay through
# the proxy. Installing 11 is the fix - do not edit build.gradle, it is a shared file.
if [ -x /usr/lib/jvm/java-11-openjdk-amd64/bin/javac ]; then
  log "JDK 11 already present"
else
  log "installing JDK 11 (gradle toolchain pin)"
  apt_install openjdk-11-jdk-headless || log "WARNING: JDK 11 install failed - config generation will not work"
fi

# --- ARM cross-compiler -----------------------------------------------------
# firmware/provide_gcc.sh fetches the pinned 14.2.rel1 build from rusefi/build_support,
# but the session proxy returns 403 for GitHub repos outside this session's owner, so
# that path cannot work here. Ubuntu's 13.2.1 builds the firmware correctly; it is just
# not the version CI pins, so flash sizes from it are not comparable with CI's.
if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
  log "arm-none-eabi-gcc already present: $(arm-none-eabi-gcc -dumpversion 2>/dev/null)"
else
  log "installing arm-none-eabi toolchain (distro 13.2.x, NOT CI's pinned 14.2.rel1)"
  apt_install gcc-arm-none-eabi binutils-arm-none-eabi libnewlib-arm-none-eabi \
    || log "WARNING: ARM toolchain install failed - firmware cannot be cross-compiled"
fi

# --- rusEFI's own tool list -------------------------------------------------
# 7z in particular fails LATE and misleadingly: compilation finishes, then
# create_ini_image.sh dies with "failed with 136".
if command -v 7z >/dev/null 2>&1 && command -v mtools >/dev/null 2>&1; then
  log "rusEFI build tools already present"
else
  log "installing rusEFI build tools (7z, mtools, dosfstools, mingw, colordiff, ...)"
  apt_update_once
  $SUDO bash "${CLAUDE_PROJECT_DIR:-.}/misc/actions/ubuntu-install-tools.sh" >/dev/null 2>&1 \
    || log "WARNING: rusEFI tool install failed - the firmware image step will fail"
fi

# --- submodules -------------------------------------------------------------
# ChibiOS, googletest, lua, openblt and friends. Nothing builds without them, and the
# unit-test Makefile's own fallback aborts the first make with a confusing
# "multiple target patterns" error when they are missing.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
if [ -f firmware/ChibiOS/os/hal/hal.mk ] && [ -f unit_tests/googletest/LICENSE ]; then
  log "submodules already initialised"
else
  log "initialising submodules (this is the slow part)"
  git submodule update --init >/dev/null 2>&1 \
    || log "WARNING: submodule init failed - builds will not work"
fi

log "ready. firmware: config/boards/spark-ems/amiral/compile_amiral.sh | tests: unit_tests/test.sh"
exit 0
