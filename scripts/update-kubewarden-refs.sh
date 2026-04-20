#!/usr/bin/env bash
# update-kubewarden-refs.sh
#
# Replace all kubewarden/github-actions internal SHA references in YAML files
# with a given commit SHA. Run this before tagging a new release so that
# self-referential workflow steps point to the commit with the desired version.
#
# This covers every file that references kubewarden/github-actions — including
# policy-gh-action-dependencies/action.yml (which pins kwctl-installer,
# syft-installer, and binaryen-installer) and all workflow files that consume
# policy-gh-action-dependencies — because all of them use the same
# kubewarden/github-actions/<sub-action>@<sha> pattern.
#
# Optionally, third-party sigstore/cosign-installer pins can be updated at the
# same time with --cosign-version (requires the gh CLI).
#
# Usage:
#   scripts/update-kubewarden-refs.sh [--cosign-version <tag>] [<commit-sha>]
#
#   --cosign-version <tag>  Update every sigstore/cosign-installer pin to this
#                           tag (e.g. v4.2.0). Fetches the commit SHA via the
#                           GitHub API; requires gh CLI to be installed.
#   <commit-sha>            Full 40-character hex SHA to pin to.
#                           Defaults to the current HEAD of the repository.

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
    echo "Usage: $(basename "$0") [--cosign-version <tag>] [<commit-sha>]"
    echo ""
    echo "  --cosign-version <tag>  Update sigstore/cosign-installer pins to this"
    echo "                          tag (e.g. v4.2.0). Requires gh CLI."
    echo "  <commit-sha>            40-char hex SHA to pin to (default: HEAD)"
    exit 1
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

is_valid_sha() {
    [[ "$1" =~ ^[0-9a-fA-F]{40}$ ]]
}

is_valid_tag() {
    # Accept typical semver-style git tags: v1.2.3, v1.2.3-rc1, etc.
    [[ "$1" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?([._-][a-zA-Z0-9._-]+)*$ ]]
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

COSIGN_VERSION=""
NEW_SHA=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        --cosign-version)
            [[ $# -ge 2 ]] || die "--cosign-version requires a tag argument."
            COSIGN_VERSION="$2"
            shift 2
            ;;
        -*)
            die "Unknown option: '$1'"
            ;;
        *)
            [[ -z "$NEW_SHA" ]] || die "Too many arguments. Expected at most one SHA argument."
            NEW_SHA="$1"
            shift
            ;;
    esac
done

# Resolve repository root so the script works from any working directory.
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
    || die "Not inside a git repository."

if [[ -z "$NEW_SHA" ]]; then
    NEW_SHA=$(git -C "$REPO_ROOT" rev-parse HEAD) \
        || die "Failed to resolve HEAD commit SHA."
fi

is_valid_sha "$NEW_SHA" \
    || die "Invalid SHA: '$NEW_SHA'. Must be a 40-character hexadecimal string."

# ---------------------------------------------------------------------------
# Resolve cosign SHA if requested
# ---------------------------------------------------------------------------

COSIGN_SHA=""

if [[ -n "$COSIGN_VERSION" ]]; then
    is_valid_tag "$COSIGN_VERSION" \
        || die "Invalid cosign tag: '$COSIGN_VERSION'. Expected format: v1.2.3"

    command -v gh >/dev/null 2>&1 \
        || die "gh CLI not found. Install it or omit --cosign-version."

    echo "Fetching commit SHA for sigstore/cosign-installer@${COSIGN_VERSION}..."
    COSIGN_SHA=$(gh api "repos/sigstore/cosign-installer/commits/${COSIGN_VERSION}" --jq '.sha' 2>/dev/null) \
        || die "Failed to fetch SHA for sigstore/cosign-installer@${COSIGN_VERSION}. Check the tag name and gh authentication."

    is_valid_sha "$COSIGN_SHA" \
        || die "Unexpected response from GitHub API (not a valid SHA): '$COSIGN_SHA'"

    echo "  cosign-installer ${COSIGN_VERSION} → ${COSIGN_SHA}"
fi

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
# Kubewarden target pattern (with or without a trailing comment):
#   uses: kubewarden/github-actions/<sub-action>@<40-char-sha>[ # anything]
#
# Replacement (no trailing comment):
#   uses: kubewarden/github-actions/<sub-action>@<NEW_SHA>
#
# Cosign target pattern (trailing comment replaced with new version tag):
#   uses: sigstore/cosign-installer@<40-char-sha>[ # anything]
#
# Replacement:
#   uses: sigstore/cosign-installer@<COSIGN_SHA> # <COSIGN_VERSION>
# ---------------------------------------------------------------------------

KW_CHANGED=0
COSIGN_CHANGED=0
COSIGN_SKIPPED=0

for FILE in "${YAML_FILES[@]}"; do
    HAS_KW=false
    HAS_COSIGN=false

    grep -qE 'uses:[[:space:]]+kubewarden/github-actions/[^@]+@[0-9a-fA-F]{40}' "$FILE" 2>/dev/null \
        && HAS_KW=true
    grep -qE 'uses:[[:space:]]+sigstore/cosign-installer@[0-9a-fA-F]{40}' "$FILE" 2>/dev/null \
        && HAS_COSIGN=true

    [[ "$HAS_KW" == true || "$HAS_COSIGN" == true ]] || continue

    if [[ "$HAS_KW" == true ]]; then
        sed -i -E \
            's|(uses:[[:space:]]+kubewarden/github-actions/[^@]+@)[0-9a-fA-F]{40}([[:space:]]*#[^\n]*)?\s*$|\1'"$NEW_SHA"'|g' \
            "$FILE" || die "sed failed on file: $FILE"
        echo "Updated (kubewarden refs):   $FILE"
        KW_CHANGED=$((KW_CHANGED + 1))
    fi

    if [[ "$HAS_COSIGN" == true ]]; then
        if [[ -n "$COSIGN_SHA" ]]; then
            sed -i -E \
                's|(uses:[[:space:]]+sigstore/cosign-installer@)[0-9a-fA-F]{40}([[:space:]]*#[^\n]*)?\s*$|\1'"$COSIGN_SHA"' # '"$COSIGN_VERSION"'|g' \
                "$FILE" || die "sed failed on file: $FILE"
            echo "Updated (cosign-installer):  $FILE"
            COSIGN_CHANGED=$((COSIGN_CHANGED + 1))
        else
            COSIGN_SKIPPED=$((COSIGN_SKIPPED + 1))
        fi
    fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""

if [[ $KW_CHANGED -eq 0 ]]; then
    echo "No kubewarden/github-actions SHA references found — nothing to update."
else
    echo "Done. Updated $KW_CHANGED file(s) to kubewarden SHA $NEW_SHA"
fi

if [[ $COSIGN_CHANGED -gt 0 ]]; then
    echo "Done. Updated $COSIGN_CHANGED file(s) to cosign-installer ${COSIGN_VERSION} (${COSIGN_SHA})"
fi

if [[ $COSIGN_SKIPPED -gt 0 ]]; then
    echo "Skipped $COSIGN_SKIPPED file(s) with sigstore/cosign-installer pins."
    echo "  Re-run with --cosign-version <tag> to update them (e.g. --cosign-version v4.1.1)."
fi
