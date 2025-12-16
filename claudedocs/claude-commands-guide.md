# Co-Bricks Claude 명령어 가이드

이 문서는 co-bricks 프로젝트에서 사용할 수 있는 Claude Code slash commands와 sub-agents를 설명합니다.

## 목차
- [Slash Commands](#slash-commands)
- [Sub-Agents](#sub-agents)
- [사용 예시](#사용-예시)
- [워크플로우](#워크플로우)

---

## Slash Commands

### `/bricks:sync` - 템플릿 동기화

템플릿 프로젝트를 Mason bricks로 동기화합니다.

**사용법:**
```
/bricks:sync --type monorepo --project good_teacher
/bricks:sync --type app --project petmedi
```

**파라미터:**
| 파라미터 | 설명 | 예시 |
|---------|------|------|
| `--type` | brick 타입 (monorepo, app) | `--type monorepo` |
| `--project` | 프로젝트 디렉토리명 | `--project good_teacher` |
| `--dry-run` | 변경사항 미리보기 | `--dry-run` |
| `--verbose` | 상세 로그 출력 | `--verbose` |

**동작 흐름:**
1. `.envrc`에서 프로젝트 설정 추출
2. 소스 템플릿과 대상 brick 디렉토리 검증
3. 조건부 구조 및 선택적 기능 백업
4. 템플릿 파일을 brick `__brick__` 디렉토리로 복사
5. 하드코딩된 값을 Mason 템플릿 변수로 변환
6. 조건부 구조 복원 및 설정 병합

**주요 기능:**
- 패턴 기반 템플릿 변수 변환 (프로젝트명, 조직명, 도메인)
- 조건부 디렉토리 보존 (`{{#enable_admin}}`, `{{#has_serverpod}}`)
- Git 서브모듈 제외 (coui 등)
- 병렬 파일 처리로 성능 최적화

---

### `/bricks:create` - 프로젝트 생성

Mason bricks에서 새 프로젝트를 생성합니다.

**사용법:**
```
/bricks:create --type monorepo --interactive
/bricks:create --config blueprint
```

**파라미터:**
| 파라미터 | 설명 | 예시 |
|---------|------|------|
| `--type` | 프로젝트 타입 | `--type monorepo` |
| `--config` | 저장된 설정 파일 사용 | `--config blueprint` |
| `--interactive` | 대화형 모드 | `--interactive` |
| `--save-config` | 설정을 재사용하도록 저장 | `--save-config` |
| `--name` | 프로젝트 이름 | `--name my_app` |
| `--organization` | 조직명 | `--organization MyOrg` |
| `--backend` | 백엔드 타입 | `--backend serverpod` |

**설정 파일 형식 (`projects/blueprint.json`):**
```json
{
  "type": "monorepo",
  "name": "blueprint",
  "description": "Blueprint 프로젝트",
  "organization": "Cocode",
  "tld": "im",
  "backend": "serverpod",
  "enable_admin": true
}
```

---

### `/bricks:diff` - Feature 비교 분석

프로젝트 간 또는 템플릿과 bricks 간의 feature를 비교합니다.

**사용법:**
```
# 단일 프로젝트 분석 (템플릿 vs bricks)
/bricks:diff --project-a template/good_teacher --feature auth

# 두 프로젝트 비교
/bricks:diff --project-a template/good_teacher --project-b template/blueprint --feature auth

# 전체 feature 분석
/bricks:diff --project-a template/petmedi --all-features --full-analysis
```

**파라미터:**
| 파라미터 | 설명 | 예시 |
|---------|------|------|
| `--project-a` | 첫 번째 프로젝트 경로 (필수) | `--project-a template/good_teacher` |
| `--project-b` | 두 번째 프로젝트 경로 (선택) | `--project-b template/blueprint` |
| `--feature` | 비교할 feature | `--feature auth` |
| `--all-features` | 모든 feature 비교 | `--all-features` |
| `--full-analysis` | 품질 메트릭 포함 | `--full-analysis` |
| `--output` | 리포트 출력 디렉토리 | `--output claudedocs/` |

**분석 구성 요소:**
1. **구조 분석**: 파일/디렉토리 구조 비교
2. **인터페이스 분석**: Repository 메서드 시그니처 비교 (AST 기반)
3. **품질 분석**: 에러 처리, 캐싱, 로깅, 복잡도 메트릭

**리포트 출력:**
- 개별 feature: `claudedocs/{feature}-diff-report.md`
- 요약 리포트: `claudedocs/features-summary.md`

---

### `/bricks:help` - 도움말

CLI 도움말과 사용 가능한 명령어를 표시합니다.

```
/bricks:help
```

---

## Sub-Agents

Sub-agents는 Task 도구를 통해 호출되는 전문 에이전트입니다.

### `brick-developer` - Brick 개발 전문가

Mason brick 개발을 위한 전문 에이전트입니다.

**전문 분야:**
- brick.yaml 설정 및 `__brick__` 디렉토리 구조
- Mustache 템플릿 문법 및 케이스 변환
- Hook 스크립트 개발 (pre_gen.dart, post_gen.dart)
- 변수 설계 및 기본값 설정

**템플릿 패턴 예시:**
```mustache
# 케이스 변환
{{project_name.snakeCase()}}    → my_project
{{project_name.pascalCase()}}   → MyProject
{{project_name.camelCase()}}    → myProject

# 조건부 블록
{{#has_serverpod}}
// Serverpod 전용 코드
{{/has_serverpod}}
```

---

### `template-converter` - 템플릿 변환 전문가

하드코딩된 값을 Mason 변수로 변환하는 전문 에이전트입니다.

**전문 분야:**
- 정규식 패턴 설계 및 최적화
- 컨텍스트 인식 변환 (파일 타입별 다른 변환)
- 패턴 우선순위 관리
- 케이스 변환 처리

**패턴 우선순위:**
1. GitHub URL 패턴 (가장 높음)
2. GitHub 조직 패턴
3. Apple Developer ID 패턴
4. Firebase 패턴
5. 도메인 패턴
6. 프로젝트명 패턴 (가장 낮음)

---

### `sync-analyzer` - 동기화 분석 전문가

동기화 전 검증과 드리프트 감지를 위한 전문 에이전트입니다.

**전문 분야:**
- 파일/디렉토리 구조 비교
- Repository 인터페이스 호환성 분석
- 코드 품질 메트릭 평가
- 동기화 영향 예측

**분석 결과:**
- 구조 차이 리포트
- 인터페이스 충돌 목록
- 품질 비교 분석
- 동기화 권장사항

---

## 사용 예시

### 새 프로젝트 생성 후 동기화
```bash
# 1. 대화형 모드로 프로젝트 생성
/bricks:create --type monorepo --interactive

# 2. 생성된 프로젝트에서 기능 개발 후 동기화
/bricks:sync --type monorepo --project my_new_app
```

### Feature 비교 후 동기화 결정
```bash
# 1. 변경사항 분석
/bricks:diff --project-a template/good_teacher --feature auth --full-analysis

# 2. 리포트 확인 후 동기화 진행
/bricks:sync --type monorepo --project good_teacher
```

### 설정 기반 반복 생성
```bash
# 1. 설정 저장하며 프로젝트 생성
/bricks:create --type monorepo --name template_app --save-config

# 2. 나중에 동일 설정으로 재생성
/bricks:create --config template_app
```

---

## 워크플로우

### 일반적인 개발 워크플로우

```
┌─────────────────┐
│  템플릿 프로젝트   │
│  (template/)    │
└────────┬────────┘
         │
         │ /bricks:diff (사전 분석)
         ▼
┌─────────────────┐
│   변경사항 분석   │
│   리포트 생성    │
└────────┬────────┘
         │
         │ /bricks:sync
         ▼
┌─────────────────┐
│   Mason Bricks  │
│   (bricks/)     │
└────────┬────────┘
         │
         │ /bricks:create
         ▼
┌─────────────────┐
│   새 프로젝트    │
└─────────────────┘
```

### 권장 사용 순서

1. **개발 단계**: 템플릿 프로젝트에서 기능 개발
2. **분석 단계**: `/bricks:diff`로 변경사항 분석
3. **동기화 단계**: `/bricks:sync`로 bricks 업데이트
4. **생성 단계**: `/bricks:create`로 새 프로젝트 생성
5. **검증 단계**: 생성된 프로젝트 테스트

---

## 관련 파일

- 설정 파일: `projects/*.json`
- Makefile 명령어: `make sync-monorepo`, `make sync-app`
- CLI 진입점: `bin/co_bricks.dart`
- 서비스 구현: `lib/src/services/`
