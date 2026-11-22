#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# scripts/ci/gate-passed.sh: whether a push to main can skip the gate because a PR passed it on the same files.

REPO="$BATS_TEST_DIRNAME/../../.."

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX/bin"
  git -C "$FIX" init -q -b main
  git -C "$FIX" config user.email t@example.com
  git -C "$FIX" config user.name t
  cd "$FIX"
  printf 'a\n' >a.txt
  git add -A && git commit -qm base
  HEAD_SHA="$(git rev-parse HEAD)"
  TREE="$(git rev-parse HEAD^{tree})"

  # Stub gh: answers from files, as the script's --jq would print them. runs: "<id> <tree> <url>" lines; jobs-<id>:
  # the smoke job's conclusion (empty when the run had none). STUB_GH_FAIL=1 makes every call fail.
  export STUB="$BATS_TEST_TMPDIR/stub"
  mkdir -p "$STUB"
  cat >"$FIX/bin/gh" <<'GH'
#!/usr/bin/env bash
[ -z "${STUB_GH_FAIL:-}" ] || { echo "gh: HTTP 502" >&2; exit 1; }
case "$2" in
*/workflows/ci.yml/runs*) cat "$STUB/runs" 2>/dev/null ;;
*/runs/*/jobs) id="${2%/jobs}"; cat "$STUB/jobs-${id##*/}" 2>/dev/null ;;
*) echo "unexpected: $*" >&2; exit 1 ;;
esac
GH
  chmod +x "$FIX/bin/gh"
  export FC_GH="$FIX/bin/gh" GITHUB_REPOSITORY=owner/repo
}

run_record() { # <id> <tree> <smoke job conclusion, or "" for none>
  echo "$1 $2 https://github.com/owner/repo/actions/runs/$1" >>"$STUB/runs"
  echo "$3" >"$STUB/jobs-$1"
}

@test "a green ready PR run on the same tree passes" {
  run_record 7 0000000000000000000000000000000000000000 success
  run_record 9 "$TREE" success
  run -0 --separate-stderr "$REPO/scripts/ci/gate-passed.sh" "$HEAD_SHA"
  [ "$output" = "https://github.com/owner/repo/actions/runs/9" ]
}

@test "a green run on a different tree doesn't" {
  run_record 9 0000000000000000000000000000000000000000 success
  run -1 --separate-stderr "$REPO/scripts/ci/gate-passed.sh" "$HEAD_SHA"
  [ -z "$output" ]
}

@test "a run whose smoke job didn't run doesn't" {
  run_record 9 "$TREE" ""
  run -1 --separate-stderr "$REPO/scripts/ci/gate-passed.sh" "$HEAD_SHA"
}

@test "a run whose smoke job failed doesn't" {
  run_record 9 "$TREE" failure
  run -1 --separate-stderr "$REPO/scripts/ci/gate-passed.sh" "$HEAD_SHA"
}

@test "a later green run on the same tree still counts after a checks-only one" {
  run_record 8 "$TREE" ""
  run_record 9 "$TREE" success
  run -0 --separate-stderr "$REPO/scripts/ci/gate-passed.sh" "$HEAD_SHA"
  [ "$output" = "https://github.com/owner/repo/actions/runs/9" ]
}

@test "gh failing runs the gate" {
  run_record 9 "$TREE" success
  STUB_GH_FAIL=1 run -1 --separate-stderr "$REPO/scripts/ci/gate-passed.sh" "$HEAD_SHA"
  [[ "$stderr" == *"running the gate"* ]]
}

@test "no runs at all runs the gate" {
  run -1 --separate-stderr "$REPO/scripts/ci/gate-passed.sh" "$HEAD_SHA"
}
