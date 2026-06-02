# Ivy README Demo Workflows Output Format

## Fragment Contract

```json
{
  "section": "demoWorkflows",
  "content": "string (markdown)",
  "status": "success|partial|missing",
  "preserveMode": "verbatim|structured",
  "completeness": "full|partial",
  "requiredSubsections": ["workflow_name_1", "workflow_name_2"],
  "evidence": ["file1.p.json", "file2.p.json"]
}
```

## Demo Workflows Section

**Purpose:** Extract step-by-step workflow demonstrations from demo module process files and README documentation.

**Sources (Priority order):**
1. Demo workflows from README.md under `### Demo Workflows` section (exact wording and structure)
2. Demo process files (`.p.json`) in demo modules (e.g., `msgraph-calendar-demo/processes/Demo/*.p.json`)
3. Process annotations and visual descriptions from process JSON

**Example output (fragment content only):**
```markdown
#### Translate Text

1. Launch the text translation demo from the menu.
2. Choose source and target languages.
3. Enter text and run translation.

#### Translate File

1. Launch the file translation demo from the menu.
2. Upload a file and select target language.
3. Review and download translated output.
```

Note: The `demoWorkflows` fragment `content` must NOT include the heading `### Demo Workflows`. That heading is rendered by the assembler.

## Extraction Strategy

### 1. Extract from README.md (Priority 1)

- Look for `### Demo Workflows` section
- Extract all content under that heading until next heading (`##` or `###` that changes level)
- Preserve exact wording, list structure, and callable-sub references

### 2. Extract from Demo Process Files (Priority 2, fallback)

- Discover demo modules by checking pom.xml for modules with `-demo` suffix
- For each demo module:
  - Find process files in `processes/Demo/` or `src_hd/*/demo/*/`
  - Extract process descriptions from JSON:
    - `RequestStart.name` (e.g., "readCalendar.ivp", "meet.ivp")
    - `RequestStart.config.signature` (e.g., "readCalendar", "meet")
    - Process visual descriptions (`ProcessAnnotation` elements)
  - Map to callable-sub calls via `SubProcessCall` elements
  - Generate workflow description: "run the `<processName>` demo (calls `<callableSubName>()` or `(ParamType)`)"

### 3. Apply workflow structure

- Render each workflow consistently as `#### Workflow` followed by a numbered list. Do not include an intermediate `##### Steps` subheading.

## Contract Requirements

| Field | Value | Notes |
|-------|-------|-------|
| section | `demoWorkflows` | Fixed identifier |
| content | Markdown with demo workflow steps | Can be from README.md or synthesized from process files; MUST contain only workflow blocks and steps, without the `### Demo Workflows` heading |
| status | `success` if README.md demo section found; `partial` if synthesized from processes only; `missing` if no demo content found | - |
| preserveMode | `verbatim` if from README.md; `structured` if synthesized | Preserve exact README.md wording when available |
| requiredSubsections | Array of workflow names (e.g., ["Translate Text", "Translate File"]) | Used for coverage validation |
| evidence | Array of source files scanned (README.md, process JSON files) | Helps with debugging |

## Quality Criteria

- **Prefer README.md content** - always extract from README.md first if available
- **Preserve exact wording** - use exact function names, parameter types, dialog names from README or process JSON
- **Include callable-sub signatures** - each workflow should reference which callable sub is invoked (e.g., `msCalendar:upcomingEvents()`)
- **Maintain structure** - preserve heading levels, list formatting, and grouping from source
- **Heading boundary** - do not include `### Demo Workflows` in fragment content; include only workflow headings and step lists
 - **Workflow structure** - enforce `#### Workflow` + numbered list for each workflow (do not emit `##### Steps`).
- **No fabrication** - only extract workflows that actually exist in docs or processes
- **Complete workflows** - each workflow should be a complete step-by-step instruction or description

## Example: How to Extract from Process JSON

Given process file: `msgraph-calendar-demo/processes/Demo/ms365Calendar.p.json`

```json
{
  "elements": [{
    "type": "RequestStart",
    "name": "readCalendar.ivp",
    "config": { "signature": "readCalendar" },
    "visual": { "description": "Reads upcoming events from your calendar." }
  }, {
    "type": "SubProcessCall",
    "name": "upcomingEvents()",
    "config": { "processCall": "msCalendar:upcomingEvents()" }
  }, {
    "type": "DialogCall",
    "name": "Events",
    "config": { "dialog": "msgraph.calendar.demo.Events:start(...)" }
  }]
}
```

Extracted workflow:
```
- Read upcoming events: run the `readCalendar` demo (calls `msCalendar:upcomingEvents()`), then open the "Events" dialog to browse results.
```

## Status Determination

- **success:** README.md has complete `### Demo Workflows` section with all workflows documented
- **partial:** README.md exists but only some workflows documented, or workflows extracted from process files
- **missing:** No README.md or process files with demo workflows found
