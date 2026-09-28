#!/bin/bash

set -u

usage() {
  cat <<'EOF'
Usage: convert_subs.sh [SOURCE_ENCODING]

Convert every .srt and .sub file in the current directory to UTF-8.
SOURCE_ENCODING defaults to WINDOWS-1255. Each original is saved as FILE.bak.
Files that are already valid UTF-8 are skipped.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

source_encoding="${1:-WINDOWS-1255}"
converted=0
skipped=0
failed=0
temp_file=""

cleanup() {
  if [ -n "$temp_file" ] && [ -e "$temp_file" ]; then
    rm -f "$temp_file"
  fi
}

trap cleanup EXIT
trap 'exit 130' HUP INT TERM

while IFS= read -r -d '' file; do
  if iconv -f UTF-8 -t UTF-8 "$file" >/dev/null 2>&1; then
    printf 'Skipping already UTF-8: %s\n' "$file"
    skipped=$((skipped + 1))
    continue
  fi

  backup="${file}.bak"
  if [ -e "$backup" ]; then
    printf 'Error: backup already exists, not changing %s\n' "$file" >&2
    failed=$((failed + 1))
    continue
  fi

  temp_file=$(mktemp "${TMPDIR:-/tmp}/convert_subs.XXXXXX") || exit 1
  if ! iconv -f "$source_encoding" -t UTF-8 "$file" >"$temp_file"; then
    printf 'Error: could not convert %s from %s\n' "$file" "$source_encoding" >&2
    rm -f "$temp_file"
    temp_file=""
    failed=$((failed + 1))
    continue
  fi

  if ! cp -p "$file" "$backup"; then
    printf 'Error: could not create backup %s\n' "$backup" >&2
    rm -f "$temp_file"
    temp_file=""
    failed=$((failed + 1))
    continue
  fi

  mode=$(stat -f '%Lp' "$file")
  if ! chmod "$mode" "$temp_file" || ! mv -f "$temp_file" "$file"; then
    printf 'Error: could not replace %s; original is in %s\n' "$file" "$backup" >&2
    rm -f "$temp_file"
    temp_file=""
    failed=$((failed + 1))
    continue
  fi

  temp_file=""
  printf 'Converted: %s (backup: %s)\n' "$file" "$backup"
  converted=$((converted + 1))
done < <(find . -maxdepth 1 -type f ! -name '._*' \
  \( -iname '*.srt' -o -iname '*.sub' \) -print0)

printf '\nDone: %d converted, %d skipped, %d failed.\n' "$converted" "$skipped" "$failed"

if [ "$failed" -gt 0 ]; then
  exit 1
fi
