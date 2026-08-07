#!/usr/bin/env bash
# Bootstrap installer for the `val` runner.
#
#   curl -fsSL https://raw.githubusercontent.com/Julian-Dasilva/val-releases/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --version 0.1.5
#
# Downloads the exact signed release assets, then hands them to the release's
# OWN bundled installer, which performs the real verification: detached minisign
# signature over the release manifest, every digest and size binding, and a
# mandatory `val doctor` gate before the selector moves. This script does not
# reimplement any of that — it acquires bytes and delegates.
#
# What this script does NOT give you: authenticated release SELECTION. Without
# --version it asks GitHub for the newest tag over plain HTTPS. That answer is
# not signed, so an origin able to lie about the tag list can steer you to an
# older (validly signed) release. Pass --version to remove that exposure.

set -euo pipefail

REPO="Julian-Dasilva/val-releases"
VERSION=""
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
VAL_HOME_DIR="${VAL_HOME:-$HOME/.val}"
KEEP_TMP=false

die() { printf 'val-install: %s\n' "$1" >&2; exit 1; }
note() { printf 'val-install: %s\n' "$1" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --version)   VERSION="${2:-}"; shift 2 ;;
    --version=*) VERSION="${1#*=}"; shift ;;
    --bin-home)  BIN_HOME="${2:-}"; shift 2 ;;
    --data-home) DATA_HOME="${2:-}"; shift 2 ;;
    --val-home)  VAL_HOME_DIR="${2:-}"; shift 2 ;;
    --keep-tmp)  KEEP_TMP=true; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

# --- preconditions -----------------------------------------------------------
for tool in curl tar zstd python3; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool not found: $tool"
done
python3 -c 'import sys,tomllib' 2>/dev/null ||
  die "python3 >= 3.11 with tomllib is required (found: $(python3 -V 2>&1))"

case "$(uname -s)/$(uname -m)" in
  Darwin/arm64)        TRIPLE="aarch64-apple-darwin" ;;
  Linux/x86_64)        TRIPLE="x86_64-unknown-linux-gnu" ;;
  Darwin/x86_64)       die "macOS x86_64 has no published target; only Apple Silicon (arm64) and Linux x86_64 are released" ;;
  *)                   die "unsupported host $(uname -s)/$(uname -m); released targets are macOS arm64 and Linux x86_64" ;;
esac

# --- resolve version ---------------------------------------------------------
if [ -z "$VERSION" ]; then
  note "no --version given; asking GitHub for the newest release tag (unauthenticated, unsigned answer)"
  VERSION="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))')" ||
    die "could not resolve the newest release; pass --version X.Y.Z"
fi
VERSION="${VERSION#v}"
printf '%s' "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' ||
  die "version must be X.Y.Z (got: $VERSION)"

TAG="v${VERSION}"
BASE="https://github.com/${REPO}/releases/download/${TAG}"
note "installing val ${VERSION} for ${TRIPLE}"

# --- acquire -----------------------------------------------------------------
TMP="$(mktemp -d "${TMPDIR:-/tmp}/val-install-XXXXXX")"
cleanup() { if [ "$KEEP_TMP" = true ]; then note "kept: $TMP"; else rm -rf "$TMP"; fi; }
trap cleanup EXIT

mkdir -p "$TMP/dl"
ASSETS=(
  "val-install-assets-${TAG}.tar.zst"
  "val-release-manifest.v1.json"
  "val-release-manifest.v1.json.minisig"
  "val-release-lock.v1.toml"
  "val-${TAG}-${TRIPLE}.tar.zst"
  "val-${TAG}-${TRIPLE}.tar.zst.witness.json"
)
for f in "${ASSETS[@]}"; do
  curl -fsSL --proto '=https' --tlsv1.2 -o "$TMP/dl/$f" "${BASE}/${f}" ||
    die "download failed: $f — check that ${TAG} exists at ${REPO}"
done

# --- extract the bundle, then delegate to its own installer ------------------
zstd -d -c "$TMP/dl/val-install-assets-${TAG}.tar.zst" | tar -xf - -C "$TMP" ||
  die "could not extract the install bundle"
BUNDLE="$TMP/val-install-assets-${TAG}"
[ -f "$BUNDLE/install-val.sh" ] || die "bundle is missing install-val.sh"
[ -f "$BUNDLE/val-release-lock.toml" ] || die "bundle is missing its release lock"

mkdir -p "$DATA_HOME" "$BIN_HOME" "$VAL_HOME_DIR"

# --source-dir keeps this offline: the bundled installer verifies the bytes we
# already fetched instead of resolving the lock's pinned URLs. Releases at or
# before v0.1.4 pin those URLs to the private source repository, so online
# resolution cannot work for them; this path works for every release.
bash "$BUNDLE/install-val.sh" install \
  --lock       "$BUNDLE/val-release-lock.toml" \
  --source-dir "$TMP/dl" \
  --data-home  "$DATA_HOME" \
  --bin-home   "$BIN_HOME" \
  --val-home   "$VAL_HOME_DIR" \
  --receipt    "$VAL_HOME_DIR/install-receipt-${VERSION}.json"

# --- report ------------------------------------------------------------------
note "installed: ${BIN_HOME}/val"
note "receipt:   ${VAL_HOME_DIR}/install-receipt-${VERSION}.json"
case ":${PATH}:" in
  *":${BIN_HOME}:"*) : ;;
  *) note "NOTE: ${BIN_HOME} is not on your PATH — add it to your shell profile" ;;
esac
VAL_HOME="$VAL_HOME_DIR" "${BIN_HOME}/val" --version
