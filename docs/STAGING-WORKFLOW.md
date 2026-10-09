# HS 스테이징 배포 흐름 (맥북 개발 → GitHub → HS)

`dev-api-hsmaster`(hs.hihing.co.kr) 는 **스테이징 전용**이다. 코드 수정·커밋은 맥북에서 하고, 서버에서는 받아서 배포만 한다.

## 흐름

1. **맥북**: `~/dev-pjt/PJTs/hihing/<repo>` 에서 개발·테스트 후 커밋, `git push origin <branch>`.
2. **HS**: GitHub 기준으로 저장소를 fast-forward 한다.
   ```bash
   hs-sync --dry-run platform     # 받을 커밋만 확인
   hs-sync platform               # 실제 반영 (ff-only)
   hs-sync all                    # 전체 저장소
   ```
3. **HS**: 기존 배포 명령을 그대로 쓴다. `dp-platform`, `dp-i-bff`, `dp-o-bff`, `dp-tv-frontend`, `dp-i-admin`, `dp-on-web`, `dp-on-admin`, `dp-chatbot`, `docker-compose-up` 등.

## hs-sync 규칙

- `git fetch origin` → `git merge --ff-only origin/<현재 브랜치>` 만 한다.
- 추적 파일에 미커밋 변경이 있거나, 서버에만 있는 커밋이 있어 fast-forward 가 안 되면 **거부**하고 이유를 출력한다.
- `reset` / `stash` / `checkout` / `clean` 은 하지 않는다.
- dp-* 는 **로컬 master** 를 체크아웃해 빌드한다(`dp-git-master.sh`, origin pull 없음). 그래서 현재 브랜치가 master 가 아니면 로컬 master 도 `git fetch origin master:master`(ff 만) 로 같이 갱신한다. 끄려면 `--no-master`.
- 별칭: `platform`, `i-services`, `o-services`, `docs`, `compose-tools`, `tv_backend`, `market_backend`, `market_admin`, `web`(=~/www). 디렉터리 이름도 된다.
- `hihing-o-services` 는 `hihing-os` 계정 소유라 hsmaster 로는 거부될 수 있다. 그 계정으로 실행한다.

## 서버 직접 커밋 방지

HS 저장소의 `.git/hooks/pre-commit` 이 커밋을 막는다. 긴급 시에만 `HS_ALLOW_COMMIT=1 git commit ...` 으로 우회하고, 같은 변경을 바로 맥북으로 옮겨 push 한다.

## 설치

`~/bin` 에 복사해서 쓴다: `install -m 755 bin/hs-sync ~/bin/hs-sync` (또는 `install-hihing-compose-tools.sh` 가 `/usr/local/bin` 에 설치).
