# HS 스테이징 배포 흐름 (맥북 개발 → GitHub → HS)

`dev-api-hsmaster`(hs.hihing.co.kr) 는 **스테이징 전용**이다. 코드 수정·커밋은 맥북에서 하고, 서버에서는 받아서 배포만 한다.

## 스테이징 재기동 명령과 소스 선택

- 스테이징 서버에서 `dcr <서비스>`로 배포·재기동한다. 현재 서버의 `~/.local/bin/dcr`은 `/usr/local/bin/docker-compose-restart`를 그대로 실행하므로 두 명령은 같은 동작이다. `dcr` 대신 `docker-compose-restart`를 써도 브랜치 선택이 바뀌지 않는다.
- 릴리스 빌드 대상 서비스에 `/home/hsmaster/.hihing-staging-source/<서비스명>` 파일이 있고 내용이 비어 있지 않으면, 체크아웃 브랜치보다 이 파일에 적힌 브랜치의 `origin/<브랜치>`가 우선한다. 소스 선택 파일이 없는 대상은 해당 저장소의 현재 체크아웃에서 빌드한다. 빌드 로그의 실제 ref와 커밋을 확인한다.
- 중간 검증에서 다른 브랜치가 필요하면 서비스별 소스 선택 파일이 있는지 먼저 확인한다. 파일이 있으면 그 서비스의 선택 ref를 해당 원격 브랜치로 맞추고, 없으면 해당 저장소의 체크아웃을 대상 브랜치로 맞춘 뒤 `dcr`로 배포한다. 빌드 후 선택 ref, 실행 릴리스와 검증 결과를 기록한다.
- 선택 ref 빌드의 fetch가 실패하면 기존에 받아 둔 `origin/<브랜치>`로 계속 빌드할 수 있으므로, 로그와 커밋을 반드시 대조한다. 운영 전 최종 검증 때는 소스 선택을 `master`로 되돌리거나 체크아웃을 최신 master로 맞추고, 필요한 연관 패키지 소스까지 확인한다.
- 2026-10-31 확인 당시 선택 파일은 `hihing-o-bff`, `square-admin`, `hihing-chatbot`에 있었고 모두 `master`였다. 설정은 변경될 수 있으므로 배포 시마다 다시 확인한다. 조회 시각의 상태이지 다른 서비스가 항상 master라는 뜻은 아니다.

## 흐름

1. **맥북**: `~/dev-pjt/PJTs/hihing/<repo>` 에서 개발·테스트 후 커밋, `git push origin <branch>`.
2. **HS**: GitHub 기준으로 저장소를 fast-forward 한다.
   ```bash
   hs-sync --dry-run platform     # 받을 커밋만 확인
   hs-sync platform               # 실제 반영 (ff-only)
   hs-sync all                    # 전체 저장소
   ```
3. **HS 스테이징**: 대상 서비스만 `dcr <서비스>`로 빌드·재기동하고 기능과 정상 상태를 검증한다. 개발 중간 버전은 다른 브랜치로 배포할 수 있다.
4. **운영 배포 전**: 변경을 `master`에 통합·커밋하고 원격 `master`를 최신화한다. HS의 소스 선택과 실제 빌드 커밋이 최신 원격 `master`와 일치하도록 맞춘 뒤, 그 커밋으로 대상 서비스를 `dcr` 배포·재기동하고 최종 스테이징 검증을 통과한다. 다른 브랜치에서 한 검증만으로는 부족하다.
5. **HS에서 운영 배포**: 최종 스테이징에서 검증한 동일한 최신 `master` 커밋을 소스로 대상 `dp-*`를 실행한다. `dp-platform`, `dp-i-bff`, `dp-o-bff`, `dp-tv-frontend`, `dp-i-admin`, `dp-on-web`, `dp-on-admin`, `dp-chatbot`은 운영 배포 명령이다. 실제 릴리스와 정상 상태를 확인한다. 검증 후 대상 `master`가 바뀌면 새 커밋으로 스테이징부터 다시 배포·검증한다.

## hs-sync 규칙

- `git fetch origin` → `git merge --ff-only origin/<현재 브랜치>` 만 한다.
- 추적 파일에 미커밋 변경이 있거나, 서버에만 있는 커밋이 있어 fast-forward 가 안 되면 **거부**하고 이유를 출력한다.
- `reset` / `stash` / `checkout` / `clean` 은 하지 않는다.
- dp-* 는 기본적으로 **로컬 master** 를 체크아웃해 빌드하며 자동으로 origin을 pull하지 않는다. `hs-sync`는 기본적으로 로컬 master도 fast-forward 갱신하고 `--no-master`는 이 갱신을 생략한다. `--no-master`는 중간 스테이징 작업에만 사용하고, 운영 배포 전에는 로컬 master·원격 master·최종 스테이징 검증 커밋의 일치를 별도로 확인한다. `HIHING_DP_KEEP_CHECKOUT=1` 등으로 다른 브랜치를 운영에 빌드하지 않는다.
- 별칭: `platform`, `i-services`, `o-services`, `docs`, `compose-tools`, `tv_backend`, `market_backend`, `market_admin`, `web`(=~/www). 디렉터리 이름도 된다.
- `hihing-o-services` 는 `hihing-os` 계정 소유라 hsmaster 로는 거부될 수 있다. 그 계정으로 실행한다.

## 서버 직접 커밋 방지

HS 저장소의 `.git/hooks/pre-commit` 이 커밋을 막는다. 긴급 시에만 `HS_ALLOW_COMMIT=1 git commit ...` 으로 우회하고, 같은 변경을 바로 맥북으로 옮겨 push 한다.

## 설치

`~/bin` 에 복사해서 쓴다: `install -m 755 bin/hs-sync ~/bin/hs-sync` (또는 `install-hihing-compose-tools.sh` 가 `/usr/local/bin` 에 설치).
