#!/bin/bash
set -euo pipefail

PROJECT_NAME="${1:?Usage: catalog-images.sh <project-name> [output-file] [demo-module]}"
OUTPUT_FILE="${2:-}"
DEMO_MODULE="${3:-}"
AUTO_EMBED="${AUTO_EMBED:-0}"

if [[ -z "$DEMO_MODULE" && "$PROJECT_NAME" == *-product ]]; then
    DEMO_MODULE="${PROJECT_NAME%-product}-demo"
fi

# Resolve images directory: checks in order:
#   1. {name}/images/          (standard convention)
#   2. {name}/doc/img/         (alternative convention used by some connectors)
#   3. {name}/                 (bare module directory fallback)
resolve_images_dir() {
    local name="$1"
    if [[ -d "${name}/images" ]]; then
        echo "${name}/images"
    elif [[ -d "${name}/doc/img" ]]; then
        echo "${name}/doc/img"
    elif [[ -d "${name}" ]]; then
        echo "${name}"
    else
        return 1
    fi
}

get_alt_text() {
    local name="${1%.*}"   # strip extension
    echo "$name" | tr -- '-_' '  ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} {print}'
}

get_section_title() {
    local reldir="$1"
    if [[ -z "$reldir" || "$reldir" == "." ]]; then
        echo "General"
        return
    fi
    # Title-case each path component, join with " / "
    local title=""
    while IFS= read -r part; do
        [[ -z "$part" ]] && continue
        word=$(echo "$part" | tr -- '-_' '  ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} {printf $0}')
        title+="${title:+ / }${word}"
    done < <(echo "$reldir" | tr '/' '\n')
    echo "$title"
}

get_readme_placement() {
    local section="${1,,}"
    if [[ "$section" =~ demo ]];              then echo "## Demo"
    elif [[ "$section" =~ setup|install ]];   then echo "## Setup"
    elif [[ "$section" =~ component|feature ]]; then echo "## Components"
    else echo "## Screenshots"
    fi
}

extract_external_images_from_readme() {
        local readme="$1"
        local placement="$2"
        [[ -f "$readme" ]] || return 0

        awk -v place="$placement" '
            {
                line=$0
                while (match(line, /!\[[^\]]*\]\(https?:\/\/[^)]+\)/)) {
                    img=substr(line, RSTART, RLENGTH)
                    if (!seen[img]++) {
                        print place "\t" img
                    }
                    line=substr(line, RSTART+RLENGTH)
                }
            }
        ' "$readme"
}

##############################################################################

IMAGES_DIR=$(resolve_images_dir "$PROJECT_NAME") || {
    echo "Error: Could not find directory for: $PROJECT_NAME" >&2
    echo "Tried: ${PROJECT_NAME}/images, ${PROJECT_NAME}/" >&2
    exit 1
}

echo "Scanning: $IMAGES_DIR" >&2

# Collect all images, sorted
mapfile -t IMAGE_FILES < <(
    find "$IMAGES_DIR" -type f \( \
        -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o \
        -iname "*.gif" -o -iname "*.svg" -o -iname "*.webp" -o \
        -iname "*.tiff" -o -iname "*.tif" -o -iname "*.bmp" -o \
        -iname "*.ico" -o -iname "*.mp4" \
    \) | sort
)

TOTAL=${#IMAGE_FILES[@]}

# Discover external image URLs from README files (if any)
mapfile -t EXTERNAL_IMAGES < <(
    {
      extract_external_images_from_readme "$PROJECT_NAME/README.md" "## Intro"
      extract_external_images_from_readme "$PROJECT_NAME/target/README.md" "## Intro"
      extract_external_images_from_readme "README.md" "## Intro"
    } | awk '!seen[$0]++'
)

if [[ $TOTAL -eq 0 && ${#EXTERNAL_IMAGES[@]} -eq 0 ]]; then
    echo "No images found in: $IMAGES_DIR and no external README image URLs found" >&2
    exit 0
fi

# Unique sub-directories relative to IMAGES_DIR
mapfile -t SUBDIRS < <(
    for f in "${IMAGE_FILES[@]}"; do
        rel="${f#${IMAGES_DIR}/}"
        dir=$(dirname "$rel")
        [[ "$dir" == "." ]] && dir=""
        echo "$dir"
    done | sort -u
)

output="# Image Summary: ${PROJECT_NAME}\n\n"
output+="Source: \`${IMAGES_DIR}\`  \n"
output+="Total local: ${TOTAL} image(s)\n"
output+="Total external: ${#EXTERNAL_IMAGES[@]} image(s)\n\n"
output+="---\n\n"

for subdir in "${SUBDIRS[@]}"; do
    section=$(get_section_title "$subdir")
    placement=$(get_readme_placement "$section")
    count=0
    entries=""

    for f in "${IMAGE_FILES[@]}"; do
        rel="${f#${IMAGES_DIR}/}"
        dir=$(dirname "$rel")
        [[ "$dir" == "." ]] && dir=""
        if [[ "$dir" == "$subdir" ]]; then
            count=$((count + 1))
            filename=$(basename "$f")
            alt=$(get_alt_text "$filename")
            relpath="${f#./}"
            entries+="### ${alt}\n"
            entries+="![${alt}](${relpath})\n\n"
        fi
    done

    output+="## ${section} (${count})\n\n"
    output+="> Suggested readme placement: \`${placement}\`\n\n"
    output+="${entries}"
done

if [[ ${#EXTERNAL_IMAGES[@]} -gt 0 ]]; then
    output+="## External README Images (${#EXTERNAL_IMAGES[@]})\n\n"
    output+="> Suggested readme placement: \`## Intro\`\n\n"
    for item in "${EXTERNAL_IMAGES[@]}"; do
        placement="${item%%$'\t'*}"
        image_md="${item#*$'\t'}"
        output+="${image_md}\n\n"
    done
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    echo -e "$output"
else
    echo -e "$output" > "$OUTPUT_FILE"
    echo "[+] Saved to: $OUTPUT_FILE" >&2
fi

if [[ "$AUTO_EMBED" != "0" ]]; then
    EMBED_SCRIPT="$(dirname "$0")/auto-embed-images.sh"
    if [[ -f "$EMBED_SCRIPT" ]]; then
        echo "[+] Auto-embedding images into README..." >&2
        # Use current bash executable when available to avoid PATH issues on Windows.
        if [[ -n "${BASH:-}" ]]; then
            "${BASH}" "$EMBED_SCRIPT" "$PROJECT_NAME" "${DEMO_MODULE:-}"
        elif command -v bash >/dev/null 2>&1; then
            bash "$EMBED_SCRIPT" "$PROJECT_NAME" "${DEMO_MODULE:-}"
        else
            echo "[!] bash is not available in PATH; skipping auto-embed." >&2
        fi
    else
        echo "[!] auto-embed-images.sh not found; skipping auto-embed." >&2
    fi
fi
