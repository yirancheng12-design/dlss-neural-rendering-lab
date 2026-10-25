# Evidence inventory

[Home](../README.md)

[manifest.json](manifest.json) records byte sizes and SHA-256 hashes of original files in the seven historical archive roots. Each entry identifies its source commit. New case-entry README files are excluded from archival inventory but their Markdown targets are validated. Original scripts and reports are kept unchanged.

[cases.json](cases.json) selects source JSON fields for the offline summary. Fields remain verbatim, including `UNKNOWN` and `NOT_RUN`. Every selection includes limitations. Referenced local files/fields must exist; the inspector does not resolve historical Windows paths or access the network.

To add evidence, review file provenance and privacy, add deliberate manifest entries with their source commit, add a scoped case if useful, and run the [checks](../docs/validation.md). A hash is a baseline change detector, not a statement that the experiment was correct.
