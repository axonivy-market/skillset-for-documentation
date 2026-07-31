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
#### Calendar (msgraph-calendar-demo)

- Read upcoming events: run the `readCalendar` demo (calls `msCalendar:upcomingEvents()`), then open the "Events" dialog to browse results.
- Create a meeting: run the `meet` demo and use the "CreateEvent" dialog to fill details (calls `msCalendar:createMeeting(NewEvent)`).

#### Mail (msgraph-mail-demo)

- Send mail: open the `writeMail` demo, compose your message and send (calls `msMail:writeMail(NewMail)`).
- Browse inbox: run the `inbox` demo to list messages in the "Mails" dialog.

#### Files / SharePoint (msgraph-sharepoint-demo)

- Upload a file: run the `upload` demo to create a sample file and upload it (calls `msFiles:uploadFile(File)`).
- Recent files: run the `recentFiles` demo to list recently used items (calls `msFiles:myRecentFiles()`).

#### To Do (msgraph-todo-demo)

- List tasks: run the `myToDo` demo to view your tasks (calls `msToDo:allTasks()`).
- Create a task: run the `createTask` demo and use the "CreateTask" dialog (calls `msToDo:createNewTask(NewToDo)`).

#### Teams / Chat (msgraph-teams-demo)

- Read recent messages: run the `readMessages` demo to fetch recent chat messages (calls `msChat:recentMessages()`).
- Teams web demo: run `teamsWeb` to explore the web-integrated view.
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

### 2.1 Normalize Workflow Heading Names (Mandatory)

- Source for heading text: `RequestStart.config.request.name` (fallback: `RequestStart.name`, then `config.signature`)
- Strip leading numeric prefixes before rendering heading text:
  - Primary regex: `^\d+\.\s*`
  - Extended regex (multi-level numbering): `^\d+(?:\.\d+)*\.\s*`
- Examples:
  - `1. Generate Barcodes` -> `Generate Barcodes`
  - `1.1 Document with TemplateMergeFields` -> `Document with TemplateMergeFields`
  - `2. Create an .msg mail document` -> `Create an .msg mail document`
- Never emit workflow headings with numeric prefixes in final markdown.

### 2.2 Stable Markdown Structure (Mandatory)

- Keep deterministic structure for demo workflows:
  - Module header: `#### <ModuleName> (<module-path>)` (or omitted by single-module flattening rule)
  - Workflow header: `##### <Normalized Workflow Name>`
  - Steps: ordered list (`1.`, `2.`, `3.` ...)
- Do not emit empty module/workflow headings.
- Keep one blank line between workflow heading and first step.

### 3. Group by Demo Module

- Organize workflows under demo module headers: `#### <DemoModuleName> (<module-name>-demo)`
- Preserve alphabetical or source order of demo modules

## Contract Requirements

| Field | Value | Notes |
|-------|-------|-------|
| section | `demoWorkflows` | Fixed identifier |
| content | Markdown with demo workflow steps | Can be from README.md or synthesized from process files; MUST contain only module blocks (`#### ...`) and workflow blocks (`##### ...` + ordered steps), without the `### Demo Workflows` heading |
| status | `success` if README.md demo section found; `partial` if synthesized from processes only; `missing` if no demo content found | - |
| preserveMode | `verbatim` if from README.md; `structured` if synthesized | Preserve exact README.md wording when available |
| requiredSubsections | Array of demo module names (e.g., ["Calendar", "Mail", "Files / SharePoint", "To Do", "Teams / Chat"]) | Used for coverage validation |
| evidence | Array of source files scanned (README.md, process JSON files) | Helps with debugging |

## Quality Criteria

- **Prefer README.md content** - always extract from README.md first if available
- **Preserve exact wording** - use exact function names, parameter types, dialog names from README or process JSON
- **Include callable-sub signatures** - each workflow should reference which callable sub is invoked (e.g., `msCalendar:upcomingEvents()`)
- **Maintain structure** - preserve heading levels, list formatting, and grouping from source
- **Normalize workflow names** - remove numeric prefixes from workflow headings before rendering
- **Stable structure** - keep `#### module` -> `##### workflow` -> ordered list pattern with no empty headings
- **Heading boundary** - do not include `### Demo Workflows` in fragment content; include only `#### ...` module headers and workflow bullets
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
