#!/usr/bin/env bash
# =============================================================================
#          FILE: dependency.sh
#   DESCRIPTION: Dependency check functions.
# =============================================================================

# Checks if 'jq' is installed and executable.
_ensure_jq() {
    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is not installed or not in PATH. Please install it to process JSON files." >&2
        exit 1
    fi
}