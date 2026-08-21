#!/usr/bin/env bash
set -euo pipefail

tag="${1:?release tag is required}"
distribution="${2:?distribution directory is required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
assets=()

if [[ "$(gh api "repos/$GH_REPO/immutable-releases" --jq .enabled)" != true ]]; then
  echo "okf: immutable releases must be enabled before publishing $tag" >&2
  exit 1
fi

while IFS=$'\t' read -r runner_os _ _ asset; do
  [[ "$runner_os" == \#* ]] && continue
  path="$distribution/$asset"
  [[ -f "$path" ]] || {
    echo "okf: missing release asset $path" >&2
    exit 1
  }
  assets+=("$path")
done < "$script_dir/platforms.tsv"

if draft_state="$(gh release view "$tag" --json isDraft --jq .isDraft 2>/dev/null)"; then
  if [[ "$draft_state" != true ]]; then
    echo "okf: release $tag is already public; refusing to mutate it" >&2
    exit 1
  fi
  gh release upload "$tag" "${assets[@]}" --clobber
else
  gh release create "$tag" "${assets[@]}" \
    --verify-tag --generate-notes --draft
fi
gh release edit "$tag" --draft=false
