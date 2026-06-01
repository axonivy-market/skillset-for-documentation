---
name: ivy-readme-discover-modules
description: Discover Axon Ivy Maven module roles from root pom.xml for README generation.
argument-hint: 'Discover Axon Ivy Maven module roles from root pom.xml for README generation.'
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
  - Classify modules (generic + deterministic):
    - suffix `-product` OR module contains `product.json`: product module
    - suffix `test`, `-test`, `webtest`: excluded
    - demo naming tokens: explicit demo module when name matches one of:
      - suffix `-demo`
      - suffix `-demos`
      - tokenized pattern `-demos-` (for names like `pattern-demos-lock`)
    - remaining: candidates for main/demo fallback
  - If explicit demo modules are empty, infer demo modules by lightweight process evidence:
    - scan `<module>/processes/**/*.p.json` for `"type": "RequestStart"`
    - modules with RequestStart become `demoModules`
  - If all non-excluded candidates are demos, set `mainModule` to the first inferred demo module (root module order)
    - this keeps extraction non-empty for demo-heavy repositories
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
    "isMonorepo": true,
    "discoveryMode": "suffix-based|requeststart-inferred|..."
  }
}
```

## Script usage

Use the provided script for deterministic extraction:

```bash
bash ./.github/skills/ivy-readme-discover-modules/scripts/discover-modules.sh [workspacePath]
```

## Quality criteria

- No deep source scanning beyond lightweight `RequestStart` detection.
- Deterministic output for same pom.xml.
- Must prioritize Axon Ivy/Maven conventions and keep a safe root fallback.
