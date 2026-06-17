---
name: translate-readme
description: Use when asked to translate a README to German, create README_DE.md, or produce a German version of product documentation.
argument-hint: '<product-module-name>'
user-invocable: true
---

# Translate README

Translate the `README.md` into German and write the result to `README_DE.md`.

## Purpose

Produce a German variant of the product introduction that reads naturally to native speakers while remaining accurate for a technical audience.

## Input

- `productModule` (required): The product module folder name (e.g. `mattermost-connector-product`). The skill reads `README.md` from this folder and writes `README_DE.md` to the same folder.
 - Optional: `language` (default: `de`) - target language for translation. This skill is optimized for `de` and will prefer project-provided German CMS mappings when available.

## Output

- `README_DE.md` written to `<productModule>/README_DE.md`.
- Tone: **natural, friendly, and professional** — use `du`/`dein`, and avoid jargon.
- Target language: **German**.

## Behavior / Steps

1. **Locate the source file**: `<productModule>/README.md`. Fail with a clear error if the file does not exist.

2. **Translate the extracted content** into German, following these rules:

   **Mandatory heading translation table (apply before prose translation pass):**

   The following English section headings MUST always be translated to their canonical German equivalents.
   This table takes precedence over general prose translation and over any AI-inferred wording:

   | English heading | German heading |
   |----------------|----------------|
   | `# Key features` | `# Wichtigste Funktionen` |
   | `## Demo` | `## Demo` |
   | `### Demo Workflows` | `### Demo-Workflows` |
   | `## Setup` | `## Einrichtung` |
   | `### Variables` | `### Variablen` |
   | `## Components` | `## Komponenten` |
   | `### Rest Clients` | `### Rest-Clients` |
   | `### Callable Subprocesses` | `### Aufrufbare Subprozesse` |
   | `### Dialog Components` | `### Dialog-Komponenten` |
   | `### Web Services` | `### Webdienste` |
   | `### Maven Artifacts` | `### Maven-Artefakte` |

   **Mandatory inline-label translation table (apply before prose translation pass):**

   These labels appear inside content blocks and must be translated:

   | English label | German label |
   |--------------|--------------|
   | `- **Signature**:` | `- **Signatur**:` |
   | `    - Input:` | `    - Eingabe:` |
   | `    - Input: (none)` | `    - Eingabe: (keine)` |
   | `    - Result:` | `    - Ergebnis:` |
   | `    - Result: (none)` | `    - Ergebnis: (keine)` |
   | `- **Roles:**` | `- **Rollen:**` |
   | `- **Fields:**` | `- **Felder:**` |
   | `- **Fields:** - (none)` | `- **Felder:** - (keine)` |
   | `- **Component type:**` | `- **Komponententyp:**` |
   | `- **Namespace:**` | `- **Namespace:**` |
   | `- **Purpose:**` | `- **Zweck:**` |

   **Role-name handling:**
   - Role identifiers that are proper names in Axon Ivy (e.g. `Everybody`) are kept verbatim; only surrounding prose is translated.

   **Image alt-text translation rules (mandatory, generic):**

   Alt text is treated as **prose**, not as a technical identifier.
   Apply the following classification algorithm to every token in the alt text string (the `…` inside `![…]`):

   **Token classification:**
   - **Preserve verbatim**: tokens that are technical identifiers — file extensions (`.png`, `.yaml`), version strings (`v2`, `13.2`), class/method names (`com.axonivy.*`), abbreviations that are not plain English adjectives/nouns (`OpenAPI`, `REST`, `API`, `CMS`), and proper product names that have no established German equivalent.
   - **Translate as prose**: all remaining tokens that are plain English words — adjectives (`Advanced`, `Basic`, `Extended`, `Simple`, `Detailed`, `Full`, `Quick`, `Overview`), nouns used as labels (`Demo`, `Dialog`, `File`, `Text`, `Form`, `Result`, `Setup`, `Translation`, `Upload`), verbs (`Translate`, `Configure`, `Select`), and qualifier phrases.

   **Algorithm:**
   1. Split alt text on whitespace and punctuation (` `, `-`, `–`, `:`, `(`, `)`).
   2. For each token, apply the classification above.
   3. Translate prose tokens into natural German, preserving gender agreement with adjacent translated words (e.g. adjectives agree with the noun they modify).
   4. Reconstruct the alt text preserving original separators between tokens.
   5. The result must read as natural German prose, not as a mix of German and English words.

   **Examples of the generic rule in action (not an exhaustive list):**
   - `Translate Text Demo` → `Text übersetzen Demo` (or `Demo: Text übersetzen`)
   - `Translate File Advanced Demo` → `Datei übersetzen – Erweiterte Demo`
   - `Document Splitting Dialog` → `Dokument-Aufteilung Dialog`
   - `Invoice Processing Step 2` → `Rechnungsverarbeitung Schritt 2`
   - `OpenAPI Setup Overview` → `OpenAPI-Einrichtung Übersicht`
   - `DeepL Sub Call Activity` → `DeepL-Subprozess-Aufruf`

   **Never translate:** image path tokens inside `(…)` — keep the path byte-for-byte identical.

   **Preserve verbatim (do not translate or alter):**
   - Inline code spans: `` `like this` ``
   - Fenced code blocks and their entire content.
   - Image paths inside `![…](path)` — keep the path byte-for-byte identical.
   - Hyperlink URLs inside `[…](url)` — keep the URL unchanged.
   - Markdown structural markers: `#`, `##`, `###`, `**`, `_`, `|`, `---`.
   - HTML comments.

   **Translate:**
   - All prose and bullet point text.
   - Heading label text (e.g. `### Key features` → `### Wichtigste Funktionen`).
   - Image alt text (the `…` inside `![…]`).
   - Link display text (the `…` inside `[…](url)`).

2.a **Prefer repository CMS translations when available (new):**
   - Before running the general translation pass, check the product module and main module for CMS translation files (e.g., `cms/cms_de.yaml`, `cms_de.yaml` or similar paths documented in the repository).
   - If a German CMS file is found, parse it and build a mapping of English display strings to German equivalents for the keys used in README content (for example keys under `Processes/Names`, dialog titles, labels used by demo workflows).
   - CMS selection rule: When translating to German, prefer project-provided German CMS files from the most specific scope to the most general scope, for example: `<productModule>/cms/cms_de.yaml`, `<productModule>/cms_de.yaml`, `<mainModule>/cms/cms_de.yaml`, `<mainModule>/cms_de.yaml`, repository `cms/cms_de.yaml`, repository root `cms_de.yaml`.
   - Replace occurrences of exact CMS-sourced English display strings in `README.md` (headings, workflow names, image alt texts, inline link text) with the German CMS equivalents prior to the prose translation step. Matches must be exact and respect surrounding punctuation/whitespace.
   - After applying CMS-sourced substitutions, translate remaining prose to German. Do not double-translate strings that matched CMS mappings.
   - Log or record substitutions so the translation step skips already-localized fragments (prevents double-translation or misinterpretation of placeholders).
   - Only fall back to machine translation for phrases not covered by CMS mappings.

   Rationale: project-provided CMS translations are authoritative and preserve domain-specific terminology and phrasing; preferring them avoids incorrect or inconsistent translations for UI labels and workflow titles.

3. **Apply tone**:
   - Use `du`/`dein` (informal second person) throughout.
   - Keep sentences short and direct.
   - Lead bullet points with a strong verb or benefit.
   - Avoid passive voice and overly technical jargon in prose.
   - Maintain a professional register — friendly but not casual.

3.a **Post-translation lint gate (mandatory before write):**
   After translation, scan the generated German content for English section headings and labels that should have been translated.
   Fail fast (re-translate affected lines) if any of these patterns are found outside fenced code blocks or inline code spans:

   | Forbidden English pattern | Required German form |
   |--------------------------|---------------------|
   | `^## Setup$` | `## Einrichtung` |
   | `^### Web Services$` | `### Webdienste` |
   | `^### Callable Subprocesses$` | `### Aufrufbare Subprozesse` |
   | `^### Dialog Components$` | `### Dialog-Komponenten` |
   | `^### Rest Clients$` | `### Rest-Clients` |
   | `^### Maven Artifacts$` | `### Maven-Artefakte` |
   | `^## Components$` | `## Komponenten` |
   | `    - Input:$` | `    - Eingabe:` |
   | `    - Result:$` | `    - Ergebnis:` |
   | `- \*\*Signature\*\*:` | `- **Signatur**:` |

   This gate prevents silent pass-through of English structural tokens.

4. **Assemble and write the output file**:

   - Keep the heading structure.
   - Write to `<productModule>/README_DE.md`. If the file already exists, overwrite it.
   - Enforce atomic write mode: truncate target file first, then write the complete translated content in one pass.
   - Treat the existing `<productModule>/README_DE.md` as write-only output during translation. Never read or merge prior target content when generating the new translation.
   - Never append (`>>`) or perform incremental patch updates for final translated output.
   - Post-write duplicate check: ensure exactly one full-document start exists (single leading `# ...`). If a second full document start is detected, regenerate from current `README.md` and overwrite once.

## Quality criteria

- `README_DE.md` exists at the correct path.
- No inline code span, image path, URL, or fenced code block was altered.
- The German text reads naturally with `du`/`dein` and short, benefit-led bullet points.

## Invocation requirement

When invoked by `generate-ivy-readme`, this skill must create or overwrite `<productModule>/README_DE.md` in the same run, and the result must be an actual German translation of `<productModule>/README.md`.

Mandatory expectations:

- `README_DE.md` must be predominantly German, not an unchanged English copy.
- Preserve markdown structure, URLs, image paths, inline code, fenced code blocks, XML snippets, and template variables.
- Translate headings, prose, bullet points, image alt text, and link labels into German.
- Prefer repository-provided German CMS wording when available.
- Keep technical identifiers and configuration keys unchanged.
- Preserve section coverage: every section present in `README.md` must also be present in `README_DE.md`.

Never:

- Skip German generation when `README.md` was generated.
- Copy `README.md` to `README_DE.md` without translation.
- Hand-patch an outdated `README_DE.md`; regenerate it from the current `README.md`.
