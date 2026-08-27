#!/usr/bin/env bash
#
# Spark EMS - provision a bare Ubuntu box as an Amiral build server.
#
# Target: Ubuntu 24.04 LTS, fresh install. Idempotent - safe to re-run.
#
# Run AS ROOT on the server:
#     bash provision-build-server.sh <git-clone-url> [build-user]
#
# What it does NOT do: security hardening. Read the "HARDEN FIRST" block below and do
# that before exposing this box to anything. A build server holds your source and, if
# you add a CI runner, your repo credentials.
#
set -euo pipefail

CLONE_URL="${1:-}"
BUILD_USER="${2:-sparkems}"

if [ -z "$CLONE_URL" ]; then
	cat >&2 <<'USAGE'
usage: provision-build-server.sh <git-clone-url> [build-user]

  <git-clone-url>  e.g. git@github.com:emretunali/spark-ems-amiral.git
  [build-user]     unprivileged user to create and build as (default: sparkems)
USAGE
	exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
	echo "ERROR: run as root" >&2
	exit 1
fi

echo "=============================================================="
echo " HARDEN FIRST - this script does not do it for you"
echo "=============================================================="
cat <<'HARDEN'
Before this box is useful it should be safe. In another terminal:

  1. Change the root password:            passwd
  2. Install your SSH public key:         ssh-copy-id -i ~/.ssh/id_ed25519.pub root@<host>
  3. Disable password login and root SSH, in /etc/ssh/sshd_config:
         PermitRootLogin prohibit-password
         PasswordAuthentication no
         KbdInteractiveAuthentication no
     then: systemctl restart ssh
  4. Firewall - allow only SSH:
         ufw default deny incoming && ufw allow OpenSSH && ufw --force enable
  5. Unattended security updates:
         apt-get install -y unattended-upgrades

If the server's credentials have ever been sent over chat, email or a ticket,
treat them as public and rotate them now.
HARDEN
echo
read -r -p "Continue with provisioning? [y/N] " reply
case "$reply" in [yY]*) ;; *) echo "aborted"; exit 1 ;; esac

# --- packages ---------------------------------------------------------------
echo "==> installing base packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q git curl xz-utils build-essential gdb gcc-multilib xxd ccache tmux

echo "==> installing JDK 11 (the root build.gradle pins JavaLanguageVersion 11)"
apt-get install -y -q openjdk-11-jdk-headless

echo "==> installing rusEFI build tools (7z, mtools, dosfstools, colordiff, mingw, ...)"
# Cloned below; use the repo's own list once we have it. These are the same packages.
apt-get install -y -q make g++-multilib g++-mingw-w64 gcc-mingw-w64 sshpass mtools zip 7zip dosfstools colordiff

# --- build user -------------------------------------------------------------
if ! id -u "$BUILD_USER" >/dev/null 2>&1; then
	echo "==> creating user $BUILD_USER"
	adduser --disabled-password --gecos "" "$BUILD_USER"
fi
# serial ports, for when an ECU is attached to this machine
usermod -a -G dialout "$BUILD_USER"

HOME_DIR=$(getent passwd "$BUILD_USER" | cut -d: -f6)
REPO_DIR="${HOME_DIR}/spark-ems-amiral"

# --- clone + toolchain, as the build user -----------------------------------
sudo -u "$BUILD_USER" -H bash -euo pipefail -s "$CLONE_URL" "$REPO_DIR" <<'ASUSER'
CLONE_URL="$1"
REPO_DIR="$2"

if [ ! -d "$REPO_DIR/.git" ]; then
	echo "==> cloning $CLONE_URL"
	git clone "$CLONE_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
echo "==> initialising submodules (ChibiOS, googletest, lua, openblt, ...)"
git submodule update --init

echo "==> installing the PINNED arm-none-eabi toolchain (14.2.rel1, same as CI)"
# provide_gcc.sh caches into ~/.rusefi-tools and no-ops if already correct.
mkdir -p "$HOME/.rusefi-tools"
cd "$HOME/.rusefi-tools"
bash "$REPO_DIR/firmware/provide_gcc.sh"

# PATH for interactive shells
PROFILE_LINE='export PATH=$PATH:$HOME/.rusefi-tools/gcc-arm-none-eabi/bin'
grep -qxF "$PROFILE_LINE" "$HOME/.profile" 2>/dev/null || echo "$PROFILE_LINE" >> "$HOME/.profile"
grep -qxF "$PROFILE_LINE" "$HOME/.bashrc"  2>/dev/null || echo "$PROFILE_LINE" >> "$HOME/.bashrc"

# ccache makes repeat builds dramatically cheaper - the whole point of a persistent box
CCACHE_LINE='export PATH=/usr/lib/ccache:$PATH'
grep -qxF "$CCACHE_LINE" "$HOME/.bashrc" 2>/dev/null || echo "$CCACHE_LINE" >> "$HOME/.bashrc"
ccache --max-size=10G >/dev/null

echo "==> verifying"
export PATH="$PATH:$HOME/.rusefi-tools/gcc-arm-none-eabi/bin"
arm-none-eabi-gcc --version | head -1
java -version 2>&1 | head -1
ASUSER

cat <<EOF

==============================================================
 Provisioning done.
==============================================================
Build user : $BUILD_USER
Repo       : $REPO_DIR

Build Amiral:
    su - $BUILD_USER
    cd $REPO_DIR/firmware/config/boards/spark-ems/amiral
    ./compile_amiral.sh

Run unit tests:
    cd $REPO_DIR/unit_tests && ./test.sh
    (the FIRST make in a fresh clone stops with "please run make again" after it
     checks out googletest - that is expected, just run it a second time)

Optional - self-hosted GitHub Actions runner. This is the main reason to have this
box once the repo is private, because Actions minutes are metered there:
    https://github.com/emretunali/spark-ems-amiral/settings/actions/runners/new
    Install it as user '$BUILD_USER', NOT root. Then in the Amiral workflows change
    'runs-on: ubuntu-latest' to 'runs-on: self-hosted'.
    Note: a self-hosted runner executes whatever a workflow says, so only enable it
    for this private repo - never for a public repo that accepts outside PRs.

Optional - run Claude Code here for persistent sessions:
    tmux new -s amiral      # so the session survives your SSH disconnecting
EOF
