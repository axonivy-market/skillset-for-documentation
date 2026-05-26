# Output Format

The generated report is Markdown.
- If there are multiple `CallSubStart` with the tag `connector`, the report should be organized as follows:
  - One section per CALLABLE_SUB file (only listed if at least one `CallSubStart` with tag `connector` exists in the file):
    - `#### <path>`
  - Under each file, one bullet per connector start:
      - `Signature`
      - `Input`
      - `Result`
It there is no `CallSubStart` with tag `connector`, the skill should output a single bullet point: `No CallSubStart with tag connector`.

## Field Rules
- `Input` is `none` when no parameter config exists.
- `Result` is `none` when no result config exists.

## Example Output
```
#### docuware-connector/processes/UploadService.p.json
- Signature: uploadFileWithIndexFields
  Input: configKey: String, fileCabinetId: String, file: File, indexFields: List<com.axonivy.connector.docuware.connector.DocuWareProperty>, storeDialogId: String
  Result: document: com.docuware.dev.schema._public.services.platform.Document

- Signature: uploadFileWithIndexFields
  Input: configKey: String, fileCabinetId: String, fileStream: java.io.InputStream, fileName: String, indexFields: List<com.axonivy.connector.docuware.connector.DocuWareProperty>, storeDialogId: String
  Result: document: com.docuware.dev.schema._public.services.platform.Document
```