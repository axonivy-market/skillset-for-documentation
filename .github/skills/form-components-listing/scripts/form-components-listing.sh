#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <directory> [output-file]

Scan an Axon Ivy UI folder tree and list nested UI dialogs and UI components.
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

# Determine module and src_hd root.
# If user passed a module name (e.g. process-analyser) or module path, prefer module/src_hd.
if [[ -d "$ARG/src_hd" ]]; then
  MODULE_DIR=$(realpath -m "$ARG")
  ROOT=$(realpath -m "$ARG/src_hd")
elif [[ -d "$ARG" && $(basename "$ARG") == "src_hd" ]]; then
  ROOT=$(realpath -m "$ARG")
  MODULE_DIR=$(realpath -m "$(dirname "$ARG")")
elif [[ -d "$ARG" ]]; then
  echo "Error: module '$ARG' does not contain src_hd directory" >&2
  exit 2
else
  echo "Error: module or path '$ARG' not found" >&2
  exit 2
fi

# module name for relative paths
MODULE_NAME=$(basename "$MODULE_DIR")

# Ensure ROOT exists
if [[ ! -d "$ROOT" ]]; then
  echo "Error: src_hd directory '$ROOT' not found" >&2
  exit 2
fi

to_module_path() {
  local p
  p=$(realpath -m "$1")
  local rel=${p#"$MODULE_DIR"/}
  if [[ "$rel" == "$p" ]]; then
    echo "$p"
  else
    echo "$MODULE_NAME/$rel"
  fi
}

command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' is required." >&2; exit 3; }

print_entry() {
  local dir=$1 xhtml=$2 is_component=${3:-false}
  local name datafile namespace params pf kind sig ns ns2 simple purpose
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
  kind=""
  sig=""
  if [[ -n $pf ]]; then
    kind=$(jq -r '.kind // empty' "$pf" 2>/dev/null || true)
    [[ -z $namespace ]] && ns2=$(jq -r '.config.data // .namespace // empty' "$pf" 2>/dev/null || true) && [[ -n $ns2 ]] && namespace=$ns2
    sig=$(jq -r '.elements[]? | select(.type=="HtmlDialogStart") | .name // empty' "$pf" 2>/dev/null | head -n1 || true)
  fi

  # Build a one-line purpose hint from the component kind and name
  if [[ $is_component == true ]]; then
    purpose="Reusable UI component"
  else
    purpose="UI dialog"
  fi

  echo
  echo "#### ${name} — ${purpose}"
  echo
  echo "- **Namespace:** ${namespace:-(unknown)}"
  echo "- **Component type:** ${kind:-HTML_DIALOG}"
  if [[ -n $params ]]; then
    echo "- **Fields:**"
    echo "$params"
  else
    echo "- **Fields:** (none declared)"
  fi
  if [[ -n $pf ]]; then
    if [[ -n $sig ]]; then
      echo "- **Where used:** Dialog with start method '${sig}' — process: $(to_module_path "$pf")"
    else
      echo "- **Where used:** $(to_module_path "$pf")"
    fi
  fi
}

# temporary buffers
dlg_tmp=$(mktemp)
comp_tmp=$(mktemp)
out_tmp=$(mktemp)

# Collect xhtml files, splitting dialogs vs component dialogs; exclude webContent
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
    echo "$dir|$xhtml" >> "$comp_tmp"
  else
    echo "$dir|$xhtml" >> "$dlg_tmp"
  fi
done < <(find "$ROOT" -type f -name '*.xhtml' -print0)

{
  echo "# Axon Ivy UI Scan"
  echo
  echo "Scanned path: $ROOT"
  echo
  echo "#### dialogs"

  sort -u "$dlg_tmp" | while IFS='|' read -r dir xhtml; do
    print_entry "$dir" "$xhtml" false
  done

  echo
  echo "#### components"

  sort -u "$comp_tmp" | while IFS='|' read -r dir xhtml; do
    print_entry "$dir" "$xhtml" true
  done

  # Print p.json component files anywhere (exclude webContent)
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
      echo "- Component file: $(to_module_path "$pf")"
      [[ -n $type_field ]] && echo "  - type: $type_field"
      name=$(jq -r '.name // .id // empty' "$pf" 2>/dev/null || true)
      [[ -n $name ]] && echo "  - name: $name"
      desc=$(jq -r '.description // empty' "$pf" 2>/dev/null || true)
      [[ -n $desc ]] && echo "  - description: $desc"
    fi
  done < <(find "$ROOT" -type f -name '*.p.json' -print0)

  echo
  echo "---"
  echo "Scan complete."
} > "$out_tmp"

rm -f "$dlg_tmp" "$comp_tmp"

if [ -z "$OUTPUT_FILE" ]; then
  cat "$out_tmp"
else
  mv "$out_tmp" "$OUTPUT_FILE"
  echo "✓ Form components written to: $OUTPUT_FILE"
fi
rm -f "$out_tmp" 2>/dev/null || true
