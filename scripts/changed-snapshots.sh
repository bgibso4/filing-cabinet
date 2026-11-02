#!/bin/bash
# Print one modified snapshot reference (__Snapshots__/*.png) per line.
# Usage: changed-snapshots.sh [--cached] [base]
#   --cached  compare the index to HEAD (what a commit will contain)
#   base      compare the working tree to this ref (default HEAD)
set -eu
cd "$(git rev-parse --show-toplevel)"
if [ "${1:-}" = "--cached" ]; then
    git diff --cached --name-only --diff-filter=M -- '*__Snapshots__/*.png'
else
    git diff --name-only --diff-filter=M "${1:-HEAD}" -- '*__Snapshots__/*.png'
fi
