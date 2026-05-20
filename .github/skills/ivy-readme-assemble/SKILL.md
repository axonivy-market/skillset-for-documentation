---
name: ivy-readme-assemble
description: Assemble final README from precomputed fragments and write to target path.
argument-hint: '<target-readme-path>'
user-invocable: true
---

# Ivy README Assemble

Assemble README from fragment inputs without recomputation.

## Inputs

- `targetReadme` (required): output path
- `fragments` (required): precomputed markdown fragments
- `templateRef` (optional): template/schema path
- `styleProfile` (optional): formatting profile inferred from repository docs

## Behavior

1. Read template order and [output-format.md](../references/output-format.md) for fallback rules.
2. For each fragment:
   - If status is `success` or `partial`: inject `content` verbatim.
   - If status is `partial` and content is synthesized, inject the content with a note indicating it was auto-generated.
   - Example: "This section was auto-generated based on available data."
   - If status is `missing` or content is empty: keep section heading and inject `- No information was delivered for this section.`
   - Validate fragment quality before injection: reject pseudo-filled content (e.g., generic placeholders without extracted structure) and normalize to `missing` with the default fallback.
   - If `requiredSubsections` is provided, verify each subsection appears in `content`; for missing entries, append explicit placeholder lines under the correct section.
   - If `preserveMode=verbatim`, do not rewrap, renumber, or normalize markdown blocks.
    - If `preserveMode!=verbatim`, normalize ordered-list sequence before injection:
       - Detect broken list numbering (for example repeated top-level `1.` items).
       - Renumber sequentially by indentation level so top-level steps render as `1.`, `2.`, `3.` and nested steps stay nested.
       - Do not alter fenced code blocks, inline code, links, or image paths.
   - Resolve heading aliases from `styleProfile` and inject into the repository-native heading without changing the fragment content.
   - **Demo section**: Inject `demoIntroSection` directly under `## Demo`. Always render heading `### Demo workflows` after `demoIntroSection`, then inject `demoWorkflows` fragment content (or fallback if missing).
   - **Setup section**: Assemble in order: Roles → OpenAPI → Variables block reference → [Setup steps].
   - **Roles placement**: Insert as bullet point at start of Setup section (before steps): `- **Roles:** ...`
   - **OpenAPI placement**: Insert as bullet point WITHIN Setup section (not separate `## Components` section): `- **OpenAPI:** Spec URL + Namespace`
   - **Variables placement**: Inject under `## Setup` as `### Variables` subsection (not standalone section) unless style profile explicitly requests standalone.
   - **Image placement**: If an image fragment is present with `standalone=false`, place image snippets in the target sections indicated by fragment placement hints (for example intro/demo/setup). If `productImageSection` status is `missing` or empty, do NOT create a standalone `## Images` section. Instead, skip image section entirely. All images must be embedded within their related content sections (Setup, Demo, etc.).
     - **Image embedding algorithm** (required, step-aware for per-workflow demo images):
       
       **Algorithm Overview:**
       For each image in `productImageSection.images[]`:
         1. Extract placement hint: `image.placement` (e.g., `demo:workflow-Person Search:step-2`)
         2. Route image to target section based on placement prefix
         3. For demo workflow images, find and embed image at exact step location
       
       **Placement Types & Embedding Logic:**
       
       **Type 1: `demo:workflow-<WorkflowName>:step-<N>`** (highest priority)
       ```
       Goal: Insert image directly below numbered step N in specific workflow
       
       Algorithm:
         1. Parse placement → WorkflowName="Document Splitting", StepNumber=2
         2. Scan Demo section for workflow heading: ##### Document Splitting
         3. Within that workflow block, find step 2 line (e.g., "2. Upload or select a document...")
         4. Insert image after step 2:
            - Add blank line after step 2
            - Insert image snippet: "   ![Alt Text](images/....png)"
            - Add blank line after image
         5. Adjust indentation to match workflow step indentation (3 spaces)
       
       Example input (GENERIC - any workflow):
       ```markdown
       ##### Document Splitting
       1. Launch the Document Splitting demo from the demo menu.
       2. Upload or select a document from the file browser.
       3. Configure splitting parameters (page range, orientation).
       4. Review the split result and download the files.
       ```
       
       Example output (image inserted after step 2):
       ```markdown
       ##### Document Splitting
       1. Launch the Document Splitting demo from the demo menu.
       2. Upload or select a document from the file browser.
       
          ![Document Splitting Dialog](images/DocumentSplitting.png)
       
       3. Configure splitting parameters (page range, orientation).
       4. Review the split result and download the files.
       ```
       
       **Note:** This applies to ANY workflow - replace "Document Splitting" with your workflow name
       ```
       
       **Type 2: `demo:workflow-<WorkflowName>`** (workflow-level, no step)
       ```
       Goal: Insert image after all workflow steps (end of workflow block)
       
       Algorithm:
         1. Parse placement → WorkflowName="Data Validation"
         2. Scan Demo section for workflow heading: ##### Data Validation
         3. Find all numbered steps (1., 2., 3., ...)
         4. Insert image after last step:
            - Add blank line
            - Insert image snippet
            - Add blank line
       
       Example (works for any workflow):
       ##### Data Validation
       1. Launch the Data Validation workflow.
       2. Load your dataset or connect to data source.
       3. Configure validation rules and thresholds.
       4. Execute validation and review results.
       
          ![Validation Results](images/DataValidation.png)
       ```
       
       **Type 3: `intro`**
       ```
       Goal: Insert image after first paragraph of product description
       
       Algorithm:
         1. Locate productDescriptionSection content
         2. Find first paragraph (text before first blank line)
         3. Insert image after first paragraph:
            - Blank line, image, blank line
       ```
       
       **Type 4: `demo`** (fallback without workflow match)
       ```
       Goal: Insert image under ## Demo before ### Demo workflows
       
       Algorithm:
         1. Locate ## Demo section heading
         2. Find ### Demo workflows subheading
         3. Insert image between them
       ```
       
       **Type 5: `setup`**
       ```
       Goal: Insert image inside ## Setup near related step or config
       ```
       
       **Workflow Name Matching (Robust & Fuzzy - GENERIC):**
       ```
       Step 1: Normalize both sides
         - image placement: WorkflowName = "Document Splitting" → "document splitting"
         - readme heading: "##### Document Splitting" → "document splitting"
         - Rules: lowercase, remove punctuation, collapse whitespace
       
       Step 2: Compare normalized forms
         - Exact match: if normalized_placement == normalized_heading → use it
         - Substring match: if one is substring of other → use it
         - Token match: if all tokens from one appear in other → use it
         - Score-based: if multiple matches, pick highest scoring match
       
       Step 3: If no match found
         - Log warning: "Image placement 'demo:workflow-X' did not match any heading"
         - Fallback: insert image under ## Demo before ### Demo workflows
       
       WORKS FOR ANY WORKFLOW - Examples:
         - "Document Splitting" ↔ "DocumentSplitting.png"
         - "Data Validation" ↔ "DataValidation.png"
         - "Invoice Processing" ↔ "InvoiceProcessing.png"
       ```
       
       **Step Number Extraction & Matching (GENERIC):**
       ```
       Goal: Find exact line number in workflow to insert image
       
       Algorithm:
         1. Extract all numbered lines from workflow block (pattern: "1. ", "2. ", "3. ", etc.)
         2. Match pattern: "^N\. " (e.g., "2. " for step 2)
         3. Find insertion point:
            - Start from step line (e.g., "2. Select configuration options...")
            - Scan forward until next numbered line (e.g., "3. Review...")
            - OR end of workflow block
         4. Insert image at that position with blank line before & after
       
       Works for ANY workflow - Examples:
         - Step 1: "1. Launch the demo..."
         - Step 2: "2. Configure settings..."
         - Step 3: "3. Execute the workflow..."
       ```
       
       **Pseudo-code for step insertion (GENERIC - works for any workflow):**
       ```javascript
       function insertImageAfterStep(workflowBlock, stepNum, imageSnippet) {
         lines = workflowBlock.split('\n')
         
         // Find step N line (pattern: "N. " at start of line)
         for (i = 0; i < lines.length; i++) {
           if (lines[i].match(new RegExp('^' + stepNum + '\\. '))) {
             stepLineIndex = i
             break
           }
         }
         
         if (stepLineIndex == null) return null  // step not found
         
         // Find insertion point (after step content, before step N+1)
         insertionIndex = stepLineIndex + 1
         for (i = stepLineIndex + 1; i < lines.length; i++) {
           if (lines[i].match(new RegExp('^' + (stepNum + 1) + '\\. '))) {
             insertionIndex = i
             break
           }
         }
         
         // Insert image with blank lines
         lines.splice(insertionIndex, 0, '', imageSnippet, '')
         
         return lines.join('\n')
       }
       
       // WORKS FOR ANY PROJECT - example calls:
       // - insertImageAfterStep(docSplittingBlock, 2, "![Document Splitting](images/DocumentSplitting.png)")
       // - insertImageAfterStep(invoiceBlock, 1, "![Invoice Upload](images/InvoiceUpload.png)")
       // - insertImageAfterStep(validationBlock, 3, "![Validation Results](images/Results.png)")
       ```
       
       **Indentation Rules:**
       ```
       - Workflow step line:      "1. ..." (0 indent)
       - Image after step:        "   ![...]()" (3 spaces indent)
       - Blank line:              "" (empty)
       
       Example indentation:
       1. Step one
       2. Step two
       
          ![image](path)
       
       3. Step three
       ```
       
       **Complete Example (Full Flow - GENERIC):**
       ```
       Input Fragment:
       {
         "section": "productImageSection",
         "images": [
           {
             "path": "images/DocumentSplitting.png",
             "placement": "demo:workflow-Document Splitting:step-2"
           }
         ]
       }
       
       README Content (before):
       ### Demo workflows
       #### my-demo-module (any demo module)
       ##### Document Splitting
       1. Launch the Document Splitting demo
       2. Upload a document or select from library
       3. Configure splitting parameters
       4. Review and download results
       
       README Content (after):
       ### Demo workflows
       #### my-demo-module
       ##### Document Splitting
       1. Launch the Document Splitting demo
       2. Upload a document or select from library
       
          ![Document Splitting Dialog](images/DocumentSplitting.png)
       
       3. Configure splitting parameters
       4. Review and download results
       
       WORKS FOR ANY PROJECT - Just replace:
         - "Document Splitting" with your workflow name
         - "DocumentSplitting.png" with your image filename
         - Step 2 with your target step number
       ```
       
       **Error Handling:**
       ```
       - If step number not found: log warning, insert after last step instead
       - If workflow not found: log warning, insert under ## Demo fallback
       - If image path invalid: skip image, log error
       - If placement malformed: default to "demo" placement
       ```
       
       1. Use `images[]` per-image `placement` hints when available. For each image in order:
          - If `placement` is `demo:workflow-<WorkflowName>`, find the workflow block in the Demo section with heading matching `<WorkflowName>` and insert the image snippet immediately after the step list for that workflow.
          - If `placement` is `demo:workflow-<WorkflowName>:step-<N>`, find the workflow block and insert the image snippet directly below numbered step `N` (same indentation level as workflow step attachments).
          - **Matching algorithm (robust):** Before attempting an exact match, normalize both the `<WorkflowName>` from the placement value and each demo workflow heading using the same rules: lowercase, remove punctuation (quotes, parentheses), collapse repeated whitespace, replace common punctuation with spaces, and trim. Compare normalized forms for equality; if no exact equality, then try substring match of token sequences (longest-first). This relaxed matching makes placements resilient to minor differences in punctuation, quoting, or diacritics.
          - If `placement` is `intro`, insert after the first paragraph of `productDescriptionSection`.
          - If `placement` is `demo`, insert under `## Demo` before `### Demo workflows` (or close to the Demo section if no workflows exist).
          - If `placement` is `setup`, insert within `## Setup` near the related step or at top of `### Variables` if the image documents configuration.
          - If no matching heading is found after relaxed matching, fall back to the nearest parent section (`productDescriptionSection`, `Demo`, `Setup`). When falling back from `demo:workflow-...`, prefer inserting under `## Demo` before `### Demo workflows`.
          - Insert the image snippet on a separate indented block: blank line, image line, blank line. Preserve the snippet exactly as provided by the fragment.
       2. If multiple images target the same insertion point, append them in discovery order.
       3. If `standalone=true`, create `## Images` and place any images without explicit placements there; otherwise do not create `## Images`.
       4. Do not alter image paths or alt-text. Do not add captions unless the fragment includes them.

### Example:
If an image has `placement: demo:workflow-Document Splitting`, assembler must find the `##### Document Splitting` workflow block in the Demo section and insert the image after the numbered steps for that workflow.

If an image has `placement: demo:workflow-Document Splitting:step-2`, assembler must insert the image directly below step `2.` in that workflow.
   - **Critical image rule**: Do not create a standalone `## Images` section under any circumstances unless the template or fragment explicitly sets `standalone=true`. When `productImageSection` is missing/empty, simply omit the entire Images section from output — do not insert a fallback placeholder like "No images detected".
   - **Components hierarchy rule**: Always render `## Components` and place `### Connector Processes`, `### Form Components`, and `### Maven artifacts` beneath it.
   - Never render `## Connector Processes` as top-level heading.
   - **Variables missing rule**: Under `### Variables`, if `variablesSection` is missing/empty, inject exactly `- No variables were detected.`
3. Never omit a section heading from the template. The assembler MUST always render heading `### Demo workflows` after `demoIntroSection`, even if the `demoWorkflows` fragment is missing or empty.
4. Remove unnecessary HTML comments (e.g., `<!-- status: ... -->`) from fragment content before injection. Never include timestamps, skill names, or other metadata in the final output.
5. Preserve exact variable block `@variables.yaml@` if present.
6. Apply `styleProfile` when present to keep repository-native markdown conventions (ordered list style, OpenAPI style, callable-sub layout).
6.1 Prefer repository-native section placement when style profile indicates it (e.g., variables inside setup).
7. Write assembled result to target path.
## Fragment validation rules

- **Mandatory fragments**: productDescriptionSection, keyFeatures, demoIntroSection, demoWorkflows, rolesSection, openApiSection, setupSection, variablesSection, callableSubSection, formComponentSection, mavenArtifactSection
- **Optional fragments**: optionalAuthSection, productImageSection
- Treat content as pseudo-filled if it only states availability (e.g., "present in file", "see process file") without extracted details required by that section.
- Pseudo-filled content must be normalized to `missing` and rendered with explicit fallback text.
- Normalization must preserve section headings and template order.
- Roles and OpenAPI must be presented as inline bullet points in Setup, NOT as separate sections.

## Quality criteria

- No scanning in this step.
- No paraphrasing or reformatting of fragments.
   - Heading order follows the README Template Format in output-format.md strictly. The assembler MUST always render sections in this order, regardless of fragment extraction order:
      1. Product description (productDescriptionSection)
      2. Key features (keyFeatures)
      3. Demo (demoIntroSection, then heading ### Demo workflows, then demoWorkflows)
      4. Setup (rolesSection, openApiSection, variablesSection, optionalAuthSection)
      5. Components (callableSubSection, formComponentSection, openApiSection, mavenArtifactSection)
   - If any fragment is missing, inject the fallback placeholder at the correct position.
- Must keep all template headings even when fragment data is missing.
- Must never read from or mutate approved `README.md` during assembly.
- Must report subsection coverage gaps before writing final output.
- Must not pass through ambiguous placeholder prose as successful extraction output.
