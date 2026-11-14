#!/usr/bin/env bash
# Exits 0 when a change touches only docs/, site/ and Markdown (or nothing), 1 when it touches anything else.
#   docs-only.sh <git diff revisions…>   e.g. HEAD^1 HEAD, or BASE...HEAD
# CI's plan uses it to skip the simulator suite, the TestFlight workflow to skip the upload.
set -euo pipefail
changed="$(git diff --name-only "$@")"
[ -z "$changed" ] || ! grep -qvE '^docs/|^site/|\.md$' <<<"$changed"
