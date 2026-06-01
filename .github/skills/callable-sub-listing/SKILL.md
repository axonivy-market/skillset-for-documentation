---
name: callable-sub-listing
description: 'Generate docs listings for Axon Ivy CALLABLE_SUB process files with all CallSubStart entries, including signature, parameter, and result details. Use when process JSON changes and docs need refresh.'
argument-hint: '[mainModule path] [optional: path-glob for process files]'
user-invocable: true
---

# Connector processes

Generate a repeatable documentation listing from process files where:
- process kind is CALLABLE_SUB
- start element type is CallSubStart
- Extract all entries (not tag-filtered)

## Inputs
- `mainModule` (required): path to main module (e.g., "connector-main", "service-core", etc.)
- Optional file glob argument. Default: `**/*.p.json` (anchored to mainModule/processes/)
- Optional output file path. If omitted, print to stdout

## Procedure

1. **Glob pattern anchoring:**
   - Start from: `<mainModule>/processes/`
   - Apply glob: `**/*.p.json` (default) or custom pattern
   - Result: All matched process file paths

2. **For each matched process file:**
   - Verify process kind is CALLABLE_SUB
   - Extract all CallSubStart elements
   - For each CallSubStart, collect:
     - Signature (name and parameters)
     - Input parameters with types and descriptions
     - Result/output parameters with types and descriptions
     - **NEW:** Visual description from `visual.description` field (if present)

3. **Output Shape**
    - Group by process file, with heading `#### [process-file-name].p.json`
    - For each callable sub, print the signature as: `**[name]([paramType] [paramName], ...) -> [resultVar]: [resultType]**` (bold)
    - **Signature format rules**:
      - Include **full parameter names** from `config.input.params[].name` (not just type)
      - Include **full type names** (not shortened) — e.g., `msgraph.connector.NewMail` not `NewMail`
      - Format: `**[name]([paramType] [paramName], [paramType] [paramName]) -> [resultVar]: [resultType]**`
      - Multiple params separated by `, `
      - If no inputs: state `()` with no params listed
      - If no result: state `-> (none)` or omit result entirely
      - Example: `**writeMail(msgraph.connector.NewMail mail) -> message: com.microsoft.graph.MicrosoftGraphMessage**`
    - List input and result parameters with types, descriptions, and mapping
    - If there are no input/result parameters, clearly state `(none)`
    - If a description is present, print it after the signature or in the description section
    - Keep heading, grouping, and format consistent (do not add extra headings)
    - Include status comment at end

3.1 **Completeness gate (mandatory):**
        - For each scanned process file, compute `totalCallSubStart`.
        - Compute `renderedCallSubStart` in output.
        - If `renderedCallSubStart < totalCallSubStart`, set status to `partial` and append explicit placeholders for missing entries:
            - `- Callable sub detected but full parameter mapping could not be resolved from source.`
        - Never emit generic placeholders such as "callable subs present in file".
        - Only set status `missing` when no CALLABLE_SUB file with CallSubStart exists after a genuine scan. If so, synthesize a block: "No connector processes delivered by this extension."

## Output Format


If no CALLABLE_SUB process is found, set content to: "No connector processes delivered by this extension."

```json
{
    "section": "callableSubSection",
    "status": "success|partial|missing",
    "content": "#### [process-file-name-1].p.json\n\n- **writeMail(msgraph.connector.NewMail mail) -> message: com.microsoft.graph.MicrosoftGraphMessage**\n    - Input:\n        - `mail` (msgraph.connector.NewMail) - The mail to send\n    - Result:\n        - `message` (com.microsoft.graph.MicrosoftGraphMessage) - The message that was sent\n\n#### [process-file-name-2].p.json\n\n- **upcomingEvents() -> myEvents: java.util.List<com.microsoft.graph.MicrosoftGraphEvent>**\n    - Input: (none)\n    - Result:\n        - `myEvents` (java.util.List<com.microsoft.graph.MicrosoftGraphEvent>) - List with upcoming events from calendar"
}
```

Example markdown content field:

```markdown
#### msCalendar.p.json

- **upcomingEvents() -> myEvents: java.util.List<com.microsoft.graph.MicrosoftGraphEvent>**
    - Input: (none)
    - Result:
        - `myEvents` (java.util.List<com.microsoft.graph.MicrosoftGraphEvent>) - List with upcoming events from calendar

- **createMeeting(msgraph.connector.NewEvent evt) -> meeting: com.microsoft.graph.MicrosoftGraphEvent**
    - Input:
        - `evt` (msgraph.connector.NewEvent) - The new event that should be created in your calendar
    - Result:
        - `meeting` (com.microsoft.graph.MicrosoftGraphEvent) - The event that was created in your calendar

#### msMail.p.json

- **writeMail(msgraph.connector.NewMail mail) -> message: com.microsoft.graph.MicrosoftGraphMessage**
    - Input:
        - `mail` (msgraph.connector.NewMail) - The mail to send
    - Result:
        - `message` (com.microsoft.graph.MicrosoftGraphMessage) — The message that was sent
```

**Output format rules:**
- Return JSON fragment with `section=callableSubSection`, `status`, and markdown `content`
- Do NOT include HTML comments in the content field (status metadata goes in JSON fields only)
- Start output directly with `#### [file-name].p.json` file grouping headers (no parent section headings)
- Group by process file; do not add extra section headings (template provides `### Callable Subprocesses`)
- Bold signature: `**[name]([input params]) -> [output var]: [type]**`
- Input section: list all input parameters with types and descriptions, if none, state `(none)`
- Result section: list all output parameters with types and descriptions, if none, state `(none)`
- Descriptions pulled from `visual.description` or parameter `desc` fields when available
- Keep format, heading, and grouping consistent
- Deterministic order: files alphabetically, then CallSubStart elements in source order

## Quality criteria

- Glob pattern properly anchored to mainModule/processes/
- All matched process files scanned (no silent failures)
- All CALLABLE_SUB entries extracted
- Descriptions from visual.description included when available
- Parameters grouped by input/result sections
- Output status reflects completeness (success | partial | missing)
- No ambiguous placeholders are allowed in place of missing extractions.
- Prefer repository-native wording from the README template; use `Callable Subprocesses` in generated component listings.
