#!/usr/bin/env bash
set -euo pipefail

tag="${1:?release tag is required}"
distribution="${2:?distribution directory is required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
assets=()

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

# The immutable-releases settings endpoint is not readable with the
# workflow's GITHUB_TOKEN (403), so immutability is verified on the
# published release itself — the outcome the guard actually cares about.
if [[ "$(gh api "repos/$GH_REPO/releases/tags/$tag" --jq .immutable)" != true ]]; then
  echo "okf: release $tag was published mutable; enable immutable releases" \
    "for $GH_REPO and republish" >&2
  exit 1
fi
