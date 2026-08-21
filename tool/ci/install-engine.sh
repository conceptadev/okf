#!/usr/bin/env bash
set -euo pipefail

version="${1:?engine version is required}"
runner_os="${2:?runner OS is required}"
runner_arch="${3:?runner architecture is required}"
destination="${4:?destination is required}"
if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "okf: engine version must be a complete v-prefixed release tag" >&2
  exit 2
fi
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
asset="$(bash "$script_dir/platform-asset.sh" "$runner_os" "$runner_arch")"

curl --fail --silent --show-error --location --retry 3 \
  --output "$destination" \
  "https://github.com/conceptadev/okf/releases/download/$version/$asset"
gh release verify-asset "$version" "$destination" \
  --repo conceptadev/okf >/dev/null
chmod +x "$destination"
printf '%s\n' "$destination"
