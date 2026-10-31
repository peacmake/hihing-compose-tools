#!/usr/bin/env bash
set -euo pipefail
# Install only the staging restart tools; never install or invoke o-docker-dp.
root=/home/hsmaster
repo="$root/hihing-compose-tools"
if [ "$(id -u)" -ne 0 ]; then echo 'Run this installer with sudo on the staging server.' >&2; exit 1; fi
if [ ! -f "$root/.hihing-deploy-profile" ] || [ "$(tr -d '[:space:]' < "$root/.hihing-deploy-profile")" != hs ]; then
  echo 'Refusing: staging profile hs was not confirmed.' >&2; exit 1
fi
for f in bin/dcr bin/dcr-user-wrapper bin/docker-compose-restart bin/hihing-compose-lib bin/o-docker-control; do
  [ -f "$repo/$f" ] || { echo "Missing: $repo/$f" >&2; exit 1; }
done
if [ -n "$(git -c "safe.directory=$repo" -C "$repo" status --porcelain --untracked-files=no)" ]; then
  echo 'Refusing: compose-tools tracked worktree is dirty.' >&2; exit 1
fi
head=$(git -c "safe.directory=$repo" -C "$repo" rev-parse HEAD)
remote=$(git -c "safe.directory=$repo" -C "$repo" rev-parse refs/remotes/origin/main)
if [ "$head" != "$remote" ]; then echo 'Refusing: checkout is not origin/main.' >&2; exit 1; fi
backup=$(mktemp -d "$root/diagnostics/staging-restart-tools-backup.XXXXXXXX")
for f in /usr/local/bin/dcr /usr/local/bin/docker-compose-restart /usr/local/bin/hihing-compose-lib /usr/local/bin/o-docker-control "$root/bin/docker-compose-restart" "$root/bin/hihing-compose-lib" "$root/.local/bin/dcr"; do
  if [ -f "$f" ]; then mkdir -p "$backup$(dirname "$f")"; cp -p "$f" "$backup$f"; fi
done
install -m 755 "$repo/bin/dcr" /usr/local/bin/dcr
install -m 755 "$repo/bin/docker-compose-restart" /usr/local/bin/docker-compose-restart
install -m 755 "$repo/bin/o-docker-control" /usr/local/bin/o-docker-control
install -m 644 "$repo/bin/hihing-compose-lib" /usr/local/bin/hihing-compose-lib
install -o hsmaster -g hsmaster -m 755 "$repo/bin/docker-compose-restart" "$root/bin/docker-compose-restart"
install -o hsmaster -g hsmaster -m 644 "$repo/bin/hihing-compose-lib" "$root/bin/hihing-compose-lib"
install -d -o hsmaster -g hsmaster -m 755 "$root/.local/bin"
install -o hsmaster -g hsmaster -m 755 "$repo/bin/dcr-user-wrapper" "$root/.local/bin/dcr"
printf 'Installed staging restart tools from %s; backups: %s\n' "$head" "$backup"
