#!/bin/sh
# Fetches the Monero library of monero_c for macOS, checks it against the digest of its release, and joins
# the arm64 and the x86_64 builds into one universal file at macos/Libraries/. The Xcode build copies that
# file into the app. The app ships the library as a separate file that the user can replace, because
# monero_c has the license LGPL-3.0.
#
# Usage: sh tool/fetch_monero_c.sh
set -eu

VERSION="v0.18.4.6-RC2"
# CHECKED 4 Oct 2026, source the GitHub API of MrCyjaneK/monero_c: the digest of the asset release-bundle.zip.
BUNDLE_SHA256="94ae3d99f878d1e392b9c49d4c5431e4d0b7780c6177081df5369d05e68cea70"
BUNDLE_URL="https://github.com/MrCyjaneK/monero_c/releases/download/${VERSION}/release-bundle.zip"
LIBRARY="libmonero_wallet2_api_c.dylib"
ARCHITECTURES="aarch64-apple-darwin x86_64-apple-darwin"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="${ROOT}/build/native-cache"
BUNDLE="${CACHE}/release-bundle-${VERSION}.zip"
OUT="${ROOT}/macos/Libraries"

mkdir -p "${CACHE}" "${OUT}"

matches_digest() {
  [ -f "$1" ] && [ "$(shasum -a 256 "$1" | cut -d ' ' -f 1)" = "${BUNDLE_SHA256}" ]
}

if matches_digest "${BUNDLE}"; then
  echo "The bundle ${VERSION} is in the cache and matches its digest."
else
  echo "Downloading the bundle ${VERSION}."
  curl --fail --location --output "${BUNDLE}.part" "${BUNDLE_URL}"
  mv "${BUNDLE}.part" "${BUNDLE}"
  if ! matches_digest "${BUNDLE}"; then
    rm -f "${BUNDLE}"
    echo "The bundle does not match the digest ${BUNDLE_SHA256}. Nothing was installed." >&2
    exit 1
  fi
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
SLICES=""
for ARCHITECTURE in ${ARCHITECTURES}; do
  unzip -q -o "${BUNDLE}" "${VERSION}/${ARCHITECTURE}/${LIBRARY}" -d "${WORK}"
  SLICES="${SLICES} ${WORK}/${VERSION}/${ARCHITECTURE}/${LIBRARY}"
done

# shellcheck disable=SC2086
lipo -create ${SLICES} -output "${OUT}/${LIBRARY}"
install_name_tool -id "@rpath/${LIBRARY}" "${OUT}/${LIBRARY}"
echo "Installed ${OUT}/${LIBRARY}: $(lipo -archs "${OUT}/${LIBRARY}")"
