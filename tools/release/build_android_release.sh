#!/usr/bin/env bash
# GAL REVIEW REQUIRED BEFORE NEXT MODULE
# See the latest pending-review-request-*.md in P_PLAN/reviews/ and current-review-thread.md

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  tools/release/build_android_release.sh [--validate-only]

What it does:
  1. Verifies pubspec.yaml version and public/version.json version stay aligned
  2. Verifies android/key.properties and the referenced keystore exist
  3. Builds Android release artifacts:
     - split-per-abi APKs
     - AAB bundle
  4. Prints artifact paths and sha256 checksums

Notes:
  - Expects to be run from anywhere inside the repo
  - Requires a real android/key.properties before running
EOF
}

validate_only=false
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi
if [[ "${1:-}" == "--validate-only" ]]; then
  validate_only=true
elif [[ $# -gt 0 ]]; then
  echo "Unknown argument: $1" >&2
  usage
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

pubspec_version="$(sed -n 's/^version: //p' pubspec.yaml | head -n1)"
marketing_version="${pubspec_version%%+*}"
manifest_version="$(sed -n 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/p' public/version.json | head -n1)"

if [[ -z "$pubspec_version" || -z "$manifest_version" ]]; then
  echo "Failed to read version metadata from pubspec.yaml or public/version.json" >&2
  exit 1
fi

if [[ "$marketing_version" != "$manifest_version" ]]; then
  echo "Version mismatch: pubspec marketing version is '$marketing_version' but public/version.json is '$manifest_version'" >&2
  exit 1
fi

key_properties="android/key.properties"
if [[ ! -f "$key_properties" ]]; then
  echo "Missing $key_properties" >&2
  echo "Copy android/key.properties.example to android/key.properties and fill in your real signing values." >&2
  exit 1
fi

read_property() {
  local key="$1"
  sed -n "s/^${key}=//p" "$key_properties" | head -n1
}

store_file_raw="$(read_property storeFile)"
store_password="$(read_property storePassword)"
key_password="$(read_property keyPassword)"
key_alias="$(read_property keyAlias)"

if [[ -z "$store_file_raw" || -z "$store_password" || -z "$key_password" || -z "$key_alias" ]]; then
  echo "android/key.properties is incomplete. Expected storeFile/storePassword/keyPassword/keyAlias." >&2
  exit 1
fi

if [[ "$store_file_raw" = /* ]]; then
  store_file="$store_file_raw"
else
  store_file="$repo_root/android/$store_file_raw"
fi

if [[ ! -f "$store_file" ]]; then
  echo "Keystore not found: $store_file" >&2
  exit 1
fi

echo "Release metadata looks good:"
echo "  pubspec version: $pubspec_version"
echo "  marketing version: $marketing_version"
echo "  manifest version: $manifest_version"
echo "  key alias: $key_alias"
echo "  keystore: $store_file"

if [[ "$validate_only" == true ]]; then
  echo "Validation-only mode complete."
  exit 0
fi

flutter clean
flutter pub get
flutter build apk --release --split-per-abi
flutter build appbundle --release

echo
echo "Artifacts:"
find build/app/outputs/flutter-apk -maxdepth 1 -type f \( -name 'app-*-release.apk' -o -name 'app-release.apk' \) | sort
find build/app/outputs/bundle/release -maxdepth 1 -type f -name '*.aab' | sort

if command -v sha256sum >/dev/null 2>&1; then
  echo
  echo "SHA256:"
  find build/app/outputs/flutter-apk -maxdepth 1 -type f \( -name 'app-*-release.apk' -o -name 'app-release.apk' \) | sort | while read -r file; do
    sha256sum "$file"
  done
  find build/app/outputs/bundle/release -maxdepth 1 -type f -name '*.aab' | sort | while read -r file; do
    sha256sum "$file"
  done
fi
