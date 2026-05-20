---
name: ivy-readme-discover-modules
description: Discover Axon Ivy Maven module roles from root pom.xml for README generation.
argument-hint: '[optional: workspace root path]'
user-invocable: true
---

# Ivy README Discover Modules

Discover main, demo, and product modules quickly for Axon Ivy/Maven repositories.

## Inputs

- `workspacePath` (optional): workspace root path

## Behavior

1. Detect Axon Ivy/Maven repository layout in this order:
  - Maven multi-module (`pom.xml` with `<modules>`)
  - Single-module Maven repo (`pom.xml` without `<modules>`)
2. If a root `pom.xml` with `<modules>` exists:
  - Enumerate `<modules>`.
  - Classify modules:
    - suffix `-demo`: demo module
    - suffix `-product`: product module
    - suffix `test`, `-test`, `webtest`: excluded
    - remaining: main candidates
3. If no Maven modules are found:
  - use repository root as `mainModule`
  - set `productModule` to repository root
  - set `demoModules` and `excludedModules` to empty arrays
  - set `repoProfile.buildSystem` to `unknown`
4. Return deterministic JSON:

```json
{
  "mainModule": "...",
  "demoModules": ["..."],
  "productModule": "...",
  "excludedModules": ["..."],
  "repoProfile": {
    "buildSystem": "maven|unknown",
    "languageHints": ["java"],
    "isMonorepo": true
  }
}
```

## Quality criteria

- No deep source scanning.
- Deterministic output for same pom.xml.
- Must prioritize Axon Ivy/Maven conventions and keep a safe root fallback.
