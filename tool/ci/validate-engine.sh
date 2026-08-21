#!/usr/bin/env bash
set -euo pipefail

okf="${1:?okf binary is required}"
bundle="${2:?bundle path is required}"
strict="${3:?strict setting is required}"
arguments=(validate "$bundle")

case "$strict" in
  true) arguments+=(--strict) ;;
  false) ;;
  *)
    echo "okf: strict must be true or false" >&2
    exit 2
    ;;
esac

exec "$okf" "${arguments[@]}"
