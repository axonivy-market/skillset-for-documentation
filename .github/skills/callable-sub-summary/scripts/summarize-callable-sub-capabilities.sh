#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash summarize-callable-sub-capabilities.sh [glob] [output-file]
# Examples:
#   bash summarize-callable-sub-capabilities.sh
#   bash summarize-callable-sub-capabilities.sh './**/*.p.json'
#   bash summarize-callable-sub-capabilities.sh './**/*.p.json' docs/callable-sub-capabilities-summary.txt

GLOB_PATTERN="${1:-./**/*.p.json}"
OUTPUT_FILE="${2:-}"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed." >&2
  exit 1
fi

json_tmp="$(mktemp)"
summary_tmp="$(mktemp)"
trap 'rm -f "$json_tmp" "$summary_tmp"' EXIT

bash ./.github/skills/msgraph-callable-sub-listing/scripts/list-callable-sub-starts-json.sh "$GLOB_PATTERN" "$json_tmp" >/dev/null

jq -r '
  def cap: if length == 0 then . else (.[0:1] | ascii_upcase) + .[1:] end;
  def domain($f):
    ($f | split("/") | last | sub("\\.p\\.json$"; "") | sub("^ms"; "") | ascii_downcase);

  . as $root
  | ($root.processes // []) as $procs
  | ($procs | length) as $processCount
  | ([ $procs[] | .starts // [] | length ] | add // 0) as $startCount
  | ([ $procs[] | select((.starts // [] | length) > 0) | domain(.file) ] | unique) as $domains
  | ([ $procs[] | .starts[]? | .signature | select(. != null and . != "") ] | unique) as $signatures
  | ([ $procs[] | .starts[]? | select((.input | type) == "object" and ((.input.params // []) | length > 0)) ] | length) as $withInput
  | ([ $procs[] | .starts[]? ] | length) as $totalStarts
  | ([ $procs[] | .starts[]? | select((.result | type) == "object" and ((.result.params // []) | length > 0)) ] | length) as $withResult
  | ($totalStarts - $withInput) as $withoutInput
  | ($totalStarts - $withResult) as $withoutResult
  | "Connector callable sub capabilities were detected in \($processCount) process files, with \($startCount) connector start entries in total.",
    (if ($domains | length) > 0
      then "Covered domains include " + (($domains | map(cap)) | join(", ")) + "."
      else "No connector domains were detected."
     end),
    (if ($signatures | length) > 0
      then "Representative operations are " + ($signatures | join(", ")) + "."
      else "No callable signatures were detected."
     end),
    "Input parameters are defined on \($withInput) starts, while \($withoutInput) starts expose no typed input params.",
    "Result parameters are defined on \($withResult) starts, while \($withoutResult) starts expose no typed result params.",
    "This summary is derived from connector-tagged CallSubStart elements only."
' "$json_tmp" > "$summary_tmp"

if [[ -n "$OUTPUT_FILE" ]]; then
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  cat "$summary_tmp" | tee "$OUTPUT_FILE"
else
  cat "$summary_tmp"
fi
