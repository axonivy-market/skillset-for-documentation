---
name: ivy-readme-demo-workflows
description: Generate Demo section workflow text from demo process files only.
argument-hint: '<demo-module-path>'
user-invocable: true
---

# Ivy README Demo Workflows

Generate `## Demo` body from demo starts.

## Inputs

- `demoModules` (required): array of demo module paths as discovered by `ivy-readme-discover-modules` skill
   - Each module path is a workspace-relative module directory path string
  - Auto-populated from root pom.xml module list
- Optional: `groupByModule` (default: true) - when true, groups workflows under #### Module headers
 - Optional: `language` (default: `en`) - preferred language for resolved CMS values and synthesized prose. When producing the source `README.md` callers MUST set `language: en`.

## Behavior

0. **Demo Intro Section (before workflows)**:
  - Extract ONLY the first paragraph(s) of the `## Demo` section from `<mainModule>/README.md`, stopping at the first subheading (`###` or `#####`).
   - Do NOT include any workflow steps, subheadings, or repeated content in `demoIntroSection`.
   - Do NOT copy entire demo workflow blocks verbatim from existing README files to avoid duplication during assembly.
    - CMS resolution rule: When resolving `ivy.cms.co(...)` or other CMS-derived display strings, prefer CMS files matching the requested `language` input:
       - If `language=en`: prefer `<module>/cms/cms_en.yaml` then `<module>/cms_en.yaml` then repository root `cms_en.yaml`.
       - If `language=de`: prefer `<module>/cms/cms_de.yaml` then `<module>/cms_de.yaml` then repository root `cms_de.yaml`.
       - If no CMS file for requested language exists, fall back to English, then to any available CMS file.
   - IMPORTANT: The demo-workflows skill must not inject German prose into the source `README.md` when `language=en` is used. Translation to German must be performed by `translate-readme` (see translate-readme SKILL.md). When extracting from existing README files, only extract the short demo intro paragraph and explicit external links; do not re-extract numbered workflow steps that the assembler will generate from process metadata.
   - Look for external demo links (e.g., `[Microsoft Calendar](https://market.axonivy.com/msgraph-calendar)`)
   - Include service mapping and link text exactly as sourced
     - Source priority:
       1. Try: Main module README.md
       2. Try: Root repository README.md (## Demo section)
       3. Fallback: Synthesize from demo module names and process metadata
    - Anti-duplication guard (mandatory):
      - Do not ingest workflow bodies from an assembler-generated target README of the same run.
      - If source file equals the current `targetReadme`, extract only intro text before the first `###` subheading and explicit external links.
      - If a candidate extraction block contains another top-level heading (`# `) or template restart markers, reject it and continue with process-based workflow extraction.
    - Link preference rule:
       - If both market links and local relative README links exist for the same service, keep the market link (`https://market.axonivy.com/...`).
       - Do not downgrade market links to repository-relative links.
   - Enhance fallback synthesis logic for demo intro:
      - If demo module names are not descriptive, extract from module directory names
      - Include a default link to documentation if no specific links are found
      - Use generic template: "Check the demo implementations provided. Visit documentation to learn more."
   - If found, return as `demoIntroSection` fragment with `status: success`.
   - If only workflow steps available: return `status: partial` (workflows present, no intro)
  - **MANDATORY:** When extracting demoWorkflows, do NOT include any content from demoIntroSection. Only include workflow blocks and their steps; each workflow should be rendered as a heading followed by a numbered step list (no additional subheading required).

1. **For each demo module in demoModules array:**
   - Scan `<demoModule>/processes/**/*.p.json` for all files (recursive)
   - Extract user-facing `RequestStart` entries with or without tags
   - Identify related `CallSubStart` references (format: `<processName>:<callableSubName>()`)

2. **Extract workflow metadata:**
   - Request name and description from `config.request.name` and `config.request.description`, resolved using the CMS resolution rule above according to the `language` input.
   - Connected callable subs from `SubProcessCall` elements (format: `<processName>:<callableSubName>()`)
   - Tags (for quality hints, not filtering)

3. **Build workflow steps in friendly, step-by-step format:**
   - **Audience:** Write for non-technical stakeholders; avoid jargon and internal process references
   - **Format:** Multi-step numbered guidelines (3–5 steps per workflow, adapt freely)
   - **Tone:** Friendly and professional; plain language first, technical detail only when needed for reproducibility
   - **Each step must cover:**
     - User action: "Launch the [friendly-name] process", "Click [button/field]", "Fill in [description]"
     - Observable outcome: "You'll see [dialog/form/data]", "Results display [information]"
   - **Launch rule:** Use friendly `RequestStart` display name, never internal file names (for example, avoid `.ivp` names in user-facing prose)
   - **Do NOT include:** callable sub names in user-facing steps (e.g., no "(calls `processName:callableSubName()`)") 
   - **Do include:** friendly RequestStart display names from `config.request.name`, observable UI elements (dialogs, forms, buttons)
   - **Docker/deployment:** If available in module config or dockerfile, mention in final step (e.g., "If Docker deployment is available, [action]")
   - Template example (adapt to actual RequestStart data):
     ```
     #### [Friendly Workflow Name from RequestStart]
     1. Launch the process from the menu
     2. You'll see a [dialog/form/interface] with [observable elements]
     3. Perform action: [user action like fill fields, click button]
     4. Review the [results/output/confirmation]
     5. Optional: Docker/deployment-specific next steps
     ```

3.2 **Merge behavior with existing `## Demo` section (mandatory):**
   - Compare generated workflows against currently documented workflows in the product README.
   - Add workflows that exist in demo processes but are not documented yet.
   - Remove workflows that are documented but no longer exist in demo processes.
   - Update workflows whose behavior no longer matches the current process flow.
   - Keep unchanged wording for workflows that are still accurate.
  - Never merge by appending a second full `## Demo` body when a `### Demo Workflows` section already exists; replace the existing workflow block in-place.
   - **NEVER include the demoIntroSection content in demoWorkflows.**

3.3 **Module rendering guard (mandatory):**
   - Never emit a module heading without at least one workflow block below it.
   - If module scan succeeds but no workflow details can be rendered, emit exactly one placeholder workflow block under that module:
     ```
     ##### [Workflow Name Pending]
     1. Launch the process from the demo menu.
     2. Workflow details could not be resolved from source process metadata.
     ```
   - This prevents empty demo subsections such as `#### Module` followed directly by the next top-level section.

3.3.1 **Workflow markdown structure rule (mandatory):**
  - Render each workflow consistently as:
    ```
    #### [Friendly Workflow Name]
    1. Step one
    2. Step two
    ```
  - Do not insert an intermediate `##### Steps` subheading. Keep the markup compact and consistent across projects.
  - Do not prepend a separate module wrapper heading in the default flow.
  - If repository style profile explicitly requires module grouping, keep grouping but still enforce workflow heading depth consistency within each group.

3.1 **Completeness gate (mandatory):**
   - Count extracted `RequestStart` entries per module.
   - Count rendered workflow blocks per module.
   - If rendered count is lower than extracted count, set fragment status to `partial` and append one placeholder block per missing workflow:
     ```
    #### Workflow [N]
     - Workflow detected but mapping details were not fully resolved from source process model.
     ```
   - Only set `missing` when no `RequestStart` entries exist after a genuine scan.
   - Never silently skip unmatched `RequestStart` entries.

3.4 **Image Integration Support (NEW - GENERIC):**
   - **Optional input:** `imageMetadata` array containing pre-matched images from product-image-summary
     ```json
     [
       {
         "filename": "DocumentSplitting.png",
         "matched_workflow": "Document Splitting",
         "step_number": 2,
         "snippet": "![Document Splitting Dialog](images/DocumentSplitting.png)"
       },
       {
         "filename": "DataValidation.png",
         "matched_workflow": "Data Validation",
         "step_number": null,
         "snippet": "![Validation Results](images/DataValidation.png)"
       }
     ]
     ```
   - When image metadata is provided:
     - Do NOT embed images in this step; delegate to assembler
     - Instead, pass image metadata forward to `productImageSection` fragment
     - Assembler will use placement hints to insert images at correct workflow step
   - This skill's responsibility: generate clean workflow text without embedded images
   - Assembler's responsibility: insert images using placement hints (`demo:workflow-<Name>:step-<N>`)
   - Benefit: Decouples workflow text generation from image embedding logic
   - WORKS FOR ANY PROJECT: Examples above use generic workflow names (Document Splitting, Data Validation)
     Replace with your actual workflow names when implementing



4. **Return JSON fragments conforming to [output-format.md](./references/output-format.md), with markdown in `content`:**

Output TWO fragments:

**Fragment 1: Demo Intro Section (before workflows)**
```json
{
   "section": "demoIntroSection",
   "status": "success|partial|missing",
   "content": "[Intro paragraph]\n\n[link 1]\n[link 2]\n\n<!-- extracted from README -->"
}
```

**Fragment 2: Demo Workflows**
```json
{
   "section": "demoWorkflows",
   "status": "success|partial|missing",
  "content": "#### [Friendly Workflow Name]\n\n1. [User action or observable outcome]\n2. [What user sees]\n3. [What user can do]\n4. [Next step or result]\n5. [Docker/deployment callout if available]"
}
```

Example markdown content for demoIntroSection field (extracted from README):

```markdown
Check the demo implementations provided:

[Service Name 1](https://market.axonivy.com/service-1) - description of integration

[Service Name 2](https://market.axonivy.com/service-2) and [Service Name 3](https://market.axonivy.com/service-3) - more services
```

*Note: Extract exact links and text from README; do not add branded content.*

Example markdown content for demoWorkflows field (generated from RequestStart metadata):

```markdown
#### [Workflow Name from RequestStart.config.request.name]

1. Launch the process from the menu or dashboard
2. You'll see a [form/dialog/interface] displaying [observable data/elements]
3. [User action]: fill in fields, select options, or trigger workflow
4. [Observable outcome]: system processes request and shows [results/confirmation]
5. If Docker deployment is configured: [available next step]

#### [Another Workflow Name]

1. Launch process
2. [Interface description]
3. [User action]
4. [Result/confirmation]
```

*Note: All content is extracted from process metadata; step count adapts per workflow (typically 3–5 steps).*

**Output format rules:**
- Return JSON fragment with `section=demoWorkflows`, `status`, and markdown `content`
- The `demoWorkflows` fragment `content` MUST NOT include heading `### Demo Workflows`; only include workflow blocks and steps.
 - Render each workflow as `#### [Friendly Workflow Name]` followed by a numbered step list. Do not emit `##### Steps`.
- Workflow steps: Numbered 1–N (typically 3–5 steps, adapt per workflow)
  - Each step focuses on **user action or observable outcome**, not internal process mechanics
   - No callable sub references in steps (for example, avoid `calls processName:callableSubName()`)
  - Each step describes what user sees (dialogs, forms, data) and what they can do (click, fill, view)
- Do not use internal file names as launch instructions in prose
- Final step: Mention Docker/deployment capability if available in module
- End with status comment
- Deterministic order: process files alphabetical, then `RequestStart` by `config.signature`/`name`
- If no workflows are found in a module after scan, include one explicit placeholder workflow block for that module

## Quality criteria

- No scanning outside demo module
- Deterministic order: process files alphabetical, RequestStart by name within each
- Preserve the single consistent workflow heading structure in output (no `##### Steps`).
- **Audience**: Write for non-technical stakeholders; use friendly language
- **Format**: Multi-step numbered guidelines per workflow (not bullets, not single lines)
- **Content**: Focus on user actions and observable outcomes; remove technical jargon
- **Merge fidelity**: Add/remove/update workflows to match current demo processes
- **No empty modules**: Never output a module header without at least one workflow block
- **Completeness**: All RequestStart entries represented in output or marked as partial/missing
- Docker/deployment mention in final workflow step (if available)

### Updates to Demo Workflows

- Output format: **Multi-step numbered guidelines** (3–5 steps per workflow, not bullets)
- Audience: **Non-technical stakeholders** — remove callable sub names and internal process references
- Content: Focus on **user actions and observable outcomes** (what user sees, what they can do)
- Workflow names: Extract **friendly RequestStart display names** from `config.request.name`, not `.p.json` filenames
- Docker integration: Mention Docker/deployment capability in **final workflow step** (if available in module)
- Completeness gate: Ensure all RequestStart entries are represented; mark partial/missing if gaps exist
- Ensure scanner uses recursive `processes/**/*.p.json` instead of top-level-only process files
- Output conforms to output format reference, including JSON fragment structure with status comments
- Prefer `market.axonivy.com` demo links when available in source docs; keep local links only as fallback.

#### NEW: Image Integration for Demo Workflows

**Purpose:** Support automatic image embedding into demo workflow steps without modifying this skill's output.

**Workflow:**
1. **This skill** generates clean workflow text (no embedded images)
2. **product-image-summary skill** provides image metadata with placement hints
3. **ivy-readme-assemble skill** uses placement hints to embed images at correct workflow steps

**Image Placement Hints (GENERIC):**
- Format: `demo:workflow-<WorkflowName>:step-<N>`
- Examples:
  - `demo:workflow-Document Splitting:step-2`
  - `demo:workflow-Data Validation:step-1`
  - `demo:workflow-Invoice Processing:step-3`
- Assembler will insert image after specified step of corresponding workflow
- Works for ANY workflow name, ANY step number

**For skill implementers:**
- Accept optional `imageMetadata` input (pre-matched images from product-image-summary)
- Do NOT embed images into workflow text in this step
- Generate workflow steps without image placeholders
- Let assembler handle image insertion using placement hints

**Benefit of separation:**
- Workflow text stays clean and reusable
- Image matching logic centralized in product-image-summary
- Multiple image placement options without modifying workflow text
- Easy to update images without regenerating demo workflows
- GENERIC ALGORITHM works for any project, any workflow name
