#!/usr/bin/env bash
set -euo pipefail

# Prints the release asset that carries the okf binary for a runner. cli_pkg
# names every standalone archive "<name>-<version>-<os>-<arch>.<format>", so
# the asset is version-dependent and cannot be a fixed string in the manifest.

version="${1:?release version is required}"
runner_os="${2:?runner OS is required}"
runner_arch="${3:?runner architecture is required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while IFS=$'\t' read -r candidate_os candidate_arch platform; do
  [[ "$candidate_os" == \#* ]] && continue
  if [[ "$candidate_os" == "$runner_os" && "$candidate_arch" == "$runner_arch" ]]; then
    printf 'okf-%s-%s.tar.gz\n' "${version#v}" "$platform"
    exit 0
  fi
done < "$script_dir/platforms.tsv"

echo "okf: no released binary for $runner_os $runner_arch" >&2
exit 1
