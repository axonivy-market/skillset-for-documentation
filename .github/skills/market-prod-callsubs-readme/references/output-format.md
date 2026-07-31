# Output Format Reference

## Sub-Skill Output Contract

All sub-skills must follow a standardized output contract to ensure consistent assembly and prevent missing sections.

### JSON Fragment Contract

```json
{
  "section": "string (required)",
  "content": "string or markdown (required, may be empty)",
  "status": "enum: success|partial|missing",
  "preserveMode": "enum: verbatim|structured (optional, default: structured)",
  "completeness": "enum: full|partial (optional)",
  "requiredSubsections": ["subsection heading 1", "subsection heading 2"] (optional),
  "styleProfile": {
    "callableSubFormat": "enum: signature-bullets|inline-heading (optional)",
    "openApiFormat": "enum: image-link|text-link (optional)",
    "orderedListStyle": "enum: all-1|incremental (optional)"
  },
  "evidence": ["file1", "file2"] (optional, for debugging)
}
```

**Fields:**
- **section**: Identifier for the README section (e.g., `productDescriptionSection`, `keyFeatures`, `demoIntroSection`, `demoWorkflows`, `setupSection`, `variablesSection`, `callableSubSection`, `formComponentSection`, `restClientsSection`, `webServicesSection`, `openApiSection`, `mavenArtifactSection`).
- **content**: Raw Markdown text. Must be present even if empty; never omit the field.
- **status**: `success` (full content), `partial` (incomplete), `missing` (no content found).
- **preserveMode**: `verbatim` preserves source blocks exactly (long setup/auth sections), `structured` allows deterministic restructuring.
- **completeness**: `full` means all expected subsections were found, `partial` means at least one expected subsection is missing.
- **requiredSubsections**: Used by assembler quality gate to ensure critical subsections are not silently dropped.
- **styleProfile**: Optional formatting preference inferred from existing repository documentation style.
- **evidence**: List of files/sources scanned. Helps debugging if content is unexpectedly empty.

### Markdown Fragment Contract (Legacy Compatibility)

For this README generation flow, JSON fragment output is the required contract.
Plain Markdown-only output is legacy compatibility mode and should be normalized to the JSON fragment contract before assembly.

```json
{
  "section": "demoWorkflows",
  "content": "#### Calendar (module)\n\n- Run the readCalendar demo...\n\n<!-- status: success -->",
  "status": "success"
}
```

If a skill still emits plain Markdown, the orchestrator must wrap it into a JSON fragment with the correct section key before passing it to assembly.

### Assembler Fallback Rules

When the assembler receives a fragment:

1. **If status is `success` or `partial`**: Inject `content` verbatim.
2. **If status is `missing` or content is empty**: Keep section heading and inject `- No information was delivered for this section.`
3. **Never omit a section heading** from the template.
4. **Never include footer metadata** - Remove generation timestamps, skill attribution comments, or output contract references from final output.
5. **Coverage gate before write**: if fragment declares `requiredSubsections`, mark fragment as `partial` when any are missing and inject explicit placeholder lines for each missing subsection.
6. **Honor `preserveMode=verbatim`** for setup/auth/variables blocks to avoid dropping long instructional content.
7. **Placement rule**: `variablesSection` should be rendered under `## Setup` as `### Variables` unless style profile explicitly requires standalone placement.
8. **Variables missing rule**: If `variablesSection` is `missing` or empty, render no fallback sentence under `### Variables`.
8. **Demo rule**: Render `demoIntroSection` under `## Demo`, then always render heading `### Demo Workflows` before injecting `demoWorkflows` fragment content (or fallback if missing). The assembler MUST always render heading `### Demo Workflows` after `demoIntroSection`, even if the `demoWorkflows` fragment is missing or empty.
9. **Demo link preference**: Prefer `https://market.axonivy.com/...` links when both market and local relative links are present for the same demo service.
10. **Components hierarchy**: Always render `## Components` as parent heading. Render `Callable Subprocesses`, `Dialog Components`, `Rest Clients`, `Web Services`, and `Maven Artifacts` as `###` subsections in canonical order.
11. **Canonical Rest Clients mapping**: `### Rest Clients` is rendered from `restClientsSection` content (extracted from `config/rest-clients.yaml`).
12. **Canonical Web Services mapping**: `### Web Services` is rendered from `webServicesSection` content (extracted from `config/webservice-clients.yaml`).
13. **Web Services fallback condition**: show `- For this market extension we do not provide any Web Services.` only when no webservice-clients evidence exists after a genuine extraction attempt.

---

## README Template Format

The generated README should follow this format:

```markdown
# Product Name

Product description: a simple, non-technical summary of the product's value proposition and capabilities. This should be accessible to non-technical stakeholders and marketing-oriented, avoiding technical jargon.

**Key features**

- Concise bullet point describing a key feature of the product.

## Demo

Step-by-step user workflow derived from the demo module(s). This should describe how a user would interact with the product in a real-world scenario, based on the processes and assets found in the demo module(s).

### Demo Workflows

Assembler injects demoIntroSection under Demo, then injects demoWorkflows under Demo Workflows.

## Setup

Technical setup instructions derived from the main module's configuration definitions. This should include:
- Required environment and configuration steps discovered from source documentation/configuration
- Authentication/authorization setup if present
- API/endpoint setup details if present
- Additional notes and troubleshooting

### Variables

{{variableSection}}

If no variables are found after a genuine extraction attempt, keep `### Variables` without adding fallback text.

## Components

### Callable Subprocesses

{{callableSubSection}}

### Dialog Components

{{formComponentSection}}

### Rest Clients

{{restClientsSection}}

### Web Services

{{webServicesSection}}

### Maven Artifacts

{{mavenArtifactSection}}
```

**Template Rules:**
- Preserve exact product description and key features from source
- Include the exact literal fenced block containing @variables.yaml@ in variables section
- Never include footer metadata or generation timestamps
- All sections are required; use fallback content if missing
- Prefer repository-native style profile when detected (list numbering, OpenAPI section style, callable-sub formatting)
- For this repository flow, all sub-skills must provide JSON fragments where `content` contains markdown.
