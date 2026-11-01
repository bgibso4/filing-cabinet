#!/usr/bin/env bats

HOOKS="$BATS_TEST_DIRNAME/.."

setup() {
  export TMPDIR="$BATS_TEST_TMPDIR"
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR"
  export FC_FAST_CMD="true"
}

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

@test "mark-dirty marks Swift edits only" {
  "$HOOKS/mark-dirty.sh" <<<"$(edit_json /r/README.md)"
  [ ! -e "$TMPDIR/fc-dirty-s1" ]
  "$HOOKS/mark-dirty.sh" <<<"$(edit_json /r/App/Home.swift)"
  [ -e "$TMPDIR/fc-dirty-s1" ]
}

@test "stop gate passes when the session never edited Swift" {
  export FC_FAST_CMD="echo should-not-run; exit 1"
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stop gate blocks when tests fail and includes the output" {
  touch "$TMPDIR/fc-dirty-s1"
  export FC_FAST_CMD="echo 'Test testFoo failed'; exit 1"
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  [ "$(jq -r .decision <<<"$output")" = "block" ]
  [[ "$(jq -r .reason <<<"$output")" == *"Test testFoo failed"* ]]
}

@test "stop gate blocks when make fast exits non-zero with no test output" {
  touch "$TMPDIR/fc-dirty-s1"
  export FC_FAST_CMD="exit 65"
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  [ "$(jq -r .decision <<<"$output")" = "block" ]
}

@test "stop gate hands back after 3 failures" {
  touch "$TMPDIR/fc-dirty-s1"
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

@test "stop gate clears the marker on success" {
  touch "$TMPDIR/fc-dirty-s1"
  echo 2 >"$TMPDIR/fc-stop-s1"
  run "$HOOKS/stop-gate.sh" <<<"$(stop_json)"
  [ "$status" -eq 0 ]
  [ ! -e "$TMPDIR/fc-dirty-s1" ]
  [ ! -e "$TMPDIR/fc-stop-s1" ]
}

@test "hooks fail closed with a message when jq is missing" {
  local bin="$BATS_TEST_TMPDIR/nojq"
  mkdir -p "$bin"
  for tool in bash cat tr mktemp dirname; do ln -sf "$(command -v $tool)" "$bin/$tool"; done
  for script in format-on-edit guard-generated guard-hook-bypass mark-dirty stop-gate; do
    run env PATH="$bin" "$bin/bash" "$HOOKS/$script.sh" <<<"$(stop_json)"
    [ "$status" -eq 2 ]
    [[ "$output" == *"jq missing: brew install jq"* ]]
  done
}

@test "concurrent stop gates serialize on the lock" {
  touch "$TMPDIR/fc-dirty-s1" "$TMPDIR/fc-dirty-s2"
  export FC_FAST_CMD="echo start \$\$ \$(date +%s%N) >>'$TMPDIR/log'; sleep 1; echo end \$\$ \$(date +%s%N) >>'$TMPDIR/log'"
  "$HOOKS/stop-gate.sh" <<<'{"session_id":"s1"}' &
  "$HOOKS/stop-gate.sh" <<<'{"session_id":"s2"}' &
  wait
  [ "$(wc -l <"$TMPDIR/log")" -eq 4 ]
  # Serialized means the log reads start, end, start, end.
  [ "$(awk '{print $1}' "$TMPDIR/log" | paste -sd' ' -)" = "start end start end" ]
}
