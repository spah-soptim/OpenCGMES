# CIMVocabCheck supply-chain artifacts

This directory holds the committed Software Bill of Materials (SBOM) and the
third-party license attribution for the **CIMVocabCheck** distributables (the Java
library, CLI and language server). The CIMNotebook editor plugins keep their own
SBOMs under [`cimnotebook/sbom/`](../../cimnotebook/sbom/). Every file here is
generated, committed, and verified in CI.

| Path                    | Distributable            | Tool                   | Covers                                                                             |
| ----------------------- | ------------------------ | ---------------------- | ---------------------------------------------------------------------------------- |
| `maven/bom.json`        | Java library / CLI / LSP | CycloneDX Maven plugin | `cimxml` + `cimvocabcheck-core`/`cli`/`lsp` and all shipped (compile+runtime) deps |
| `maven/THIRD-PARTY.txt` | "                        | license-maven-plugin   | attribution for the above                                                          |

All BOMs are [CycloneDX](https://cyclonedx.org/) 1.6 JSON.

## Regenerating

```bash
scripts/generate-sbom.sh maven        # requires mvn
```

(`scripts/generate-sbom.sh` with no args regenerates all three components across both
sbom directories.) Output is deterministic (stable component ordering; serial numbers
and build timestamps are stripped/disabled), so re-running with unchanged dependencies
produces byte-identical files.

**Whenever you change a Maven dependency** — a version in any `pom.xml` — re-run the
script and commit the updated files in the same change.

## CI enforcement (`cimvocabcheck-ci` → `sbom` job)

The job re-runs `scripts/generate-sbom.sh maven` (Java toolchain) and:

1. **License gate** — fails if any dependency uses a license that is **not** on
   the reviewed open-source allow-list, or has no detectable license.
2. **Drift check** — `git diff --exit-code -- cimvocabcheck/sbom`. Fails if the
   committed files no longer match the current dependency set. Fix by running
   the script and committing the result.

## License allow-list

All shipped/built-against dependencies must use a reviewed open-source license:

`Apache-2.0`, `MIT`, `ISC`, `BSD-2-Clause`, `BSD-3-Clause`, `EPL-1.0`, `EPL-2.0`,
`GPL-2.0-with-classpath-exception` (OpenJDK-style; `org.glassfish:jakarta.json`,
dual-licensed with EPL-2.0).

The allow-list lives in two places, kept in sync:

- **Maven**: `<includedLicenses>` + `<licenseMerges>` under the
  `license-maven-plugin` config in the root `pom.xml`.
- **npm + Gradle** (CIMNotebook plugins): `ALLOWED` / `MERGES` in
  `scripts/check-sbom-licenses.py`.
