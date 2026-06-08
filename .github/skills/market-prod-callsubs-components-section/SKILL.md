---
name: market-prod-callsubs-components-section
description: >
  Generate and update only the ## Components section (Callable Subprocesses,
  Dialog Components, Web Services, Maven Artifacts) in both README.md (English)
  and README_DE.md (German) for an Axon Ivy Maven product module.
  Invoke with: /market-prod-callsubs-components-section
argument-hint: 'Generate and update only the ## Components section in README.md and README_DE.md for the product module.'
user-invocable: true
---

# Generate Ivy README – Components Section

Regenerate the `## Components` section **only** in:
- `<productModule>/README.md` (English)
- `<productModule>/README_DE.md` (German)

All other sections in both files are preserved byte-for-byte.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `workspacePath` | No | current workspace | Root of the repository |
| `mainModule` | No | discovered from `pom.xml` | Main Axon Ivy module path |
| `productModule` | No | discovered from `pom.xml` | Product module path (write target) |
| `targetReadme` | No | `<productModule>/README.md` | Full path to English README |
| `targetReadmeDe` | No | `<productModule>/README_DE.md` | Full path to German README |

## Autonomous execution policy (mandatory)

- Run fully non-interactive.
- Derive all paths automatically from root `pom.xml` when not provided.
- Execute extraction sub-skills directly (read their `SKILL.md` and scan source files)
  if they cannot be invoked as callable tools.
- Never stop between extraction and write steps.
- Always overwrite the `## Components` section in **both** README files in a single pass.
- Never create new README files in this skill.
- Fail fast if either `README.md` or `README_DE.md` does not exist.
- Fail fast if `## Components` (EN) or `## Komponenten` (DE) heading is missing.

## Sub-skills used

| Sub-skill | Fragment produced |
|-----------|------------------|
| `ivy-readme-discover-modules` | `productModule`, `mainModule`, `demoModules` |
| `callable-sub-listing` | `callableSubSection` |
| `form-components-listing` | `formComponentSection` |
| `ivy-readme-key-features` (openApiSection only) | `openApiSection` |
| `maven-artifact-listing` | `mavenArtifactSection` |

## Behavior / Steps

### Step 1 — Resolve module paths

Apply skill `ivy-readme-discover-modules` against root `pom.xml`.
Use `mainModule`, `productModule`.
Derive `targetReadme` and `targetReadmeDe` when omitted.

When `productModule` is not provided, the skill will select a module
directory that contains both `README.md` and `README_DE.md` and use that as
the `productModule`. If no such directory exists the skill will fail fast
and exit with an error (no fallback heuristics are applied).

### Step 2 — Extract fragments (run in parallel)

For each sub-skill below, read that sub-skill's `SKILL.md` and execute its
extraction logic directly against repository source files:

1. **callableSubSection** — scan `<mainModule>/processes/**/*.p.json`
   - Keep only `CALLABLE_SUB` process files.
   - For each `CallSubStart`, extract: signature name, full input param types+names,
     full result param types+names, `visual.description` if present.
   - Format as documented in `callable-sub-listing` SKILL.md.
  - If none found: `status: missing`, content: empty. The final fallback sentence is injected only in Step 3.

2. **formComponentSection** — scan `<mainModule>/src_hd/**`
  - Find dialog process files matching `*Process.p.json`.
  - Extract `Fields` from the process element where `config.signature == "start"`.
  - Use `config.input.params[]` (`name`, `type`, `desc`) from that `start` signature.
   - Extract CMS descriptions from `cms_en.yaml` where available.
  - `Component type` must be one of exactly three values only:
    - `Component dialog` when `.xhtml` contains `<cc:interface ...>`
    - `UI dialog` when `.xhtml` contains `<ui:composition ...>`
    - `Form dialog` when sibling file name matches `*.f.json`
    - If a component has no declared start params, render fields in one line as: `- **Fields:** - (none)`
   - Format as documented in `form-components-listing` SKILL.md.
  - If none found: `status: missing`, content: empty. The final fallback sentence is injected only in Step 3.

3. **openApiSection** — read `<mainModule>/config/rest-clients.yaml`
  - Extract only `OpenAPI.SpecUrl` for every entry.
  - Only accept `SpecUrl` values that start with `http://` or `https://`.
  - Render URLs only (no namespace, no image syntax, no additional metadata).
  - If none found: `status: missing`, content: empty. The final fallback sentence is injected only in Step 3.

4. **mavenArtifactSection** — read `<productModule>/product.json`
   - Extract `maven-dependency` and `maven-import` artifacts ordered by root `pom.xml` module order.
   - Mark `maven-import` artifacts with `importInWorkspace == false` as optional.
   - Render numbered list with XML `<dependency>` blocks (no `<version>` element).
  - If none found: `status: missing`, content: empty. The final fallback sentence is injected only in Step 3.

### Step 3 — Build English Components section

Assemble the `## Components` block from extracted fragments with these rules:
- Always render `## Components`.
- Always render all `###` subsection headings in this exact order: `Callable Subprocesses`, `Dialog Components`, `Web Services`, `Maven Artifacts`.
- For each subsection:
  - If fragment status is not `missing`, render normal fragment content.
  - If fragment status is `missing`, render exactly one fixed fallback bullet under that same subsection heading:
    - `### Callable Subprocesses` -> `- For this market extension we do not provide any Callable Subprocesses.`
    - `### Dialog Components` -> `- For this market extension we do not provide any Dialog Components.`
    - `### Web Services` -> `- For this market extension we do not provide any Web Services.`
    - `### Maven Artifacts` -> `- For this market extension we do not provide any Maven Artifacts.`
  - The fill-in label in this fixed sentence must be exactly one of: `Callable Subprocesses`, `Dialog Components`, `Web Services`, `Maven Artifacts`.
- Do not append one combined summary sentence at the end of `## Components`.

```markdown
## Components

### Callable Subprocesses
{{render callableSubSection content OR fixed fallback line for Callable Subprocesses}}

### Dialog Components
{{render formComponentSection content OR fixed fallback line for Dialog Components}}

### Web Services
{{render openApiSection content OR fixed fallback line for Web Services}}

### Maven Artifacts
{{render mavenArtifactSection content OR fixed fallback line for Maven Artifacts}}
```

### Step 4 — Inject English Components section into README.md

1. Read `targetReadme`.  
  - File must already exist.
2. Locate the existing `## Components` heading.  
   - If found: replace from the `## Components` line through the end of the file
     (or through the line immediately before the next `## ` heading at the same depth)
     with the new Components block.  
  - If not found: stop with error (do not append).  
3. Write the result back to `targetReadme`.  

Replacement boundary rules:
- The replacement region starts at the line that is exactly `## Components`
  (including any trailing whitespace).
- The replacement region ends at:
  - the line immediately before the next `## ` (level-2 heading), OR
  - the end of file if no further `## ` heading exists.
- Lines outside this region MUST NOT be modified.

### Step 5 — Build German Components section (translate)

Translate the assembled English Components block into German following the rules
from the `translate-readme` SKILL.md:

**Preserve verbatim (do not translate):**
- Inline code spans `` `like this` ``
- Fenced code blocks and their entire content
- Image paths inside `![…](path)` — keep the path byte-for-byte
- Hyperlink URLs inside `[…](url)` — keep the URL unchanged
- Markdown structural markers: `#`, `##`, `###`, `**`, `_`, `|`, `---`
- XML snippets (dependency blocks)
- Template variables and YAML keys

**Translate:**
- All prose and bullet point text
- Heading labels (e.g. `### Callable Subprocesses` → `### Aufrufbare Unterprozesse`)
- Image alt text
- Link display text
- Parameter descriptions

Standard German heading translations used in this section:

| English | German |
|---------|--------|
| `## Components` | `## Komponenten` |
| `### Callable Subprocesses` | `### Aufrufbare Unterprozesse` |
| `### Dialog Components` | `### Dialogkomponenten` |
| `### Web Services` | `### Webdienste` |
| `### Maven Artifacts` | `### Maven-Artefakte` |
| `- **Signature:**` | `- **Signatur:**` |
| `- Input:` | `- Eingaben:` |
| `- Result:` | `- Ergebnis:` |
| `- For this market extension we do not provide any callable subprocesses.` | `- Fuer diese Market Extension stellen wir keine aufrufbaren Unterprozesse bereit.` |
| `- For this market extension we do not provide any dialog components.` | `- Fuer diese Market Extension stellen wir keine Dialogkomponenten bereit.` |
| `- For this market extension we do not provide any web services.` | `- Für diese Market-Erweiterung stellen wir keine Webdienste bereit.` |
| `- For this market extension we do not provide any maven artifacts.` | `- Fuer diese Market Extension stellen wir keine Maven-Artefakte bereit.` |
| `*(optional)*` | `*(optional)*` |
| `*(dependency)*` | `*(Abhängigkeit)*` |
| `Reusable form component` | `Wiederverwendbare Formularkomponente` |
| `(inferred purpose)` | `(abgeleiteter Zweck)` |
| `Component type:` | `Komponententyp:` |
| `Fields:` | `Felder:` |
| `- **Fields:** - (none)` | `- **Felder:** - (keine)` |
| `Namespace:` | `Namespace:` |
| `Purpose:` | `Zweck:` |

Apply tone: `du`/`dein`, short direct sentences, benefit-led bullets, no passive voice.

### Step 6 — Inject German Components section into README_DE.md

Same boundary-replacement algorithm as Step 4, but applied to `targetReadmeDe`.

`README_DE.md` must already exist and already contain `## Komponenten`.
If file or heading is missing: stop with error (do not create or append).

### Step 7 — Report

Output a concise summary:

```
[OK]  callableSubSection   — <N callable subs from K files>
[OK]  formComponentSection — <M components>
[OK]  openApiSection       — <L entries>
[OK]  mavenArtifactSection — <J artifacts>
Written: <targetReadme>   (## Components section updated)
Written: <targetReadmeDe> (## Komponenten section updated)
```

Replace `[OK]` with `[PARTIAL]` when status=partial, and `[MISSING]` when status=missing.

## Execution guards

- Never modify any section other than `## Components` / `## Komponenten` in existing files.
- Never create `README.md` / `README_DE.md` from this skill.
- Never remove the trailing newline at the end of files.
- Never include generation timestamps, skill names, or HTML-comment metadata in the
  written Markdown output.
- Do not re-run other sections (Demo, Setup, Key Features) even if they are outdated.
- Always validate that `## Components` heading still exists in the written file after
  the operation.

## Scripts

One executable script is provided under `scripts/`:

| Script | Platform | Usage |
|--------|----------|-------|
| `generate-components-section.sh` | Bash (Linux / macOS / Git Bash / WSL) | See below |

### Bash

```bash
# From repository root:
bash ./.github/skills/market-prod-callsubs-components-section/scripts/generate-components-section.sh \
  <mainModule> <productModule>

# Examples:
bash ./.github/skills/market-prod-callsubs-components-section/scripts/generate-components-section.sh \
  docusign-connector docusign-connector-product

bash ./.github/skills/market-prod-callsubs-components-section/scripts/generate-components-section.sh \
  docusign-connector docusign-connector-product \
  docusign-connector-product/README.md \
  docusign-connector-product/README_DE.md
```

### Windows (keep using .sh)

If `bash` in PowerShell routes to WSL and fails because no distro is installed,
run the same `.sh` script via Git Bash executable directly:

```powershell
"C:\Program Files\Git\bin\bash.exe" ./.github/skills/market-prod-callsubs-components-section/scripts/generate-components-section.sh \
  idp-connector idp-connector-product
```

Notes:
- This keeps one single script (`.sh`) for all environments.
- No `.ps1` wrapper is required.

## Quality criteria

- Scope strictly limited to the `## Components` section.
- Callable sub signatures are extracted with full parameter names and types.
- Form component fields come from dialog `start` signatures (`config.input.params[]`); if none exist, render `- **Fields:** - (none)`.
- German translation must localize callable-sub labels (for example `Signature`, `Input`, `Result`) while preserving parameter types and names.
- Maven artifact blocks contain `<groupId>`, `<artifactId>`, `<type>` only (no `<version>`).
- German section uses project CMS translations when available; falls back to the
  translation table defined in Step 5.
- Deterministic output: same source files → same output on every run.
- No external HTTP calls; all data from local repository files.
