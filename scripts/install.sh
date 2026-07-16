#!/bin/bash
#
# KiroMeter installer — downloads the latest release, installs it to
# /Applications, removes the Gatekeeper quarantine flag, and launches it.
#
# Usage (one-liner):
#   curl -fsSL https://raw.githubusercontent.com/mvn-bachhuynh-dn/kiro-meter/main/scripts/install.sh | bash
#
# Or download and run:
#   bash install.sh
#
set -euo pipefail

REPO="mvn-bachhuynh-dn/kiro-meter"
APP_NAME="KiroMeter.app"
ASSET="KiroMeter-macOS.zip"
INSTALL_DIR="/Applications"

info()  { printf '\033[0;34m▶\033[0m %s\n' "$1"; }
ok()    { printf '\033[0;32m✅\033[0m %s\n' "$1"; }
err()   { printf '\033[0;31m❌\033[0m %s\n' "$1" >&2; }

# --- Preconditions ---------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
  err "KiroMeter only runs on macOS."
  exit 1
fi

for tool in curl unzip; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    err "Required tool '$tool' is not installed."
    exit 1
  fi
done

# --- Resolve the latest release asset URL ----------------------------------
info "Looking up the latest KiroMeter release…"
DOWNLOAD_URL=$(
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep -o "https://github.com/${REPO}/releases/download/[^\"']*${ASSET}" \
    | head -1
)

if [[ -z "${DOWNLOAD_URL}" ]]; then
  err "Could not find ${ASSET} in the latest release."
  err "Check https://github.com/${REPO}/releases"
  exit 1
fi

# --- Download & unpack ------------------------------------------------------
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

info "Downloading ${ASSET}…"
curl -fSL --progress-bar "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ASSET}"

info "Unpacking…"
unzip -q "${TMP_DIR}/${ASSET}" -d "${TMP_DIR}"

if [[ ! -d "${TMP_DIR}/${APP_NAME}" ]]; then
  err "${APP_NAME} was not found inside the archive."
  exit 1
fi

# --- Quit a running instance -----------------------------------------------
if pgrep -x "KiroMeter" >/dev/null 2>&1; then
  info "Quitting the running KiroMeter instance…"
  osascript -e 'quit app "KiroMeter"' >/dev/null 2>&1 || pkill -x "KiroMeter" || true
  sleep 1
fi

# --- Install (with sudo fallback if /Applications isn't writable) ----------
SUDO=""
if [[ ! -w "${INSTALL_DIR}" ]]; then
  info "Administrator rights are required to write to ${INSTALL_DIR}."
  SUDO="sudo"
fi

info "Installing to ${INSTALL_DIR}/${APP_NAME}…"
${SUDO} rm -rf "${INSTALL_DIR:?}/${APP_NAME}"
${SUDO} mv "${TMP_DIR}/${APP_NAME}" "${INSTALL_DIR}/"

# --- Remove quarantine so Gatekeeper won't block the unsigned app ----------
info "Removing the download quarantine flag…"
${SUDO} xattr -cr "${INSTALL_DIR}/${APP_NAME}"

# --- Launch -----------------------------------------------------------------
info "Launching KiroMeter…"
open "${INSTALL_DIR}/${APP_NAME}"

ok "KiroMeter installed! Look for the usage percentage in your menu bar."
echo
echo "Prerequisite: make sure Kiro CLI is installed and you're logged in:"
echo "  kiro-cli login"
