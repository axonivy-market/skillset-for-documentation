---
name: ivy-readme-key-features
description: Generate key-features and setup fragments from one Axon Ivy Maven main module only.
argument-hint: '<main-module-path>'
user-invocable: true
---

# Ivy README Key Features

Generate product description, key-feature bullets, demo intro, and complete setup/variables/openapi sections for Axon Ivy/Maven repositories.

## Inputs

- `mainModule` (required): main module path
 - Optional: `language` (default: `en`) - preferred language for CMS lookups and synthesized prose. When generating the source `README.md`, callers MUST set `language: en` so extracted prose is English. Use `language: de` only when producing `README_DE.md` during translation.

## Behavior

0. **Source priority (enhanced for marketing/UX):**
   - Priority 1: module documentation sources (README/README_*.md in product or main module) for section structure, intro, images, external links, and long instructional blocks
   - Priority 2: configuration sources (`config/variables.yaml`, `config/rest-clients.yaml`, `config/roles.xml`)
   - Priority 3: process/cms hints (`processes/*.p.json`, cms files)
   - If intro block is missing, synthesize a marketing-friendly intro with product image and external links if available.
         - If an image is present in the intro block, include the image markdown in the `productDescriptionSection.content` and record a placement hint `intro` for the `productImageSection` (so assemblers embed the image inline into the intro).
   - Add fallback synthesis logic to ensure a default product description is always generated:
      - Use repository name and module name to create a generic description.
      - Example: "The [module name] connector integrates seamlessly with Microsoft 365 services, providing robust features for [key services]."
      - Include a placeholder image or link if none are found.
   - If key features are missing, synthesize user-centric, benefit-driven bullets grouped by service area (Mail, Calendar, Files, Teams, ToDo, etc.) with real-world examples.
   - Never fabricate setup steps that are not present in sources, but always synthesize intro/features if missing.

0.1 **Anti-duplication source safety (mandatory):**
   - Never treat the current generation target file (`targetReadme`, typically `<productModule>/README.md`) as authoritative source input in the same generation run.
   - On regeneration, if `<productModule>/README.md` already exists and appears to be assembler-generated (for example contains the canonical template headings like `## Demo`, `## Setup`, `## Components`), do not ingest any section content from it.
   - Do not scan `<productModule>/README.md` for compatibility in the default flow.
   - If extraction detects nested top-level heading blocks (`# ...`) inside a fragment candidate, discard that candidate and continue with non-generated sources.

1. **Key Features** (6 bullets, benefit-driven):
   - **Format**: Each bullet MUST start with user benefit, not technical implementation.
   - **Source priority**:
       1. Try: Extract from `<mainModule>/README.md` (existing Key Features section)
   2. Derive from connector processes: Extract CALLABLE_SUB process signatures from `<mainModule>/processes/*.p.json`
        - For each CallSubStart: extract name, input params, result type
        - Look for `visual.description` field to understand user capability
        - Map to service area (Mail, Calendar, Files, Teams, ToDo, etc.)
     3. Configuration hints: `config/roles.xml` and `config/rest-clients.yaml`
   - **Synthesis rules** (when no pre-written features found):
     - Use verb + object pattern: "Send emails", "Create calendar events", "Upload files"
     - Add outcome/benefit: "directly from your Axon Ivy processes"
     - Group by service: Mail, Calendar, Teams, Files, ToDo
     - Examples: 
       - ❌ Wrong: "writeMail() callable sub sends messages"
       - ✅ Right: "Send emails and manage recipients directly from your processes"
   - **Quality gate**: If synthesized features are generic (e.g., "integrates X"), mark `status=partial`
   - Preserve sourced features exactly; never rewrite approved feature text.

   1.1 **Product Description Section** (mandatory, marketing style):
         - Extract the introductory product description block from module documentation sources.
         - If available, include product image and external links (e.g., Microsoft Graph overview, documentation, etc.).
         - Source priority with fallback:
            1. Try: `<mainModule>/README.md` or `<mainModule>/doc/README.md` (first paragraph). Prefer the main module README as source of canonical intro text.
            2. **Fallback:** Root repository `README.md` (extract first intro paragraph before any ### sections)
            3. If no intro is found in docs, synthesize from repository evidence (`config/*`, process metadata, product.json).
         - If no intro is found, synthesize a marketing-friendly intro with product image and external links.
         - External image URLs found in source README files are valid and should be preserved (no forced local image copy required).
         - Exclude non-product intro noise from extracted intro blocks:
            - CI/CD badges, shields, workflow status images, and other badge-style images/links
            - self-referential documentation links that point to the generated target README or the current product module README
            - navigation-only CTA lines such as `Read our documentation` when they do not add product meaning
         - Preserve paragraph structure, image, and marketing-friendly wording.

      1.1.1 **Intro quality gate (generic, mandatory):**
             - Evaluate extracted intro quality using structure checks:
                - at least 2 prose sentences, and
                - at least 1 capability statement, and
                - optional visual/link block when available from sources.
             - If intro is missing or below threshold, synthesize a repository-grounded intro from source evidence (`config/rest-clients.yaml`, process descriptions, product docs).
             - Never hardcode product-specific wording.
             - Mark `status=partial` when intro is synthesized from mixed sources instead of a single canonical doc block.

      1.2 **Demo Intro Section** (recommended, with external links):
         - Extract introductory `## Demo` body text and catalog links from module documentation when available.
          - If images are present in the Demo intro block, include the image markdown in `demoIntroSection.content` and record `placement=demo` for the product image fragment.
         - If available, include external demo links and service mapping.
         - **NEW:** Source priority with fallback:
            1. Try: `<mainModule>/README.md` (## Demo section content before ### subsections, plus any external demo links)
            2. **Fallback:** Root repository `README.md` (extract ## Demo section if present)
         - If no demo intro is found, synthesize a demo intro with external links and service mapping.
         - Keep this separate from workflow steps (which come from demo workflow skill).
         - Include links in Markdown format (preserve as-is from source)

2. **Setup Section** (mandatory, concise):
   - Extract all numbered steps from source documentation or configuration
   - The extracted `setupSection` MUST be returned in sequence-correct order.
   - **Normalize list formatting (MANDATORY):**
     - **Step 1: Detect broken hierarchy** — Parse the source setup block line by line:
       - Count top-level numbered items (lines starting with `1.`, `2.`, `3.`, etc. at indent level 0)
       - Count repeated numbers: If more than 2 top-level items are numbered `1.` (not `1.1.`, `1.2.`, etc.), the hierarchy is BROKEN
       - Identify sub-item indentation levels (tabs vs spaces, count spaces)
      - **Step 2: If broken numbering detected, auto-normalize:**
         - Re-number top-level items sequentially: `1.`, `2.`, `3.`, `4.`, etc.
         - Normalize sub-item numbering to reflect the parent top-level index using dotted notation:
            - Sub-numbered items become `N.M.` where `N` is the parent top-level number and `M` the sequential child index.
            - Example: top-level `4.` with three child lines originally numbered `1.` becomes `4.1.`, `4.2.`, `4.3.` respectively.
         - Preserve detail bullets (non-numbered items under sub-steps): keep as `- ` with proper indentation
         - Specifically handle repeated `1.` sequences at increased indentation by mapping them to the parent index plus child counter (this prevents repeated `1.` in sublists):
            - Detect lines where indentation > 0 and the numeric marker is `1.` (or repeated same number) and assign hierarchical numbers using the current top-level index.
         - Example transformation:
            ```
            BEFORE (broken):
            1. First step
            1. Navigate somewhere
                1. Sub-step A
                1. Sub-step B
            1. Another step

            AFTER (normalized):
            1. First step
            2. Navigate somewhere
                2.1. Sub-step A
                2.2. Sub-step B
            3. Another step
            ```
     - **Step 3: Apply consistent indentation:**
       - Top-level items: NO indent
       - Sub-numbered items (1.1., 1.2., etc.): 3 spaces
       - Nested bullets under sub-items (- format): 6 spaces
       - Code blocks or nested prose: match parent indentation + 3 spaces
     - **Step 4: Preserve existing correct numbering:**
       - If hierarchy is already correct (1., 2., 3.... with proper sub-numbering 1.1., 1.2., etc.), do NOT modify it
     - **Enforcement:**
       - If broken numbering is detected and corrected, return `setupSection.preserveMode = structured`
       - Use `preserveMode = verbatim` ONLY when numbering/indentation is already consistent and must remain byte-identical
       - NEVER return a setup fragment with repeated top-level `1.` items when they represent different sequential steps — this is a violation
   - **Image placement rule:**
     - Separate images to dedicated lines (not inline with step text)
     - Indent images to match parent step indentation level (same as parent step)
     - Add blank line BEFORE image and blank line AFTER image block for readability
     - Preserve image markdown exactly: `![alt-text](path/to/image.png)`
     - **Image path rewriting (mandatory when source and target are in different directories):**
       - When extracting content from a source file (e.g., `setup.md`) that lives in a different directory than the target README, all relative image paths in that content MUST be rewritten to remain valid from the target README location.
       - Algorithm:
         1. Determine `sourceDir` = directory of the source file (e.g., `msgraph-connector-product/`)
         2. Determine `targetDir` = directory of the target README (e.g., `msgraph-connector-product/products/msgraph-connector/`)
         3. Compute `relPrefix` = relative path from `targetDir` back to `sourceDir` using standard `../` traversal (e.g., `../../`)
         4. For every image reference `![alt](path)` in the extracted content where `path` does NOT start with `http`, `/`, or `../` pointing outside `sourceDir`: prepend `relPrefix` to `path`.
         5. Verify the resulting path is resolvable from `targetDir`; if not, log a warning and keep original.
       - Example: source at `product/setup.md` uses `doc/img/foo.png`; target README at `product/products/connector/README.md` → rewrite to `../../doc/img/foo.png`.
       - This rule applies to all content sources: `setup.md`, module README, `doc/README.md`, and any inline doc fragment.
     - Example:
       ```
       3. Navigate to Settings.
          1. Click Authorization.
       
             ![auth-dialog](../../doc/img/auth.png)
       
          2. Paste your token.
       ```
   - **Start with inline highlights**: Roles, OpenAPI (not separate section), and variables block reference upfront
   - **Tone and readability:** Write in a friendly, professional, user-first style; explain what the user does and what they should expect next
   - Avoid unexplained jargon in prose; when technical identifiers are required (variable keys, endpoint paths, class names), keep them exact but wrap them in concise explanatory text
   - Include repository-specific setup subsections exactly as documented (authentication, endpoints, integration keys, runtime config, etc.)
   - Do NOT synthesize new subsection headings that are not present in source docs (for example `### Azure App`).
   - Template alignment rule: avoid emitting `### Azure App` as a heading in final setup fragments; convert that content into ordered setup steps under `## Setup`.
   - If source setup contains only numbered steps without subsections, keep it that way.
   - Include any additional setup notes, images references, or test confirmation steps
   - Use `preserveMode=verbatim` when long setup blocks are found in source docs AND numbering is already correct
   - Populate `requiredSubsections` with discovered mandatory subsections
   - Include `### Variables` as a subsection of Setup by default when variables are present
   - **CRITICAL**: OpenAPI info goes INTO Setup as a bullet point, NOT as a separate section (assembler will place it under Setup, not Components)
   - **NO standalone `## Images` section** — all images must be embedded inline within their related setup steps or sections

2.1 **Roles Section** (NEW - extract from config/roles.xml):
   - Scan `<mainModule>/config/roles.xml` for role definitions
   - Extract role names and descriptions
   - Format: `**Roles:** [Role 1] (description), [Role 2] (description)`
   - If all roles granted: `**Roles:** Everybody (configured in config/roles.xml)`
   - Return as `rolesSection` fragment
   - If missing: set `status: missing`, content: "Roles configuration not documented"

3. **Variables Section**:
   - Extract complete variable block from `config/variables.yaml` 
   - Preserve all inline comments and explanations
   - Include any NOTE/[!NOTE] blocks if present
   - Keep block formatting and indentation stable (verbatim where possible)
   - If missing, set fragment status to `missing` with content exactly: `- No variables were detected.`
   - Do not synthesize fake/default YAML keys when the source file is missing.
   - Replace `{{variableSection}}` with this exact fenced block (preserve the backticks literally in the output file):
```
@variables.yaml@
```

   3.1 **OpenAPI Section**:
      - Extract OpenAPI endpoint/spec details from `config/rest-clients.yaml` and related docs.
      - Present OpenAPI spec URL and namespace.
      - Return as a dedicated `openApiSection` fragment for deterministic placement in assembly.
        - If no OpenAPI spec is found, set fragment status to `missing` and content to exactly: `- No information was delivered for this section.`

4. Maven Artifacts: Extract artifact coordinates from `product.json`, then order the rendered list by the root `pom.xml` module sequence. Format as numbered list with XML dependency blocks and include only `groupId`, `artifactId`, and `<type>`; do NOT include a `<version>` element in the README (the build/pipeline should resolve versions). Use `*(optional)*` marker for optional artifacts and set status:missing if none found.

5. Return JSON fragments conforming to [output-format.md](references/output-format.md)

## Language / CMS behavior

- When invoked with `language=en`, the skill MUST prefer English CMS files (`cms_en.yaml`) for string resolution and produce English prose for all synthesized sections. If English CMS is missing, fall back to repository defaults but favor English output.
- When invoked with `language=de`, the skill may prefer German CMS files (`cms_de.yaml`) and produce German prose for outputs intended for translation (for example when invoked by `translate-readme`).
- The central orchestration (`generate-ivy-readme`) must call extractors with `language=en` when building the source `README.md` and must call `translate-readme` to produce `README_DE.md` (which may use `language=de` internally).

## Output Sections

- `productDescriptionSection`: Introductory description block with image and links
- `keyFeatures`: Feature bullets only (6 items, benefit-driven)
- `demoIntroSection`: Intro text + external links (from ## Demo section in source or market links)
- `rolesSection`: Roles configuration extracted from `config/roles.xml`
- `openApiSection`: OpenAPI resources/config details (Spec URL + Namespace) — goes INTO Setup section
- `setupSection`: All setup steps discovered from source docs/configuration (numbered steps, images preserved)
- `variablesSection`: Complete variables YAML with comments and notes
- `mavenArtifactSection`: Maven artifacts with numbered XML dependency blocks. Do not include a `<version>` element in the generated blocks; prefer leaving version resolution to the packaging/build pipeline.

Each section should include contract metadata when possible:
- `preserveMode`: `verbatim` for long instructional blocks, otherwise `structured`
- `completeness`: `full|partial`
- `requiredSubsections`: discovered subsection headings that must appear in final output

For `setupSection`, default to `preserveMode: structured`.
Only use `preserveMode: verbatim` when no list normalization is required.

## Quality criteria

- Scope limited to main module only
- Extract complete product intro + setup details, not simplified versions
- Setup prose is friendly and understandable for non-technical stakeholders while preserving exact technical values
- Preserve all inline comments and documentation
- Preserve image references exactly
- No demo/product scans in this step
- Must produce comprehensive output for Axon Ivy/Maven repositories
