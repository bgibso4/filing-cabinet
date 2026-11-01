#!/usr/bin/env bats

HOOKS="$BATS_TEST_DIRNAME/.."

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/repo"
  export FC_FAST_CMD="true"
  mkdir -p "$CLAUDE_PROJECT_DIR"
  git -C "$CLAUDE_PROJECT_DIR" init -q
  git -C "$CLAUDE_PROJECT_DIR" config user.email t@example.com
  git -C "$CLAUDE_PROJECT_DIR" config user.name t
  printf '.build/\n' >"$CLAUDE_PROJECT_DIR/.gitignore"
  printf 'let a = 1\n' >"$CLAUDE_PROJECT_DIR/A.swift"
  cd "$CLAUDE_PROJECT_DIR"
  # Stubs append to this file whenever Fast runs.
  export RAN="$BATS_TEST_TMPDIR/ran"
}

fast_ran() { [ -s "$RAN" ]; }
set_swift() { printf '%s\n' "$1" >"$CLAUDE_PROJECT_DIR/A.swift"; }

edit_json() { printf '{"session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1"; }
bash_json() { jq -n --arg c "$1" '{session_id:"s1",tool_name:"Bash",tool_input:{command:$c}}'; }
stop_json() { echo '{"session_id":"s1","hook_event_name":"Stop"}'; }

@test "guard blocks edits inside the xcodeproj" {
  run bash -c "'$HOOKS/guard-generated.sh' <<<'$(edit_json /r/FilingCabinet.xcodeproj/project.pbxproj)'"
  [ "$status" -eq 2 ]
  [[ "$output" == *"make generate"* ]]
}

@test "guard blocks edits under Generated" {
  run bash -c "'$HOOKS/guard-generated.sh' <<<'$(edit_json /r/App/Generated/Tokens.swift)'"
  [ "$status" -eq 2 ]
}

@test "guard allows edits elsewhere" {
  run bash -c "'$HOOKS/guard-generated.sh' <<<'$(edit_json /r/App/Home.swift)'"
  [ "$status" -eq 0 ]
}

@test "guard blocks --no-verify" {
  run bash -c "'$HOOKS/guard-hook-bypass.sh' <<<'$(bash_json 'git commit --no-verify -m x')'"
  [ "$status" -eq 2 ]
}

@test "guard blocks git -c core.hooksPath" {
  run bash -c "'$HOOKS/guard-hook-bypass.sh' <<<'$(bash_json 'git -c core.hooksPath=/dev/null commit -m x')'"
  [ "$status" -eq 2 ]
}

@test "guard allows a normal commit" {
  run bash -c "'$HOOKS/guard-hook-bypass.sh' <<<'$(bash_json 'git commit -m x')'"
  [ "$status" -eq 0 ]
}

@test "stop gate passes without running Fast when no Swift changed since green" {
  "$HOOKS/swift-fingerprint.sh" record "$("$HOOKS/swift-fingerprint.sh")"
  export FC_FAST_CMD="echo ran >>'$RAN'; exit 1"
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  ! fast_ran
}

@test "stop gate runs Fast after a Swift change made by any means and blocks on failure" {
  "$HOOKS/swift-fingerprint.sh" record "$("$HOOKS/swift-fingerprint.sh")"
  set_swift 'let a = 2'
  export FC_FAST_CMD="echo ran >>'$RAN'; echo 'Test testFoo failed'; exit 1"
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$(jq -r .decision <<<"$output")" = "block" ]
  fast_ran
}

@test "after a pass a second stop is a no-op" {
  export FC_FAST_CMD="echo ran >>'$RAN'"
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$RAN")" -eq 1 ]
}

@test "a committed change that was never verified still runs Fast" {
  "$HOOKS/swift-fingerprint.sh" record "$("$HOOKS/swift-fingerprint.sh")"
  set_swift 'let a = 3'
  git -C "$CLAUDE_PROJECT_DIR" add -A
  git -C "$CLAUDE_PROJECT_DIR" commit -q -m change
  export FC_FAST_CMD="echo ran >>'$RAN'"
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  fast_ran
}

@test "a subagent stop with an already-green fingerprint passes" {
  "$HOOKS/swift-fingerprint.sh" record "$("$HOOKS/swift-fingerprint.sh")"
  export FC_FAST_CMD="echo ran >>'$RAN'; exit 1"
  run "$HOOKS/stop-gate.sh" <<<'{"session_id":"s1","agent_id":"a1","hook_event_name":"SubagentStop"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  ! fast_ran
}

@test "a subagent keeps its own attempt counter" {
  set_swift 'let a = 4'
  export FC_FAST_CMD="exit 1"
  run "$HOOKS/stop-gate.sh" <<<'{"session_id":"s1","agent_id":"a1","hook_event_name":"SubagentStop"}'
  [ "$(jq -r .decision <<<"$output")" = "block" ]
  [ -e "$TMPDIR/fc-stop-a1" ]
  [ ! -e "$TMPDIR/fc-stop-s1" ]
}

@test "block reason leads with the failing test, ANSI stripped" {
  set_swift 'let a = 5'
  export FC_FAST_CMD="printf 'noise\n\033[31mFailing tests:\033[0m\n    HomeTests.testGreeting\n\nmore noise\n'; exit 1"
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$(jq -r .reason <<<"$output" | head -n1)" = "    HomeTests.testGreeting" ]
  [[ "$(jq -r .reason <<<"$output")" != *$'\033'* ]]
}

@test "guard ignores flags in other commands of the same line" {
  run "$HOOKS/guard-hook-bypass.sh" <<<"$(bash_json 'git commit -m x; head -n1 file')"
  [ "$status" -eq 0 ]
}

@test "stop gate blocks when tests fail and includes the output" {
  export FC_FAST_CMD="echo 'Test testFoo failed'; exit 1"
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  [ "$(jq -r .decision <<<"$output")" = "block" ]
  [[ "$(jq -r .reason <<<"$output")" == *"Test testFoo failed"* ]]
}

@test "stop gate blocks when make fast exits non-zero with no test output" {
  export FC_FAST_CMD="exit 65"
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  [ "$(jq -r .decision <<<"$output")" = "block" ]
}

@test "stop gate hands back after 3 failures" {
  export FC_FAST_CMD="echo boom; exit 1"
  for _ in 1 2; do
    run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
    [ "$(jq -r .decision <<<"$output")" = "block" ]
  done
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"still failing after 3 attempts"* ]]
  [ ! -e "$TMPDIR/fc-stop-s1" ]
}

nojq_path() {
  local bin="$BATS_TEST_TMPDIR/nojq"
  mkdir -p "$bin"
  for tool in bash cat tr mktemp dirname; do ln -sf "$(command -v $tool)" "$bin/$tool"; done
  echo "$bin"
}

@test "stop gate fails open with a message when jq is missing" {
  local bin
  bin="$(nojq_path)"
  run env PATH="$bin" "$bin/bash" "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"jq missing: Fast gate skipped — brew install jq"* ]]
}

@test "guards still fail closed with a message when jq is missing" {
  local bin
  bin="$(nojq_path)"
  for script in format-on-edit guard-generated guard-hook-bypass; do
    run env PATH="$bin" "$bin/bash" "$HOOKS/$script.sh" <<<"$(stop_json)"
    [ "$status" -eq 2 ]
    [[ "$output" == *"jq missing: brew install jq"* ]]
  done
}

@test "guard blocks commit -n, short-flag clusters and case variants" {
  for c in 'git commit -n -m x' 'git commit -anm x' 'git commit -nm "msg"' 'git -c core.hookspath=/dev/null commit' 'git commit --NO-VERIFY'; do
    run "$HOOKS/guard-hook-bypass.sh" <<<"$(bash_json "$c")"
    [ "$status" -eq 2 ]
  done
}

@test "guard allows commit -m and git log -n" {
  for c in 'git commit -m "fix"' 'git log -n 3' 'git commit --amend -m x' 'git commit -am "fix"'; do
    run "$HOOKS/guard-hook-bypass.sh" <<<"$(bash_json "$c")"
    [ "$status" -eq 0 ]
  done
}

@test "guard ignores flags mentioned inside a commit message" {
  for c in 'git commit -m "mention --no-verify here"' 'git commit -m "catch commit -n"' "git commit -m 'core.hookspath -n'" 'git commit -am "git commit -n"'; do
    run "$HOOKS/guard-hook-bypass.sh" <<<"$(bash_json "$c")"
    [ "$status" -eq 0 ]
  done
}

@test "guard still blocks a bypass flag alongside a commit message" {
  for c in 'git commit -m "msg" --no-verify' 'git commit -nm "msg"' 'git commit -m "x" -n'; do
    run "$HOOKS/guard-hook-bypass.sh" <<<"$(bash_json "$c")"
    [ "$status" -eq 2 ]
  done
}

@test "concurrent stop gates serialize on the lock" {
  set_swift 'let b = 2'
  export FC_FAST_CMD="echo start \$\$ \$(date +%s%N) >>'$TMPDIR/log'; sleep 1; echo end \$\$ \$(date +%s%N) >>'$TMPDIR/log'; exit 1"
  "$HOOKS/stop-gate.sh" <<<'{"session_id":"s1"}' &
  "$HOOKS/stop-gate.sh" <<<'{"session_id":"s2"}' &
  wait
  [ "$(wc -l <"$TMPDIR/log")" -eq 4 ]
  # Serialized means the log reads start, end, start, end.
  [ "$(awk '{print $1}' "$TMPDIR/log" | paste -sd' ' -)" = "start end start end" ]
}
