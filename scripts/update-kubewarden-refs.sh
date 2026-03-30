#!/usr/bin/env bash
# update-kubewarden-refs.sh
#
# Replace all kubewarden/github-actions internal SHA references in YAML files
# with a given commit SHA. Run this before tagging a new release so that
# self-referential workflow steps point to the commit with the desired version.
#
# Usage:
#   scripts/update-kubewarden-refs.sh [<commit-sha>]
#
#   <commit-sha>  Full 40-character hex SHA to pin to.
#                 Defaults to the current HEAD of the repository.

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
    echo "Usage: $(basename "$0") [<commit-sha>]"
    echo ""
    echo "  <commit-sha>  40-char hex SHA to pin to (default: HEAD)"
    exit 1
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

is_valid_sha() {
    [[ "$1" =~ ^[0-9a-fA-F]{40}$ ]]
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if [[ $# -gt 1 ]]; then
    die "Too many arguments. Expected at most one SHA argument."
fi

# Resolve repository root so the script works from any working directory.
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
    || die "Not inside a git repository."

if [[ $# -eq 1 ]]; then
    NEW_SHA="$1"
else
    NEW_SHA=$(git -C "$REPO_ROOT" rev-parse HEAD) \
        || die "Failed to resolve HEAD commit SHA."
fi

is_valid_sha "$NEW_SHA" \
    || die "Invalid SHA: '$NEW_SHA'. Must be a 40-character hexadecimal string."

# ---------------------------------------------------------------------------
# Find YAML files
# ---------------------------------------------------------------------------

mapfile -t YAML_FILES < <(
    find "$REPO_ROOT" \
        -type f \( -name "*.yml" -o -name "*.yaml" \) \
        -not -path "*/.git/*"
)

if [[ ${#YAML_FILES[@]} -eq 0 ]]; then
    echo "No YAML files found under $REPO_ROOT."
    exit 0
fi

# ---------------------------------------------------------------------------
# Replace SHA references
#
# Target pattern (with or without a trailing comment):
#   uses: kubewarden/github-actions/<sub-action>@<40-char-sha>[ # anything]
#
# Replacement (no trailing comment):
#   uses: kubewarden/github-actions/<sub-action>@<NEW_SHA>
# ---------------------------------------------------------------------------

CHANGED=0

for FILE in "${YAML_FILES[@]}"; do
    # Check if the file has any kubewarden/github-actions reference at all.
    if ! grep -qE 'uses:[[:space:]]+kubewarden/github-actions/[^@]+@[0-9a-fA-F]{40}' "$FILE" 2>/dev/null; then
        continue
    fi

    # Perform the in-place substitution:
    #   - Match the SHA (40 hex chars) after the @ in a kubewarden ref
    #   - Remove any trailing " # ..." comment on the same line
    if sed -i -E \
        's|(uses:[[:space:]]+kubewarden/github-actions/[^@]+@)[0-9a-fA-F]{40}([[:space:]]*#[^\n]*)?\s*$|\1'"$NEW_SHA"'|g' \
        "$FILE"; then
        echo "Updated: $FILE"
        CHANGED=$((CHANGED + 1))
    else
        die "sed failed on file: $FILE"
    fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $CHANGED -eq 0 ]]; then
    echo "No kubewarden/github-actions SHA references found — nothing to update."
else
    echo ""
    echo "Done. Updated $CHANGED file(s) to SHA $NEW_SHA"
fi
