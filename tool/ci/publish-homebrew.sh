#!/usr/bin/env bash
set -euo pipefail

# Commits the rendered formula to the Homebrew tap. Reruns are safe: an
# unchanged formula is a no-op, so a replayed release does not create an empty
# commit or fail the job.

tag="${1:?release tag is required}"
distribution="${2:?distribution directory is required}"
tap="${HOMEBREW_TAP_REPO:?HOMEBREW_TAP_REPO must be set}"
token="${HOMEBREW_TAP_TOKEN:?HOMEBREW_TAP_TOKEN must be set}"
# Overridable so the push path can be exercised against a local repository.
remote="${HOMEBREW_TAP_REMOTE:-https://github.com/$tap.git}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
version="${tag#v}"

formula="$(bash "$script_dir/homebrew-formula.sh" "$tag" "$distribution")"

checkout="$(mktemp -d)"
trap 'rm -rf "$checkout"' EXIT

# The token stays in the credential header rather than the remote URL so it is
# not written to .git/config or echoed by git's progress output.
auth="$(printf 'x-access-token:%s' "$token" | base64 | tr -d '\n')"
git -c "http.https://github.com/.extraheader=Authorization: Basic $auth" \
  clone --depth 1 "$remote" "$checkout"

mkdir -p "$checkout/Formula"
printf '%s\n' "$formula" > "$checkout/Formula/okf.rb"

cd "$checkout"
git add Formula/okf.rb
# Compare against the index rather than the work tree: on the first release the
# formula is a new file, which "git diff" alone reports as no change.
if git diff --cached --quiet -- Formula/okf.rb; then
  echo "okf: tap already carries the $tag formula"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git commit -m "okf $version"
git -c "http.https://github.com/.extraheader=Authorization: Basic $auth" \
  push origin HEAD
