---
name: generate-ivy-readme-components-section
description: >
  Generate and update only the ## Components section (Callable Subprocesses,
  Dialog Components, Web Services, Maven Artifacts) in both README.md (English)
  and README_DE.md (German) for an Axon Ivy Maven product module.
  Invoke with: /generate-ivy-readme-components-section
argument-hint: '[optional: workspace root path] [optional: mainModule] [optional: targetReadme]'
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
- If `README_DE.md` does not yet exist, create it with only the translated Components section.
- If `README.md` does not yet exist, create it with only the Components section (no other sections).

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

### Step 2 — Extract fragments (run in parallel)

For each sub-skill below, read that sub-skill's `SKILL.md` and execute its
extraction logic directly against repository source files:

1. **callableSubSection** — scan `<mainModule>/processes/**/*.p.json`
   - Keep only `CALLABLE_SUB` process files.
   - For each `CallSubStart`, extract: signature name, full input param types+names,
     full result param types+names, `visual.description` if present.
   - Format as documented in `callable-sub-listing` SKILL.md.
   - If none found: `status: missing`, content: `- No connector processes delivered by this extension.`

2. **formComponentSection** — scan `<mainModule>/src_hd/**`
   - Extract `.d.json` fields (name, type) as source-of-truth.
   - Extract CMS descriptions from `cms_en.yaml` where available.
   - Format as documented in `form-components-listing` SKILL.md.
   - If none found: `status: missing`, content: `- No form components delivered by this extension.`

3. **openApiSection** — read `<mainModule>/config/rest-clients.yaml`
   - Extract `OpenAPI.SpecUrl` and `OpenAPI.Namespace` for every entry.
   - Present as bullet list: `- **[ClientName]:** [SpecUrl] (Namespace: [Namespace])`.
   - If none found: `status: missing`, content: `- No information was delivered for this section.`

4. **mavenArtifactSection** — read `<productModule>/product.json`
   - Extract `maven-dependency` and `maven-import` artifacts ordered by root `pom.xml` module order.
   - Mark `maven-import` artifacts with `importInWorkspace == false` as optional.
   - Render numbered list with XML `<dependency>` blocks (no `<version>` element).
   - If none found: `status: missing`, content: `- No information was delivered for this section.`

### Step 3 — Build English Components section

Assemble the following Markdown block from extracted fragments.
Use the fallback placeholder `- No information was delivered for this section.`
for any fragment whose status is `missing`.

```markdown
## Components

### Callable Subprocesses

{{callableSubSection.content}}

### Dialog Components

{{formComponentSection.content}}

### Web Services

{{openApiSection.content}}

### Maven Artifacts

{{mavenArtifactSection.content}}
```

### Step 4 — Inject English Components section into README.md

1. Read `targetReadme`.  
2. Locate the existing `## Components` heading.  
   - If found: replace from the `## Components` line through the end of the file
     (or through the line immediately before the next `## ` heading at the same depth)
     with the new Components block.  
   - If not found: append the new Components block at the end of the file.  
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
| `### Web Services` | `### Web-Services` |
| `### Maven Artifacts` | `### Maven-Artefakte` |
| `- Input:` | `- Eingaben:` |
| `- Result:` | `- Ergebnis:` |
| `(no description available)` | `(keine Beschreibung verfügbar)` |
| `- No information was delivered for this section.` | `- Es wurden keine Informationen für diesen Abschnitt geliefert.` |
| `- No connector processes delivered by this extension.` | `- Diese Erweiterung liefert keine Connector-Prozesse.` |
| `- No form components delivered by this extension.` | `- Diese Erweiterung liefert keine Formularkomponenten.` |
| `*(optional)*` | `*(optional)*` |
| `*(dependency)*` | `*(Abhängigkeit)*` |
| `Reusable form component` | `Wiederverwendbare Formularkomponente` |
| `(inferred purpose)` | `(abgeleiteter Zweck)` |
| `Component type:` | `Komponententyp:` |
| `Fields:` | `Felder:` |
| `Namespace:` | `Namespace:` |
| `Where used:` | `Verwendung:` |
| `Purpose:` | `Zweck:` |

Apply tone: `du`/`dein`, short direct sentences, benefit-led bullets, no passive voice.

### Step 6 — Inject German Components section into README_DE.md

Same boundary-replacement algorithm as Step 4, but applied to `targetReadmeDe`.

If `README_DE.md` does not yet exist, create it containing only the translated
Components block.

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
bash ./.github/skills/generate-ivy-readme-components-section/scripts/generate-components-section.sh \
  <mainModule> <productModule>

# Examples:
bash ./.github/skills/generate-ivy-readme-components-section/scripts/generate-components-section.sh \
  docusign-connector docusign-connector-product

bash ./.github/skills/generate-ivy-readme-components-section/scripts/generate-components-section.sh \
  docusign-connector docusign-connector-product \
  docusign-connector-product/README.md \
  docusign-connector-product/README_DE.md
```

## Quality criteria

- Scope strictly limited to the `## Components` section.
- Callable sub signatures are extracted with full parameter names and types.
- Form component fields come from `.d.json` files only (no fabrication).
- Maven artifact blocks contain `<groupId>`, `<artifactId>`, `<type>` only (no `<version>`).
- German section uses project CMS translations when available; falls back to the
  translation table defined in Step 5.
- Deterministic output: same source files → same output on every run.
- No external HTTP calls; all data from local repository files.
