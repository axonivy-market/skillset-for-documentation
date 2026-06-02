# Output Format Reference

This document defines the required markdown schema that the `form-components-listing` skill must return.

## Required Per-Component Shape

For each dialog or form component, emit exactly one block with this structure and this field order:

```markdown
#### ComponentName
- **Namespace:** full.namespace.or.(unknown)
- **Component type:** Component dialog | UI dialog | Form dialog
- **Fields:**
  - `fieldName` (FieldType) — description
- **Purpose:** One user-facing sentence
```

## Rules

- `####` heading is required for every component.
- `Namespace`, `Component type`, `Fields`, and `Purpose` are mandatory lines and must appear in that order.
- `Fields` must always be rendered as a section.
- If no fields are declared in the start signature, render:

```markdown
- **Fields:** - (none)
```

- If no purpose can be extracted from CMS, XHTML, or process metadata, render:

```markdown
- **Purpose:** (not documented in source)
```

## Forbidden Output

Do not emit any of the following labels in the final markdown:

- `Parameter`
- `Main feature/logic`
- `UI attributes`
- `Paths`

## Example Output

```markdown
#### WriteMail
- **Namespace:** msgraph.mail.demo.WriteMail
- **Component type:** UI dialog
- **Fields:** - (none)
- **Purpose:** Compose a mail, add or remove recipients, and send the message.
```
