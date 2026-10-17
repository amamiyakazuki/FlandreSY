#!/usr/bin/env bash
set -euo pipefail
release_tools_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$release_tools_dir/android_release.py" "$@"
