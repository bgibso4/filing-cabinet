#!/usr/bin/env bash
# Whether CI's gate already passed on exactly these files, so a push to main can skip the simulator jobs.
#   gate-passed.sh <sha>   exit 0 and print the run's URL when a pull request's CI run succeeded with its smoke job
#                          on a head commit whose tree is <sha>'s tree; exit 1 otherwise
# A PR's CI run tests the PR merged into main. When the PR was up to date with main, its merge to main has the head's
# tree, so the tests already ran on these files. A draft's or a docs-only PR's run has no smoke job, so it never
# counts. If GitHub can't be asked, the answer is no and the gate runs.
# Reads GITHUB_REPOSITORY; calls the GitHub API through gh (GH_TOKEN, actions: read). FC_GH is a seam for the tests.
set -uo pipefail
gh="${FC_GH:-gh}"
sha="$1"
repo="$GITHUB_REPOSITORY"

no() {
	echo "warning: $1: running the gate." >&2
	exit 1
}

tree="$(git rev-parse --verify --quiet "$sha^{tree}")" || no "$sha isn't a commit here"
runs="$("$gh" api "repos/$repo/actions/workflows/ci.yml/runs?event=pull_request&status=success&per_page=50" \
	--jq '.workflow_runs[] | "\(.id) \(.head_commit.tree_id) \(.html_url)"')" || no "couldn't list CI's pull request runs"

while read -r id run_tree url; do
	[ -n "$id" ] && [ "$run_tree" = "$tree" ] || continue
	smoke="$("$gh" api "repos/$repo/actions/runs/$id/jobs" --jq '.jobs[] | select(.name == "smoke") | .conclusion')" ||
		no "couldn't read the jobs of run $id"
	if [ "$smoke" = success ]; then
		echo "$url"
		exit 0
	fi
done <<<"$runs"
exit 1
