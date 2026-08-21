#!/usr/bin/env bash
set -euo pipefail

workspace="${1:?workspace is required}"
if git -C "$workspace" rev-parse --verify HEAD >/dev/null 2>&1; then
  printf 'false\n'
elif [[ -z "$(find "$workspace" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  printf 'true\n'
else
  echo "okf: refusing to replace a nonempty workspace without a Git checkout" >&2
  exit 1
fi
