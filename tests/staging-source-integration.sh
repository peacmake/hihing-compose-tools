#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/work/hihing-o-services/bff/node_modules" "$tmp/work/bin" "$tmp/work/.hihing-staging-source"
touch "$tmp/work/docker-compose.yml" "$tmp/work/.hihing-deploy-profile" "$tmp/work/bin/nest-release.sh"
printf 'hs\n' > "$tmp/work/.hihing-deploy-profile"
git init -q --initial-branch=master "$tmp/source"
git -C "$tmp/source" config user.email test@example.invalid
git -C "$tmp/source" config user.name test
mkdir -p "$tmp/source/bff"
printf 'MASTER\n' > "$tmp/source/bff/source.txt"
git -C "$tmp/source" add .
git -C "$tmp/source" commit -qm initial
git clone -q --bare "$tmp/source" "$tmp/remote.git"
rm -rf "$tmp/work/hihing-o-services"
git clone -q "$tmp/remote.git" "$tmp/work/hihing-o-services"
mkdir -p "$tmp/work/hihing-o-services/bff/node_modules"
printf 'DIRTY\n' > "$tmp/work/hihing-o-services/bff/source.txt"
printf 'UNTRACKED\n' > "$tmp/work/hihing-o-services/bff/new.txt"
printf 'ignored-branch\n' > "$tmp/work/.hihing-staging-source/hihing-o-bff"
cd "$tmp/work"
source "$root/bin/hihing-compose-lib"
realpath() { if [[ "$1" == --relative-to=* ]]; then printf 'bff\n'; else command realpath "$@"; fi; }
resolve_hihing_network() { printf test-network; }
docker() {
  local mount app='' releases='' previous=''
  for mount in "$@"; do
    if [ "$previous" = -v ]; then
      case "$mount" in
        *:/usr/src/app) app="${mount%:/usr/src/app}" ;;
        *:/usr/src/app/.nest-releases) releases="${mount%:/usr/src/app/.nest-releases}" ;;
      esac
    fi
    previous="$mount"
  done
  test -n "$app"
  cat "$app/source.txt" > "$tmp/seen-source"
  if [ -f "$app/new.txt" ]; then cp "$app/new.txt" "$tmp/seen-untracked"; fi
  if [ -n "$releases" ]; then mkdir -p "$releases/test-release"; touch "$releases/test-release/main.js" "$releases/test-release/.build-complete"; printf 'test-release\n'; fi
}
HIHING_STAGING_RESTART_SOURCE=worktree build_fe_release hihing-o-bff
test "$(cat "$tmp/seen-source")" = DIRTY
test "$(cat "$tmp/seen-untracked")" = UNTRACKED
rm "$tmp/seen-untracked"
HIHING_STAGING_RESTART_SOURCE=master build_fe_release hihing-o-bff
test "$(cat "$tmp/seen-source")" = MASTER
test ! -e "$tmp/seen-untracked"
test "$(cat hihing-o-services/bff/.nest-release)" = test-release
mv "$tmp/remote.git" "$tmp/remote-offline.git"
printf 'UNCHANGED' > hihing-o-services/bff/.nest-release
if HIHING_STAGING_RESTART_SOURCE=master build_fe_release hihing-o-bff; then
  echo 'FAIL: master fetch failure was accepted' >&2; exit 1
fi
test "$(cat hihing-o-services/bff/.nest-release)" = UNCHANGED
test "$(cat hihing-o-services/bff/source.txt)" = DIRTY
test "$(cat hihing-o-services/bff/new.txt)" = UNTRACKED
printf 'PASS: dirty and untracked worktree; clean fetched master; fail closed; working tree preserved\n'
