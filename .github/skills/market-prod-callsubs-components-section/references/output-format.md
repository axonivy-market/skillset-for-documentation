# Output Format Reference

## Fragment Contract

All fragments produced or consumed by this skill follow the standard JSON contract
defined in [`generate-ivy-readme`](../../generate-ivy-readme/references/output-format.md).

## Components Section Template

The assembled `## Components` section must always render `## Components` and must
preserve this subsection order: `Callable Subprocesses`, `Dialog Components`,
`Rest Clients`, `Web Services`, `Maven Artifacts`.
If a subsection is missing, keep the heading and inject exactly one fallback bullet
under that subsection.

```markdown
## Components

### Callable Subprocesses

{{callableSubSection.content}}

### Dialog Components

{{formComponentSection.content}}

### Rest Clients

{{restClientsSection.content}}

<!-- restClientsSection bullet format: - **OpenAPI:** [<Name or clientKey>](<OpenAPI.SpecUrl>)
     Example: - **OpenAPI:** [deepl-connector](https://raw.githubusercontent.com/DeepLcom/openapi/main/openapi.yaml)
     Forbidden in output: Url, Icon, Features, Properties, Namespace -->

### Web Services

{{webServicesSection.content}}

<!-- webServicesSection bullet format: - **OpenAPI:** [<Name or serviceKey>](<OpenAPI.SpecUrl>)
     Example: - **OpenAPI:** [myService](https://example.com/ws-openapi.yaml)
     Forbidden in output: Url, Wsdl, WsdlUrl, Properties -->

### Maven Artifacts

{{mavenArtifactSection.content}}
```

German equivalent (`README_DE.md`):

```markdown
## Komponenten

### Aufrufbare Unterprozesse

{{callableSubSection.content — translated}}

### Dialogkomponenten

{{formComponentSection.content — translated}}

### Rest-Clients

{{restClientsSection.content — translated}}

<!-- Same bullet format as EN. URL inside [...](url) is never translated. -->

### Web-Services

{{webServicesSection.content — translated}}

<!-- Same bullet format as EN. URL inside [...](url) is never translated. -->

### Maven-Artefakte

{{mavenArtifactSection.content — translated}}
```

## Fragment Status Values

| Status | Meaning |
|--------|---------|
| `success` | All expected content found and rendered |
| `partial` | Some content found but not complete |
| `missing` | No content found after genuine extraction attempt |

## Missing Fragment Handling

| Fragment | Missing behavior |
|----------|-----------------|
| `callableSubSection` | Omit subsection; note may mention `Callable Subprocesses`. |
| `formComponentSection` | Omit subsection; note may mention `Dialog Components`. |
| `restClientsSection` | Keep subsection and inject `- For this market extension we do not provide any Rest Clients.` |
| `webServicesSection` | Keep subsection and inject `- For this market extension we do not provide any Web Services.` |
| `mavenArtifactSection` | Omit subsection; note may mention `Maven Artifacts`. |

German equivalents:

| Fragment | Fehlendes Verhalten (DE) |
|----------|-----------------------|
| `callableSubSection` | Unterabschnitt auslassen; Hinweis kann `aufrufbaren Unterprozesse` nennen. |
| `formComponentSection` | Unterabschnitt auslassen; Hinweis kann `Dialogkomponenten` nennen. |
| `restClientsSection` | Unterabschnitt beibehalten und `- Für diese Market-Erweiterung stellen wir keine Rest-Clients bereit.` einfügen. |
| `webServicesSection` | Unterabschnitt beibehalten und `- Für diese Market-Erweiterung stellen wir keine Webdienste bereit.` einfügen. |
| `mavenArtifactSection` | Unterabschnitt auslassen; Hinweis kann `Maven-Artefakte` nennen. |

## Injection Rules

- The skill replaces **only** the `## Components` block (English) or `## Komponenten`
  block (German) in the target file.
- The replacement region starts at the matching `## ` heading line and ends at
  the line immediately before the next `## ` heading at the same depth, or EOF.
- All other sections in the file are preserved byte-for-byte.
- No timestamps, skill attribution, or HTML comment metadata appear in final output.
