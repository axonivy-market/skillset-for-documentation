---
name: form-components-listing
description: Use when asked for a detailed summary, listing, or overview of form components in the project.
argument-hint: '[optional: path to main module src_hd directory, e.g. my-connector/src_hd]'
user-invocable: true
---


# Form Components Summary

Generate a concise, marketing-oriented summary of available form components from main module(s) in an Axon Ivy project.
Enforce one fixed markdown shape per component so downstream README assembly cannot drift.

## Inputs
- Optional path to the `src_hd` directory of the main module (e.g. `my-connector/src_hd`).
- If path is omitted, resolve to `<mainModule>/src_hd` from caller context; do not scan workspace root.
- Optional `includeDemoModules` flag (default: `false`). When `false`, scan only the resolved/provided main module path.

Performance note:
- For large monorepos, always pass `<mainModule>/src_hd` (or `<mainModule>`) explicitly.
- Workspace-root scans are not allowed in normal extraction flow.

## Extraction Rules

1. **Scan for form components** in `src_hd` directory
   - Default behavior must be main-module scoped only.
   - Do not scan unrelated workspace modules unless `includeDemoModules=true` is explicitly set by caller.
2. **For each component**, extract:
   - Component name and namespace (from folder or xhtml name)
  - Component type using these rules (only 3 allowed output values):
    - `Component dialog`: detect `<cc:interface ...>` in `.xhtml`
    - `UI dialog`: detect `<ui:composition ...>` in `.xhtml`
    - `Form dialog`: detect sibling file name matching `*.f.json`
   - **Component parameters (Fields):** prefer the dialog's `start` signature from the process definition.
     - For HTML dialogs, read `<mainModule>/src_hd/**/*Process.p.json` and find the `HtmlDialogStart` or equivalent element where `config.signature == "start"`.
     - Use `config.input.params[]` (`name`, `type`, `desc`) from that `start` signature as the canonical `Fields` list.
     - **Do not** use `.d.json` to populate the `Fields` list when a `start` signature is present; use `.d.json` only as a fallback or for other runtime fields.
   - Component purpose/description (from CMS or inline documentation)

3. **Data source priority (ENHANCED)**:
   - **Primary source:** Process `start` signature (`HtmlDialogStart.config.input.params[]`) for the `Fields` list
   - **Enrichment source 1:** `.cms` files for user-facing descriptions and component purpose
   - **Enrichment source 2:** `.xhtml` component definition files for:
     - Component type classification restricted to `Component dialog`, `UI dialog`, `Form dialog`
     - User-facing purpose hints from visible headings/labels when no CMS description exists
   - **Enrichment source 3:** `.d.json` dataclass files for runtime fields and comments (only used for enrichment, not to override `Fields` when `start` signature exists)
   - **Enrichment source 4:** Related process files (`processes/**/*.p.json`) for:
     - Which callable subs use this component (SubProcessCall references)
     - Which demo dialogs instantiate this component (DialogCall references)
   - **Enrichment source 5:** README/setup documentation for component usage context
  - **Synthesis rule (when sources incomplete):**
   - If `start` signature is absent, do NOT derive `Fields` from `.d.json`; instead mark `Fields` as not declared and set `status: partial`.
   - Use field names and types from the `start` signature to infer component purpose when available.
     - Example: "NewMail captures email metadata (recipients, subject, body) for mail operations"
     - Link to related callable sub or demo dialog
     - Mark status as `partial` when synthesized
   - Never fabricate component attributes—only synthesize purpose/context
  - If no components are found in scoped paths, synthesize a block: "No form components delivered by this extension."

4. **Output Format (STRICT)**:
   - **Component heading:** `#### [Component Name]` or `#### [Component Name] — [One-line purpose/benefit]`
   - Each component must be preceded by a markdown level-4 heading (`####`), not a bullet point
   - **Namespace line:** `- **Namespace:** [full.namespace]`
   - **Type line:** `- **Component type:** [Component dialog | UI dialog | Form dialog]`
   - **Fields section with descriptions** (NOT just field types without descriptions):
     ```markdown
     - **Fields:**
        - `fieldName1` (FieldType1) — [Description: what this field is used for, e.g., "Email recipients list"]
        - `fieldName2` (FieldType2) — [Description: e.g., "Message subject line"]
     ```
   - **Separator safety:** append ` — [description]` only when description is non-empty after normalization.
     - Trim whitespace before checking emptiness.
     - Treat placeholder-only values as empty (`-`, `--`, `—`, `n/a`, `N/A`).
     - Never emit dangling suffixes like `` `field` (Type) — ``.
   - **Purpose section (mandatory):**
     ```markdown
     - **Purpose:** [One user-facing sentence explaining what this component does and why users need it]
     ```
   - **Forbidden keys in final markdown:** `Parameter`, `Main feature/logic`, `UI attributes`, `Paths`
   - If no start signature fields are present, render this exact single-line placeholder:
     ```markdown
     - **Fields:** - (none)
     ```
   - If no description can be extracted, still render:
     ```markdown
     - **Purpose:** (not documented in source)
     ```
   - Keep exact `.d.json` field names and types (never abbreviate or simplify)
   - Always include Namespace + Type + Fields + Purpose lines
   - Ensure heading (####), grouping, and format are consistent across all components
   - Do NOT output simple bullet list format like `- **ComponentName**` with just field types

5. **Return JSON fragment**:
   ```json
   {
     "section": "formComponentSection",
     "status": "success|partial|missing",
    "content": "#### [ComponentName] — [Purpose]\n- **Namespace:** ...\n- **Component type:** ...\n- **Fields:**\n   - `field1` (...) — description\n   - `field2` (...) — description\n- **Purpose:** ...",
     "completeness": "full|partial"
   }
   ```
   - If CMS descriptions and cross-references found: `status: success`, `completeness: full`
   - If some enrichment missing: `status: partial`, `completeness: partial`
   - If only `.d.json` extracted (no enrichment): `status: partial` with note that descriptions were not available in source
   - Do NOT include HTML comments in the content field (status metadata goes in JSON fields only)

6. **Shape enforcement**:
  - Every component block must use exactly this ordered body structure:
    1. `- **Namespace:**`
    2. `- **Component type:**`
    3. `- **Fields:**`
    4. `- **Purpose:**`
  - No additional top-level bullets may appear inside a component block.

## Usage

Before running, check the current OS. If on Windows, git bash or WSL is recommended to use for best compatibility.
### Print to stdout
```bash
bash ./.github/skills/form-components-listing/scripts/form-components-listing.sh '<src_hd path>'
```

### Write to file
```bash
bash ./.github/skills/form-components-listing/scripts/form-components-listing.sh '<src_hd path>' 'docs/form-components.md'
```

The scanner accepts a module folder or a `src_hd` folder.

For README generation flows, callers must pass only `<mainModule>` or `<mainModule>/src_hd`.
Do not pass workspace root or multi-module parent folders unless `includeDemoModules=true` is explicitly required.

## Output
- The skill returns a JSON fragment conforming to [output-format.md](../references/output-format.md), with markdown stored in `content`
- Include status comment at end:

```markdown
<!-- status: success|partial|missing -->
```

JSON shape example:

```json
{
   "section": "formComponentSection",
   "status": "success|partial|missing",
   "content": "[form components markdown summary]"
}
```

- The exact output schema is defined in the reference file:
  - [references/output-format.md](references/output-format.md)

## Quality Criteria

- **Accuracy**: `Fields` must match the dialog `start` signature parameters when present; do NOT use `.d.json` to populate `Fields`.
- **Structure integrity**: The final markdown block for each component must contain only `Namespace`, `Component type`, `Fields`, and `Purpose` in that order.
- **Completeness**: Include all components found in src_hd
- **No fabrication**: Do not generate component attributes that don't exist in source
- **Scope safety**: Default scan must not include demo/test modules unless explicitly requested.
- The skill accepts an optional input path (module or UI tree) and is not tied to a specific module name; callers may pass any module or top-level UI folder
- For full component listings or raw scan output, use the scanner script directly
- Output contract is JSON fragment; markdown-only output must be wrapped before assembly.

### Updates to Form Components Listing

- Ensure output conforms to JSON format as specified in the output format reference.
- Add support for `.cms` files to extract user-facing descriptions.
- Enforce the fixed README structure: `Namespace`, `Component type`, `Fields`, `Purpose`.
- Do not emit legacy labels such as `Parameter`, `Main feature/logic`, or `UI attributes`.
- Use JSON status/completeness fields for metadata (not HTML comments)
