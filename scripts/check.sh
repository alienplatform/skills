#!/usr/bin/env bash
# Checks every skill against the Agent Skills spec basics and this repo's rules.
# Usage: scripts/check.sh [--links]   (--links also fetches every alien.dev docs URL)
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

for dir in skills/*/; do
  name=$(basename "$dir")
  file="$dir/SKILL.md"
  [ -f "$file" ] || { echo "missing $file"; fail=1; continue; }

  fm_name=$(awk '/^---$/{n++; next} n==1 && /^name:/{print $2; exit}' "$file")
  [ "$fm_name" = "$name" ] || { echo "$file: name '$fm_name' does not match directory '$name'"; fail=1; }
  echo "$name" | grep -Eq '^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$' || { echo "$file: invalid name"; fail=1; }

  desc=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); print; exit}' "$file")
  [ -n "$desc" ] || { echo "$file: missing description"; fail=1; }
  [ "${#desc}" -le 1024 ] || { echo "$file: description is ${#desc} chars (max 1024)"; fail=1; }

  lines=$(wc -l < "$file")
  [ "$lines" -le 300 ] || { echo "$file: $lines lines (keep under 300)"; fail=1; }

  for ref in $(grep -oE 'references/[a-z0-9-]+\.md' "$file" | sort -u); do
    [ -f "$dir/$ref" ] || { echo "$file: broken reference $ref"; fail=1; }
  done
done

# Words and characters this repo does not use.
if grep -rnE '—' skills README.md AGENTS.md; then echo "em dash found"; fail=1; fi

if [ "${1:-}" = "--links" ]; then
  for url in $(grep -rhoE 'https://alien\.dev/docs/[a-z0-9/_-]+\.md' skills README.md | sort -u); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "$url")
    [ "$code" = "200" ] || { echo "$code $url"; fail=1; }
  done
fi

[ "$fail" = 0 ] && echo "ok"
exit "$fail"
