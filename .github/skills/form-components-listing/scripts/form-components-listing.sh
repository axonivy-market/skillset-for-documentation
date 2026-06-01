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
  local module_dir=$1 dir=$2 xhtml=$3
  local name datafile namespace params pf ns ns2 simple purpose comp_type
  name="$(basename "$dir")"
  datafile=$(ls -1 "$dir"/*.d.json 2>/dev/null | head -n1 || true)
  namespace=""
  params=""
  purpose=""
  if [[ -n $datafile ]]; then
    ns=$(jq -r '.namespace // empty' "$datafile" 2>/dev/null || true)
    [[ -n $ns ]] && namespace=$ns
    simple=$(jq -r '.simpleName // empty' "$datafile" 2>/dev/null || true)
    [[ -n $simple ]] && name=$simple
    params=$(jq -r '.fields[]? | "   - `" + .name + "` (" + .type + ")"' "$datafile" 2>/dev/null || true)
  fi
  pf=$(find "$dir" -maxdepth 1 -type f -name '*.p.json' | head -n1 || true)
  if [[ -n $pf ]]; then
    [[ -z $namespace ]] && ns2=$(jq -r '.config.data // .namespace // empty' "$pf" 2>/dev/null || true) && [[ -n $ns2 ]] && namespace=$ns2
  fi

  # Component type is restricted to 3 values only: Component, UI dialog, Form dialog.
  # Priority: Form dialog (*.f.json) > Component (<cc:interface>) > UI dialog (<ui:composition> or fallback)
  if find "$dir" -maxdepth 1 -type f -name '*.f.json' | grep -q .; then
    comp_type="Form dialog"
  elif grep -qiE '<cc:interface([[:space:]>])' "$xhtml" 2>/dev/null; then
    comp_type="Component"
  else
    comp_type="UI dialog"
  fi

  # Build a one-line purpose hint
  purpose="Reusable form component"

  echo
  echo "#### ${name} — ${purpose}"
  echo
  echo "- **Namespace:** ${namespace:-(unknown)}"
  echo "- **Component type:** ${comp_type}"
  if [[ -n $params ]]; then
    echo "- **Fields:**"
    echo "$params"
  else
    echo "- **Fields:** (none declared)"
  fi
}

# temporary buffers
comp_tmp=$(mktemp)
out_tmp=$(mktemp)

# Collect only form components from all roots; exclude webContent
for ROOT in "${ROOTS[@]}"; do
  MODULE_DIR=$(realpath -m "$(dirname "$ROOT")")

  while IFS= read -r -d '' xhtml; do
    case "$xhtml" in
      *[/]webContent/*|*[/]webcontent/*)
        continue
        ;;
    esac

    dir=$(dirname "$xhtml")
    is_component=false
    if grep -qiE 'componentType\s*=\s*"IvyComponent"' "$xhtml" 2>/dev/null; then
      is_component=true
    else
      for df in "$dir"/*.d.json; do
        [[ -f $df ]] || continue
        ns=$(jq -r '.namespace // empty' "$df" 2>/dev/null || true)
        if [[ -n $ns ]] && echo "$ns" | grep -q '\.component\.'; then
          is_component=true
          break
        fi
      done
      if [[ $is_component == false ]]; then
        while IFS= read -r -d '' pf; do
          pns=$(jq -r '.config.data // .namespace // empty' "$pf" 2>/dev/null || true)
          if [[ -n $pns ]] && echo "$pns" | grep -q '\.component\.'; then
            is_component=true
            break
          fi
        done < <(find "$dir" -maxdepth 1 -type f -name '*.p.json' -print0)
      fi
    fi

    if [[ $is_component == true ]]; then
      echo "$MODULE_DIR|$dir|$xhtml" >> "$comp_tmp"
    fi
  done < <(find "$ROOT" -type f -name '*.xhtml' -print0)
done

{
  echo "# Axon Ivy Form Components Scan"
  echo
  echo "Scanned src_hd roots:"
  for ROOT in "${ROOTS[@]}"; do
    echo "- $ROOT"
  done
  echo
  echo "#### form components"

  sort -u "$comp_tmp" | while IFS='|' read -r module_dir dir xhtml; do
    print_entry "$module_dir" "$dir" "$xhtml"
  done

  # Print p.json component files anywhere (exclude webContent)
  for ROOT in "${ROOTS[@]}"; do
    MODULE_DIR=$(realpath -m "$(dirname "$ROOT")")
    while IFS= read -r -d '' pf; do
      case "$pf" in
        *[/]webContent/*|*[/]webcontent/*)
          continue
          ;;
      esac
      type_field=$(jq -r '.type // empty' "$pf" 2>/dev/null || true)
      in_component_dir=false
      case "$pf" in
        */component/*|*/components/*) in_component_dir=true ;;
      esac

      if [[ $in_component_dir == true ]] || echo "$type_field" | grep -qi component; then
        echo
        echo "- Component file: $(to_module_path "$MODULE_DIR" "$pf")"
        [[ -n $type_field ]] && echo "  - type: $type_field"
        name=$(jq -r '.name // .id // empty' "$pf" 2>/dev/null || true)
        [[ -n $name ]] && echo "  - name: $name"
        desc=$(jq -r '.description // empty' "$pf" 2>/dev/null || true)
        [[ -n $desc ]] && echo "  - description: $desc"
      fi
    done < <(find "$ROOT" -type f -name '*.p.json' -print0)
  done

  echo
  echo "---"
  echo "Scan complete."
} > "$out_tmp"

rm -f "$comp_tmp"

if [ -z "$OUTPUT_FILE" ]; then
  cat "$out_tmp"
else
  mv "$out_tmp" "$OUTPUT_FILE"
  echo "✓ Form components written to: $OUTPUT_FILE"
fi
rm -f "$out_tmp" 2>/dev/null || true
