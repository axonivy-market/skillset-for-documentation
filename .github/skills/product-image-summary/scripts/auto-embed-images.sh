#!/usr/bin/env bash
set -euo pipefail

# auto-embed-images.sh
# Generic script to infer image placements and embed image snippets into
# <product-module>/README.md near matching demo workflow headings.
# Usage: ./auto-embed-images.sh [product-module-dir] [demo-module-dir]

PRODUCT=${1:?Usage: auto-embed-images.sh <product-module-dir> [demo-module-dir]}
DEMO=${2:-}
if [[ -z "$DEMO" && "$PRODUCT" == *-product ]]; then
  DEMO="${PRODUCT%-product}-demo"
fi

if [[ -d "$PRODUCT" ]]; then
  PRODUCT_DIR="$PRODUCT"
else
  PRODUCT_DIR="$PWD/$PRODUCT"
fi

if [[ -n "$DEMO" && -d "$DEMO" ]]; then
  DEMO_DIR="$DEMO"
else
  DEMO_DIR="$PWD/$DEMO"
fi

IMAGES_DIR="${PRODUCT_DIR}/images"
README="${PRODUCT_DIR}/README.md"

STOPWORDS_REGEX='\\b(img|image|screenshot|example|demo|sample|screen|shot|step|result|validation)\\b'

if [[ ! -f "$README" ]]; then
  echo "README not found: $README" >&2
  exit 1
fi

if [[ ! -d "$IMAGES_DIR" ]]; then
  echo "Images dir not found: $IMAGES_DIR" >&2
  exit 1
fi

# Normalize string for comparison
normalize() {
  # Lowercase, remove non-alphanum, collapse spaces
  local s="$*"
  s=$(echo "$s" | tr '[:upper:]' '[:lower:]')
  s=$(echo "$s" | sed -E 's/[^a-z0-9]+/ /g')
  s=$(echo "$s" | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^ //; s/ $//')
  printf "%s" "$s"
}

# Extract word tokens from text.
tokens_from_text() {
  local text="$1"
  text=$(echo "$text" | sed -E 's/([a-z0-9])([A-Z])/\1 \2/g')
  text=$(normalize "$text")
  if [[ -z "$text" ]]; then
    printf ""
    return
  fi
  echo "$text" | tr ' ' '\n' | sed -E "/^$/d" | sed -E "s/${STOPWORDS_REGEX}//g" | sed -E '/^$/d' | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

# Workflow headings from README (preferred source).
# Only read headings that live under the Demo section so the script works
# whether the README uses a single flattened demo module or multiple module groups.
read_workflow_headings_from_readme() {
  awk '
    /^##[[:space:]]+Demo([[:space:]]|$)/ { inDemo=1; next }
    inDemo && /^##[[:space:]]+/ { inDemo=0 }
    inDemo && /^#####\s+/ {
      h=$0
      sub(/^#####\s+/, "", h)
      if (length(h) > 0) print h
    }
  ' "$README" | awk '!seen[$0]++'
}

# Fallback workflow names from demo process metadata.
read_workflow_names_from_demo_processes() {
  [[ -n "$DEMO" ]] || return 0
  [[ -d "$DEMO_DIR/processes" ]] || return 0

  find "$DEMO_DIR/processes" -name "*.p.json" -print0 | while IFS= read -r -d '' f; do
    awk '
      /"request"[[:space:]]*:[[:space:]]*\{/ {inReq=1}
      inReq && /"name"[[:space:]]*:[[:space:]]*"[^"]+"/ {
        match($0, /"name"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)
        if (m[1] != "") print m[1]
        inReq=0
      }
      inReq && /\}/ {inReq=0}
    ' "$f"
  done | awk '!seen[$0]++'
}

# Read all candidate workflow names.
read_demo_workflows() {
  local names
  names=$(read_workflow_headings_from_readme)
  if [[ -n "$names" ]]; then
    printf "%s\n" "$names"
    return 0
  fi
  read_workflow_names_from_demo_processes
}

# Check if snippet exists in README (idempotency)
snippet_exists() {
  local snippet="$1"
  local file_ref
  file_ref=$(echo "$snippet" | sed -E 's/^!\[[^]]*\]\(([^)]+)\)$/\1/')
  grep -F -- "$file_ref" "$README" >/dev/null 2>&1
}

# Validate local image path before inserting markdown snippet.
# A valid path must be relative, safe, and resolvable from PRODUCT_DIR.
is_valid_local_image_path() {
  local rel_path="$1"

  [[ -n "$rel_path" ]] || return 1
  [[ "$rel_path" != *$'\n'* && "$rel_path" != *$'\r'* ]] || return 1
  [[ "$rel_path" != /* && "$rel_path" != \\* ]] || return 1
  [[ ! "$rel_path" =~ ^[A-Za-z]:[/\\] ]] || return 1
  [[ "$rel_path" != *".."* ]] || return 1
  [[ "$rel_path" != *"("* && "$rel_path" != *")"* ]] || return 1

  [[ -f "${PRODUCT_DIR}/${rel_path}" ]] || return 1
  return 0
}

# Infer step number from filename suffix (e.g. extraction4, flow-2, screenshot_03).
infer_step_from_filename() {
  local filename="$1"
  local base="${filename%.*}"
  if [[ "$base" =~ ([0-9]+)$ ]]; then
    local step="${BASH_REMATCH[1]}"
    step=$(echo "$step" | sed -E 's/^0+([0-9])$/\1/')
    printf "%s" "$step"
  fi
}

# Count token overlap between image tokens and workflow tokens.
score_overlap() {
  local image_tokens="$1"
  local workflow_tokens="$2"
  awk -v a="$image_tokens" -v b="$workflow_tokens" '
    BEGIN {
      split(a, A, " ")
      split(b, B, " ")
      for (i in A) if (A[i] != "") seen[A[i]] = 1
      c = 0
      for (j in B) if (B[j] != "" && seen[B[j]]) c++
      print c
    }
  '
}

# Infer best workflow from filename by token overlap.
infer_workflow_from_filename() {
  local filename="$1"
  local workflows=("$@")
  workflows=("${workflows[@]:1}")

  local base="${filename%.*}"
  local image_tokens
  image_tokens=$(tokens_from_text "$base")
  [[ -n "$image_tokens" ]] || return 0

  local best=""
  local best_score=0
  local wf
  for wf in "${workflows[@]}"; do
    [[ -n "$wf" ]] || continue
    local wf_tokens
    wf_tokens=$(tokens_from_text "$wf")
    [[ -n "$wf_tokens" ]] || continue
    local score
    score=$(score_overlap "$image_tokens" "$wf_tokens")
    if (( score > best_score )); then
      best_score=$score
      best="$wf"
    fi
  done

  if (( best_score > 0 )); then
    printf "%s" "$best"
  fi
}

# Insert snippet after a specific line number.
insert_after_line() {
  local line_no="$1"
  local snippet="$2"
  awk -v target="$line_no" -v snippet="$snippet" '
    { print }
    NR == target {
      print ""
      print snippet
      print ""
    }
  ' "$README" > "$README".tmp && mv "$README".tmp "$README"
}

# Find the line number of a workflow heading (##### ...).
find_workflow_heading_line() {
  local workflow="$1"
  local target
  target=$(normalize "$workflow")

  # iterate file with line numbers
  local ln=0
  while IFS= read -r line; do
    ln=$((ln+1))
    if [[ "$line" =~ ^##### ]]; then
      # strip heading marker and normalize
      h=${line#"#####"}
      h=${h## }
      nh=$(normalize "$h")
      if [[ "$nh" == "$target" || "$nh" == "document $target" || "$nh" == *" $target"* || "$target" == *" $nh"* ]]; then
        printf "%s" "$ln"
        return 0
      fi
    fi
  done < "$README"
}

# Find the line number where a workflow block ends.
find_workflow_block_end_line() {
  local heading_line="$1"
  local ln=0
  local in_block=0
  local last_ln=0
  while IFS= read -r line; do
    ln=$((ln+1))
    if (( ln <= heading_line )); then
      continue
    fi
    if [[ "$line" =~ ^##### ]]; then
      # the previous line is end of block
      printf "%s" "$((ln-1))"
      return 0
    fi
    last_ln=$ln
  done < "$README"
  # EOF
  printf "%s" "$last_ln"
}

# Find the line number of numbered step N inside a workflow heading block.
find_workflow_step_line() {
  local workflow="$1"
  local step="$2"
  local heading_line
  heading_line=$(find_workflow_heading_line "$workflow")
  [[ -z "$heading_line" ]] && return 0

  local end_line
  end_line=$(find_workflow_block_end_line "$heading_line")

  local ln=0
  while IFS= read -r line; do
    ln=$((ln+1))
    if (( ln <= heading_line )); then
      continue
    fi
    if (( ln > end_line )); then
      break
    fi
    if [[ "$line" =~ ^[[:space:]]*${step}\.[[:space:]] ]]; then
      printf "%s" "$ln"
      return 0
    fi
  done < "$README"
}

# Insert snippet under matching workflow heading or fallback
insert_snippet() {
  local placement="$1";
  local snippet="$2";

  if [[ "$placement" =~ ^demo:workflow-(.+):step-([0-9]+)$ ]]; then
    local wf=${BASH_REMATCH[1]}
    local step=${BASH_REMATCH[2]}
    local step_line
    step_line=$(find_workflow_step_line "$wf" "$step")
    if [[ -n "$step_line" ]]; then
      insert_after_line "$step_line" "$snippet"
      return 0
    fi
    # Fallback to workflow-level placement when step is not found.
    placement="demo:workflow-${wf}"
  fi

  if [[ "$placement" =~ ^demo:workflow-(.+)$ ]]; then
    local wf=${BASH_REMATCH[1]}
    local heading_line
    heading_line=$(find_workflow_heading_line "$wf")
    if [[ -n "$heading_line" ]]; then
      local end_line
      end_line=$(find_workflow_block_end_line "$heading_line")
      insert_after_line "$end_line" "$snippet"
      return 0
    fi
  fi

  # fallback: place under ## Demo before ### Demo Workflows
  if grep -q '^##[[:space:]]\+Demo' "$README"; then
    # insert before "### Demo Workflows" if exists
    if grep -q '^###[[:space:]]\+Demo Workflows' "$README"; then
      # insert before that heading
      awk -v snippet="$snippet" '
        BEGIN{inserted=0}
        /^###[[:space:]]+Demo Workflows/ && !inserted { print ""; print snippet; print ""; inserted=1 }
        { print }
      ' "$README" > "$README".tmp && mv "$README".tmp "$README"
      return 0
    else
      # append under Demo section
      awk -v snippet="$snippet" '
        BEGIN{inDemo=0; printed=0}
        /^##[[:space:]]+Demo/ { print; inDemo=1; next }
        { print }
        END{ if (inDemo && !printed) { print ""; print snippet; print "" } }
      ' "$README" > "$README".tmp && mv "$README".tmp "$README"
    fi
  fi
  return 0
}

# Main flow
mapfile -t WORKFLOWS < <(read_demo_workflows)
if [[ ${#WORKFLOWS[@]} -eq 0 ]]; then
  echo "No demo workflows discovered; image insertion will fallback to Demo section." >&2
fi

echo "Detected workflows:" >&2
if [[ ${#WORKFLOWS[@]} -gt 0 ]]; then
  printf "%s\n" "${WORKFLOWS[@]}" | sed 's/^/ - /' >&2
else
  echo " - (none)" >&2
fi

# Process images
while IFS= read -r -d '' img; do
  filename=$(basename "$img")
  placement="demo"

  inferred_step=$(infer_step_from_filename "$filename")
  inferred_workflow=""
  if [[ ${#WORKFLOWS[@]} -gt 0 ]]; then
    inferred_workflow=$(infer_workflow_from_filename "$filename" "${WORKFLOWS[@]}")
  fi

  if [[ -n "$inferred_workflow" && -n "$inferred_step" ]]; then
    placement="demo:workflow-${inferred_workflow}:step-${inferred_step}"
  elif [[ -n "$inferred_workflow" ]]; then
    placement="demo:workflow-${inferred_workflow}"
  fi

  snippet_path="images/${filename}"
  if ! is_valid_local_image_path "$snippet_path"; then
    echo "Skipping invalid image path for embedding: ${snippet_path}" >&2
    continue
  fi

  snippet="![${filename%.*}](${snippet_path})"
  if snippet_exists "$snippet"; then
    echo "Skipping existing snippet for $filename" >&2
    continue
  fi
  echo "Embedding $filename as $placement" >&2
  insert_snippet "$placement" "$snippet"
done < <(find "$IMAGES_DIR" -type f -print0 | sort -z)

echo "Done. README updated: $README" >&2
exit 0
