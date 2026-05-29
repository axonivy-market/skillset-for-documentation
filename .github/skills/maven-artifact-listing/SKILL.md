---
name: maven-artifact-listing
description: Generate Maven artifact dependency blocks from product.json installers, ordered by root pom.xml modules, for README assembly.
argument-hint: '<path-to-product.json>'
user-invocable: true
---

# Maven Artifact Listing

Extract Maven artifacts from `product.json`, ordered by the root `pom.xml` module sequence, and return a JSON fragment for README assembly.

## Inputs

- `productJson` (required): path to product.json

## Behavior

1. Read artifact coordinates from `product.json` installers (`maven-dependency` and `maven-import`).
2. Resolve the root repository `pom.xml` module order and use that sequence as the canonical sort order for rendered artifacts.
   - Match each artifact to its Maven module by `artifactId`.
   - Preserve the relative order declared in the root `<modules>` section.
   - Artifacts present in `product.json` but absent from the root module list must be appended after ordered modules, preserving their original installer order.
3. Mark artifacts originating from `maven-import` with `importInWorkspace == false` as optional.
4. Exclude artifacts ending with `test`.
5. Render a numbered list of artifacts and XML dependency snippets.
6. Use template variables or resolved values:
   - Prefer resolved `artifactId` values from `product.json` when present (e.g., `idp-connector-demo`).
   - Use template variables like `@artifact.id@` only when the source product.json uses placeholders or template variables instead of concrete artifact coordinates.
7. Formatting rules:
   - List item title MUST be `artifactId` only (for example: `smart-workflow-openai`), not `groupId:artifactId`.
   - Keep optional marker as `*(optional)*` after artifact name.
   - Do not append inline metadata tuples like `(version: ..., type: ...)` to list item titles.
   - Keep `<type>...</type>` inside XML block only.
   - Omit `<version>@version@</version>`.

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