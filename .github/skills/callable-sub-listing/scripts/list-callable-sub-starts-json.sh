#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash list-callable-sub-starts-json.sh [glob] [output-file]
# Examples:
#   bash list-callable-sub-starts-json.sh
#   bash list-callable-sub-starts-json.sh './msgraph-connector/processes/*.p.json'
#   bash list-callable-sub-starts-json.sh './**/*.p.json' docs/callable-sub-starts.json

GLOB_PATTERN="${1:-./**/*.p.json}"
OUTPUT_FILE="${2:-}"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed." >&2
  exit 1
fi

# Build file list from the provided glob using find fallback.
if [[ "$GLOB_PATTERN" == "./**/*.p.json" ]]; then
  mapfile -d '' files < <(find . -type f -name '*.p.json' -print0 | sort -z)
else
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

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

for file in "${files[@]}"; do
  jq -c --arg file "$file" '
    if (.kind // "") != "CALLABLE_SUB" then
      empty
    else
      {
        file: $file,
        starts: [
          .elements[]?
          | select(.type == "CallSubStart")
          | ((.config.signature // .name // "callableSub") as $sig
            | ((.config.input // .config.parameter).params // []) as $in
            | (.config.result.params // []) as $out
            | (if ($out | length) > 0
                then (($out[0].name // "result") + ": " + ($out[0].type // "Object"))
                else "(none)"
               end) as $sigResult
            | {
              id: (.id // null),
              name: (.name // null),
              signature: $sig,
              signatureLabel: ("- **" + $sig + " -> " + $sigResult + "**"),
              tags: (.tags // []),
              input: (
                if .config.input then
                  {
                    params: ((.config.input.params // []) | map({
                      name: (.name // null),
                      type: (.type // null),
                      desc: (.desc // null)
                    }))
                  }
                elif .config.parameter then
                  {
                    params: ((.config.parameter.params // []) | map({
                      name: (.name // null),
                      type: (.type // null),
                      desc: (.desc // null)
                    }))
                  }
                else
                  null
                end
              ),
              result: (
                if .config.result then
                  {
                    params: ((.config.result.params // []) | map({
                      name: (.name // null),
                      type: (.type // null),
                      desc: (.desc // null)
                    }))
                  }
                else
                  null
                end
              )
            })
        ]
      }
    end
  ' "$file" >> "$tmp_file"
done

generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

jq -s --arg generatedAt "$generated_at" --arg glob "$GLOB_PATTERN" '
  {
    generatedAt: $generatedAt,
    glob: $glob,
    processes: .
  }
' "$tmp_file" |
if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  tee "$OUTPUT_FILE"
else
  cat
fi
