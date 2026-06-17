---
name: market-prod-callsubs-readme
description: Generate a product README for an Axon Ivy project. Use when asked to create, generate, or update a README.md or README_DE.md for an Axon Ivy product module.
---

Purpose
-------
Create a well-structured README for an Axon Ivy product following the schema in [format reference](./references/output-format.md).
Content is derived from the main module(s) and demo module(s). The tone is friendly and professional, suitable for both technical and non-technical stakeholders.

This skill generates production documentation for the detected product module:
- `README.md` (English)
- `README_DE.md` (German)

The skill must always:
* Dynamically detect the correct product module folder for output (see below).
* Assemble `README.md` strictly from sub-skill outputs, following the modular extraction and assembly protocol.
* Generate `README_DE.md` from the generated `README.md` via `translate-readme` in the same run.
* Ensure the flow remains generic and reusable across Axon Ivy/Maven repository structures.

Inputs
------
- `workspacePath` (optional): path to repository root. Default: current workspace.
- `module` (optional): explicit module name to treat as the main module.
- `targetReadme` (optional): output path. Default: `<discovered-product-module>/README.md`.
- `targetReadmeDe` (optional): output path. Default: `<discovered-product-module>/README_DE.md`.

Autonomous execution policy (mandatory)
--------------------------------------
- Run fully non-interactive when invoked (no clarification prompts by default).
- Always generate/update `README.md` in one pass, even if some extractors fail.
- Always generate/update `README_DE.md` in the same pass.
- Automatically invoke all required sub-skills (`ivy-readme-key-features`, `callable-sub-listing`, `form-components-listing`, etc.) without user confirmation.
- If a listed sub-skill cannot be invoked as a callable unit by the runtime, **immediately** read that sub-skill's `SKILL.md` and execute its extraction logic directly against repository source files in the same turn — this is MANDATORY and takes priority over normalization.
- If external script dependencies (e.g., `jq`) are unavailable, automatically switch to internal source parsing (read files directly using available tools) and continue.
- **Only normalize a fragment to `missing` after** a genuine extraction attempt has been made and truly produced no content (e.g., directory does not exist, no matching process files found).
- Normalizing a fragment to `missing` without first attempting extraction is a violation of this policy.
- Before assembly, produce an in-memory execution ledger entry for every required extractor with: `skill`, `readSkillMd=yes|no`, `extractionAttempted=yes|no`, `filesScanned=[...]`, `fragmentsProduced=[...]`, `status=done|missing|failed`.
- Assembly is forbidden if any required extractor is absent from the execution ledger or has `readSkillMd=no` or `extractionAttempted=no`.
- If `workspacePath`, `module`, `targetReadme`, or `targetReadmeDe` are omitted, derive them automatically and continue without asking the user.

Configuration defaults
----------------------
- `keyFeatureRange`: 3–8 bullets
- `excludeSuffixes`: `test` or `webtest`
- `missingSectionFallback`: `- No information was delivered for this section.`
- `styleProfilePolicy`: `infer-from-repo`
- `completenessGate`: `strict`

Runtime optimization rules (mandatory)
--------------------------------------
- Use module-scoped extraction paths whenever possible:
   - `callable-sub-listing`: scan `<mainModule>/processes/**` first (avoid `./**/*.p.json` global scans)
   - `form-components-listing`: scan `<mainModule>/src_hd` only. Do not fallback to demo or other modules.
   - `restClientsSection`: parse `<mainModule>/config/rest-clients.yaml` directly in this orchestration skill (no dedicated helper script in this skill directory)
   - `product-image-summary`: prefer canonical image folders (`images`, `doc/img`, `docs/images`) before any full-root fallback
- Run independent extractors in parallel after module discovery.
- Avoid repeated scans of the same folder tree in one run; reuse already collected file lists in-memory inside the same orchestration step.
- Keep strict completeness behavior; do not use fragment hash-cache shortcuts.

Sub-skill protocol
------------------
For every **APPLY SKILL: `<name>`** instruction in the steps below:
1. Call the specified skill with the given arguments.
   - If the runtime cannot directly invoke the skill, immediately read that skill's `SKILL.md` and perform its documented extraction logic yourself in the same run.
2. Expect output conforming to [output-format.md](./references/output-format.md) contract.
3. Inject the stdout output **verbatim** at the named `{{placeholder}}` — do not reformat, summarize, or paraphrase.

Execution guardrails (mandatory)
--------------------------------
1. Do not manually draft, rewrite, or "quick-fix" `README.md` content.
2. `README.md` may be written only by the `ivy-readme-assemble` step using collected fragments.
3. `README_DE.md` may be written only by `translate-readme` using the generated `README.md` as source.
4. If any required sub-skill output is unavailable or malformed, create a normalized `missing` fragment (`section`, `content`, `status`) and continue assembly.
5. Never patch an already generated `README.md` to compensate for missed sub-skills; re-run modular extraction + assembly flow.
6. Never patch an already generated `README_DE.md` by hand; re-run translation from the current generated `README.md`.
7. Do not return a blocked result if assembly can still run with normalized `missing` fragments.
8. **Normalization enforcement**: `ivy-readme-key-features` MUST normalize broken list numbering in setup sections (e.g., repeated `1.` items must be renumbered to `1.`, `2.`, `3.`, `4.`, etc. at top level with proper sub-numbering `1.1.`, `1.2.` for nested items). If source has broken numbering, return `preserveMode=structured` in fragment.
9. **Image handling**: Do NOT create standalone `## Images` section in final README. All images must be embedded within their related sections (Setup, Demo, etc.). If `productImageSection` fragment is `missing`, omit images entirely from output — do not insert fallback text.
9.1 **Image path validation (mandatory)**: Before embedding image snippets, validate that each path is safe and resolvable from the target README location. If a path is broken/malformed, skip that image snippet and continue generation.
10. **Write mode enforcement (mandatory)**: `README.md` and `README_DE.md` must be written with full-file overwrite semantics (truncate then write). Never append to existing files and never use patch-style partial updates for final generation output. The target file is write-only during generation and must not be treated as an input source.
11. **Duplicate guard (mandatory)**: Before assembling or translating, ignore any existing content in the target README paths. Do not ingest `<productModule>/README.md` or `<productModule>/README_DE.md` as source material in the same run. After writing each target file, validate that there is only one top-level title block (single leading `# ...` document start). If repeated full document starts are detected, regenerate and overwrite the target file once using the same source fragments/translation output.


Output
------
- Primary output: `<detected-product-module>/README.md` (or `targetReadme` if provided).
- Secondary output (default): `<detected-product-module>/README_DE.md` (or `targetReadmeDe` if provided).
- The final README section order is strictly enforced by the README Template Format in output-format.md, not by fragment extraction order. All fragments are mapped to their correct section and assembled in this canonical order.
- The product module is always resolved dynamically:
   - After resolving the product module from pom.xml, check if it contains a `products/<product-name>/product.json` or `products/<product-name>/README.md` (deepest product folder wins).
   - If found, treat that as the main product module and create `README.md` there.
   - If not, fallback to the root product module folder.
   - If `targetReadme` is omitted, always write `<resolved-product-module>/README.md` without asking the user.
   - If `targetReadmeDe` is omitted, always write `<resolved-product-module>/README_DE.md` without asking the user.
- Output content must be assembled strictly from sub-skill results.

Behavior / Steps
----------------
1. Resolve defaults:
   - APPLY SKILL `ivy-readme-discover-modules` to resolve `productModule` from root `pom.xml`.
   - If `module` is omitted, use discovered `mainModule`.
   - `targetReadme = <productModule>/README.md` when omitted.
   - `targetReadmeDe = <productModule>/README_DE.md` when omitted.

1.0 Generic module safety (mandatory):
   - Treat `demoModules=[]` as suspicious in multi-module repositories when process files exist.
   - Consider repositories with explicit demo naming tokens (`-demo`, `-demos`, `-demos-`) as valid demo candidates before inferring by process evidence.
   - If `demoModules` is empty but non-excluded modules contain `processes/**/*.p.json` with `RequestStart`, infer those modules as `demoModules` in-memory for this run.
   - If `mainModule` has no useful extraction evidence (no setup docs, no variables, no callable subs, no `src_hd`), retry extractors with a module set fallback:
     - `moduleSetForExtraction = all non-excluded, non-product modules`
    - Exception: `form-components-listing` must remain main-module scoped. If `<mainModule>/src_hd` is missing or yields no components, keep `formComponentSection` as `missing` and render the fixed fallback sentence under `### Dialog Components`.
   - This fallback is generic and must not rely on naming conventions like `-demo`.

1.1 Resolve generic Axon Ivy/Maven profile:
   - Read `repoProfile` from `ivy-readme-discover-modules` output.
   - If no explicit multi-module structure exists, treat repository root as both main and product module.
   - Keep the same assembly protocol for single-module and multi-module Axon Ivy/Maven projects.

1.2 Resolve style profile:
   - Infer `styleProfile` from existing repository docs if available (ordered list style, OpenAPI display style, callable-sub layout).
   - Apply inferred style profile consistently during assembly.

2. Modular rebuild path (default and required):
   - APPLY SKILL `ivy-readme-discover-modules`
   - APPLY SKILL `ivy-readme-key-features`
   - APPLY SKILL `callable-sub-listing`
   - APPLY SKILL `form-components-listing`
   - APPLY SKILL `ivy-readme-demo-workflows`
   - APPLY SKILL `maven-artifact-listing`
   - APPLY SKILL `product-image-summary`
   - APPLY SKILL `ivy-readme-assemble`
   - `product-image-summary` is a mandatory extractor, not optional polish.
   - The flow MUST execute `product-image-summary` for every README generation run before assembly, even when no local image folder is expected.
   - Only after reading its `SKILL.md` and attempting extraction may the image fragment be normalized to `missing`.

2.0 Multi-module extraction fallback (mandatory):
    - If a sub-skill scoped to `mainModule` returns `missing` but other candidate modules exist, re-run that sub-skill extraction logic across `moduleSetForExtraction` and merge deterministically.
    - Applies at minimum to:
       - `ivy-readme-demo-workflows` (scan all inferred `demoModules`)
       - `callable-sub-listing` (scan all candidate modules' `processes/**/*.p.json`)
       - `ivy-readme-key-features` setup/variables roles fallback when main module is sparse
   - `form-components-listing` is excluded from this fallback and must not scan candidate modules beyond `<mainModule>/src_hd`.
    - Normalize to `missing` only after this fallback scan also produces no content.

2.1 Mandatory fragment mapping (must be present before assembly):
   - `productDescriptionSection` <- from `ivy-readme-key-features`
   - `keyFeatures` <- from `ivy-readme-key-features`
   - `demoIntroSection` <- from `ivy-readme-demo-workflows` (with external links) OR explicit fallback
   - `demoWorkflows` <- from `ivy-readme-demo-workflows`
   - `rolesSection` <- from `ivy-readme-key-features` (extracted from config/roles.xml)
   - `setupSection` <- from `ivy-readme-key-features` (setup steps only, no roles/openapi inline)
   - `variablesSection` <- from `ivy-readme-key-features`
   - `openApiSection` <- from `ivy-readme-key-features` (will be placed in Setup by assembler, not separate section)
   - `restClientsSection` <- extracted from `<mainModule>/config/rest-clients.yaml` for rendering under `### Rest Clients`
   - `webServicesSection` <- extracted from `<mainModule>/config/webservice-clients.yaml` for rendering under `### Web Services`
   - `callableSubSection` <- from `callable-sub-listing`
   - `formComponentSection` <- from `form-components-listing`
   - `mavenArtifactSection` <- from `maven-artifact-listing`
   - `productImageSection` <- from `product-image-summary`

2.2 Pre-assembly validation gate (required):
   - Validate the execution ledger before fragment validation.
   - The ledger MUST contain exactly these required extractor entries before assembly: `ivy-readme-discover-modules`, `ivy-readme-key-features`, `callable-sub-listing`, `form-components-listing`, `ivy-readme-demo-workflows`, `maven-artifact-listing`, `product-image-summary`.
    - `product-image-summary` MUST be present in the ledger for every run, regardless of whether images are ultimately found.
   - For each required extractor entry, verify all of the following:
     - `readSkillMd=yes`
     - `extractionAttempted=yes`
     - `filesScanned` is present and non-empty unless the extractor's documented scope genuinely does not require file reads
     - `fragmentsProduced` contains at least one mapped fragment name or an explicit normalized `missing` fragment name
   - If any required extractor entry is missing or fails these checks, treat the run as invalid and DO NOT assemble.
   - Validate all mandatory fragment mappings exist and are structurally valid (`section`, `content`, `status`).
   - If validation fails, normalize invalid/missing entries into `missing` fragments and continue.
   - **Acceptance check (mandatory)**: if `<mainModule>/config/rest-clients.yaml` contains an OpenAPI spec URL (`OpenAPI.SpecUrl`), `openApiSection` MUST NOT be normalized to `missing`.
   - **Acceptance check (mandatory)**: when `<mainModule>/config/webservice-clients.yaml` contains at least one `WebServiceClients.*.OpenAPI.SpecUrl`, `webServicesSection` MUST NOT be normalized to `missing`.
   - **Acceptance check (mandatory)**: when `<mainModule>/config/webservice-clients.yaml` has service entries but none contain `OpenAPI.SpecUrl`, `webServicesSection` MUST be normalized to `missing`.
   - **Acceptance check (mandatory)**: when `<mainModule>/config/rest-clients.yaml` contains at least one `RestClients.*.OpenAPI.SpecUrl`, `restClientsSection` MUST NOT be normalized to `missing`.
   - **Acceptance check (mandatory)**: when `<mainModule>/config/rest-clients.yaml` has `RestClients` entries but none contain `OpenAPI.SpecUrl`, `restClientsSection` MUST be normalized to `missing`.
   - Always create or update `README.md` when assembly is available.

2.3 Dependency fallback (required):
   - If a sub-skill script cannot run due to missing tooling (e.g., `jq`) or module path mismatch, parse repository source files directly and produce equivalent fragment output.
   - For `restClientsSection`, source parsing is the primary path in this skill and MUST emit only OpenAPI-spec bullets from `OpenAPI.SpecUrl`.
   - For `webServicesSection`, source parsing is the primary path in this skill and MUST emit only OpenAPI-spec bullets from `OpenAPI.SpecUrl`.
   - Keep the same fragment contract and section mapping; do not stop the flow.
   - Continue to `ivy-readme-assemble` with available + normalized fragments in the same run.

3. Rebuild output rules:
   - Assemble using schema order from `output-format.md`.
   - Treat `README.md` target content as non-authoritative in every run. Never merge with existing target-file content; always compose a fresh document from the fragment map and overwrite the target file in full.
   - Do not prepend, parse, or copy any product description block from README.md.
   - Inject sub-skill outputs verbatim using the contract defined in `output-format.md`.
   - If a Demo Workflows section is present in docs or can be inferred from demo process files, inject it as a subheading under Demo.
   - Include a Demo intro/body paragraph before Demo Workflows when available (`demoIntroSection`).
   - Keep Setup concise; do not render full raw YAML configuration payloads (for example complete `app.yaml` samples) in generated setup steps.
   - Setup may be sourced from parent module docs, but before assembly any fenced config/code blocks must be summarized into short action steps for the product README.
   - If setup source contains large YAML/code snippets, summarize the required keys as short instructions instead of copying the snippet.
   - Keep variables under Setup as a `### Variables` subsection by default; do not create a standalone `## Variables` section unless style profile explicitly requires it.
   - If `variablesSection` is genuinely missing after extraction, do not render any fallback sentence under `### Variables`.
   - Do not drop sections when a fragment is empty, except inside `## Components` where empty subsections must be omitted.
   - Apply assembler fallback rules: keep heading + inject placeholder if status is `missing` or content is empty.
   - Enforce coverage gate: when fragment declares `requiredSubsections`, missing subsections must be reported and rendered with explicit placeholders.
   - Preserve the fenced block exactly:

      ```
      @variables.yaml@
      ```
      Do not replace this placeholder with expanded YAML content.
      If the token is emitted inline, normalize it to the fenced block above before assembly.
   - Always render `## Components` as parent heading.
      - Within `## Components`, always render `### Callable Subprocesses`, `### Dialog Components`, `### Rest Clients`, `### Web Services`, and `### Maven Artifacts` in this order.
         - Canonical render rule: `### Rest Clients` is sourced from `restClientsSection` (`config/rest-clients.yaml`).
         - Canonical render rule: `### Web Services` is sourced from `webServicesSection` (`config/webservice-clients.yaml`).
    - If any of these subsections is missing, render one bullet fallback directly under that subsection heading (do not append a combined sentence at the end):
       - `- For this market extension we do not provide any Callable Subprocesses.`
       - `- For this market extension we do not provide any Dialog Components.`
      - `- For this market extension we do not provide any Rest Clients.`
       - `- For this market extension we do not provide any Web Services.`
       - `- For this market extension we do not provide any Maven Artifacts.`
         - Rest Clients fallback is allowed only when no rest-clients evidence is found after a genuine extraction attempt.
         - Web Services fallback is allowed only when no webservice-clients evidence is found after a genuine extraction attempt.
   - **Rest Clients rendering gate (mandatory):** `### Rest Clients` must be rendered from `restClientsSection` as OpenAPI spec bullets only.
      - Allowed shape per entry: `- **OpenAPI:** [<SpecLabel>](<OpenAPI.SpecUrl>)`
         - The `<SpecLabel>` SHOULD be a short, safe display label derived from the RestClient `Name` with " specification" appended (for example `DeepL API specification`) or, if `Name` is not suitable, derived from the host token of the SpecUrl. If no safe label can be derived, use the raw URL as link text.
         - Required subsection block shape:
            ```markdown
            ### Rest Clients

            - **OpenAPI:** [<SpecLabel>](<OpenAPI.SpecUrl>)
            ```
         - Do not add descriptive prose before/after the bullet.
      - If an entry has no `OpenAPI.SpecUrl`, skip that entry and do not fallback to `Url`.
      - Forbidden in rendered Rest Clients content: `Url`, `Icon`, `Features`, `Properties`, `Namespace`, raw client IDs, or nested bullets under a client label.
         - Exactness validation (mandatory): every non-empty line in `restClientsSection.content` must match `^- \*\*OpenAPI:\*\* \[[^\]]+\]\([^\)]+\)$`.
      - If forbidden fields are present, the run is invalid and the subsection must be regenerated from OpenAPI spec links only.
       - **Web Services rendering gate (mandatory):** `### Web Services` must be rendered from `webServicesSection` as OpenAPI spec bullets only.
          - Allowed shape per entry: `- **OpenAPI Spec:** [<SpecLabel>](<OpenAPI.SpecUrl>)`
         - Required subsection block shape:
            ```markdown
            ### Web Services

            - **OpenAPI Spec:** [<SpecLabel>](<OpenAPI.SpecUrl>)
            ```
         - Do not add descriptive prose before/after the bullet.
         - If an entry has no `OpenAPI.SpecUrl`, skip that entry and do not fallback to `Url`, `Wsdl`, or `WsdlUrl`.
         - Forbidden in rendered Web Services content: `Url`, `Wsdl`, `WsdlUrl`, `Name`, `Properties`, service IDs, or nested bullets under a service label.
         - Exactness validation (mandatory): every non-empty line in `webServicesSection.content` must match `^- \*\*OpenAPI Spec:\*\* \[[^\]]+\]\([^\)]+\)$`.
         - If forbidden fields are present, the run is invalid and the subsection must be regenerated from OpenAPI spec links only.
   - Never render `## Callable Subprocesses` as a top-level section.
   - **CRITICAL**: Remove any footer metadata, generation timestamps, skill attribution comments, or output contract references from final output.
   - Only footer-free content appears in README.md.
   - Do not add helper sections such as `## Notes`, `## Generation Info`, or other non-template metadata headings.

4. Sub-skill quality criteria (enforced):
   - **ivy-readme-key-features**: Extract product intro with image + external links, benefit-driven key features (6 items), roles from config/roles.xml, complete Setup section with steps, the fixed literal variables placeholder block `@variables.yaml@`, OpenAPI spec info (used in Setup), and optional auth/runtime sections exactly as documented.
   - **ivy-readme-key-features**: Do not synthesize `### Azure App` heading unless that heading exists in source docs. Keep setup headings source-driven.
   - **ivy-readme-demo-workflows**: Extract demo intro paragraph + external market links BEFORE workflow steps, include module grouping with #### headers, use friendly non-technical step-by-step language, and never output empty module headings.
   - **ivy-readme-demo-workflows**: Normalize workflow heading names by stripping leading numeric prefixes from `config.request.name` (for example `1. ...`, `1.1 ...`) before rendering `#####` workflow headings.
   - **ivy-readme-demo-workflows**: Prefer `https://market.axonivy.com/...` links over local relative links when both are available in sources.
   - **form-components-listing**: Extract component `Fields` from dialog `start` signature parameters in `<mainModule>/src_hd/**/*Process.p.json`; if no start params exist, render `- **Fields:** - (none)`.
   - **callable-sub-listing**: Include exact signatures with full parameter names and types (e.g., `writeMail(msgraph.connector.NewMail mail) -> ...`)
   - **maven-artifact-listing**: Prefer resolved `artifactId` values from `product.json`; use template variables (for example `@artifact.id@`) only when the source itself uses placeholders.
   - **restClientsSection extraction**: Read `<mainModule>/config/rest-clients.yaml` and render only OpenAPI spec links from `RestClients.*.OpenAPI.SpecUrl`.
         - Output must be markdown bullets in this exact form only:
            - `- **OpenAPI:** [<SpecLabel>](<OpenAPI.SpecUrl>)`
         - Derive `<SpecLabel>` from the RestClient `Name` field with " specification" appended (e.g., `DeepL API specification`), or from the hostname if `Name` is not suitable. If no safe label can be derived, use the raw URL.
      - Do not render expanded rest-client metadata (`Url`, `Icon`, `Features`, `Properties`, `Namespace`) in the final subsection.
      - If no `OpenAPI.SpecUrl` exists after a genuine extraction attempt, normalize `restClientsSection` to `missing` and allow the canonical fallback sentence.
   - **webServicesSection extraction**: Read `<mainModule>/config/webservice-clients.yaml` and render only OpenAPI spec links from `WebServiceClients.*.OpenAPI.SpecUrl`.
      - Output must be markdown bullets in this exact form only:
         - `- **OpenAPI Spec:** [<SpecLabel>](<OpenAPI.SpecUrl>)`
      - Do not render expanded web-service metadata (`Url`, `Wsdl`, `WsdlUrl`, `Name`, `Properties`) in the final subsection.
      - If no `OpenAPI.SpecUrl` exists after a genuine extraction attempt, normalize `webServicesSection` to `missing` and allow the canonical fallback sentence.
   - All skills must preserve inline comments, documentation, and image references from sources

5. Optional quality check:
   - Report missing headings and missing media references (`images/...`) as coverage gaps.
   - Report missing required subsections declared by fragments as fidelity gaps.
   - Report style drifts from inferred style profile (list numbering, OpenAPI presentation, callable-sub formatting).
   - The check should focus on section completeness and section placement, not exact wording equality.

6. Translation:
   - APPLY SKILL `translate-readme` to generate `README_DE.md` from generated `README.md`.
   - **MANDATORY**: If the runtime cannot invoke `translate-readme` as a callable unit:
      1. Read `translate-readme` SKILL.md to obtain its translation logic.
      2. Execute the logic directly: parse README.md line-by-line (preserve URLs/code blocks, translate prose/headings).
      3. Write README_DE.md.
      4. Validate all sections from README.md are present in README_DE.md.
   Implementation for AI orchestration (mandatory)
------------------------------------------------
**CRITICAL: When invoked, AI MUST execute the entire flow in ONE PASS without stopping between steps:**

1. **Parallel sub-skill execution (batch 1 - independent):**
   - First invoke `ivy-readme-discover-modules` to resolve `mainModule`, `demoModules`, and `productModule`.
   - If `demoModules` is empty and repository is multi-module, perform the generic `RequestStart` inference fallback before invoking dependent sub-skills.
   - Then invoke in parallel: `ivy-readme-key-features`, `callable-sub-listing`, `form-components-listing`, `ivy-readme-demo-workflows`, `maven-artifact-listing`, `product-image-summary` using the resolved module paths.
   - **MANDATORY PRE-EXECUTION GATE**: For EACH sub-skill listed above, before producing any fragment output:
     1. Read that sub-skill's `SKILL.md` file to obtain its extraction logic.
     2. Execute the documented extraction logic directly against the repository source files (process JSON files, config YAML, src_hd, product.json, setup docs, etc.).
     3. Only after a genuine extraction attempt may a fragment be marked as `missing`.
     4. A fragment MUST NOT be normalized to `missing` solely because the sub-skill cannot be invoked as a callable tool. The extraction logic from SKILL.md MUST be executed manually instead.
       5. Record an execution ledger entry immediately after the extraction attempt, including `filesScanned` and `fragmentsProduced`.
    - **MANDATORY BATCH-1 COMPLETENESS GATE**: Batch 1 is incomplete until the execution ledger contains entries for all required extractors named in section 2.2. Missing ledger entries are a hard failure and assembly MUST NOT start.
   - Collect all stdout outputs in a single collection.
   - Do NOT wait for user feedback or confirmation between invocations.
   - Do NOT present an interim plan/result to the user before assembly is complete.

2. **Fragment collection (batch 2 - sequential post-processing):**
   - Materialize the execution ledger into a compact pre-assembly checklist for internal validation in this exact order: `skill | readSkillMd | extractionAttempted | filesScanned | fragmentsProduced | status`.
   - Parse all sub-skill outputs into fragment objects mapping to mandatory fragment names (see section 2.1).
   - For any sub-skill whose extraction logic was executed and genuinely produced no content (e.g., no `src_hd` directory, no matching process files), auto-normalize to `{ status: "missing", section: "...", content: "- No information was delivered for this section." }`.
   - Exception: when `section = "variablesSection"`, normalize to `{ status: "missing", section: "variablesSection", content: "" }` so `### Variables` has no fallback sentence.
   - **FORBIDDEN**: Normalizing a fragment to `missing` without first reading the sub-skill SKILL.md and attempting source-file extraction. This is a violation equivalent to skipping the sub-skill entirely.
   - Build complete fragment map WITHOUT user interaction.
   - Populate omitted fragments (`openApiSection`, `restClientsSection`, `webServicesSection`, `productImageSection`) with normalized `missing` entries instead of asking whether they should be skipped, but only after their documented extraction logic has been attempted.

3. **Assembly (batch 3 - single execution):**
   - Invoke `ivy-readme-assemble` ONCE with complete fragment map.
   - Assemble writes `README.md` directly to disk.
   - No human review or patching after assembly.

4. **Translation (batch 4 - single execution):**
   - Invoke `translate-readme` ONCE to create/update `README_DE.md` from the generated `README.md`.
   - Do not ask for confirmation.

5. **Completion:**
   - Report the execution ledger or checklist for all required extractors so it is visible which sub-skills were executed, which files were scanned, and which fragments were produced.
   - Report which fragments were found vs normalized to `missing`.
   - Report output path of generated `README.md`.
   - Report output path of generated `README_DE.md`.
   - Report any assembly warnings/gaps (missing subsections, coverage gaps).

**Enforcement rules:**
- If step 1 sub-skills are split across multiple AI responses → VIOLATION (must be single batch).
- If user confirmation is requested between steps 1-3 → VIOLATION (autonomous policy violated).
- If `README.md` is hand-edited or patched after assembly → VIOLATION (assembly-only rule).
- If `README_DE.md` is hand-edited or patched instead of regenerated via `translate-readme` → VIOLATION.
- If generated output is appended to existing content (resulting in duplicated full document blocks) → VIOLATION.
- If `README.md` is not written at all → VIOLATION (must always generate with fragments, even `missing` ones).
- If `README_DE.md` is not written at all → VIOLATION.
- If the runtime cannot invoke a sub-skill and the AI does not immediately execute that sub-skill's documented logic itself → VIOLATION.
- If ANY fragment is normalized to `missing` without a prior read of that sub-skill's SKILL.md and a genuine attempt to extract from repository source files → VIOLATION (extraction-before-normalization rule).
- If assembly starts while the execution ledger is incomplete, missing a required extractor, or lacks `filesScanned` evidence for a required extractor → VIOLATION.
- If `product-image-summary` is treated as optional, skipped for convenience, or deferred until after assembly → VIOLATION.
- If `product-image-summary` is absent from the execution ledger when canonical image folders or external README images exist, the run is invalid and MUST be treated as failed rather than silently continuing.
- If the AI produces a README where ALL or MOST sections contain the fallback placeholder, and the repository contains discoverable source files (process JSON, variables.yaml, setup docs, product.json) → VIOLATION (silent skip of extraction step).

Invariants
----------
- Default file created/updated is `<discovered-product-module>/README.md`.
- Default translated file created/updated is `<discovered-product-module>/README_DE.md`.
- Generation must be performed via sub-skills and assembly.
- No cache usage.
- Big flow must be split into small independent skills.
- The flow must be generic for multi-module and single-module Axon Ivy/Maven repositories.
- Empty or missing fragment outputs must still produce visible section placeholders in the assembled README.
- Generated `README.md` content is always independent from any pre-existing `README.md` content.
- Generated `README_DE.md` must come from translating the generated `README.md` in the same run.
- If modular extraction is incomplete, generation still writes `README.md` using placeholder-backed fragments and reports gaps.
- External image URLs found in source README files are valid image evidence and may be embedded without local file copies.