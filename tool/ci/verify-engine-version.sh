#!/usr/bin/env bash
set -euo pipefail

binary="${1:?binary is required}"
tag="${2:?release tag is required}"
actual="$("$binary" --version)"
expected="okf ${tag#v}"

if [[ "$actual" != "$expected" ]]; then
  echo "okf: $tag builds $actual; expected $expected" >&2
  exit 1
fi
