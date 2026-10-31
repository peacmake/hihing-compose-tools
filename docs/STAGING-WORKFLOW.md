# HS 스테이징 배포 흐름 (맥북 개발 → GitHub → HS)

`dev-api-hsmaster`(hs.hihing.co.kr) 는 **스테이징 전용**이다. 2026-10-31에 아래 동작의 도구가 설치됐다. 코드 수정·커밋은 맥북에서 하고, 서버에서는 받아서 배포만 한다.

## 스테이징 재기동 명령과 소스 선택

- `dcr <서비스>`는 스테이징 최종 검증용이다. 체크아웃과 서비스별 선택 파일을 무시하고 최신 `origin/master`를 가져와 그 커밋으로 빌드한다. fetch 실패 시 중단하며 기존 커밋으로 진행하지 않는다. master 릴리스 빌드를 지원하지 않는 서비스나 빌드 생략 옵션은 거부한다.
- `docker-compose-restart <서비스>`는 스테이징 중간 검증용이다. 현재 체크아웃과 미커밋·미추적 변경을 포함해 빌드하며, 서비스별 선택 파일을 무시한다. 소스 경로·브랜치·커밋·변경 파일이 로그에 표시된다. `sudo o-docker-control restart <서비스>`도 같은 방식이다.
- 두 경로 모두 기존 선빌드·롤링 및 헬스 검사를 유지한다. 작업 트리가 빌드 중 바뀌지 않게 관리하고, 미커밋 빌드의 검증 결과를 운영 배포 승인 근거로 사용하지 않는다. `o-docker-dp restart`는 별도의 운영 배포 명령으로 유지한다.

## 흐름

1. **맥북**: `~/dev-pjt/PJTs/hihing/<repo>` 에서 개발·테스트 후 커밋, `git push origin <branch>`.
2. **HS**: GitHub 기준으로 저장소를 fast-forward 한다.
   ```bash
   hs-sync --dry-run platform     # 받을 커밋만 확인
   hs-sync platform               # 실제 반영 (ff-only)
   hs-sync all                    # 전체 저장소
   ```
3. **HS 스테이징**: 중간 버전은 `docker-compose-restart <서비스>`로 배포·검증할 수 있다. 최종 master 검증은 `dcr <서비스>`로 한다.
4. **운영 배포 전**: 변경을 `master`에 통합·커밋하고 원격 `master`를 최신화한다. HS의 소스 선택과 실제 빌드 커밋이 최신 원격 `master`와 일치하도록 맞춘 뒤, 그 커밋으로 대상 서비스를 `dcr` 배포·재기동하고 최종 스테이징 검증을 통과한다. 다른 브랜치에서 한 검증만으로는 부족하다.
5. **HS에서 운영 배포**: 최종 스테이징에서 검증한 동일한 최신 `master` 커밋을 소스로 대상 `dp-*`를 실행한다. `dp-platform`, `dp-i-bff`, `dp-o-bff`, `dp-tv-frontend`, `dp-i-admin`, `dp-on-web`, `dp-on-admin`, `dp-chatbot`은 운영 배포 명령이다. 실제 릴리스와 정상 상태를 확인한다. 검증 후 대상 `master`가 바뀌면 새 커밋으로 스테이징부터 다시 배포·검증한다.

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
