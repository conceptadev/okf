#!/usr/bin/env bash
set -euo pipefail

# Renders the Homebrew formula for a published okf release. Supported platforms
# come from platforms.tsv, so the tap covers exactly the assets the release
# actually carries.

tag="${1:?release tag is required}"
distribution="${2:?distribution directory is required}"
repository="${GH_REPO:?GH_REPO must be set}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# brew audit enforces this block order, so drive the output from it rather than
# from the row order in platforms.tsv.
declare -a ordering=(
  'macOS:ARM64:on_macos:on_arm'
  'macOS:X64:on_macos:on_intel'
  'Linux:ARM64:on_linux:on_arm'
  'Linux:X64:on_linux:on_intel'
)

# Collect the declared platforms so unsupported rows fail loudly instead of
# being silently dropped from the formula.
declare -a rows=()
while IFS=$'\t' read -r runner_os runner_arch _ asset; do
  [[ "$runner_os" == \#* ]] && continue
  [[ -n "$runner_os" ]] || continue
  matched=0
  for entry in "${ordering[@]}"; do
    IFS=: read -r entry_os entry_arch _ _ <<< "$entry"
    if [[ "$entry_os" == "$runner_os" && "$entry_arch" == "$runner_arch" ]]; then
      matched=1
      break
    fi
  done
  if (( matched == 0 )); then
    echo "okf: no Homebrew predicate for $runner_os $runner_arch" >&2
    exit 1
  fi
  rows+=("$runner_os:$runner_arch:$asset")
done < "$script_dir/platforms.tsv"

if (( ${#rows[@]} == 0 )); then
  echo "okf: platforms.tsv declares no release assets" >&2
  exit 1
fi

# Homebrew derives the class name from the file name; okf.rb is Okf. The
# version is scanned from the tag in each download URL, so declaring it here
# would be redundant.
cat <<HEADER
class Okf < Formula
  desc "Format-first toolkit for Open Knowledge Format bundles"
  homepage "https://github.com/$repository"
  license "Apache-2.0"
HEADER

previous_os=''
for entry in "${ordering[@]}"; do
  IFS=: read -r entry_os entry_arch os_predicate arch_predicate <<< "$entry"
  for row in "${rows[@]}"; do
    IFS=: read -r row_os row_arch asset <<< "$row"
    [[ "$row_os" == "$entry_os" && "$row_arch" == "$entry_arch" ]] || continue

    path="$distribution/$asset"
    [[ -f "$path" ]] || {
      echo "okf: missing release asset $path" >&2
      exit 1
    }
    sha256="$(bash "$script_dir/sha256.sh" "$path")"

    if [[ "$entry_os" != "$previous_os" ]]; then
      [[ -n "$previous_os" ]] && printf '  end\n'
      printf '\n  %s do\n' "$os_predicate"
      previous_os="$entry_os"
    fi
    cat <<PLATFORM
    $arch_predicate do
      url "https://github.com/$repository/releases/download/$tag/$asset"
      sha256 "$sha256"
    end
PLATFORM
  done
done
printf '  end\n'

cat <<'FOOTER'

  def install
    # Release assets are bare executables named for their platform; Homebrew
    # downloads them without extracting, so install the one file as "okf".
    bin.install Dir["okf-*"].fetch(0) => "okf"
  end

  test do
    assert_match "okf #{version}", shell_output("#{bin}/okf --version")
  end
end
FOOTER
