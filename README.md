## co-bricks

![coverage][coverage_badge]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

[Very Good CLI][very_good_cli_link]로 생성됨 🤖

Mason 브릭 동기화 CLI 도구입니다.

---

## 시작하기 🚀

### 설치

#### 옵션 1: GitHub에서 설치 (권장)

```sh
dart pub global activate --source git https://github.com/coco-de/co-bricks.git
```

#### 옵션 2: 로컬 경로에서 설치

레포지토리를 로컬에 클론한 경우, 로컬 경로에서 활성화할 수 있습니다:

```sh
# co-bricks 디렉토리로 이동
cd /path/to/co-bricks

# 로컬 경로에서 활성화
dart pub global activate --source path .

# 또는 절대 경로로 활성화
dart pub global activate --source path /absolute/path/to/co-bricks
```

#### 옵션 3: pub.dev에서 설치 (향후)

[pub.dev](https://pub.dev)에 배포되면 다음 명령어로 전역 활성화할 수 있습니다:

```sh
dart pub global activate co-bricks
```

### 설치 확인

활성화 후 설치를 확인하세요:

```sh
# co-bricks가 설치되었는지 확인
dart pub global list | grep co-bricks

# CLI 테스트
co-bricks --help
```

### PATH 설정

활성화 후 `co-bricks` 명령어를 찾을 수 없는 경우, pub cache bin 디렉토리를 PATH에 추가하세요:

**zsh 사용 시 (macOS/Linux):**
```sh
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc
```

**bash 사용 시:**
```sh
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.bashrc
source ~/.bashrc
```

## 사용법

### 개발 중 (권장)

개발 중에는 최신 코드 변경사항이 즉시 반영되도록 `dart run` 명령을 사용하세요:

> **참고**: Global activation으로는 최신 변경사항이 즉시 반영되지 않을 수 있습니다.
> 개발 중에는 항상 `dart run`을 사용하세요.

```sh
# Makefile 사용 (가장 간단)
$ cd template/co-bricks
$ make sync-monorepo PROJECT=good_teacher
$ make sync-app PROJECT=good_teacher

# dart run 직접 사용
$ dart run template/co-bricks/bin/co_bricks.dart sync --type monorepo --project-dir template/good_teacher
$ dart run template/co-bricks/bin/co_bricks.dart sync --type app --project-dir template/good_teacher
```

### 프로덕션 사용

Global activation을 통해 설치한 경우:

#### App 브릭 동기화

```sh
# App 브릭 동기화 (현재 디렉토리에서 .envrc 자동 탐지)
$ co-bricks sync --type app

# 특정 프로젝트 디렉토리에서 App 브릭 동기화
$ co-bricks sync --type app --project-dir /path/to/project
```

#### Monorepo 브릭 동기화

```sh
# Monorepo 브릭 동기화 (현재 디렉토리에서 .envrc 자동 탐지)
$ co-bricks sync --type monorepo

# 특정 프로젝트 디렉토리에서 Monorepo 브릭 동기화
$ co-bricks sync --type monorepo --project-dir /path/to/project
```

> **참고**: Global activation 후 코드를 변경한 경우, 변경사항을 반영하려면 재활성화가 필요합니다:
> ```sh
> $ dart pub global deactivate co_bricks
> $ dart pub global activate --source path /path/to/co-bricks
> ```

### Monorepo 프로젝트 생성

브릭을 사용하여 새로운 monorepo 프로젝트를 생성할 수 있습니다:

#### Interactive 모드 (권장)

```sh
$ co-bricks create --type monorepo
```

사용자 친화적인 프롬프트가 표시되며 모든 설정값을 입력할 수 있습니다.

프로젝트 생성 완료 후 다음 질문이 표시됩니다:
```
Run "make start" to initialize the project now? (Y/n)
```
- **Y (기본값)**: 프로젝트를 자동으로 초기화합니다 (의존성 설치, Git 초기화 등)
- **n**: 수동으로 초기화할 수 있도록 건너뜁니다

#### Non-interactive 모드 (자동화)

```sh
$ co-bricks create --type monorepo --no-interactive \
  --name good_teacher \
  --description "Good Teacher App" \
  --organization laputa \
  --tld im \
  --org-tld im \
  --github-org coco-de \
  --github-repo good-teacher \
  --github-visibility private \
  --backend serverpod \
  --admin-email tech@laputa.im \
  --enable-admin \
  --apple-developer-id tech@laputa.im \
  --itc-team-id 127782534 \
  --team-id Y7BR9G2CVC \
  --cert-cn Laputa \
  --cert-ou Production \
  --cert-o "Laputa Inc." \
  --cert-l Seoul \
  --cert-st Mapo \
  --cert-c KR
  # random_project_id는 자동 생성됨
```

#### 자동 부트스트래핑 모드

프로젝트 생성 후 자동으로 `make start`를 실행하려면 `--auto-start` 플래그를 추가하세요:

```sh
$ co-bricks create --type monorepo --auto-start \
  --no-interactive \
  --name good_teacher \
  --description "Good Teacher App" \
  # ... (나머지 옵션)
```

이 명령어는 프로젝트 생성 후 자동으로:
- Flutter 의존성 설치
- Git 저장소 초기화
- GitHub 저장소 생성 (gh CLI가 설정된 경우)
- 초기 커밋 생성

#### 생성된 프로젝트 구조

프로젝트가 생성되면 다음과 같은 구조를 갖습니다:

```
good_teacher/
├── .envrc                 # 프로젝트 설정 (위에서 입력한 모든 값 포함)
├── Makefile              # 개발 편의 명령어
├── app/                  # Flutter 앱 (빈 디렉토리 - 별도 생성 필요)
├── backend/              # Serverpod 백엔드 (빈 디렉토리 - 별도 생성 필요)
├── feature/              # Feature 모듈들
├── package/              # 공유 패키지
└── ...
```

> **참고**: `monorepo` 브릭은 프로젝트 구조만 생성합니다.
> 실제 앱과 백엔드는 `feature/application`, `feature/common` 등에 이미 포함되어 있거나,
> 필요시 별도의 브릭으로 생성해야 합니다.

#### 다음 단계

생성된 프로젝트에서:

```sh
$ cd good_teacher
$ make start    # 의존성 설치, git 초기화, GitHub 저장소 생성
```

### 기타 명령어

```sh
# CLI 버전 확인
$ co-bricks --version

# 사용법 도움말 표시
$ co-bricks --help

# create 명령어 도움말 표시 (모든 옵션 확인)
$ co-bricks create --help

# sync 명령어 도움말 표시
$ co-bricks sync --help
```

## 작동 방식

1. **자동 .envrc 탐지**: CLI는 현재 디렉토리(또는 지정한 `--project-dir`)에서 시작하여 상위 디렉토리로 올라가면서 `.envrc` 파일을 자동으로 검색합니다.

2. **프로젝트 설정**: `.envrc` 파일을 파싱하여 다음 정보를 추출합니다:
   - `PROJECT_NAME`: 프로젝트 이름 (예: `good_teacher`)
   - `ORG_NAME`: 조직 이름 (예: `laputa`)
   - `ORG_TLD`: 조직 TLD (예: `im`)
   - 기타 설정 값들

3. **템플릿 동기화**:
   - **App 타입**: `template/{project}/app/` → `bricks/{app,console,widgetbook}/__brick__/` 동기화
   - **Monorepo 타입**: `template/{project}/*` → `bricks/monorepo/__brick__/{{project_name}}/` 동기화

4. **템플릿 변수 변환**: 모든 하드코딩된 프로젝트명, 조직명, Firebase ID 등이 자동으로 Mason 템플릿 변수로 변환됩니다 (예: `{{project_name.snakeCase()}}`).

## 요구사항

- Dart SDK ^3.9.0
- 프로젝트 설정이 포함된 `.envrc` 파일이 있는 프로젝트
- `template/{project_name}/` 디렉토리에 있는 템플릿 프로젝트

## 테스트 실행 및 커버리지 🧪

모든 단위 테스트를 실행하려면 다음 명령어를 사용하세요:

```sh
$ dart pub global activate coverage 1.15.0
$ dart test --coverage=coverage
$ dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
```

생성된 커버리지 리포트를 보려면 [lcov](https://github.com/linux-test-project/lcov)를 사용할 수 있습니다.

```sh
# 커버리지 리포트 생성
$ genhtml coverage/lcov.info -o coverage/

# 커버리지 리포트 열기
$ open coverage/index.html
```

---

[coverage_badge]: coverage_badge.svg
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_cli_link]: https://github.com/VeryGoodOpenSource/very_good_cli
