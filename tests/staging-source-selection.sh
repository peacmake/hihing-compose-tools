#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/work/bin" "$tmp/work/app/node_modules" "$tmp/work/.hihing-staging-source"
touch "$tmp/work/docker-compose.yml" "$tmp/work/.hihing-deploy-profile" "$tmp/work/bin/nest-release.sh"
cd "$tmp/work"
source "$root/bin/hihing-compose-lib"
FE_RELEASE_APP_DIRS[test-app]=app
FE_RELEASE_KIND[test-app]=nest
resolve_hihing_network() { printf test-network; }
build_fe_release_from_ref() { printf '%s\n' "$2" > "$tmp/chosen"; }
docker() { printf called > "$tmp/docker-called"; }
printf 'old-feature\n' > .hihing-staging-source/test-app
HIHING_STAGING_RESTART_SOURCE=master build_fe_release test-app
test "$(cat "$tmp/chosen")" = master
rm "$tmp/chosen"
HIHING_STAGING_RESTART_SOURCE=worktree build_fe_release test-app
test ! -f "$tmp/chosen"
test -f "$tmp/docker-called"
rm "$tmp/docker-called"
HIHING_STAGING_RESTART_SOURCE= build_fe_release test-app
test "$(cat "$tmp/chosen")" = old-feature
printf 'PASS: master ignores pins; worktree ignores pins; legacy callers retain pins\n'
