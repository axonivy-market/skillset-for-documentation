#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <directory> [output-file]

Scan Axon Ivy src_hd trees and list form components.
Outputs Markdown. If output-file is omitted, prints to stdout.

Requires: jq
EOF
}

if [[ ${1:-} == "" ]]; then
  usage
  exit 1
fi

ARG=$1
OUTPUT_FILE="${2:-}"

ROOTS=()

# Resolve roots:
# 1) module path containing src_hd
# 2) explicit src_hd path
# 3) parent path containing one or more modules with src_hd
if [[ -d "$ARG/src_hd" ]]; then
  ROOTS+=("$(realpath -m "$ARG/src_hd")")
elif [[ -d "$ARG" && $(basename "$ARG") == "src_hd" ]]; then
  ROOTS+=("$(realpath -m "$ARG")")
elif [[ -d "$ARG" ]]; then
  while IFS= read -r -d '' root; do
    ROOTS+=("$(realpath -m "$root")")
  done < <(find "$ARG" -mindepth 2 -maxdepth 2 -type d -name src_hd -print0)
  if [[ ${#ROOTS[@]} -eq 0 ]]; then
    echo "Error: no src_hd directories found under '$ARG'" >&2
    exit 2
  fi
else
  echo "Error: module or path '$ARG' not found" >&2
  exit 2
fi

to_module_path() {
  local module_dir=$1
  local p=$2
  local module_name
  module_name=$(basename "$module_dir")
  p=$(realpath -m "$p")
  local rel=${p#"$module_dir"/}
  if [[ "$rel" == "$p" ]]; then
    echo "$p"
  else
    echo "$module_name/$rel"
  fi
}

command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' is required." >&2; exit 3; }

print_entry() {
  local module_dir=$1 dir=$2 xhtml=$3 pfile=$4
  local name namespace ns2 purpose comp_type proc_params
  name="$(basename "$dir")"
  namespace=""
  purpose=""
  if [[ -n $pfile ]]; then
    ns2=$(jq -r '.config.data // .namespace // empty' "$pfile" 2>/dev/null || true) || true
    [[ -n $ns2 ]] && namespace=$ns2
  fi

  # Component type is restricted to 3 values only: Component dialog, UI dialog, Form dialog.
  # Priority: Form dialog (*.f.json) > Component (<cc:interface>) > UI dialog (<ui:composition> or fallback)
  if find "$dir" -maxdepth 1 -type f -name '*.f.json' | grep -q .; then
    comp_type="Form dialog"
  elif grep -qiE '<cc:interface([[:space:]>])' "$xhtml" 2>/dev/null; then
    comp_type="Component dialog"
  else
    comp_type="UI dialog"
  fi

  # Build a one-line purpose hint from visible UI headline first, then fall back.
  purpose=$(awk 'match($0, /<h[1-6][^>]*>([^<]+)<\/h[1-6]>/, m) { print m[1]; exit }' "$xhtml" 2>/dev/null || true)
  [[ -z "$purpose" ]] && purpose="(not documented in source)"

  echo
  echo "#### ${name}"
  echo
  echo "- **Namespace:** ${namespace:-(unknown)}"
  echo "- **Component type:** ${comp_type}"
  # Prefer Fields from process start signature (HtmlDialogStart) when available
  if [[ -n $pfile ]]; then
    # extract params from start signature
    proc_params=$(jq -r '
      .elements[]?
      | select(.type == "HtmlDialogStart" or .type == "HtmlDialogMethodStart" or .type == "HtmlDialogStart")
      | select(.config.signature == "start")
      | .config.input.params[]?
      | ((.desc // "") | gsub("^\\s+|\\s+$"; "")) as $d
      | "   - `" + .name + "` (" + .type + ")"
        + (if ($d != "" and $d != "-" and $d != "--" and $d != "—" and ($d | ascii_downcase) != "n/a")
           then " — " + $d
           else ""
           end)' "$pfile" 2>/dev/null || true)
    if [[ -n $proc_params ]]; then
      echo "- **Fields:**"
      echo "$proc_params"
    else
      echo "- **Fields:** - (none)"
    fi
  else
    echo "- **Fields:** - (none)"
  fi

  echo "- **Purpose:** ${purpose}"
}

# temporary buffers
comp_tmp=$(mktemp)
out_tmp=$(mktemp)

# Collect dialog/component directories from all roots; exclude webContent.
# Performance: scan unique candidate directories once, then resolve metadata per directory.
for ROOT in "${ROOTS[@]}"; do
  MODULE_DIR=$(realpath -m "$(dirname "$ROOT")")

  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue

    # Choose the first xhtml file in directory as representative.
    xhtml=$(find "$dir" -maxdepth 1 -type f -name '*.xhtml' | head -n1 || true)
    [[ -z "$xhtml" ]] && continue

    pf=$(find "$dir" -maxdepth 1 -type f \( -name '*Process.p.json' -o -name '*.p.json' \) | head -n1 || true)
    ff=$(find "$dir" -maxdepth 1 -type f -name '*.f.json' | head -n1 || true)
    if [[ -n "$pf" || -n "$ff" ]]; then
      echo "$MODULE_DIR|$dir|$xhtml|$pf" >> "$comp_tmp"
    fi
  done < <(
    find "$ROOT" -type f -name '*.xhtml' -print |
      grep -Ev '/web[Cc]ontent/' |
      sed 's|/[^/]*$||' |
      sort -u
  )
done

{
  found_any=false
  sort -u "$comp_tmp" | while IFS='|' read -r module_dir dir xhtml pf; do
    found_any=true
    print_entry "$module_dir" "$dir" "$xhtml" "$pf"
  done

  if [[ ! -s "$comp_tmp" ]]; then
    echo "- No form components delivered by this extension."
  fi
} > "$out_tmp"

rm -f "$comp_tmp"

if [ -z "$OUTPUT_FILE" ]; then
  cat "$out_tmp"
else
  mv "$out_tmp" "$OUTPUT_FILE"
  echo "✓ Form components written to: $OUTPUT_FILE"
fi
rm -f "$out_tmp" 2>/dev/null || true
