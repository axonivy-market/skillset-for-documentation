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
   - Combine artifacts from all installer sections (`maven-import`, `maven-dependency`, and other installer types that contain Maven coordinates) into a single canonical list.
   - De-duplicate artifacts by `groupId:artifactId:type`. When the same artifact appears in multiple installer entries prefer the coordinate entry that is most concrete (i.e., does not use template placeholders) and preserve deterministic installer precedence when ties occur.
   - Do NOT hardcode a preference that hides entire installer categories. Instead, present both `maven-import` and `maven-dependency` artifacts merged and ordered by project/module ordering (see next step).
2. Resolve the root repository `pom.xml` module order and use that sequence as the canonical sort order for rendered artifacts.
   - Parse the root `pom.xml` `<modules>` list to obtain the repository's canonical module sequence.
   - Match each artifact to a module by `artifactId` when possible. Sort matched artifacts according to the module sequence from the root POM.
   - Any artifacts not matched to a module (for example external artifacts or those declared only in product.json) are appended after the ordered module artifacts, preserving their original appearance order from `product.json`.
   - If module order cannot be determined (single-module repository or missing root POM), fall back to the order in which artifacts appear in `product.json`.
3. Mark artifacts originating from `maven-import` with `importInWorkspace == false` as optional only when that flag is explicitly present and `false`.
4. Exclude artifacts ending with `test`.
5. Render a numbered list of artifacts and XML dependency snippets.
6. Use template variables or resolved values:
   - Prefer resolved `artifactId` values from `product.json` when present (e.g., `idp-connector-demo`).
   - Use template variables like `@artifact.id@` only when the source product.json uses placeholders or template variables instead of concrete artifact coordinates.
7. Formatting rules:
   - List item title must be concise and use only `artifactId` (for example `deepl-connector-demo`), not full coordinates.
   - Keep optional marker as `*(optional)*` only when optionality is explicitly known from source metadata.
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