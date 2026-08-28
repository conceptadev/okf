#!/usr/bin/env bash
set -euo pipefail

output="${CHANGESETS_OUTPUT:?CHANGESETS_OUTPUT is required}"
: > "$output"

dart run tool/ci/sync_release_version.dart --check
version="$(node -p "require('./package.json').version")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "okf: invalid release version $version" >&2
  exit 1
}

tag="v$version"
if git rev-parse --quiet --verify "refs/tags/$tag^{commit}" >/dev/null; then
  echo "okf: $tag already exists; nothing to release"
  exit 0
fi

printf '{"type":"git-tag","tag":"%s","packageName":"okf"}\n' \
  "$tag" >> "$output"
