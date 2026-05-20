---
name: form-components-listing
description: Use when asked for a detailed summary, listing, or overview of form components or form dialogs in the project.
argument-hint: '[optional: path to main module src_hd directory, e.g. my-connector/src_hd]'
user-invocable: true
---


# Form Components Summary

Generate a concise, marketing-oriented summary of available form dialog and form components from main module(s) in an Axon Ivy project.
Ensure output grouping, heading, and dual-view (runtime/UI) are consistent and clear.

## Inputs
- Optional path to the `src_hd` directory of the main module (e.g. `my-connector/src_hd`). Defaults to scanning the current workspace.
- Optional `includeDemoModules` flag (default: `false`). When `false`, scan only the provided main module path.

## Extraction Rules

1. **Scan for form components** in `src_hd` directory
   - Default behavior must be main-module scoped only.
   - Do not scan unrelated workspace modules unless `includeDemoModules=true` is explicitly set by caller.
2. **For each component**, extract:
   - Component name and namespace (from folder or xhtml name)
   - Component type (HTML_DIALOG, COMPONENT, etc.)
   - **Paths to component files** (xhtml location)
   - **Actual component parameters** from the corresponding `.d.json` dataclass file (NOT fabricated)
   - **UI attributes** declared in `.xhtml` component interface (if present)
   - Component purpose/description (from CMS or inline documentation)

3. **Data source priority (ENHANCED)**:
   - **Primary source:** `.d.json` dataclass files for actual field names and types
   - **Enrichment source 1:** `.cms` files for user-facing descriptions and component purpose
   - **Enrichment source 2:** `.xhtml` component definition files for:
     - Component type (HTML_DIALOG, HTML_COMPONENT, JSF Composite Component, etc.)
     - JSF `cc:interface` attributes and metadata if present
     - Component start method signature
   - **Enrichment source 3:** Related process files (`processes/**/*.p.json`) for:
     - Which callable subs use this component (SubProcessCall references)
     - Which demo dialogs instantiate this component (DialogCall references)
   - **Enrichment source 4:** README/setup documentation for component usage context
   - **Synthesis rule (when sources incomplete):**
     - Use field names and types to infer component purpose
     - Example: "NewMail captures email metadata (recipients, subject, body) for mail operations"
     - Link to related callable sub or demo dialog
     - Mark status as `partial` when synthesized
   - Never fabricate component attributes—only synthesize purpose/context
  - If no components are found in scoped paths, synthesize a block: "No form components delivered by this extension."

4. **Output Format (ENHANCED with enriched content)**:
   - **Component heading:** `#### [Component Name] — [One-line purpose/benefit]` (NOT just `- **[Component Name]**`)
   - Each component must be preceded by a markdown level-4 heading (`####`), not a bullet point
   - **Namespace line:** `- **Namespace:** [full.namespace]`
   - **Type line:** `- **Component type:** [Data Class | HTML_DIALOG | JSF Composite Component | etc.]`
   - **Fields section with descriptions** (NOT just field types without descriptions):
     ```markdown
     - **Fields:**
        - `fieldName1` (FieldType1) — [Description: what this field is used for, e.g., "Email recipients list"]
        - `fieldName2` (FieldType2) — [Description: e.g., "Message subject line"]
     ```
   - **Where used section (if found):**
     ```markdown
     - **Where used:** [Callable sub name], [Demo dialog name], [Other process name]
     ```
   - **Purpose section (if available):**
     ```markdown
     - **Purpose:** [One user-facing sentence explaining what this component does and why users need it]
     ```
   - Keep exact `.d.json` field names and types (never abbreviate or simplify)
   - Always include Namespace + Type lines (helps users understand scope and integration point)
   - Ensure heading (####), grouping, and format are consistent across all components
   - Do NOT output simple bullet list format like `- **ComponentName**` with just field types

5. **Return JSON fragment**:
   ```json
   {
     "section": "formComponentSection",
     "status": "success|partial|missing",
     "content": "#### [ComponentName] — [Purpose]\n- **Namespace:** ...\n- **Component type:** ...\n- **Fields:**\n   - `field1` (...) — description\n   - `field2` (...) — description\n- **Where used:** ...\n- **Purpose:** ...",
     "completeness": "full|partial"
   }
   ```
   - If CMS descriptions and cross-references found: `status: success`, `completeness: full`
   - If some enrichment missing: `status: partial`, `completeness: partial`
   - If only `.d.json` extracted (no enrichment): `status: partial` with note that descriptions were not available in source
   - Do NOT include HTML comments in the content field (status metadata goes in JSON fields only)

6. **Dual-view blocks when both sources exist**:
   - Runtime parameters (from `.d.json`)
   - UI attributes (from `.xhtml`)
   - Component metadata from all enrichment sources

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

The scanner is module-agnostic; pass any `src_hd` directory or top-level UI folder.

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

- **Accuracy**: Parameters must match actual `.d.json` dataclass definitions
- **Dual-source integrity**: Keep runtime parameters and UI attributes separated; never merge or relabel them
- **Completeness**: Include all components found in src_hd
- **No fabrication**: Do not generate component attributes that don't exist in source
- **Scope safety**: Default scan must not include demo/test modules unless explicitly requested.
- The skill accepts an optional input path (module or UI tree) and is not tied to a specific module name; callers may pass any module or top-level UI folder
- For full component listings or raw scan output, use the scanner script directly
- Output contract is JSON fragment; markdown-only output must be wrapped before assembly.

### Updates to Form Components Listing

- Ensure output conforms to JSON format as specified in the output format reference.
- Add support for `.cms` files to extract user-facing descriptions.
- Separate runtime parameters and UI attributes in the output.
- Use JSON status/completeness fields for metadata (not HTML comments)
