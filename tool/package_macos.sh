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
set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(sed -n 's/^version: \([0-9][0-9.]*\)+[0-9][0-9]*$/\1/p' "${ROOT}/pubspec.yaml")"
MONERO_C_VERSION="$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "${ROOT}/tool/fetch_monero_c.sh")"
# CHECKED 5 Oct 2026, source the GitHub API of MrCyjaneK/monero_c: the commit of monero-project/monero that the tag
# v0.18.4.6-RC2 builds. It changes with the version in tool/fetch_monero_c.sh.
MONERO_COMMIT="dbcc7d212c094bd1a45f7291dbb99a4b4627a96d"
APP="${ROOT}/build/macos/Build/Products/Release/Kranox.app"
LIBRARY="${APP}/Contents/Frameworks/libmonero_wallet2_api_c.dylib"
APP_CODE="${APP}/Contents/Frameworks/App.framework/App"
# The relay of a release, the default of AppConfig.bridgeRelay: a build with BRIDGE_RELAY of a relay for development
# carries another address and must not ship (K-10 of the security review of 0.2.0).
RELEASE_RELAY="https://relay.kranox.cash"
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

# Tor built into the app (from 13 Oct 2026): the plugin `tor` of Foundation Devices builds arti and its crates into
# the app as one static library, so the notices name each crate with its license. The plugin lives in the pub cache
# at the commit that pubspec.yaml pins; cargo lists the crates of the two macOS targets alone.
TOR_PLUGIN="$(python3 -c '
import json, sys
for p in json.load(open(sys.argv[1]))["packages"]:
    if p["name"] == "tor":
        print(p["rootUri"].replace("file://", ""))
' "${ROOT}/.dart_tool/package_config.json")"
[ -d "${TOR_PLUGIN}/rust" ] || fail "The plugin tor is missing from the pub cache. Run fvm flutter pub get first."
ARTI_VERSION="$(sed -n 's/^arti = { version = "\([^"]*\)".*/\1/p' "${TOR_PLUGIN}/rust/Cargo.toml")"
[ -n "${ARTI_VERSION}" ] || fail "The Cargo.toml of the plugin tor names no version of arti."
# The crates that the app ships: those reached from the crate of the plugin through its normal dependencies on the
# two macOS targets (not the dependencies of its build or its tests), each with its license and the text of the
# license files in its sources, since the licenses of MIT, BSD, ISC, and the like ask for their text beside a binary.
TOR_CRATES="$(cd "${TOR_PLUGIN}/rust" && cargo metadata --format-version 1 --locked \
  --filter-platform aarch64-apple-darwin --filter-platform x86_64-apple-darwin | python3 -c '
import json, os, sys
data = json.load(sys.stdin)
packages = {p["id"]: p for p in data["packages"]}
nodes = {n["id"]: n for n in data["resolve"]["nodes"]}
root = data["resolve"]["root"]
if root is None:
    sys.exit("the metadata names no root crate")
shipped = set()
stack = [root]
while stack:
    current = stack.pop()
    if current in shipped:
        continue
    shipped.add(current)
    for dep in nodes[current]["deps"]:
        if any(kind.get("kind") is None for kind in dep["dep_kinds"]):
            stack.append(dep["pkg"])
for id in sorted(shipped, key=lambda id: (packages[id]["name"], packages[id]["version"])):
    p = packages[id]
    print("%s %s: %s" % (p["name"], p["version"], p.get("license") or "see its repository"))
    folder = os.path.dirname(p["manifest_path"])
    texts = sorted(f for f in os.listdir(folder) if f.upper().startswith(("LICENSE", "LICENCE", "COPYING")))
    for name in texts:
        path = os.path.join(folder, name)
        if not os.path.isfile(path):
            continue
        print("  ---- %s ----" % name)
        with open(path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                print("  " + line.rstrip())
    if not texts:
        print("  (no license file in the sources of the crate; the license is the one named above)")
    print()
')" || fail "cargo metadata of the plugin tor failed, so the notices would miss the crates of Tor."
[ -n "${TOR_CRATES}" ] || fail "cargo metadata of the plugin tor listed no crate."

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
# The framework of Tor built into the app carries the static library of arti, built for both parts as well.
for binary in "${APP}/Contents/MacOS/Kranox" "${LIBRARY}" "${APP}/Contents/Frameworks/tor.framework/tor"; do
  [ -f "${binary}" ] || fail "${binary} is missing."
  for arch in arm64 x86_64; do
    lipo "${binary}" -verify_arch "${arch}" || fail "${binary} has no ${arch} part."
  done
done
# The build talks to the relay of Kranox and trusts only answers that its key signs.
LC_ALL=C grep -aq "${RELEASE_RELAY}" "${APP_CODE}" ||
  fail "The build talks to another relay than ${RELEASE_RELAY}. Build it without BRIDGE_RELAY."
if grep -Eq 'relaySigningKeys = (const )?\[\];' "${ROOT}/lib/config/app_config.dart"; then
  fail "AppConfig.relaySigningKeys holds no public key of the relay, so the app would trust no answer of it."
fi

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

Tor built into the app: arti ${ARTI_VERSION} and the plugin tor
  The Tor client of the app, arti of the Tor Project, built into the app as a static library through the plugin tor
  of Foundation Devices, with the Rust crates below. Source: https://gitlab.torproject.org/tpo/core/arti and
  https://github.com/Foundation-Devices/tor. arti: the MIT License or the Apache License, version 2.0, both at the
  end. The plugin: the MIT License, at the end. Each crate names its license here, with the license files of its
  sources under it.

${TOR_CRATES}

Flutter, Dart, and the Dart packages of the app
  Their licenses ship inside the app, in
  Kranox.app/Contents/Frameworks/App.framework/Resources/flutter_assets/NOTICES.Z, a file compressed with zlib.

Archivo
  The typeface of the app. License: the SIL Open Font License, version 1.1, below.
EOF
  license "GNU Lesser General Public License, version 3" "${RELEASE}/licenses/monero_c-LGPL-3.0.txt"
  license "GNU General Public License, version 3" "${RELEASE}/licenses/GPL-3.0.txt"
  license "Monero: BSD 3-Clause License" "${RELEASE}/licenses/monero-BSD-3-Clause.txt"
  license "arti: MIT License" "${RELEASE}/licenses/arti-MIT.txt"
  license "arti: Apache License, version 2.0" "${RELEASE}/licenses/arti-Apache-2.0.txt"
  license "The plugin tor: MIT License" "${RELEASE}/licenses/tor-plugin-MIT.txt"
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
