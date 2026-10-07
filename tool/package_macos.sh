#!/bin/sh
# Packs the release build of the macOS app into a disk image for a release on GitHub: the app, a link to
# Applications, and the notices of the third-party software inside the app. It checks the build first and writes the
# SHA-256 of the image. With a signing key it signs that list as hashes.txt; without one it writes the list as
# hashes.unsigned.txt only, so that no release can carry an unsigned list under the name that users check.
#
# Usage, in apps/wallet:
#   fvm flutter build macos --release
#   sh tool/package_macos.sh
# To sign the list of hashes, set GNUPGHOME to the keyring of the release key and KRANOX_SIGNING_KEY to the
# fingerprint of that key. The files go to build/release/<version>/.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(sed -n 's/^version: \([0-9][0-9.]*\)+[0-9][0-9]*$/\1/p' "${ROOT}/pubspec.yaml")"
MONERO_C_VERSION="$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "${ROOT}/tool/fetch_monero_c.sh")"
# CHECKED 5 Oct 2026, source the GitHub API of MrCyjaneK/monero_c: the commit of monero-project/monero that the tag
# v0.18.4.6-RC2 builds. It changes with the version in tool/fetch_monero_c.sh.
MONERO_COMMIT="dbcc7d212c094bd1a45f7291dbb99a4b4627a96d"
APP="${ROOT}/build/macos/Build/Products/Release/Kranox.app"
LIBRARY="${APP}/Contents/Frameworks/libmonero_wallet2_api_c.dylib"
RELEASE="${ROOT}/tool/release"
FONT_LICENSE="${ROOT}/assets/fonts/archivo/OFL.txt"
OUT="${ROOT}/build/release/${VERSION}"
STAGE="${OUT}/stage"
IMAGE="Kranox-${VERSION}-macos.dmg"

fail() {
  echo "$1" >&2
  exit 1
}

license() {
  printf '\n\n==== %s ====\n\n' "$1"
  cat "$2"
}

[ -n "${VERSION}" ] || fail "pubspec.yaml holds no version of the form 1.2.3+4."
[ -n "${MONERO_C_VERSION}" ] || fail "tool/fetch_monero_c.sh names no version of monero_c."
[ -d "${APP}" ] || fail "${APP} is missing. Run fvm flutter build macos --release first."

# The build must be of this version, signed as a whole, made for both kinds of Mac, with the hardened runtime, which
# keeps other software from injecting a library through DYLD_INSERT_LIBRARIES, and without the entitlement that lets
# a debugger read the memory of the app.
BUILT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP}/Contents/Info.plist")"
[ "${BUILT}" = "${VERSION}" ] || fail "The build is version ${BUILT}, not ${VERSION}. Build it again."
codesign --verify --deep --strict "${APP}" || fail "The signature of the app does not verify."
if codesign -d --entitlements - --xml "${APP}" 2>/dev/null | grep -q 'get-task-allow'; then
  fail "The app carries the entitlement get-task-allow. Build the release configuration."
fi
codesign -d --verbose=2 "${APP}" 2>&1 | grep -q '^CodeDirectory .*flags=0x[0-9a-f]*(.*runtime' ||
  fail "The app runs without the hardened runtime. Build the release configuration."
for binary in "${APP}/Contents/MacOS/Kranox" "${LIBRARY}"; do
  for arch in arm64 x86_64; do
    lipo "${binary}" -verify_arch "${arch}" || fail "${binary} has no ${arch} part."
  done
done

rm -rf "${OUT}"
mkdir -p "${STAGE}"
ditto "${APP}" "${STAGE}/Kranox.app"
ln -s /Applications "${STAGE}/Applications"
{
  cat <<EOF
Kranox ${VERSION} for macOS: third-party software

Kranox is built on the software below. Each license covers its own part of the app.

monero_c ${MONERO_C_VERSION}
  The Monero library of the app: Kranox.app/Contents/Frameworks/libmonero_wallet2_api_c.dylib.
  Source: https://github.com/MrCyjaneK/monero_c/tree/${MONERO_C_VERSION}
  License: the GNU Lesser General Public License, version 3, with the GNU General Public License, version 3, that
  it builds on. Both texts follow below. The library is a separate file, so you can replace it with your own build.

Monero
  Inside the Monero library. Source: https://github.com/monero-project/monero/tree/${MONERO_COMMIT}
  License: the BSD 3-Clause License, below. The library holds other open-source parts that monero_c builds in as
  well; their licenses come with the source of monero_c.

Flutter, Dart, and the Dart packages of the app
  Their licenses ship inside the app, in
  Kranox.app/Contents/Frameworks/App.framework/Resources/flutter_assets/NOTICES.Z, a file compressed with zlib.

Archivo
  The typeface of the app. License: the SIL Open Font License, version 1.1, below.
EOF
  license "GNU Lesser General Public License, version 3" "${RELEASE}/licenses/monero_c-LGPL-3.0.txt"
  license "GNU General Public License, version 3" "${RELEASE}/licenses/GPL-3.0.txt"
  license "Monero: BSD 3-Clause License" "${RELEASE}/licenses/monero-BSD-3-Clause.txt"
  license "Archivo: SIL Open Font License, version 1.1" "${FONT_LICENSE}"
} > "${STAGE}/THIRD-PARTY-NOTICES.txt"

hdiutil create -quiet -volname "Kranox ${VERSION}" -srcfolder "${STAGE}" -fs HFS+ -format UDZO -ov "${OUT}/${IMAGE}"
rm -rf "${STAGE}"

cd "${OUT}"
rm -f hashes.txt hashes.unsigned.txt kranox-release-key.asc
shasum -a 256 "${IMAGE}" > hashes.unsigned.txt
if [ -n "${KRANOX_SIGNING_KEY:-}" ]; then
  gpg --yes --local-user "${KRANOX_SIGNING_KEY}" --clearsign --output hashes.txt hashes.unsigned.txt
  rm hashes.unsigned.txt
  gpg --verify hashes.txt
  cp "${RELEASE}/kranox-release-key.asc" .
else
  echo "NOT SIGNED: hashes.unsigned.txt is no file to publish. Run again with KRANOX_SIGNING_KEY to sign the list." >&2
fi
echo "Wrote $(ls | tr '\n' ' ')to ${OUT}."
