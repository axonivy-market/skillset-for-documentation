#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash list-callable-sub-starts.sh [glob] [output-file]
# Examples:
#   bash list-callable-sub-starts.sh
#   bash list-callable-sub-starts.sh './msgraph-connector/processes/*.p.json'
#   bash list-callable-sub-starts.sh './**/*.p.json' docs/callable-sub-starts.md

GLOB_PATTERN="${1:-./**/*.p.json}"
OUTPUT_FILE="${2:-}"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed." >&2
  exit 1
fi

# Build file list from the provided glob using find fallback.
# Supports simple usage where caller provides either './**/*.p.json' or a direct path prefix.
if [[ "$GLOB_PATTERN" == "./**/*.p.json" ]]; then
  mapfile -d '' files < <(find . -type f -name '*.p.json' -print0 | sort -z)
else
  # Use shell glob expansion when a custom glob/path is passed.
  shopt -s globstar nullglob
  expanded=( $GLOB_PATTERN )
  shopt -u globstar nullglob
  files=()
  for f in "${expanded[@]:-}"; do
    if [[ -f "$f" && "$f" == *.p.json ]]; then
      files+=("$f")
    fi
  done
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No process files matched: $GLOB_PATTERN" >&2
  exit 1
fi

# Render report to stdout first, then optionally write to file.
{

  callable_count=0

  for file in "${files[@]}"; do
    kind=$(jq -r '.kind // empty' "$file")
    if [[ "$kind" != "CALLABLE_SUB" ]]; then
      continue
    fi

    # Count all CallSubStart elements (not tag-filtered per SKILL.md).
    start_count=$(jq '[.elements[]? | select(.type == "CallSubStart")] | length' "$file")

    # If no CallSubStart entries in this file, skip printing the file header.
    if [[ "$start_count" -eq 0 ]]; then
      continue
    fi

    # Count only files that contain at least one matching CallSubStart.
    callable_count=$((callable_count + 1))

    echo "#### $(basename "$file")"

    jq -r '
      .elements[]?
      | select(.type == "CallSubStart")
      | (
          (.config.signature // .name // "") as $sigName
          | ((.config.input.params // .config.parameter.params // [])
            | map((.type // "") + " " + (.name // ""))
            | map(gsub("^ +| +$"; ""))
            | join(", ")) as $inputSig
          | ((.config.result.params // [])
            | map((.name // "") + ": " + (.type // ""))
            | map(gsub("^ +| +$"; ""))
            | join(", ")) as $resultSig
          | "- **Signature**: "
            + $sigName
            + "("
            + $inputSig
            + ")"
            + (if $resultSig == "" then " -> (none)" else " -> " + $resultSig end)
            + "\n"
        )
      + "  Input: "
      + (if (.config.input // .config.parameter) then
         ((((.config.input // .config.parameter).params // [])
            | map((.name // "") + ": " + (.type // ""))
            | join(", "))
          | if . == "" then "none" else . end)
        else "none" end) + "\n"
      + "  Result: "
      + (if .config.result then
          (((.config.result.params // [])
            | map((.name // "") + ": " + (.type // ""))
            | join(", "))
          | if . == "" then "none" else . end)
        else "none" end)
      + "\n"
    ' "$file"

    echo
  done

  if [[ "$callable_count" -eq 0 ]]; then
    echo "No CALLABLE_SUB process files found."
  fi
} | if [[ -n "$OUTPUT_FILE" ]]; then
      mkdir -p "$(dirname "$OUTPUT_FILE")"
      tee "$OUTPUT_FILE"
    else
      cat
    fi
