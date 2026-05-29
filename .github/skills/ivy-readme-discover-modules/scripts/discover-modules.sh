#!/usr/bin/env bash
set -euo pipefail

# Discover module roles for Axon Ivy Maven repositories.
# Usage:
#   bash discover-modules.sh [workspacePath]

workspace_path="${1:-.}"

if [[ ! -d "$workspace_path" ]]; then
  echo "Error: workspace path does not exist: $workspace_path" >&2
  exit 1
fi

cd "$workspace_path"

root_pom="pom.xml"
if [[ ! -f "$root_pom" ]]; then
  cat <<'JSON'
{
  "mainModule": ".",
  "demoModules": [],
  "productModule": ".",
  "excludedModules": [],
  "repoProfile": {
    "buildSystem": "unknown",
    "languageHints": ["java"],
    "isMonorepo": false,
    "discoveryMode": "root-fallback"
  }
}
JSON
  exit 0
fi

mapfile -t modules < <(
  awk '
    /<modules>/,/<\/modules>/ {
      if ($0 ~ /<module>/) {
        gsub(/.*<module>/, "", $0)
        gsub(/<\/module>.*/, "", $0)
        print $0
      }
    }
  ' "$root_pom"
)

if [[ ${#modules[@]} -eq 0 ]]; then
  cat <<'JSON'
{
  "mainModule": ".",
  "demoModules": [],
  "productModule": ".",
  "excludedModules": [],
  "repoProfile": {
    "buildSystem": "maven",
    "languageHints": ["java"],
    "isMonorepo": false,
    "discoveryMode": "single-module-fallback"
  }
}
JSON
  exit 0
fi

excluded_modules=()
product_modules=()
demo_modules_explicit=()
candidate_modules=()

for module in "${modules[@]}"; do
  module_lc="$(printf '%s' "$module" | tr '[:upper:]' '[:lower:]')"

  if [[ "$module_lc" =~ (^|[-_])webtest$|(^|[-_])test$ ]]; then
    excluded_modules+=("$module")
    continue
  fi

  if [[ "$module_lc" == *-product ]] || [[ -f "$module/product.json" ]]; then
    product_modules+=("$module")
    continue
  fi

  # Explicit demo naming patterns (generic):
  # - *-demo
  # - *-demos
  # - *-demos-* (tokenized plural demo naming used by some repos)
  if [[ "$module_lc" == *-demo ]] || [[ "$module_lc" == *-demos ]] || [[ "$module_lc" == *-demos-* ]]; then
    demo_modules_explicit+=("$module")
    candidate_modules+=("$module")
    continue
  fi

  candidate_modules+=("$module")
done

product_module=""
if [[ ${#product_modules[@]} -gt 0 ]]; then
  product_module="${product_modules[0]}"
else
  # Generic fallback: choose first module that contains product.json in nested products/* if available.
  for module in "${modules[@]}"; do
    if find "$module" -type f -path "*/products/*/product.json" -print -quit | grep -q .; then
      product_module="$module"
      break
    fi
  done
fi
if [[ -z "$product_module" ]]; then
  product_module="${modules[0]}"
fi

demo_modules=()
discovery_mode="suffix-based"
if [[ ${#demo_modules_explicit[@]} -gt 0 ]]; then
  demo_modules=("${demo_modules_explicit[@]}")
else
  # Generic fallback: infer demo modules from RequestStart evidence.
  discovery_mode="requeststart-inferred"
  for module in "${candidate_modules[@]}"; do
    if [[ ! -d "$module/processes" ]]; then
      continue
    fi
    if grep -R --include='*.p.json' -E '"type"[[:space:]]*:[[:space:]]*"RequestStart"' "$module/processes" >/dev/null 2>&1; then
      demo_modules+=("$module")
    fi
  done
fi

main_module=""
for module in "${candidate_modules[@]}"; do
  skip=false
  for demo in "${demo_modules[@]}"; do
    if [[ "$module" == "$demo" ]]; then
      skip=true
      break
    fi
  done
  if [[ "$skip" == false ]]; then
    main_module="$module"
    break
  fi
done

# If all candidates are demos (common in pattern/demo repositories), select first demo as main.
if [[ -z "$main_module" ]]; then
  if [[ ${#demo_modules[@]} -gt 0 ]]; then
    main_module="${demo_modules[0]}"
    discovery_mode="${discovery_mode}+demo-main-fallback"
  elif [[ ${#candidate_modules[@]} -gt 0 ]]; then
    main_module="${candidate_modules[0]}"
    discovery_mode="${discovery_mode}+candidate-main-fallback"
  else
    main_module="$product_module"
    discovery_mode="${discovery_mode}+product-main-fallback"
  fi
fi

json_array() {
  local first=true
  printf '['
  for item in "$@"; do
    if [[ "$first" == true ]]; then
      first=false
    else
      printf ', '
    fi
    printf '"%s"' "$item"
  done
  printf ']'
}

printf '{\n'
printf '  "mainModule": "%s",\n' "$main_module"
printf '  "demoModules": %s,\n' "$(json_array "${demo_modules[@]}")"
printf '  "productModule": "%s",\n' "$product_module"
printf '  "excludedModules": %s,\n' "$(json_array "${excluded_modules[@]}")"
printf '  "repoProfile": {\n'
printf '    "buildSystem": "maven",\n'
printf '    "languageHints": ["java"],\n'
printf '    "isMonorepo": true,\n'
printf '    "discoveryMode": "%s"\n' "$discovery_mode"
printf '  }\n'
printf '}\n'
