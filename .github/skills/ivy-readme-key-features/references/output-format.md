# Ivy README Key Features Output Format

## Fragment Contract

Each sub-skill must return a JSON object conforming to this contract:

```json
{
  "section": "string (e.g., productDescriptionSection|keyFeatures|demoIntroSection|setupSection|variablesSection|openApiSection|optionalAuthSection)",
  "content": "string (markdown)",
  "status": "success|partial|missing",
  "preserveMode": "verbatim|structured",
  "completeness": "full|partial",
  "requiredSubsections": ["subsection1", "subsection2"],
  "evidence": ["file1", "file2"]
}
```

## Sections Extracted

### productDescriptionSection

**Sources (Priority order):**
1. README/README_*.md in product module (first 1-3 paragraphs before ### Key features)
2. README/README_*.md in main module
3. Configuration hints from `config/rest-clients.yaml`, `config/roles.xml`

**Example output:**
```markdown
# Product Name

Axon Ivy's [Microsoft 365](https://docs.microsoft.com/en-us/graph/overview)
connector helps you to integrate Microsoft Graph features into your process application...

This connector:
- enables fast integration into any Microsoft 365 product easily.
- ...
```

**Status:** `success` if README.md exists and has intro paragraphs, `partial` if only config hints found, `missing` if nothing found.

### keyFeatures

**Sources:**
1. `### Key features` section from README.md
2. Process signatures from `processes/*.p.json`
3. Configuration from `config/rest-clients.yaml`, `config/roles.xml`

**Example output:**
```markdown
- Integrate Microsoft 365 (Mail, Calendar, Teams, OneDrive, SharePoint) through a single connector.
- Send emails and create calendar events directly from your Axon Ivy processes.
- Upload and manage files on SharePoint/OneDrive...
```

**Status:** `success` if bullets found, `partial` if only inferred from processes, `missing` if nothing.

### demoIntroSection

**Sources:**
1. Demo intro paragraph under `## Demo` heading in README.md
2. Links to market.axonivy.com or demo explanations

**Example output:**
```markdown
Check the demo implementations we have prepared for the various services from Microsoft:

[Microsoft Calendar](https://market.axonivy.com/msgraph-calendar) - this connector integrates Microsoft Outlook features into your process application.

[Microsoft Excel](https://market.axonivy.com/excel-connector) - ...
```

**Status:** `success` if demo intro found in README.md, `missing` otherwise.

### setupSection

**Sources:**
1. `## Setup` section with all subsections (Roles, OpenAPI, Configuration variables, etc.) from README.md
2. Configuration files: `config/roles.xml`, `config/rest-clients.yaml`, `config/variables.yaml`

**Example output:**
```markdown
- **Roles:** `Everybody` (configured in `config/roles.xml`).

- **OpenAPI:** the connector exposes an OpenAPI specification. External spec URL (from `config/rest-clients.yaml`):

    https://graphexplorerapi.azurewebsites.net/openapi?tags=...

- **Configuration variables:**

```
@variables.yaml@
```
```

**Required subsections:** Roles, OpenAPI, Configuration variables

**Status:** `success` if all subsections found, `partial` if some missing.

**Preserve mode:** `verbatim` to keep exact formatting from source README.md

### variablesSection

**Sources:**
1. Complete `config/variables.yaml` with all comments and structure preserved

**Example output:**
```yaml
Variables:
  
  microsoftConnector:
    
    # Your Azure Application (client) ID
    appId: ""
    
    # Secret key from your applications "certificates & secrets"
    # [password]
    secretKey: ""
    
    # ... rest of variables with comments ...
```

**Status:** `success` if file found, `missing` otherwise.

**Preserve mode:** `verbatim` - preserve exact YAML structure, indentation, and comments

### openApiSection

**Sources:**
1. OpenAPI URL from `config/rest-clients.yaml` under `RestClients.<service>.OpenAPI.SpecUrl`

**Example output:**
```markdown
https://graphexplorerapi.azurewebsites.net/openapi?tags=me.user,me.calendar,users.calendar,me.message,me.Actions,me.todo,me.site,sites.Actions,me.drive,me.chat,chats.chat,chats.chatMessage&openApiVersion=3&graphVersion=v1.0&format=yaml&style=PowerShell
```

**Status:** `success` if URL found, `missing` otherwise.

### optionalAuthSection

**Sources:**
1. Authentication/Runtime setup documentation in README.md or dedicated config files

**Status:** `missing` if no optional auth sections found (this is optional)

## Implementation Strategy

1. **Read README.md** from product/main module
2. **Extract productDescriptionSection** - first 2-3 paragraphs before ### Key features
3. **Extract keyFeatures** - content from ### Key features section
4. **Extract demoIntroSection** - paragraph text under ## Demo before demo workflows
5. **Extract setupSection** - complete ## Setup section with all subsections
6. **Extract variablesSection** - read `config/variables.yaml` verbatim
7. **Extract openApiSection** - read OpenAPI URL from `config/rest-clients.yaml`
8. **Return all as JSON fragments** conforming to the contract above

All content must be extracted verbatim from sources - no fabrication or synthesis of content.
