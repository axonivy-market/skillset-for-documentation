---
name: product-image-summary
description: Discover and catalog all images (screenshots, diagrams, GIFs) that could be used in readme documentation, generate auto-suggested alt-text, and create markdown snippets ready for readme integration. Use when asked to find, list, or summarize product images or screenshots for documentation.
argument-hint: '[required: exact project directory name] [optional: output file]'
user-invocable: true
---


# Product Image Summary

Given the exact product module name, auto-discover its `images/` subdirectory, group images by folder structure, generate alt text from filenames, and output ready-to-copy markdown snippets.
In addition, discover external image URLs used in source README files and include them as valid image evidence.
If images are found, suggest placement (intro/demo/dashboard) and synthesize a markdown snippet for a README intro image. Produce placement hints at the individual image level so assemblers can embed images into the correct section rather than creating a separate `## Images` section.

## Inputs

- **Required:** Exact product module name (e.g., `open-weather-connector-product`) — the script looks for `{name}/images/` then falls back to `{name}/`
- **Optional:** Output file path — omit to print to stdout

### External image discovery (mandatory)

- Scan README sources in this order:
	1. `<productModule>/README.md`
	2. `<productModule>/target/README.md` (if present)
	3. repository root `README.md`
- Extract markdown image entries of form `![alt](https://...)`.
- Include extracted external images in output with placement hint `intro` unless the surrounding heading indicates `Demo` or `Setup`.
- External URLs are first-class image sources; do not downgrade them to missing just because no local file exists.

## Usage

Before running, check the current OS. If on Windows, git bash or WSL is recommended to use for best compatibility.
```bash
# Bash (Linux/macOS/WSL)
bash ./.github/skills/product-image-summary/scripts/catalog-images.sh {product module name} docs/product-images.md

# Optional: auto-embed images into README demo workflows
bash ./.github/skills/product-image-summary/scripts/auto-embed-images.sh {product module name} {demo module name}
```

On Windows, run the existing bash scripts via Git Bash (or invoke Git-for-Windows bash explicitly
from PowerShell) to ensure auto-embed runs reliably.


## Output

Images grouped by subdirectory under `images/`. Section headers reflect the folder path (e.g., `demo/dashboard/` -> `## Demo / Dashboard`). Each entry includes file path, suggested README placement, alt text, a markdown snippet, and an explicit `placement` hint for assembler embedding.

If only external images are found in README sources, still return `status: success` with those URLs in `content` and provide placement hints derived from the surrounding headings.

Return a JSON fragment compatible with assembler contracts, for example:

```json
{
	"section": "productImageSection",
	"status": "success|partial|missing",
	"content": "[markdown snippets]",
	"images": [
		{
			"path": "images/extraction1.png",
			"alt": "Extraction example",
			"snippet": "![Extraction example](images/extraction1.png)",
			"placement": "intro"
		},
		{
			"path": "images/splitting-document-1.png",
			"alt": "Splitting example",
			"snippet": "![Splitting example](images/splitting-document-1.png)",
			"placement": "demo"
		}
	],
	"placements": ["intro", "demo", "setup"],
	"standalone": false,
	"completeness": "full|partial"
}
```


## Placement rules (improved for per-workflow demo images):
- Default `standalone` to `false`.
- Provide placement hints in `placements` and also provide `images[]` with per-image `placement` fields so the assembler can place each image at the closest matching heading (see assembler rules below).
- If an image is related to a specific demo workflow, set placement as `demo:workflow-<WorkflowName>` (e.g., `demo:workflow-Document Splitting`).
	- You may infer workflow name from the image filename (e.g., `splitting`, `extraction`) or from metadata if available.
- If external README sources contain images, set `placement` based on surrounding heading context (e.g., if image is under a `## Demo` heading, placement=`demo`).
- Do not require creation of a standalone `## Images` section unless `standalone=true` is explicitly set.

### Example per-workflow placement:
```json
{
	"path": "images/splitting-document-1.png",
	"alt": "Splitting example",
	"snippet": "![Splitting example](images/splitting-document-1.png)",
	"placement": "demo:workflow-Document Splitting"
}

{
	"path": "images/splitting-document-2.png",
	"alt": "splitting-review",
	"snippet": "![splitting-review](images/splitting-document-2.png)",
	"placement": "demo:workflow-Document Splitting:step-2"
}
```

### Demo Step Ordering Rules (mandatory)

- For demo images that clearly encode a sequence in file names, generate step-aware placement:
  - `demo:workflow-<WorkflowName>:step-<N>`
- Assemblers/scripts must use this to insert image snippets directly below step `N` in that workflow.
- When a step-aware placement is emitted, it has higher priority than plain `demo:workflow-...`.

Recommended filename conventions:
- `splitting-document-1.png` -> `demo:workflow-Document Splitting:step-1`
- `splitting-document-2.png` -> `demo:workflow-Document Splitting:step-2`
- `splitting-document-3.png` -> `demo:workflow-Document Splitting:step-3`
- `splitting-document-4.png` -> `demo:workflow-Document Splitting:step-4`
- `extraction1.png` or `extraction-1.png` -> `demo:workflow-Extraction:step-1`
- `extraction2.png` or `extraction-2.png` -> `demo:workflow-Extraction:step-2`

Fallback behavior:
- If step index cannot be inferred, emit `demo:workflow-<WorkflowName>`.
- If workflow cannot be inferred, emit `demo`.

### Placement inference rules (improved for auto-matching)

#### Algorithm: Filename-to-Workflow Matching

**Core Logic:** Match image filename to demo workflow name using intelligent tokenization and scoring.

**Step 1: Extract tokens from filename**
```
Input: DocumentSplitting.png, DataValidation-2.png, screenshot.png
Process:
  - Remove file extension
  - Split on: `-`, `_`, CamelCase boundaries
  - Remove stopwords: img, screenshot, example, demo, test, data, screen, view, form, dialog
Output: 
  DocumentSplitting → ["Document", "Splitting"]
  DataValidation-2 → ["Data", "Validation"] (step: 2)
  screenshot → [] (all stopwords)
```

**Step 2: Normalize tokens**
```
Input: ["Document", "Splitting"]
Process:
  - Convert to lowercase
  - Join with spaces
  - Remove special characters
Output: "document splitting"
```

**Step 3: Extract step number (if present)**
```
Patterns to detect:
  - Suffix: -N, _N (e.g., Workflow-1.png, Workflow_2.png)
  - Embedded: Workflow1.png, Workflow2.png
Output: step number as integer or null
```

**Step 4: Match against extracted workflow names (GENERIC)**
```
Available workflows (from demo processes - ANY project):
  ["Document Splitting", "Data Validation", "Invoice Processing", "User Import"]

Scoring algorithm:
  For each workflow:
    score = 0
    normalized_workflow = normalize(workflow)  // e.g., "document splitting"
    
    // Exact match bonus (highest priority)
    if normalized_tokens == normalized_workflow:
      score += 1000
    
    // Token substring match (word-level matching)
    for token in normalized_tokens:
      if token in normalized_workflow:
        score += 100
    
    // Workflow substring match (e.g., "splitting" in "document splitting")
    for workflow_token in normalized_workflow.split():
      if workflow_token in normalized_tokens:
        score += 50
    
    record(workflow, score)
  
  return workflow with highest score (if score > 0)
```

**Step 5: Generate placement hint**
```
If matched workflow found:
  if step_number exists:
    placement = "demo:workflow-{WorkflowName}:step-{N}"
  else:
    placement = "demo:workflow-{WorkflowName}"
else:
  placement = "demo"  // fallback to general demo section
```

**Generic Examples of matching (works for ANY project):**
- `DocumentSplitting.png` → tokens `["Document", "Splitting"]` → normalized `"document splitting"` → exact match → `placement: demo:workflow-Document Splitting`
- `DataValidation.png` → tokens `["Data", "Validation"]` → normalized `"data validation"` → exact match → `placement: demo:workflow-Data Validation`
- `invoice_processing_3.png` → tokens `["invoice", "processing"]`, step `3` → match + step → `placement: demo:workflow-Invoice Processing:step-3`
- `import-1.png` → tokens `["import"]` → matches `"User Import"` workflow → `placement: demo:workflow-User Import:step-1`
- `screenshot.png` → tokens `[]` (all stopwords removed) → no match → `placement: demo` (fallback)
- `ui-flow-dialog.png` → tokens `["ui", "flow", "dialog"]` → all stopwords removed → no match → `placement: demo` (fallback)

#### Fuzzy Matching (for edge cases - GENERIC)
When exact token match fails, use token overlap scoring:
```
Similarity scoring:
  - Count matching tokens: max_tokens_in(image, workflow)
  - If similarity_score >= 50%, consider it a match
  - If multiple workflows have same score, prefer longest workflow name match
```

**Generic Examples of fuzzy matching (reusable across projects):**
- `split.png` + workflows `["Document Splitting", "Data Validation"]` → `"split"` matches `"Splitting"` → score > 0 → `placement: demo:workflow-Document Splitting`
- `validate_form.png` + workflows `["Data Validation", "Invoice Processing"]` → `"validate"` matches `"Validation"` → `placement: demo:workflow-Data Validation`
- `step2.png` + workflows `["Data Validation"]` → step `2` detected, workflow matched → `placement: demo:workflow-Data Validation:step-2`
- `process.png` + workflows `["Invoice Processing", "User Import"]` → `"process"` matches `"Processing"` → prefer longer match → `placement: demo:workflow-Invoice Processing`

#### README/Context Inference
- **Optional:** Scan surrounding content in README.md for nearby heading context
- If image is placed under `##### [Workflow Name]` heading, use that heading as the workflow name
- Example: Image placed under `##### Person Search` heading → force `placement: demo:workflow-Person Search`

#### Placement Fallback
- If no match found: default to `demo`
- If image detected in `intro` context: default to `intro`
- If image detected in `setup` context: default to `setup`
- Do not leave `placement` empty

#### Implementation in SKILL execution
- When extracting image metadata, fetch demo workflow names from:
  1. Extracted `RequestStart` process metadata (if available)
  2. Existing README.md workflow headings (`##### [Name]`)
  3. If unavailable, let assembler provide workflow list
- Pass workflow names to matching algorithm
- Return metadata with `matched_workflow` and `confidence_score` for transparency

Embedding guidance for assemblers (required):
- Assemblers MUST prefer to embed images into their target sections as follows:
  - `intro` -> insert after the first paragraph of `productDescriptionSection`
  - `demo` -> insert under `## Demo` before `### Demo workflows` or beside the related demo workflow block if placement hints include `demo:workflow-<name>`
  - `setup` -> insert inside `## Setup` close to the related step or at top of `### Variables` if the image documents configuration
- When multiple images share the same placement, assembler may insert them sequentially in the order discovered.
- Only when `standalone=true` should the assembler create a `## Images` section; otherwise images must be injected inline into related sections.

Output must conform to [output-format.md](../references/output-format.md) contract. Use JSON status field for metadata (not HTML comments).

See [references/output-format.md](references/output-format.md) for the full output schema and examples.

### Updates to Product Image Summary

- Include file path details, image metadata (size, dimensions, format), and summary sections in the output.
- Categorize images into Screenshots, Diagrams, Animations, Icons, and Other.
- Use JSON status/completeness fields for metadata (not HTML comments)
