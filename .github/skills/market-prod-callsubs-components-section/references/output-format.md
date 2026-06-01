# Output Format Reference

## Fragment Contract

All fragments produced or consumed by this skill follow the standard JSON contract
defined in [`generate-ivy-readme`](../../generate-ivy-readme/references/output-format.md).

## Components Section Template

The assembled `## Components` section must always follow this exact structure
(headings in this exact order, no skipped levels):

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

German equivalent (`README_DE.md`):

```markdown
## Komponenten

### Aufrufbare Unterprozesse

{{callableSubSection.content — translated}}

### Dialogkomponenten

{{formComponentSection.content — translated}}

### Web-Services

{{openApiSection.content — translated}}

### Maven-Artefakte

{{mavenArtifactSection.content — translated}}
```

## Fragment Status Values

| Status | Meaning |
|--------|---------|
| `success` | All expected content found and rendered |
| `partial` | Some content found but not complete |
| `missing` | No content found after genuine extraction attempt |

## Fallback Content Per Fragment

| Fragment | Missing fallback |
|----------|-----------------|
| `callableSubSection` | `- No connector processes delivered by this extension.` |
| `formComponentSection` | `- No form components delivered by this extension.` |
| `openApiSection` | `- No information was delivered for this section.` |
| `mavenArtifactSection` | `- No information was delivered for this section.` |

German equivalents:

| Fragment | Fehlender Inhalt (DE) |
|----------|-----------------------|
| `callableSubSection` | `- Diese Erweiterung liefert keine Connector-Prozesse.` |
| `formComponentSection` | `- Diese Erweiterung liefert keine Formularkomponenten.` |
| `openApiSection` | `- Es wurden keine Informationen für diesen Abschnitt geliefert.` |
| `mavenArtifactSection` | `- Es wurden keine Informationen für diesen Abschnitt geliefert.` |

## Injection Rules

- The skill replaces **only** the `## Components` block (English) or `## Komponenten`
  block (German) in the target file.
- The replacement region starts at the matching `## ` heading line and ends at
  the line immediately before the next `## ` heading at the same depth, or EOF.
- All other sections in the file are preserved byte-for-byte.
- No timestamps, skill attribution, or HTML comment metadata appear in final output.
