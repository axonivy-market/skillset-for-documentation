---
name: maven-artifact-listing
description: Generate Maven artifact dependency blocks from product.json installers for README assembly.
argument-hint: '<path-to-product.json>'
user-invocable: true
---

# Maven Artifact Listing

Extract Maven artifacts from `product.json` and return a JSON fragment for README assembly.

## Inputs

- `productJson` (required): path to product.json

## Behavior

1. Read installers from `product.json` in this deterministic order:
   1. `maven-dependency`
   2. `maven-import` with `importInWorkspace != false`
   3. `maven-import` with `importInWorkspace == false` (mark optional)
2. Exclude artifacts ending with `test`.
3. Render a numbered list of artifacts and XML dependency snippets.
4. Use template variables or resolved values:
   - Prefer resolved `artifactId` values from `product.json` when present (e.g., `idp-connector-demo`).
   - Use template variables like `@artifact.id@` and `@version@` only when the source product.json uses placeholders or template variables instead of concrete artifact coordinates.
5. Formatting rules:
   - Keep optional marker as `*(optional)*` after artifact name.
   - Do not append inline metadata tuples like `(version: ..., type: ...)` to list item titles.
   - Keep `<type>...</type>` inside XML block only.

## Output

Return JSON fragment conforming to `references/output-format.md`:

```json
{
  "section": "mavenArtifactSection",
  "status": "success|partial|missing",
  "content": "1. artifact-name\n\n```xml\n<dependency>..."
}
```

If no artifacts are found after a genuine extraction attempt, return:

```json
{
  "section": "mavenArtifactSection",
  "status": "missing",
   "content": "- No information was delivered for this section."
}
```