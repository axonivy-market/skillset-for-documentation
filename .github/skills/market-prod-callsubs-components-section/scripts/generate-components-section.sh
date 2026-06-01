#!/usr/bin/env bash
# =============================================================================
# generate-components-section.sh
#
# Regenerate ONLY the ## Components section in README.md (EN) and
# README_DE.md (DE) for an Axon Ivy Maven product module.
#
# Usage:
#   bash generate-components-section.sh <mainModule> <productModule> \
#       [targetReadme] [targetReadmeDe]
#
# Examples:
#   bash .github/skills/generate-ivy-readme-components-section/scripts/generate-components-section.sh \
#       docusign-connector docusign-connector-product
#
#   bash .github/skills/generate-ivy-readme-components-section/scripts/generate-components-section.sh \
#       docusign-connector docusign-connector-product \
#       docusign-connector-product/README.md \
#       docusign-connector-product/README_DE.md
#
# Requirements: jq, bash >= 4
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Arguments
# ---------------------------------------------------------------------------
MAIN_MODULE="${1:?Usage: $0 <mainModule> <productModule> [targetReadme] [targetReadmeDe]}"
PRODUCT_MODULE="${2:?Usage: $0 <mainModule> <productModule> [targetReadme] [targetReadmeDe]}"
TARGET_README="${3:-${PRODUCT_MODULE}/README.md}"
TARGET_README_DE="${4:-${PRODUCT_MODULE}/README_DE.md}"

if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' is required but not found in PATH." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Callable Subprocesses
# ---------------------------------------------------------------------------
build_callable_sub_section() {
  local processes_dir="${MAIN_MODULE}/processes"
  local content=""
  local found=0

  if [[ ! -d "$processes_dir" ]]; then
    echo "- No connector processes delivered by this extension."
    return
  fi

  # Collect all *.p.json files recursively (sorted for determinism)
  while IFS= read -r -d '' pfile; do
    local kind
    kind=$(jq -r '.kind // empty' "$pfile" 2>/dev/null || true)
    [[ "$kind" != "CALLABLE_SUB" ]] && continue

    local start_count
    start_count=$(jq '[.elements[]? | select(.type == "CallSubStart")] | length' "$pfile" 2>/dev/null || echo 0)
    [[ "$start_count" -eq 0 ]] && continue

    found=1
    local fname
    fname=$(basename "$pfile")
    content+="#### ${fname}"$'\n\n'

    # Iterate over each CallSubStart
    while IFS= read -r entry; do
      local sig input_params result_params vis_desc

      sig=$(echo "$entry" | jq -r '.sig // ""')
      vis_desc=$(echo "$entry" | jq -r '.desc // ""')

      # Build signature line: name(Type name, Type name) -> resultVar: ResultType
      local in_list result_list sig_line
      in_list=$(echo "$entry" | jq -r \
        '.inputs | if length == 0 then "" else map(.type + " " + .name) | join(", ") end')
      result_list=$(echo "$entry" | jq -r \
        '.results | if length == 0 then "" else .[0].type + " " + .[0].name else . end // ""' \
        2>/dev/null || echo "")
      # Simpler result string
      local result_sig
      result_sig=$(echo "$entry" | jq -r \
        'if (.results | length) > 0 then " -> " + .results[0].name + ": " + .results[0].type else "" end')

      sig_line="**${sig}(${in_list})${result_sig}**"
      content+="- ${sig_line}"$'\n'

      # Inputs
      local in_block
      in_block=$(echo "$entry" | jq -r \
        '.inputs | if length == 0 then "    - Input: (none)" else "    - Input:\n" + (map("        - `" + .name + "` (" + .type + ")" + if .desc != "" then " - " + .desc else " - (no description available)" end) | join("\n")) end')
      content+="${in_block}"$'\n'

      # Results
      local res_block
      res_block=$(echo "$entry" | jq -r \
        '.results | if length == 0 then "    - Result: (none)" else "    - Result:\n" + (map("        - `" + .name + "` (" + .type + ")" + if .desc != "" then " - " + .desc else " - (no description available)" end) | join("\n")) end')
      content+="${res_block}"$'\n'

      # Optional visual description
      if [[ -n "$vis_desc" ]]; then
        content+="    - Description: ${vis_desc}"$'\n'
      fi

      content+=$'\n'
    done < <(jq -c '
      .elements[]?
      | select(.type == "CallSubStart")
      | {
          sig: (.config.signature // (.name | gsub("\\(.*"; ""))),
          desc: (.visual.description // ""),
          inputs: ((.config.input.params // .config.parameter.params // [])
                   | map({ name: (.name // ""), type: (.type // ""), desc: (.desc // "") })),
          results: ((.config.result.params // [])
                    | map({ name: (.name // ""), type: (.type // ""), desc: (.desc // "") }))
        }
    ' "$pfile" 2>/dev/null)
  done < <(find "${processes_dir}" -type f -name '*.p.json' -print0 | sort -z)

  if [[ $found -eq 0 ]]; then
    echo "- No connector processes delivered by this extension."
  else
    printf '%s' "$content"
  fi
}

# ---------------------------------------------------------------------------
# 2. Dialog Components (main module src_hd only)
# ---------------------------------------------------------------------------
build_dialog_components_section() {
  local src_hd="${MAIN_MODULE}/src_hd"
  local content=""
  local found=0

  if [[ ! -d "$src_hd" ]]; then
    echo "- No form components delivered by this extension."
    return
  fi

  while IFS= read -r -d '' dfile; do
    # Skip demo and test namespaces
    case "$dfile" in
      *demo*|*test*) continue ;;
    esac

    local simple_name namespace fields
    simple_name=$(jq -r '.simpleName // empty' "$dfile" 2>/dev/null || true)
    namespace=$(jq -r '.namespace // empty' "$dfile" 2>/dev/null || true)
    [[ -z "$simple_name" ]] && continue
    found=1

    local dir xhtml comp_type
    dir=$(dirname "$dfile")
    xhtml=$(find "$dir" -maxdepth 1 -type f -name '*.xhtml' | head -n1 || true)

    # Component type is restricted to 3 values only: Component, UI dialog, Form dialog.
    # Priority: Form dialog (*.f.json) > Component (<cc:interface>) > UI dialog (<ui:composition> or fallback)
    if find "$dir" -maxdepth 1 -type f -name '*.f.json' | grep -q .; then
      comp_type="Form dialog"
    elif [[ -n "$xhtml" ]] && grep -qiE '<cc:interface([[:space:]>])' "$xhtml" 2>/dev/null; then
      comp_type="Component"
    else
      comp_type="UI dialog"
    fi

    content+="#### ${simple_name} — Reusable form component"$'\n\n'
    content+="- **Namespace:** ${namespace:-(unknown)}"$'\n'
    content+="- **Component type:** ${comp_type}"$'\n'

    # Fields
    local fields_md
    fields_md=$(jq -r '
      .fields[]?
      | "   - `" + .name + "` (" + .type + ") — (no description available)"
    ' "$dfile" 2>/dev/null || true)

    if [[ -n "$fields_md" ]]; then
      content+="- **Fields:**"$'\n'
      content+="${fields_md}"$'\n'
    else
      content+="- **Fields:** (none declared)"$'\n'
    fi

    content+=$'\n'
  done < <(find "${src_hd}" -type f -name '*.d.json' -print0 | sort -z)

  if [[ $found -eq 0 ]]; then
    echo "- No form components delivered by this extension."
  else
    printf '%s' "$content"
  fi
}

# ---------------------------------------------------------------------------
# 3. Web Services (OpenAPI from rest-clients.yaml)
# ---------------------------------------------------------------------------
build_web_services_section() {
  local rest_clients="${MAIN_MODULE}/config/rest-clients.yaml"
  local content=""

  if [[ ! -f "$rest_clients" ]]; then
    echo "- No information was delivered for this section."
    return
  fi

  # Parse entries from rest-clients.yaml and keep only public OpenAPI SpecUrl (http/https).
  local current_client spec_url namespace
  current_client=""
  spec_url=""
  namespace=""
  local found=0

  flush_openapi_entry() {
    local client="$1"
    local url="$2"
    local ns="$3"
    local cleaned="$url"

    # Trim wrapping quotes if present.
    cleaned="${cleaned#\"}"
    cleaned="${cleaned%\"}"
    cleaned="${cleaned#\'}"
    cleaned="${cleaned%\'}"

    # Only include public URLs.
    if [[ -n "$client" && "$cleaned" =~ ^https?:// ]]; then
      if [[ -n "$ns" ]]; then
        content+="- ![${client}](${cleaned}) (Namespace: ${ns})"$'\n'
      else
        content+="- ![${client}](${cleaned})"$'\n'
      fi
      found=1
    fi
  }

  while IFS= read -r line; do
    # Detect top-level REST client name (2-space indented key under RestClients:)
    if [[ "$line" =~ ^[[:space:]]{2}([A-Za-z][A-Za-z0-9_-]+): ]]; then
      # Flush previous client entry before switching to next client block.
      flush_openapi_entry "$current_client" "$spec_url" "$namespace"
      current_client="${BASH_REMATCH[1]}"
      spec_url=""
      namespace=""
    fi
    if [[ "$line" =~ SpecUrl:[[:space:]]*(.*) ]]; then
      spec_url="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ ^[[:space:]]+Namespace:[[:space:]]*(.*) ]]; then
      namespace="${BASH_REMATCH[1]}"
    fi
  done < "$rest_clients"

  # Flush last client entry
  flush_openapi_entry "$current_client" "$spec_url" "$namespace"

  if [[ $found -eq 0 ]]; then
    echo "- No information was delivered for this section."
  else
    printf '%s' "$content"
  fi
}

# ---------------------------------------------------------------------------
# 4. Maven Artifacts (from product.json)
# ---------------------------------------------------------------------------
build_maven_artifacts_section() {
  local product_json="${PRODUCT_MODULE}/product.json"

  if [[ ! -f "$product_json" ]]; then
    echo "- No information was delivered for this section."
    return
  fi

  # Read pom.xml module order for sorting
  local pom_modules=()
  if [[ -f "pom.xml" ]]; then
    while IFS= read -r mod; do
      pom_modules+=("$mod")
    done < <(grep -o '<module>[^<]*</module>' pom.xml | sed 's/<[^>]*>//g' 2>/dev/null || true)
  fi

  local idx=0
  local content=""

  # Process maven-dependency artifacts first (required), then maven-import (optional)
  local all_artifacts
  all_artifacts=$(jq -c '
    [ .installers[]
      | { id: .id,
          artifacts: (
            if .id == "maven-dependency" then .data.dependencies
            elif .id == "maven-import" then .data.projects
            else [] end
          ),
          optional: (.id == "maven-import")
        }
    ]
    | map(.artifacts[]? + { optional: .optional })
  ' "$product_json" 2>/dev/null || echo "[]")

  # Sort by pom.xml module order
  local sorted_artifacts="[]"
  if [[ ${#pom_modules[@]} -gt 0 ]]; then
    local order_arg
    order_arg=$(printf '%s\n' "${pom_modules[@]}" | jq -R . | jq -s .)
    sorted_artifacts=$(echo "$all_artifacts" | jq --argjson order "$order_arg" '
      . as $arts
      | ($order | to_entries | map({ key: .value, rank: .key }) | from_entries) as $rank
      | $arts | sort_by($rank[.artifactId] // 9999)
    ' 2>/dev/null || echo "$all_artifacts")
  else
    sorted_artifacts="$all_artifacts"
  fi

  while IFS= read -r artifact; do
    idx=$((idx + 1))
    local group_id artifact_id artifact_type optional_flag optional_label
    group_id=$(echo "$artifact" | jq -r '.groupId // ""')
    artifact_id=$(echo "$artifact" | jq -r '.artifactId // ""')
    artifact_type=$(echo "$artifact" | jq -r '.type // "jar"')
    optional_flag=$(echo "$artifact" | jq -r '.optional // false')

    optional_label=""
    if [[ "$optional_flag" == "true" ]]; then
      optional_label=" *(optional)*"
    fi

    content+="${idx}. ${artifact_id}${optional_label}"$'\n\n'
    content+='```xml'$'\n'
    content+="<dependency>"$'\n'
    content+="  <groupId>${group_id}</groupId>"$'\n'
    content+="  <artifactId>${artifact_id}</artifactId>"$'\n'
    content+="  <type>${artifact_type}</type>"$'\n'
    content+="</dependency>"$'\n'
    content+='```'$'\n\n'
  done < <(echo "$sorted_artifacts" | jq -c '.[]?' 2>/dev/null)

  if [[ $idx -eq 0 ]]; then
    echo "- No information was delivered for this section."
  else
    printf '%s' "$content"
  fi
}

# ---------------------------------------------------------------------------
# 5. Assemble English Components block
# ---------------------------------------------------------------------------
assemble_en() {
  local callable web_svc form_comp maven_art
  callable=$(build_callable_sub_section)
  form_comp=$(build_dialog_components_section)
  web_svc=$(build_web_services_section)
  maven_art=$(build_maven_artifacts_section)

  cat <<EOF
## Components

### Callable Subprocesses

${callable}
### Dialog Components

${form_comp}
### Web Services

${web_svc}
### Maven Artifacts

${maven_art}
EOF
}

# ---------------------------------------------------------------------------
# 6. Translate to German
# ---------------------------------------------------------------------------
translate_to_de() {
  # Receives English Components block on stdin; prints German block to stdout.
  # Rules: preserve code fences, inline code, URLs, XML, structural markers.
  # Translate prose, headings, bullet text, descriptions.
  sed \
    -e 's/^## Components$/## Komponenten/' \
    -e 's/^### Callable Subprocesses$/### Aufrufbare Unterprozesse/' \
    -e 's/^### Dialog Components$/### Dialogkomponenten/' \
    -e 's/^### Web Services$/### Web-Services/' \
    -e 's/^### Maven Artifacts$/### Maven-Artefakte/' \
    -e 's/    - Input:$/    - Eingaben:/' \
    -e 's/    - Input: (none)/    - Eingaben: (keine)/' \
    -e 's/    - Result:$/    - Ergebnis:/' \
    -e 's/    - Result: (none)/    - Ergebnis: (keine)/' \
    -e 's/(no description available)/(keine Beschreibung verfügbar)/g' \
    -e 's/- No connector processes delivered by this extension\./- Diese Erweiterung liefert keine Connector-Prozesse./g' \
    -e 's/- No form components delivered by this extension\./- Diese Erweiterung liefert keine Formularkomponenten./g' \
    -e 's/- No information was delivered for this section\./- Es wurden keine Informationen für diesen Abschnitt geliefert./g' \
    -e 's/\*(optional)\*/*(optional)*/g' \
    -e 's/Reusable form component/Wiederverwendbare Formularkomponente/g' \
    -e 's/(inferred purpose)/(abgeleiteter Zweck)/g' \
    -e 's/\*\*Component type:\*\*/**Komponententyp:**/g' \
    -e 's/\*\*Fields:\*\*/**Felder:**/g' \
    -e 's/\*\*Purpose:\*\*/**Zweck:**/g' \
    -e 's/    - Description:/    - Beschreibung:/g'
}

# ---------------------------------------------------------------------------
# 7. Inject section into a README file
#    Replaces existing ## Components block (or ## Komponenten for DE),
#    or appends if not present.
# ---------------------------------------------------------------------------
inject_section() {
  local file="$1"
  local new_block="$2"
  local heading_en="## Components"
  local heading_de="## Komponenten"

  if [[ ! -f "$file" ]]; then
    # File doesn't exist yet — create it
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$new_block" > "$file"
    echo "Created: $file"
    return
  fi

  local tmp
  tmp=$(mktemp)

  # Detect which heading variant is present (EN or DE)
  local target_heading=""
  if grep -qE '^## Components$' "$file" 2>/dev/null; then
    target_heading="$heading_en"
  elif grep -qE '^## Komponenten$' "$file" 2>/dev/null; then
    target_heading="$heading_de"
  fi

  if [[ -z "$target_heading" ]]; then
    # Not present — append with a blank line separator
    { cat "$file"; echo; printf '%s\n' "$new_block"; } > "$tmp"
  else
    # Replace region from heading through end-of-file (or next same-level heading)
    awk -v heading="$target_heading" -v new_block="$new_block" '
      BEGIN { in_section = 0; printed = 0 }
      /^## / {
        if ($0 == heading) {
          in_section = 1
          next
        } else if (in_section) {
          # We hit the next ## heading — stop skipping and print the new block before it
          if (!printed) {
            print new_block
            print ""
            printed = 1
          }
          in_section = 0
          print
          next
        }
      }
      in_section { next }
      { print }
      END {
        if (!printed) {
          print new_block
        }
      }
    ' "$file" > "$tmp"
  fi

  mv "$tmp" "$file"
  echo "Updated: $file"
}

# ---------------------------------------------------------------------------
# 8. Main
# ---------------------------------------------------------------------------
echo "=== generate-components-section ==="
echo "  mainModule    : $MAIN_MODULE"
echo "  productModule : $PRODUCT_MODULE"
echo "  targetReadme  : $TARGET_README"
echo "  targetReadmeDe: $TARGET_README_DE"
echo

# Build English block
echo "Building English Components section..."
en_block=$(assemble_en)

# Build German block
echo "Building German Components section..."
de_block=$(printf '%s\n' "$en_block" | translate_to_de)

# Inject into README.md
inject_section "$TARGET_README" "$en_block"

# Inject into README_DE.md
inject_section "$TARGET_README_DE" "$de_block"

echo
echo "Done."
