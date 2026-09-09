#!/usr/bin/env bash
set -euo pipefail

# macOS ships shasum; Linux runners ship sha256sum. Both print "<hash>  <path>".
file="${1:?file is required}"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$file" | cut -d' ' -f1
else
  shasum -a 256 "$file" | cut -d' ' -f1
fi
