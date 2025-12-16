# Co-Bricks Sub-Agents 상세 가이드

이 문서는 co-bricks 프로젝트의 전문 sub-agents 사용법을 상세히 설명합니다.

## 개요

Sub-agents는 Claude Code의 Task 도구를 통해 호출되는 전문화된 에이전트입니다. 각 에이전트는 특정 도메인에 대한 깊은 전문성을 가지고 있으며, 복잡한 작업을 효율적으로 처리합니다.

---

## Brick Developer (brick-developer)

### 역할
Mason brick 개발 전문가로서 템플릿 생성 및 변수 관리를 담당합니다.

### 활성화 트리거
- 새로운 Mason brick 생성 또는 수정
- 템플릿 변수 설계 및 구현
- 조건부 블록 개발 (`{{#condition}}...{{/condition}}`)
- Hook 스크립트 개발 (pre_gen.dart, post_gen.dart)

### 행동 원칙
재사용성과 유연성을 최우선으로 생각합니다. 모든 brick은 독립적이고, 잘 문서화되어야 하며, 다양한 설정에서 일관된 결과를 생성해야 합니다.

### 전문 분야

#### 1. Brick 구조
```
bricks/
└── my_brick/
    ├── brick.yaml          # brick 설정
    ├── __brick__/          # 템플릿 파일
    │   └── {{name}}/
    └── hooks/
        ├── pre_gen.dart    # 생성 전 실행
        └── post_gen.dart   # 생성 후 실행
```

#### 2. brick.yaml 설정
```yaml
name: my_brick
description: 내 커스텀 brick
version: 0.1.0
environment:
  mason: ">=0.1.0-dev <0.1.0"

vars:
  name:
    type: string
    description: 프로젝트 이름
    prompt: 프로젝트 이름을 입력하세요

  has_feature:
    type: boolean
    description: 기능 활성화 여부
    default: false
```

#### 3. 케이스 변환
| 변환 | 입력 | 출력 |
|------|------|------|
| `snakeCase()` | MyProject | my_project |
| `pascalCase()` | my_project | MyProject |
| `camelCase()` | my_project | myProject |
| `paramCase()` | my_project | my-project |
| `constantCase()` | my_project | MY_PROJECT |
| `dotCase()` | my_project | my.project |
| `titleCase()` | my_project | My Project |

#### 4. 조건부 블록
```mustache
{{! 조건이 true일 때만 포함 }}
{{#has_feature}}
feature_module:
  path: packages/{{name.snakeCase()}}_feature
{{/has_feature}}

{{! 조건이 false일 때 포함 }}
{{^has_feature}}
# Feature가 비활성화되어 있습니다
{{/has_feature}}

{{! 중첩 조건 }}
{{#enable_admin}}
{{#has_serverpod}}
admin_backend:
  path: backend/admin_server
{{/has_serverpod}}
{{/enable_admin}}
```

### 출력물
- 완전한 brick.yaml 설정
- 구조화된 `__brick__` 디렉토리
- pre_gen/post_gen hook 스크립트
- 사용법 문서

---

## Template Converter (template-converter)

### 역할
하드코딩된 값을 Mason 템플릿 변수로 변환하는 전문가입니다.

### 활성화 트리거
- 패턴 기반 템플릿 변수 변환 필요
- 하드코딩된 값 식별 및 대체
- 컨텍스트 인식 변환 요구사항
- 동기화 작업을 위한 정규식 패턴 개발

### 행동 원칙
패턴 순서와 컨텍스트 민감도를 체계적으로 고려합니다. 더 구체적인 패턴이 일반적인 패턴보다 먼저 실행되어야 잘못된 대체를 방지할 수 있습니다.

### 전문 분야

#### 1. 패턴 우선순위 규칙

**높은 우선순위 (먼저 실행)**
```dart
// 1. GitHub URL 패턴 - 프로젝트명 충돌 방지
'github.com/coco-de/good-teacher'
→ 'github.com/{{github_org}}/{{project_name.paramCase()}}'

// 2. GitHub 조직 패턴
'coco-de'
→ '{{github_org}}'

// 3. Apple Developer ID 패턴
'tech@laputa.im'
→ '{{apple_developer_id}}'

// 4. Firebase 패턴
'good-teacher-12345'
→ '{{random_project_id}}'
```

**중간 우선순위**
```dart
// 5. 도메인 패턴
'laputa.im'
→ '{{org_name.paramCase()}}.{{org_tld}}'

// 6. 패키지명 패턴 (역 도메인)
'im.laputa.good_teacher'
→ '{{org_tld}}.{{org_name.paramCase()}}.{{project_name.snakeCase()}}'
```

**낮은 우선순위 (나중에 실행)**
```dart
// 7. 프로젝트명 패턴
'good_teacher' → '{{project_name.snakeCase()}}'
'GoodTeacher' → '{{project_name.pascalCase()}}'
'good-teacher' → '{{project_name.paramCase()}}'
'goodTeacher' → '{{project_name.camelCase()}}'

// 8. 조직명 패턴
'laputa' → '{{org_name.paramCase()}}'
'Laputa' → '{{org_name.pascalCase()}}'
```

#### 2. 컨텍스트 인식 변환

**파일 타입별 변환**
```dart
// pubspec.yaml - 패키지명
name: good_teacher_app
→ name: {{project_name.snakeCase()}}_app

// Dart 파일 - 클래스명
class GoodTeacherApp extends StatelessWidget
→ class {{project_name.pascalCase()}}App extends StatelessWidget

// GitHub Actions - 이스케이프 필요
${{ secrets.TOKEN }}
→ ${ { secrets.TOKEN } }
```

**디렉토리별 변환**
```dart
// Firestore 컬렉션명
collection('good_teacher_users')
→ collection('{{project_name.snakeCase()}}_users')

// 백엔드 서버 디렉토리
backend/good_teacher_server/
→ backend/{{project_name.snakeCase()}}_server/
```

#### 3. 패턴 테스트 체크리스트

```markdown
□ GitHub URL이 올바르게 변환되는가?
□ 조직명이 URL과 패키지명에서 다르게 처리되는가?
□ 프로젝트명의 모든 케이스가 처리되는가?
□ 부분 매칭이 발생하지 않는가? (예: 'teacher'가 'good_teacher'에서 잘못 매칭)
□ 파일 확장자별 적절한 변환이 적용되는가?
```

### 출력물
- 순서화된 정규식 패턴 목록
- 컨텍스트 인식 변환 규칙
- 패턴별 테스트 케이스
- 패턴 순서 근거 문서

---

## Sync Analyzer (sync-analyzer)

### 역할
동기화 전 검증과 드리프트 감지를 위한 분석 전문가입니다.

### 활성화 트리거
- 동기화 전 검증 필요
- 템플릿과 bricks 간 드리프트 감지
- 프로젝트 간 feature 비교
- 동기화 영향 평가

### 행동 원칙
차이점과 그 의미를 포괄적으로 파악합니다. 모든 변경사항은 맥락에서 이해되어야 합니다 - 구조적 변경, 인터페이스 호환성, 품질 영향을 모두 고려합니다.

### 전문 분야

#### 1. 구조 분석 (Structural Diff)

```markdown
## 구조 비교 결과

### 공통 파일 (12개)
- feature/auth/domain/repository/auth_repository.dart
- feature/auth/data/repository/auth_repository_impl.dart
...

### Project A에만 존재 (3개)
- feature/auth/data/datasource/local_auth_datasource.dart
- feature/auth/domain/usecase/refresh_token_usecase.dart
...

### Project B에만 존재 (1개)
- feature/auth/presentation/bloc/auth_state.dart
```

#### 2. 인터페이스 분석 (Interface Analysis)

```markdown
## Repository 인터페이스 비교

### AuthRepository

| 메서드 | Project A | Project B | 상태 |
|--------|-----------|-----------|------|
| login | Future<User> login(String, String) | Future<User> login(String, String) | ✅ 일치 |
| logout | Future<void> logout() | Future<bool> logout() | ⚠️ 반환 타입 충돌 |
| refreshToken | Future<Token> refreshToken() | - | ❌ B에 없음 |

### 충돌 상세
- `logout`: A는 `void` 반환, B는 `bool` 반환
  - 권장: `bool` 반환으로 통일 (성공 여부 확인 가능)
```

#### 3. 품질 분석 (Quality Analysis)

```markdown
## 품질 메트릭 비교

| 메트릭 | Project A | Project B | 승자 |
|--------|-----------|-----------|------|
| 에러 처리 커버리지 | 85% | 72% | A |
| 캐싱 구현 | ✅ | ❌ | A |
| 로깅 커버리지 | 60% | 90% | B |
| 평균 메서드 복잡도 | 3.2 | 4.8 | A |

### 상세 분석

#### 에러 처리
- A: try-catch with specific exceptions
- B: generic catch blocks

#### 캐싱
- A: Hive 기반 로컬 캐싱 구현
- B: 캐싱 미구현
```

#### 4. 권장사항 생성

```markdown
## 동기화 권장사항

### 필수 조치
1. [ ] `logout` 메서드 반환 타입 통일 (bool 권장)
2. [ ] B에 `refreshToken` 메서드 추가

### 권장 조치
3. [ ] B의 에러 처리 패턴을 A 방식으로 개선
4. [ ] A에 B의 로깅 패턴 도입 고려

### 주의사항
- 캐싱 구현은 B에 점진적으로 도입 필요
- 인터페이스 변경 시 하위 호환성 고려
```

### 출력물
- 구조 비교 리포트
- 인터페이스 충돌 목록
- 품질 메트릭 비교
- 동기화 권장사항

---

## Sync Reporter (sync-reporter)

### 역할
동기화 작업 후 결과를 검증하고 상세 리포트를 생성하는 전문가입니다.

### 활성화 트리거
- 동기화 완료 후 결과 검증 필요
- brick과 템플릿 간 일관성 확인
- 변환 품질 검증
- 동기화 리포트 생성 요청

### 행동 원칙
철저한 검증과 명확한 리포팅을 최우선으로 합니다. 모든 변환이 올바르게 적용되었는지 확인하고, 발견된 문제점을 구체적으로 보고합니다.

### 검증 항목

#### 1. 구조 검증
- 디렉토리 구조 일치 여부
- 필수 파일 존재 확인
- 제외 대상 파일/디렉토리 처리 확인 (coui 서브모듈 등)

#### 2. 템플릿 변수 검증
- 하드코딩된 값이 남아있는지 확인
- 템플릿 변수 문법 올바름 확인
- 케이스 변환 정확성 검증

#### 3. 조건부 블록 검증
- `{{#condition}}...{{/condition}}` 블록 무결성
- 중첩 조건부 블록 정확성
- 조건부 디렉토리 구조 보존 확인

#### 4. 특수 파일 검증
- pubspec.yaml 종속성 변환
- melos.yaml 패키지 참조
- GitHub Actions 워크플로우 이스케이프

### 리포트 형식

```markdown
# 동기화 리포트

## 개요
- **동기화 일시**: 2024-01-15 14:30:00
- **소스**: template/good_teacher
- **대상**: bricks/monorepo/__brick__
- **상태**: ✅ 성공 / ⚠️ 경고 있음 / ❌ 실패

## 검증 결과
| 항목 | 상태 | 비고 |
|------|------|------|
| 구조 검증 | ✅ | 150개 파일 동기화 |
| 템플릿 변수 | ✅ | 하드코딩 값 없음 |
| 조건부 블록 | ✅ | 12개 블록 보존 |
| 제외 항목 | ✅ | coui, .g.dart 등 제외됨 |

## 권장 조치
1. [ ] `mason make monorepo` 로 생성 테스트
2. [ ] 생성된 프로젝트에서 `dart analyze` 실행
```

### 검증 명령어
```bash
# 하드코딩 값 탐지
grep -r "good_teacher" bricks/monorepo/__brick__/

# 제외 항목 확인
find bricks/monorepo/__brick__/ -name "coui" -o -name "*.g.dart"

# 조건부 블록 균형 확인
grep -c "{{#" bricks/monorepo/__brick__/**/*.yaml
grep -c "{{/" bricks/monorepo/__brick__/**/*.yaml
```

### 출력물
- 동기화 요약 리포트
- 상세 검증 리포트
- 오류/경고 목록
- 권장 조치 안내

---

## 에이전트 조합 활용

### 시나리오 1: 새 Feature를 Brick으로 변환

```
1. sync-analyzer: 기존 bricks와 비교 분석
2. template-converter: 변환 패턴 설계
3. brick-developer: brick 구조 설계 및 구현
4. sync-reporter: 변환 결과 검증 및 리포트
```

### 시나리오 2: 여러 프로젝트 통합

```
1. sync-analyzer: 프로젝트 간 차이 분석
2. brick-developer: 통합 brick 설계
3. template-converter: 공통 패턴 추출
4. sync-reporter: 통합 결과 검증
```

### 시나리오 3: Brick 유지보수

```
1. sync-analyzer: 드리프트 감지
2. template-converter: 패턴 업데이트 필요성 평가
3. brick-developer: brick 버전 업데이트
4. sync-reporter: 업데이트 결과 리포트
```

### 시나리오 4: 동기화 후 품질 보증

```
1. /bricks:sync 실행
2. sync-reporter: 동기화 결과 검증
   - 구조 검증
   - 하드코딩 값 탐지
   - 조건부 블록 확인
   - 제외 항목 확인 (coui 등)
3. 문제 발견 시 → template-converter로 패턴 수정
4. 재동기화 후 최종 검증
```

---

## 관련 문서

- [Claude Commands 가이드](./claude-commands-guide.md)
- [CLAUDE.md](../CLAUDE.md) - 프로젝트 개요
- [bricks/CLAUDE.md](../../CLAUDE.md) - Brick 개발 가이드
