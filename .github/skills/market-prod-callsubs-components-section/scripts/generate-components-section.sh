#!/usr/bin/env bash
# =============================================================================
# generate-components-section.sh
#
# Regenerate ONLY the ## Components section in README.md (EN) and
# README_DE.md (DE) for an Axon Ivy Maven product module.

usage() {
  cat <<EOF
Usage: $0 [MAIN_MODULE] [PRODUCT_MODULE] [TARGET_README] [TARGET_README_DE]
If MAIN_MODULE or PRODUCT_MODULE are omitted they are discovered from root pom.xml.
EOF
}

# CLI args (positional)
ARG_MAIN_MODULE="${1:-}"
ARG_PRODUCT_MODULE="${2:-}"
ARG_TARGET_README="${3:-}"
ARG_TARGET_README_DE="${4:-}"

discover_modules() {
  local pom="pom.xml"
  local modules=()

  if [[ -f "$pom" ]]; then
    # Extract <module>...</module> entries
    while IFS= read -r mod; do
      mod=$(echo "$mod" | sed -e 's/<\/?module>//g' -e 's/^[[:space:]]*//;s/[[:space:]]*$//')
      [[ -n "$mod" ]] && modules+=("$mod")
    done < <(grep -o '<module>[^<]*</module>' "$pom" 2>/dev/null || true)
  fi

  # Fallback: use directories at repo root when no modules found
  if [[ ${#modules[@]} -eq 0 ]]; then
    while IFS= read -r d; do
      d=$(basename "$d")
      modules+=("$d")
    done < <(find . -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort)
  fi

  # Determine MAIN_MODULE: first module that is not *-product, *-demo or *-test
  MAIN_MODULE=""
  if [[ -n "$ARG_MAIN_MODULE" ]]; then
    MAIN_MODULE="$ARG_MAIN_MODULE"
  else
    for m in "${modules[@]}"; do
      if [[ "$m" =~ -product$ || "$m" =~ -demo$ || "$m" =~ -test$ ]]; then
        continue
      fi
      MAIN_MODULE="$m"
      break
    done
    if [[ -z "$MAIN_MODULE" && ${#modules[@]} -gt 0 ]]; then
      MAIN_MODULE="${modules[0]}"
    fi
  fi

  # Determine PRODUCT_MODULE: prefer module ending with -product
  if [[ -n "$ARG_PRODUCT_MODULE" ]]; then
    PRODUCT_MODULE="$ARG_PRODUCT_MODULE"
  else
    PRODUCT_MODULE=""
    for m in "${modules[@]}"; do
      if [[ "$m" =~ -product$ ]] && [[ -d "$m" ]]; then
        PRODUCT_MODULE="$m"
        break
      fi
    done
    # fallback: main-product directory
    if [[ -z "$PRODUCT_MODULE" && -n "$MAIN_MODULE" && -d "${MAIN_MODULE}-product" ]]; then
      PRODUCT_MODULE="${MAIN_MODULE}-product"
    fi
    # final fallback: first module
    if [[ -z "$PRODUCT_MODULE" && ${#modules[@]} -gt 0 ]]; then
      PRODUCT_MODULE="${modules[0]}"
    fi
  fi
}

discover_modules

# Derive target readme paths
TARGET_README="${ARG_TARGET_README:-${PRODUCT_MODULE}/README.md}"
TARGET_README_DE="${ARG_TARGET_README_DE:-${PRODUCT_MODULE}/README_DE.md}"

if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' is required but not found in PATH." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# YAML / CMS helpers
# ---------------------------------------------------------------------------
parse_yaml_flat() {
  # Simple YAML flattener: prints lines as "dotted.key<TAB>value" for scalar values.
  # Works for simple project CMS YAML files with nested mappings.
  local file="$1"
  awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    /^[ \t]*#/ { next }
    /^[ \t]*$/ { next }
    {
      line = $0
      gsub(/\t/, "  ", line)
      match(line, /^[ \t]*/)
      indent = RLENGTH
      level = int(indent / 2)
      idx = index(line, ":")
      if (idx == 0) next
      key = substr(line, indent + 1, idx - indent - 1)
      value = substr(line, idx + 1)
      key = trim(key)
      value = trim(value)
      path[level] = key
      for (i = level + 1; i < 100; i++) delete path[i]
      if (value != "") {
        dotted = path[0]
        for (i = 1; i <= level; i++) {
          if (path[i] != "") {
            if (dotted == "") dotted = path[i]
            else dotted = dotted "." path[i]
          }
        }
        if (dotted == "") dotted = key
        print dotted "\t" value
      }
    }
  ' "$file"
}

build_cms_maps() {
  CMS_EN_MAP=""
  CMS_DE_MAP=""
  CMS_EN_MAP=$(mktemp)
  CMS_DE_MAP=$(mktemp)

  local en_candidates=(
    "${MAIN_MODULE}/cms/cms_en.yaml"
    "${MAIN_MODULE}/cms_en.yaml"
    "${PRODUCT_MODULE}/cms/cms_en.yaml"
    "${PRODUCT_MODULE}/cms_en.yaml"
    "cms/cms_en.yaml"
    "cms_en.yaml"
  )

  for f in "${en_candidates[@]}"; do
    if [[ -f "$f" ]]; then
      parse_yaml_flat "$f" >> "$CMS_EN_MAP"
    fi
  done

  local de_candidates=(
    "${PRODUCT_MODULE}/cms/cms_de.yaml"
    "${PRODUCT_MODULE}/cms_de.yaml"
    "${MAIN_MODULE}/cms/cms_de.yaml"
    "${MAIN_MODULE}/cms_de.yaml"
    "cms/cms_de.yaml"
    "cms_de.yaml"
  )
  for f in "${de_candidates[@]}"; do
    if [[ -f "$f" ]]; then
      parse_yaml_flat "$f" >> "$CMS_DE_MAP"
    fi
  done

  # Deduplicate by key, keep first occurrence
  if [[ -f "$CMS_EN_MAP" ]]; then
    awk -F"\t" '!seen[$1]++ { print }' "$CMS_EN_MAP" > "${CMS_EN_MAP}.uniq" && mv "${CMS_EN_MAP}.uniq" "$CMS_EN_MAP"
  fi
  if [[ -f "$CMS_DE_MAP" ]]; then
    awk -F"\t" '!seen[$1]++ { print }' "$CMS_DE_MAP" > "${CMS_DE_MAP}.uniq" && mv "${CMS_DE_MAP}.uniq" "$CMS_DE_MAP"
  fi
}

apply_cms_de_translations() {
  # Read stdin, replace occurrences of English CMS strings with German counterparts
  # based on the flattened CMS maps. This performs simple literal substitutions.
  local infile
  infile=$(mktemp)
  cat - > "$infile"
  if [[ ! -f "$CMS_EN_MAP" || ! -f "$CMS_DE_MAP" ]]; then
    cat "$infile"
    rm -f "$infile"
    return
  fi

  # For each key present in both maps, replace the English value with German value.
  while IFS=$'\t' read -r key enval; do
    # find german counterpart
    deval=$(awk -F"\t" -v k="$key" '$1==k{print $2; exit}' "$CMS_DE_MAP" 2>/dev/null || true)
    if [[ -n "$deval" && -n "$enval" ]]; then
      # escape for sed
      en_esc=$(printf '%s' "$enval" | sed -e 's/[\/&]/\\&/g')
      de_esc=$(printf '%s' "$deval" | sed -e 's/[\/&]/\\&/g')
      sed -i "s/$en_esc/$de_esc/g" "$infile" 2>/dev/null || true
    fi
  done < "$CMS_EN_MAP"

  cat "$infile"
  rm -f "$infile"
}

# ---------------------------------------------------------------------------
# 1. Callable Subprocesses
# ---------------------------------------------------------------------------
build_callable_sub_section() {
  local processes_dir="${MAIN_MODULE}/processes"
  local content=""
  local found=0
  # global counters
  CALLABLE_FILES=0
  CALLABLE_TOTAL_STARTS=0
  CALLABLE_RENDERED=0
  CALLABLE_STATUS="MISSING"

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
    CALLABLE_TOTAL_STARTS=$((CALLABLE_TOTAL_STARTS + start_count))
    CALLABLE_FILES=$((CALLABLE_FILES + 1))

    found=1
    local fname
    fname=$(basename "$pfile")
    content+="#### ${fname}"$'\n\n'
    # Iterate over each CallSubStart
    local file_rendered=0
    while IFS= read -r entry; do
      CALLABLE_RENDERED=$((CALLABLE_RENDERED + 1))
      file_rendered=$((file_rendered + 1))
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

      sig_line="${sig}(${in_list})${result_sig}"
      content+="- **Signature**: ${sig_line}"$'\n'

      # Inputs
      local in_block
      in_block=$(echo "$entry" | jq -r \
        '.inputs | if length == 0 then "    - Input: (none)" else "    - Input:\n" + (map("        - `" + .name + "` (" + .type + ")" + (if (.desc // "") != "" then " - " + .desc else "" end)) | join("\n")) end')
      content+="${in_block}"$'\n'

      # Results
      local res_block
      res_block=$(echo "$entry" | jq -r \
        '.results | if length == 0 then "    - Result: (none)" else "    - Result:\n" + (map("        - `" + .name + "` (" + .type + ")" + (if (.desc // "") != "" then " - " + .desc else "" end)) | join("\n")) end')
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
    # If some CallSubStart elements were detected but not rendered, append placeholders
    if [[ $file_rendered -lt $start_count ]]; then
      local missing=$((start_count - file_rendered))
      for ((i=0;i<missing;i++)); do
        content+="- Callable sub detected but full parameter mapping could not be resolved from source."$'\n\n'
      done
    fi
  done < <(find "${processes_dir}" -type f -name '*.p.json' -print0 | sort -z)

  if [[ $CALLABLE_RENDERED -eq 0 ]]; then
    CALLABLE_STATUS="MISSING"
    echo "- No connector processes delivered by this extension."
  else
    if [[ $CALLABLE_RENDERED -lt $CALLABLE_TOTAL_STARTS ]]; then
      CALLABLE_STATUS="PARTIAL"
    else
      CALLABLE_STATUS="OK"
    fi
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
  FORM_COMPONENT_COUNT=0
  FORM_STATUS="MISSING"

  if [[ ! -d "$src_hd" ]]; then
    echo "- No form components delivered by this extension."
    return
  fi

  while IFS= read -r -d '' pfile; do
    # Skip demo and test namespaces
    case "$pfile" in
      *demo*|*test*) continue ;;
    esac

    local dir simple_name namespace
    dir=$(dirname "$pfile")
    simple_name=$(basename "$pfile")
    simple_name="${simple_name%Process.p.json}"
    namespace=$(echo "${dir#${src_hd}/}" | tr '/' '.')
    [[ -z "$simple_name" ]] && continue

    # Only include dialog processes that expose start signature
    local has_start
    has_start=$(jq -r '[.elements[]? | select((.config.signature // "") == "start")] | length' "$pfile" 2>/dev/null || echo 0)
    [[ "$has_start" -eq 0 ]] && continue

    found=1
    FORM_COMPONENT_COUNT=$((FORM_COMPONENT_COUNT + 1))

    local xhtml comp_type
    xhtml=$(find "$dir" -maxdepth 1 -type f -name '*.xhtml' | head -n1 || true)

    # Component type is restricted to 3 values only: Component dialog, UI dialog, Form dialog.
    # Priority: Form dialog (*.f.json) > Component (<cc:interface>) > UI dialog (<ui:composition> or fallback)
    if find "$dir" -maxdepth 1 -type f -name '*.f.json' | grep -q .; then
      comp_type="Form dialog"
    elif [[ -n "$xhtml" ]] && grep -qiE '<cc:interface([[:space:]>])' "$xhtml" 2>/dev/null; then
      comp_type="Component dialog"
    else
      comp_type="UI dialog"
    fi

    local purpose_line="(not documented in source)"
    content+="#### ${simple_name}"$'\n\n'
    content+="- **Namespace:** ${namespace:-(unknown)}"$'\n'
    content+="- **Component type:** ${comp_type}"$'\n'

    # Fields from process start signature (preferred source): use config.input.params of the start signature
    local fields_md
    fields_md=$(jq -r '
      [
        .elements[]?
        | select((.config.signature // "") == "start")
        | .config.input.params[]?
      ]
      | map("    - `" + (.name // "") + "` (" + (.type // "") + ")" + (if ((.desc // "") != "") then " — " + .desc else "" end))
      | join("\n")
    ' "$pfile" 2>/dev/null || true)

    # Emit Fields in fixed section shape.
    if [[ -n "$fields_md" ]]; then
      content+="- **Fields:**"$'\n'
      content+="${fields_md}"$'\n'
    else
      content+="- **Fields:** - (none)"$'\n'
    fi

    # Enrich with CMS description when available
    if [[ -f "$CMS_EN_MAP" ]]; then
      desc=$(awk -F"\t" -v s="$simple_name" '{ n=split($1,a,"."); if (a[n]==s) {print $2; exit} }' "$CMS_EN_MAP" 2>/dev/null || true)
      if [[ -z "$desc" && -n "$namespace" ]]; then
        desc=$(awk -F"\t" -v ns="$namespace" -v s="$simple_name" '{ if (index($1, ns) && index($1, s)) {print $2; exit} }' "$CMS_EN_MAP" 2>/dev/null || true)
      fi
      if [[ -n "$desc" ]]; then
        purpose_line="$desc"
      fi
    fi

    content+="- **Purpose:** ${purpose_line}"$'\n'

    content+=$'\n'
  done < <(find "${src_hd}" -type f -name '*Process.p.json' -print0 | sort -z)

  if [[ $FORM_COMPONENT_COUNT -eq 0 ]]; then
    FORM_STATUS="MISSING"
    echo "- No form components delivered by this extension."
  else
    FORM_STATUS="OK"
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
    WEB_ENTRIES=0
    WEB_STATUS="MISSING"
    echo "- No information was delivered for this section."
    return
  fi

  # Parse entries from rest-clients.yaml and keep only public OpenAPI.SpecUrl (http/https).
  local spec_url
  spec_url=""
  local found=0

  while IFS= read -r line; do
    if [[ "$line" =~ SpecUrl:[[:space:]]*(.*) ]]; then
      spec_url="${BASH_REMATCH[1]}"
      # Trim wrapping quotes if present.
      spec_url="${spec_url#\"}"
      spec_url="${spec_url%\"}"
      spec_url="${spec_url#\'}"
      spec_url="${spec_url%\'}"

      # Render URL only.
      if [[ "$spec_url" =~ ^https?:// ]]; then
        content+="- ${spec_url}"$'\n'
        found=$((found + 1))
      fi
    fi
  done < "$rest_clients"

  if [[ $found -eq 0 ]]; then
    WEB_ENTRIES=0
    WEB_STATUS="MISSING"
    echo "- No information was delivered for this section."
  else
    WEB_ENTRIES=$found
    WEB_STATUS="OK"
    printf '%s' "$content"
  fi
}

# ---------------------------------------------------------------------------
# 4. Maven Artifacts (from product.json)
# ---------------------------------------------------------------------------
build_maven_artifacts_section() {
  local product_json="${PRODUCT_MODULE}/product.json"

  if [[ ! -f "$product_json" ]]; then
    MAVEN_ARTIFACTS=0
    MAVEN_STATUS="MISSING"
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
    [
      .installers[]?
      | if .id == "maven-dependency" then
          (.data.dependencies[]? | . + { optional: false })
        elif .id == "maven-import" then
          (.data.projects[]? | . + { optional: ((.importInWorkspace // true) == false) })
        else
          empty
        end
      | select((.artifactId // "") | test("test$") | not)
    ]
  ' "$product_json" 2>/dev/null || echo "[]")

  # Sort by pom.xml module order
  local sorted_artifacts="[]"
  if [[ ${#pom_modules[@]} -gt 0 ]]; then
    local order_arg
    order_arg=$(printf '%s\n' "${pom_modules[@]}" | jq -R . | jq -s .)
    sorted_artifacts=$(echo "$all_artifacts" | jq --argjson order "$order_arg" '
      def rank($order; $artifactId):
        ($order | index($artifactId)) // 9999;
      sort_by(rank($order; .artifactId))
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
    MAVEN_ARTIFACTS=0
    MAVEN_STATUS="MISSING"
    echo "- No information was delivered for this section."
  else
    MAVEN_ARTIFACTS=$idx
    MAVEN_STATUS="OK"
    printf '%s' "$content"
  fi
}

# ---------------------------------------------------------------------------
# 5. Assemble English Components block
# ---------------------------------------------------------------------------
assemble_en() {
  local callable web_svc form_comp maven_art
  local callable_file form_file web_file maven_file

  callable_file=$(mktemp)
  form_file=$(mktemp)
  web_file=$(mktemp)
  maven_file=$(mktemp)

  build_callable_sub_section > "$callable_file"
  build_dialog_components_section > "$form_file"
  build_web_services_section > "$web_file"
  build_maven_artifacts_section > "$maven_file"

  callable=$(cat "$callable_file")
  form_comp=$(cat "$form_file")
  web_svc=$(cat "$web_file")
  maven_art=$(cat "$maven_file")

  rm -f "$callable_file" "$form_file" "$web_file" "$maven_file"

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
    -e 's/^- \*\*Signature:\*\*/- **Signatur:**/g' \
    -e 's/    - Input:$/    - Eingaben:/' \
    -e 's/    - Input: (none)/    - Eingaben: (keine)/' \
    -e 's/    - Result:$/    - Ergebnis:/' \
    -e 's/    - Result: (none)/    - Ergebnis: (keine)/' \
    -e 's/(no description available)/(keine Beschreibung verfügbar)/g' \
    -e 's/- No connector processes delivered by this extension\./- Diese Erweiterung liefert keine Connector-Prozesse./g' \
    -e 's/- No form components delivered by this extension\./- Diese Erweiterung liefert keine Formularkomponenten./g' \
    -e 's/- No information was delivered for this section\./- Es wurden keine Informationen für diesen Abschnitt geliefert./g' \
    -e 's/\*(optional)\*/*(optional)*/g' \
    -e 's/(inferred purpose)/(abgeleiteter Zweck)/g' \
    -e 's/\*\*Component type:\*\*/**Komponententyp:**/g' \
    -e 's/\*\*Fields:\*\*/**Felder:**/g' \
    -e 's/- \*\*Felder:\*\* - (none)/- **Felder:** - (keine)/g' \
    -e 's/- \*\*Fields:\*\* - (none)/- **Felder:** - (keine)/g' \
    -e 's/- \*\*Felder:\*\* - (none declared)/- **Felder:** - (keine)/g' \
    -e 's/- \*\*Fields:\*\* - (none declared)/- **Felder:** - (keine)/g' \
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

# Prepare CMS maps (for descriptions and DE substitutions)
echo "Preparing CMS maps..."
build_cms_maps

# Build English block
echo "Building English Components section..."
en_block_file=$(mktemp)
assemble_en > "$en_block_file"
en_block=$(cat "$en_block_file")
rm -f "$en_block_file"

# Build German block
echo "Building German Components section..."
# First apply CMS-provided German translations where available, then run general translation
de_block=$(printf '%s\n' "$en_block" | apply_cms_de_translations | translate_to_de)

# Inject into README.md
inject_section "$TARGET_README" "$en_block"

# Inject into README_DE.md
inject_section "$TARGET_README_DE" "$de_block"

echo
# Cleanup CMS temp files
rm -f "${CMS_EN_MAP:-}" "${CMS_DE_MAP:-}" 2>/dev/null || true
# ---------------------------------------------------------------------------
# 9. Report summary (per SKILL Step 7)
# ---------------------------------------------------------------------------

status_label() {
  case "$1" in
    OK|"OK") echo "OK" ;;
    PARTIAL|"PARTIAL") echo "PARTIAL" ;;
    MISSING|"MISSING") echo "MISSING" ;;
    *) echo "UNKNOWN" ;;
  esac
}

callable_label=$(status_label "$CALLABLE_STATUS")
form_label=$(status_label "$FORM_STATUS")
web_label=$(status_label "$WEB_STATUS")
maven_label=$(status_label "$MAVEN_STATUS")

printf '[%s]  %-22s — %s\n' "$callable_label" "callableSubSection" "${CALLABLE_RENDERED:-0} callable subs from ${CALLABLE_FILES:-0} files"
printf '[%s]  %-22s — %s\n' "$form_label" "formComponentSection" "${FORM_COMPONENT_COUNT:-0} components"
printf '[%s]  %-22s — %s\n' "$web_label" "openApiSection" "${WEB_ENTRIES:-0} entries"
printf '[%s]  %-22s — %s\n' "$maven_label" "mavenArtifactSection" "${MAVEN_ARTIFACTS:-0} artifacts"

echo "Written: ${TARGET_README}   (## Components section updated)"
echo "Written: ${TARGET_README_DE} (## Komponenten section updated)"

echo "Done."
