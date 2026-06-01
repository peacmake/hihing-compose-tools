#!/usr/bin/env bash
set -euo pipefail

OWNER="peacmake"
REPO="hihing-compose-tools"
BRANCH="${1:-main}"
BASE_URL="https://raw.githubusercontent.com/${OWNER}/${REPO}/${BRANCH}/bin"
INSTALL_DIR="/usr/local/bin"

FILES=(
  docker-compose-up
  docker-compose-down
  docker-compose-logs
  docker-compose-restart
  docker-compose-ps
  hihing-compose-lib
)

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "required command not found: $1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd install

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Installing hihing compose tools into ${INSTALL_DIR}"
echo "Source: ${BASE_URL}"

for file in "${FILES[@]}"; do
  echo "Downloading ${file}..."
  curl -fsSL "${BASE_URL}/${file}" -o "${TMP_DIR}/${file}"
done

for file in docker-compose-up docker-compose-down docker-compose-logs docker-compose-restart docker-compose-ps; do
  install -m 755 "${TMP_DIR}/${file}" "${INSTALL_DIR}/${file}"
done

install -m 644 "${TMP_DIR}/hihing-compose-lib" "${INSTALL_DIR}/hihing-compose-lib"

echo
echo "Installed files:"
ls -l "${INSTALL_DIR}"/docker-compose-* "${INSTALL_DIR}/hihing-compose-lib"
echo
echo "Done."
