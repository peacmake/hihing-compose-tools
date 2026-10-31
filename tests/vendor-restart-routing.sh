#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/compose"
cat > "$tmp/bin/docker-compose-restart" <<'SH'
#!/usr/bin/env bash
set -eu
printf '%s %s\n' "$HIHING_COMPOSE_INCLUDE_WORKDIR" "$1" > "$PROBE_OUTPUT"
SH
chmod +x "$tmp/bin/docker-compose-restart"
for pair in 'hihing-o-bff:o-bff' 'square-admin:square-admin' 'hihing-chat:hihing-chatbot'; do
  service=${pair%%:*}; expected=${pair#*:}
  PATH="$tmp/bin:$PATH" COMPOSE_ROOT="$tmp/compose" PROBE_OUTPUT="$tmp/output" bash "$root/bin/o-docker-control" restart "$service"
  test "$(cat "$tmp/output")" = "1 $expected"
done
printf 'PASS: vendor restarts route to the same worktree restart for BFF, admin and chatbot\n'
