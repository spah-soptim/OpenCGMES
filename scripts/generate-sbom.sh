#!/usr/bin/env bash
# Generate the OpenCGMES supply-chain artifacts (CycloneDX SBOM + THIRD-PARTY attribution).
#
# Usage: scripts/generate-sbom.sh [maven] [vscode] [intellij]   (no args = all three)
#
#   maven    -> cimvocabcheck/sbom/maven/{bom.json,THIRD-PARTY.txt}
#               Java library/CLI/LSP: cimxml + cimvocabcheck-core/cli/lsp and shipped deps.
#   vscode   -> cimnotebook/sbom/vscode/{bom.json,THIRD-PARTY.txt}
#               VS Code extension shipped npm deps (vscode-languageclient, ...).
#   intellij -> cimnotebook/sbom/intellij/{bom.json,THIRD-PARTY.txt}
#               IntelliJ plugin compile deps (IntelliJ Platform, LSP4IJ).
#
# Selecting a subset lets the independent cimvocabcheck / cimnotebook CI workflows each
# regenerate and drift-check only the artifacts they own. All files are committed; CI
# fails if a regeneration differs from what is committed or uses a non-allow-listed license.
#
# Requires (per selected component): mvn (maven), node/npm (vscode), Gradle wrapper (intellij).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VOCAB_SBOM_DIR="${REPO_ROOT}/cimvocabcheck/sbom"   # maven (CIMVocabCheck)
NB_SBOM_DIR="${REPO_ROOT}/cimnotebook/sbom"        # vscode + intellij (CIMNotebook)
MVN="${MVN:-mvn}"
GRADLE="${GRADLE:-./gradlew}"
CYCLONEDX_NPM="@cyclonedx/cyclonedx-npm@4.2.1"

# Which components to (re)generate — default to all.
if [[ $# -eq 0 ]]; then
    COMPONENTS=(maven vscode intellij)
else
    COMPONENTS=("$@")
fi
want() {
    local c
    for c in "${COMPONENTS[@]}"; do [[ "${c}" == "$1" ]] && return 0; done
    return 1
}

# Strip the single metadata.timestamp line from a CycloneDX BOM. CycloneDX stamps
# the current time even in reproducible mode, which would churn the committed
# file on every run; everything else in the BOM is already deterministic.
strip_bom_timestamp() {
    python3 - "$1" <<'PY'
import re, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    lines = fh.readlines()
ts = re.compile(r'^\s{4}"timestamp"\s*:\s*".*Z",\s*$')
kept = [ln for ln in lines if not ts.match(ln)]
removed = len(lines) - len(kept)
if removed != 1:
    sys.exit(f"{path}: expected to strip exactly 1 timestamp line, stripped {removed}")
with open(path, "w", encoding="utf-8") as fh:
    fh.writelines(kept)
PY
}

# ---------------------------------------------------------------------------
# 1. Maven (cimxml + cimvocabcheck-core/cli/lsp)  ->  cimvocabcheck/sbom/maven
# ---------------------------------------------------------------------------
if want maven; then
    echo ">> [maven] Generating CycloneDX SBOM (aggregate) ..."
    # Plugin config (output path, reproducible flags, scopes) lives in the root
    # pom.xml. Running from the reactor root lets cimvocabcheck-core resolve the cimxml
    # SNAPSHOT from the reactor without a prior `mvn install`.
    ( cd "${REPO_ROOT}" && "${MVN}" -B -ntp org.cyclonedx:cyclonedx-maven-plugin:makeAggregateBom )

    echo ">> [maven] Generating THIRD-PARTY attribution + enforcing license allow-list ..."
    ( cd "${REPO_ROOT}" && "${MVN}" -B -ntp license:aggregate-add-third-party )

    strip_bom_timestamp "${VOCAB_SBOM_DIR}/maven/bom.json"
fi

# ---------------------------------------------------------------------------
# 2. VS Code extension (shipped npm dependencies)  ->  cimnotebook/sbom/vscode
# ---------------------------------------------------------------------------
if want vscode; then
    echo ">> [vscode] Generating CycloneDX SBOM (shipped npm deps) ..."
    mkdir -p "${NB_SBOM_DIR}/vscode"
    # --omit dev: only what esbuild bundles into the VSIX. --package-lock-only:
    # resolve from the committed lockfile (no install needed). --output-reproducible:
    # no serial number / timestamp.
    ( cd "${REPO_ROOT}/cimnotebook/vscode" && npx --yes "${CYCLONEDX_NPM}" \
        --omit dev --package-lock-only --output-reproducible \
        --output-format JSON --output-file "${NB_SBOM_DIR}/vscode/bom.json" )

    echo ">> [vscode] Checking license allow-list + writing attribution ..."
    python3 "${SCRIPT_DIR}/check-sbom-licenses.py" \
        --bom "${NB_SBOM_DIR}/vscode/bom.json" \
        --output "${NB_SBOM_DIR}/vscode/THIRD-PARTY.txt" \
        --name "CIMNotebook VS Code extension"
fi

# ---------------------------------------------------------------------------
# 3. IntelliJ plugin (compile-time IntelliJ Platform libraries + LSP4IJ)
#    ->  cimnotebook/sbom/intellij  (cyclonedxBom destination set in build.gradle.kts)
# ---------------------------------------------------------------------------
if want intellij; then
    echo ">> [intellij] Generating CycloneDX SBOM (compileClasspath) ..."
    # Task config (scope = compileClasspath, output path) lives in build.gradle.kts.
    ( cd "${REPO_ROOT}/cimnotebook/intellij" && ${GRADLE} cyclonedxBom --no-daemon -q )
    strip_bom_timestamp "${NB_SBOM_DIR}/intellij/bom.json"

    echo ">> [intellij] Checking license allow-list + writing attribution ..."
    python3 "${SCRIPT_DIR}/check-sbom-licenses.py" \
        --bom "${NB_SBOM_DIR}/intellij/bom.json" \
        --output "${NB_SBOM_DIR}/intellij/THIRD-PARTY.txt" \
        --name "CIMNotebook IntelliJ plugin"
fi

echo ">> Done. Generated: ${COMPONENTS[*]}"
