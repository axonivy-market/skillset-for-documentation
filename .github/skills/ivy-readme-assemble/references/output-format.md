# Ivy README Assemble Output Format

## Purpose

Define the canonical fragment contract, section order, and fallback rendering rules used by `ivy-readme-assemble`.

## Input Contract

Assembler receives:

```json
{
  "targetReadme": "<path>",
  "fragments": {
    "productDescriptionSection": {"section":"productDescriptionSection","status":"success|partial|missing","content":"..."},
    "keyFeatures": {"section":"keyFeatures","status":"success|partial|missing","content":"..."},
    "demoIntroSection": {"section":"demoIntroSection","status":"success|partial|missing","content":"..."},
    "demoWorkflows": {"section":"demoWorkflows","status":"success|partial|missing","content":"..."},
    "rolesSection": {"section":"rolesSection","status":"success|partial|missing","content":"..."},
    "openApiSection": {"section":"openApiSection","status":"success|partial|missing","content":"..."},
    "setupSection": {"section":"setupSection","status":"success|partial|missing","content":"..."},
    "variablesSection": {"section":"variablesSection","status":"success|partial|missing","content":"..."},
    "callableSubSection": {"section":"callableSubSection","status":"success|partial|missing","content":"..."},
    "formComponentSection": {"section":"formComponentSection","status":"success|partial|missing","content":"..."},
    "restClientsSection": {"section":"restClientsSection","status":"success|partial|missing","content":"..."},
    "webServicesSection": {"section":"webServicesSection","status":"success|partial|missing","content":"..."},
    "mavenArtifactSection": {"section":"mavenArtifactSection","status":"success|partial|missing","content":"..."},
    "productImageSection": {"section":"productImageSection","status":"success|partial|missing","content":"..."}
  }
}
```

Each fragment may additionally contain:
- `preserveMode`: `verbatim|structured`
- `requiredSubsections`: string array
- `completeness`: `full|partial`

## Canonical README Section Order

Assembler must render sections in this order:

1. Product description (`productDescriptionSection`)
2. Key features (`keyFeatures`)
3. Demo
   - Intro/body (`demoIntroSection`)
   - Heading `### Demo Workflows`
   - Workflows (`demoWorkflows`)
4. Setup
   - Roles bullet (`rolesSection`)
   - OpenAPI bullet (`openApiSection`)
   - Setup steps (`setupSection`)
   - Heading `### Variables`
   - Variables block (`variablesSection`)
5. Components
   - `### Callable Subprocesses` (`callableSubSection`)
   - `### Dialog Components` (`formComponentSection`)
  - `### Rest Clients` (`restClientsSection`)
   - `### Web Services` (`webServicesSection`)
   - `### Maven Artifacts` (`mavenArtifactSection`)

## Fallback Rules

Default fallback line for missing/empty content:

- `- No information was delivered for this section.`

Components-specific fallback lines:

- Callable Subprocesses: `- For this market extension we do not provide any callable subprocesses.`
- Dialog Components: `- For this market extension we do not provide any dialog components.`
- Rest Clients: `- For this market extension we do not provide any rest clients.`
- Web Services: `- For this market extension we do not provide any web services.`
- Maven Artifacts: `- For this market extension we do not provide any maven artifacts.`

## Components Placeholder Shape

Assembler must support this exact placeholder structure:

```markdown
### Rest Clients

{{restClientsSection}}

### Web Services

{{webServicesSection}}
```

Variables special rule:
- If `variablesSection` is missing/empty, render `### Variables` heading with no fallback text.

OpenAPI special rule:
- If `openApiSection` is missing/empty, render exactly:
  - `- **OpenAPI:** No information was delivered for this section.`

## Injection Rules

- For `status=success|partial`, inject `content` verbatim.
- For `status=missing` or empty `content`, keep heading and render fallback according to rules above.
- If `preserveMode=verbatim`, do not renumber lists or normalize blocks.
- If `preserveMode!=verbatim`, list-number normalization is allowed.
- Remove HTML status comments from fragment body before final write.
- Preserve fenced block containing `@variables.yaml@` exactly.

## Image Rules

- Do not create standalone `## Images` unless fragment sets `standalone=true`.
- When `standalone=false`, place image snippets by placement hints (`intro`, `demo`, `setup`, `demo:workflow-...`).
- Validate image path safety; skip malformed/unresolvable paths.

## Output Requirements

- Full-file overwrite (truncate then write), no append mode.
- Final file must contain exactly one top-level document start (`# ...`).
- No footer metadata (timestamps, skill names, generation comments).
