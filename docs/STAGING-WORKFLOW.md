# HS 스테이징 배포 흐름 (맥북 개발 → GitHub → HS)

`dev-api-hsmaster`(hs.hihing.co.kr) 는 **스테이징 전용**이다. 2026-10-31에 아래 동작의 도구가 설치됐다. 코드 수정·커밋은 맥북에서 하고, 서버에서는 받아서 배포만 한다.

깃 커밋 메시지의 제목과 본문은 한글로만 작성하고 영문 접두어도 쓰지 않는다.

사용자가 스테이징 배포를 요청하면 아래 스테이징 순서까지 수행한다. 운영 배포는 사용자가 별도로 요청했거나 처음부터 명시한 경우에만 진행한다. 이미 운영 배포가 요청된 경우 스테이징 통과 후 같은 확인을 다시 묻지 않는다.

## 스테이징 재기동 명령과 소스 선택

- `dcr <서비스>`는 스테이징 최종 검증용이다. 체크아웃과 서비스별 선택 파일을 무시하고 최신 `origin/master`를 가져와 그 커밋으로 빌드한다. fetch 실패 시 중단하며 기존 커밋으로 진행하지 않는다. master 릴리스 빌드를 지원하지 않는 서비스나 빌드 생략 옵션은 거부한다.
- `docker-compose-restart <서비스>`는 스테이징 중간 검증용이다. 현재 체크아웃과 미커밋·미추적 변경을 포함해 빌드하며, 서비스별 선택 파일을 무시한다. 소스 경로·브랜치·커밋·변경 파일이 로그에 표시된다. `sudo o-docker-control restart <서비스>`도 같은 방식이다.
- 두 경로 모두 기존 선빌드·롤링 및 헬스 검사를 유지한다. 작업 트리가 빌드 중 바뀌지 않게 관리하고, 미커밋 빌드의 검증 결과를 운영 배포 승인 근거로 사용하지 않는다. `o-docker-dp restart`는 별도의 운영 배포 명령으로 유지한다.

## 흐름

1. **맥북**: 대상 변경을 검증하고 `master`에 한글 메시지로 커밋한 뒤 `git push origin master`로 푸시한다.
2. **HS**: `ssh dev-api-hsmaster`로 접속해 변경된 저장소만 GitHub 기준으로 fast-forward 한다.
   ```bash
   ~/bin/hs-sync --dry-run platform i-services
   ~/bin/hs-sync platform i-services
   ```
   변경이 없는 저장소는 제외한다. 서버의 현재 브랜치가 `master`인지, 체크아웃·로컬 `master`·`origin/master`가 푸시한 커밋과 같은지, 관련 작업 트리에 다른 변경이 없는지 확인한다. 예를 들어 platform은 다음 명령으로 확인한다.
   ```bash
   target_repo="$HOME/hihing-platform-api"
   git -C "$target_repo" status --short --branch
   git -C "$target_repo" rev-parse HEAD
   git -C "$target_repo" rev-parse refs/heads/master
   git -C "$target_repo" rev-parse refs/remotes/origin/master
   git -C "$target_repo" ls-remote --heads origin master
   ```
   미커밋 작업이나 서버 전용 커밋 때문에 거부되면 보존하고 중단한다.
3. **HS 스테이징**: 바뀐 서비스만 `dcr <서비스>`로 배포한다. `dcr`은 원격 master 스냅샷을 빌드하므로 배포 후 빌드 로그의 커밋과 서버 체크아웃·현재 원격 master가 같은지 다시 확인한다. 달라졌으면 동기화와 배포를 반복한다.
4. **스테이징 검증**: 실제 릴리스·커밋·health·로그와 변경 기능의 API 또는 화면을 확인한다. DB 변경이 있으면 마이그레이션과 데이터 호환성도 확인한다. 합성 검증과 실제 사용자 검증을 구분해 보고한다.
5. **운영 요청이 있는 경우**: 원격 master·서버 로컬 master·스테이징 검증 커밋을 다시 비교하고, 같을 때 HS에서 해당 `dp-*`만 실행한다. `dp-platform`, `dp-i-bff`, `dp-o-bff`, `dp-tv-frontend`, `dp-i-admin`, `dp-on-web`, `dp-on-admin`, `dp-chatbot`은 운영 배포 명령이다. 실제 운영 릴리스·health와 변경 기능을 확인한다. 커밋이 바뀌면 `hs-sync`부터 스테이징 배포·검증을 반복한다.

사용자가 스테이징까지만 요청했거나 운영을 요청하지 않은 경우 4단계에서 멈춘다. 푸시나 배포가 권한·자동 승인 검토에 막히면 우회하지 않고 중단된 단계와 사유를 보고한다.

## hs-sync 규칙

- `git fetch origin` → `git merge --ff-only origin/<현재 브랜치>` 만 한다.
- 추적 파일에 미커밋 변경이 있거나, 서버에만 있는 커밋이 있어 fast-forward 가 안 되면 **거부**하고 이유를 출력한다.
- `reset` / `stash` / `checkout` / `clean` 은 하지 않는다.
- dp-* 는 기본적으로 **로컬 master** 를 체크아웃해 빌드하며 자동으로 origin을 pull하지 않는다. `hs-sync`는 기본적으로 로컬 master도 fast-forward 갱신하고 `--no-master`는 이 갱신을 생략한다. 운영 배포 전에는 로컬 master·원격 master·`dcr` 최종 스테이징 검증 커밋의 일치를 별도로 확인한다. `HIHING_DP_KEEP_CHECKOUT=1` 등으로 다른 브랜치를 운영에 빌드하지 않는다.
- 별칭: `platform`, `i-services`, `o-services`, `docs`, `compose-tools`, `tv_backend`, `market_backend`, `market_admin`, `web`(=~/www). 디렉터리 이름도 된다.
- `hihing-o-services` 는 `hihing-os` 계정 소유라 hsmaster 로는 거부될 수 있다. 그 계정으로 실행한다.

## 서버 직접 커밋 방지

HS 저장소의 `.git/hooks/pre-commit` 이 커밋을 막는다. 긴급 시에만 `HS_ALLOW_COMMIT=1 git commit ...` 으로 우회하고, 같은 변경을 바로 맥북으로 옮겨 push 한다.

## 설치

`~/bin` 에 복사해서 쓴다: `install -m 755 bin/hs-sync ~/bin/hs-sync` (또는 `install-hihing-compose-tools.sh` 가 `/usr/local/bin` 에 설치).
