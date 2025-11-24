# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**co-bricks** is a Mason bricks synchronization CLI tool that automates the process of converting template projects into reusable Mason bricks with dynamic template variables. It scans `.envrc` files for project configuration and intelligently transforms hardcoded values into Mason template syntax.

## Development Commands

### Creating Projects

**Interactive mode (recommended)**:
```bash
dart run bin/co_bricks.dart create --type monorepo
```

**Non-interactive mode** (all options):
```bash
dart run bin/co_bricks.dart create --type monorepo --no-interactive \
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

### Running the CLI During Development

**Recommended approach** - Use Makefile commands for immediate code reflection:

```bash
# From template/co-bricks directory
make sync-monorepo PROJECT=good_teacher
make sync-app PROJECT=good_teacher
```

**Alternative** - Direct dart run:

```bash
dart run bin/co_bricks.dart sync --type monorepo --project-dir template/good_teacher
dart run bin/co_bricks.dart sync --type app --project-dir template/good_teacher
```

### Saving and Reusing Project Configurations

**Save configuration during creation**:
```bash
dart run bin/co_bricks.dart create --type monorepo \
  --name blueprint \
  --description "Blueprint project" \
  --organization Cocode \
  --save-config  # This saves the configuration to projects/blueprint.json
```

**List saved configurations**:
```bash
dart run bin/co_bricks.dart create-from-config --list
```

**Create from saved configuration**:
```bash
# Use saved configuration
dart run bin/co_bricks.dart create-from-config --config blueprint

# Override output directory
dart run bin/co_bricks.dart create-from-config --config blueprint --output-dir ../new-location

# Override auto-start setting
dart run bin/co_bricks.dart create-from-config --config blueprint --auto-start
```

**Manual configuration editing**:
Configurations are stored in `projects/` directory as JSON files. You can manually create or edit these files:

```json
{
  "type": "monorepo",
  "name": "blueprint",
  "description": "Blueprint - Cocode's service blueprint implementation",
  "organization": "Cocode",
  "tld": "im",
  "org_tld": "im",
  "github_org": "coco-de",
  "github_repo": "blueprint",
  "github_visibility": "private",
  "backend": "serverpod",
  "enable_admin": true,
  "admin_email": "dev@cocode.im",
  "output_dir": "..",
  "auto_start": false
}
```

### Diff Detection (Feature Comparison)

**Detect differences between project implementations**:

The diff detection engine compares features across multiple projects to identify:
- File structure differences
- Repository interface compatibility
- Implementation quality metrics
- Code patterns and best practices

**Single Project Analysis Mode** (template vs bricks):
```bash
# Compare template project with existing bricks
dart run bin/co_bricks.dart diff \
  --project-a template/good-teacher \
  --feature auth

# With full quality analysis
dart run bin/co_bricks.dart diff \
  --project-a template/good-teacher \
  --feature auth \
  --full-analysis

# Analyze all features against bricks
dart run bin/co_bricks.dart diff \
  --project-a template/good-teacher \
  --all-features
```

**Comparison Mode** (two projects):
```bash
# Compare two different projects
dart run bin/co_bricks.dart diff \
  --project-a template/good-teacher \
  --project-b template/blueprint \
  --feature auth

# With full quality analysis
dart run bin/co_bricks.dart diff \
  --project-a template/good-teacher \
  --project-b template/blueprint \
  --feature auth \
  --full-analysis
```

**Compare all features**:
```bash
# All features with summary report
dart run bin/co_bricks.dart diff \
  --project-a template/good-teacher \
  --project-b template/blueprint \
  --all-features \
  --output claudedocs/diff-reports

# With quality analysis for all features
dart run bin/co_bricks.dart diff \
  --project-a template/good-teacher \
  --project-b template/blueprint \
  --all-features \
  --full-analysis
```

**Analysis Components**:

1. **Structural Diff** (FeatureDiffer):
   - Compares file structures across feature directories
   - Identifies common, unique, and missing files
   - Filters by layer (domain, data, presentation)

2. **Interface Analysis** (InterfaceAnalyzer):
   - Compares Repository interface method signatures using AST
   - Detects signature conflicts (same method, different return type/parameters)
   - Identifies missing methods in either project

3. **Quality Analysis** (QualityAnalyzer) - Optional with `--full-analysis`:
   - Error handling quality (try-catch patterns, specific exception types)
   - Caching strategy implementation
   - Logging coverage
   - Code complexity metrics (methods per line)

4. **Report Generation** (DiffReporter):
   - Comprehensive Markdown reports in `claudedocs/` or specified output directory
   - Executive summary with key metrics
   - Detailed analysis by section
   - Actionable recommendations for sync/merge

**Report Location**:
- Individual feature reports: `claudedocs/{feature}-diff-report.md`
- Summary report (--all-features): `claudedocs/features-summary.md`

**Use Cases**:

*Single Project Analysis Mode:*
- **Pre-sync validation**: Check template changes before syncing to bricks
- **New feature detection**: Identify features not yet in bricks (generates baseline report)
- **Drift detection**: Find differences between template and bricks over time
- **Quality improvement**: Compare current implementation with brick patterns

*Comparison Mode:*
- **Cross-project learning**: Compare openapi vs serverpod implementations
- **Migration planning**: Identify missing features to port between projects
- **Best practice identification**: Determine which implementation has better patterns
- **Merge preparation**: Analyze conflicts before integrating features

### Testing

```bash
# Run all tests
dart test

# Run specific test file
dart test test/src/commands/sync_command_test.dart

# Run with coverage
dart pub global activate coverage 1.15.0
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info

# View coverage report
genhtml coverage/lcov.info -o coverage/
open coverage/index.html
```

### Installation and Activation

```bash
# Global activation from local path (for development)
dart pub global activate --source path .

# Deactivate before re-activating after code changes
dart pub global deactivate co_bricks
dart pub global activate --source path .

# Check installation
dart pub global list | grep co-bricks
co-bricks --version
```

### Analysis and Linting

```bash
# Run static analysis (using very_good_analysis)
dart analyze

# Format code
dart format .
```

## Architecture

### Core Workflow Pattern

The CLI follows a three-phase workflow:

1. **Configuration Discovery**: Automatically searches up the directory tree for `.envrc` files
2. **Template Synchronization**: Copies template files to brick directories (`bricks/{type}/__brick__/`)
3. **Variable Conversion**: Transforms hardcoded values into Mason template syntax using regex patterns

### Key Components

**Commands** (`lib/src/commands/`):
- `SyncCommand` - Main synchronization command supporting `--type app|monorepo`
- `CreateCommand` - Project creation from bricks (interactive mode supported)
- Command pattern with `args` library for argument parsing

**Services** (`lib/src/services/`):
- `EnvrcService` - Parses `.envrc` files and extracts project configuration
- `SyncAppService` - Syncs app templates to `bricks/{app,console,widgetbook}/__brick__/`
- `SyncMonorepoService` - Syncs monorepo templates to `bricks/monorepo/__brick__/{{project_name}}/`
- `CreateMonorepoService` - Generates new projects using Mason bricks

**Utilities** (`lib/src/utils/`):
- `TemplateConverter` - Pattern-based replacement engine for template variable conversion
- `FileUtils` - File system operations with logging

### Template Variable Transformation

The tool uses ordered regex patterns in `TemplateConverter.buildPatterns()`:

1. **GitHub URL patterns** (highest priority - prevents project name conflicts)
2. **GitHub organization patterns**
3. **Apple Developer ID patterns**
4. **Firebase and domain-specific patterns**
5. **Project name patterns** (snake_case, PascalCase, kebab-case, camelCase)
6. **Organization patterns**

Pattern application order is critical - more specific patterns must execute before general ones.

### Optional Feature Preservation

When synchronizing templates that don't include optional features (like console when `ENABLE_ADMIN=false`), the sync process preserves existing brick structures for those features:

**Feature Preservation Flow**:
1. **Detection**: Before sync, check if optional features exist in source template
2. **Backup**: If feature exists in brick but not in template, backup to temporary directory
3. **Sync**: Normal sync process copies template → brick
4. **Restore**: After sync, restore backed-up optional features from temporary directory

**Supported Optional Features**:
- `console` - Controlled by `ENABLE_ADMIN` variable in `.envrc`
  - Console app directory: `app/{{project_name}}_console`
  - Console feature directory: `feature/{{#enable_admin}}console{{/enable_admin}}`
  - Console packages in melos.yaml with `{{#enable_admin}}` blocks

**Validation**:
- `_validateOptionalFeatures()` checks `.envrc` for `ENABLE_ADMIN` setting
- Warns if `ENABLE_ADMIN=true` but console directories are missing
- Provides info message if `ENABLE_ADMIN=false` and console not present

**Implementation Details**:
- `_preserveOptionalFeatures()`: Backs up conditional directories using `Directory.systemTemp`
- `_restoreOptionalFeatures()`: Restores directories after sync completes
- `_extractConditionalBlocks()`: Extracts `{{#enable_admin}}` package blocks from melos.yaml
- `_mergeConditionalBlocks()`: Merges console packages back into synced melos.yaml

**Case Transformation Handling**:
Template variable case transformations (paramCase, snakeCase, etc.) are context-aware:
- GitHub URLs use paramCase: `github.com/org/{{project_name.paramCase()}}`
- Package names use snakeCase: `{{project_name.snakeCase()}}_service`
- Firestore collections use snakeCase: `{{project_name.snakeCase()}}_users`
- No blanket replacements - `TemplateConverter` handles context-specific transformations

### Directory Discovery Logic

Both services traverse upward from the current/specified directory to find:
- `.envrc` files (configuration source)
- `template/{project_name}/` directories (source templates)
- `bricks/` directory (target brick location)

This allows the CLI to work from any subdirectory within a project.

## Project Configuration (.envrc)

The CLI requires these variables in `.envrc`:
- `PROJECT_NAME` - Project identifier (e.g., `good_teacher`)
- `ORG_NAME` - Organization name (e.g., `laputa`)
- `ORG_TLD` - Top-level domain (e.g., `im`)
- `GITHUB_ORG`, `GITHUB_REPO` - Optional GitHub configuration
- `RANDOM_PROJECT_ID` - Optional Firebase/unique identifiers
- `APPLE_DEVELOPER_ID` - Optional Apple developer configuration

## Mason Template Conventions

Generated bricks use Mason's template variable syntax:
- `{{project_name.snakeCase()}}` - Snake case transformation
- `{{project_name.pascalCase()}}` - Pascal case transformation
- `{{org_name}}` - Organization name
- `{{org_tld}}` - Top-level domain
- Conditional directories: `{{#has_serverpod}}backend/{{/has_serverpod}}`

## Dependencies

- `mason` ^0.1.0-dev.58 - Brick generation engine
- `mason_logger` ^0.3.3 - Colorful CLI logging
- `args` ^2.7.0 - Command-line argument parsing
- `yaml` ^3.1.2 - YAML parsing for brick configurations
- `path` ^1.9.0 - Cross-platform path operations

## Code Quality Standards

This project uses:
- **very_good_analysis** for strict linting (with `public_member_api_docs` disabled)
- **mocktail** for testing with mocks
- **build_runner** for code generation (version management via `build_version`)

## Repository Structure Context

The CLI is designed to work within a monorepo structure:
```
bricks/                      # Mason brick definitions
  app/                       # App brick
  console/                   # Console app brick
  monorepo/                  # Monorepo brick
  widgetbook/                # Widgetbook brick
  [other bricks...]
template/
  co-bricks/                 # This CLI tool
  good_teacher/              # Example template project
    app/                     # App templates
      good_teacher/          # Main app
      good_teacher_console/  # Console app
      good_teacher_widgetbook/  # Widgetbook
    .envrc                   # Project configuration
  [other projects...]
```

## Performance Optimizations

The CLI has been optimized for large projects (15,000+ files) with the following improvements:

### Pattern Caching
- Template conversion patterns are compiled once and cached per sync session
- **Impact**: 60-80% reduction in pattern generation time
- **Implementation**: `SyncMonorepoService._getPatterns()` with `_patternCache`

### Extension-based File Detection
- Text file detection uses extension lookup before I/O operations
- Fallback to byte reading only for unknown extensions (512 bytes vs 1KB)
- **Impact**: 80% reduction in file type detection I/O (~15MB saved)
- **Implementation**: `FileUtils.isTextFile()` with `_processableExtensions`

### Parallel File Processing
- Files are processed in batches of 50 using `Future.wait()`
- Concurrent template conversion and file writing
- **Impact**: 3-5x speedup on multi-core systems
- **Implementation**: `SyncMonorepoService._processFiles()` with batch parallelization

### Combined Performance Improvement
- **Before**: 10-15 minutes for large projects
- **After**: 1-2 minutes (approximately **10x faster**)

## Important Implementation Notes

- **Pattern Order Matters**: In `TemplateConverter`, GitHub URL patterns MUST be applied before project name patterns to prevent incorrect replacements
- **Directory Traversal**: All services traverse upward to find required directories, enabling execution from any subdirectory
- **Template Variable Escaping**: File paths and directory names containing template variables use `{{#conditionalDir}}` syntax for Mason compatibility
- **Error Handling**: Uses typed exceptions (`FileSystemException`, `FormatException`) with detailed error messages for debugging
- **Parallel Processing**: File operations use batch parallelization with `eagerError: false` for resilient error handling

## Git Workflow

### Commit Message Format

**IMPORTANT**: All commit messages MUST be written in **Korean** following **Conventional Commits** with **Gitmoji**.

```
<type>(<scope>): <gitmoji> <한글 설명>

[optional Korean body]
[optional footer with issue reference]

🎉 Generated with Claude Code (https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**한글 커밋 예시:**
```
feat(home): ✨ 사용자 프로필 페이지 추가

아바타, 소개, 설정 기능을 포함한 사용자 프로필 구현

Closes #123

🎉 Generated with Claude Code (https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

```
fix(auth): 🐛 토큰 갱신 무한 루프 해결

요청 중 토큰 만료 시 발생하는 무한 갱신 루프 수정

Fixes #456

🎉 Generated with Claude Code (https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

```
perf(sync): ⚡ 동기화 성능 10배 개선

패턴 캐싱, 확장자 기반 파일 감지, 병렬 파일 처리 추가
대규모 프로젝트(15,000+ 파일) 동기화 시간 10-15분 → 1-2분으로 단축

🎉 Generated with Claude Code (https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**일반적인 타입:**
- `feat`: 새로운 기능
- `fix`: 버그 수정
- `refactor`: 코드 리팩토링
- `test`: 테스트 추가/수정
- `docs`: 문서 변경
- `chore`: 빌드/설정 작업
- `style`: 코드 포맷팅
- `perf`: 성능 개선

**일반적인 깃모지:**
- ✨ `:sparkles:` - 새로운 기능
- 🐛 `:bug:` - 버그 수정
- 📝 `:memo:` - 문서 추가/수정
- 🎨 `:art:` - 코드 구조/포맷 개선
- ⚡ `:zap:` - 성능 개선
- 🔥 `:fire:` - 코드/파일 삭제
- 🚀 `:rocket:` - 배포
- 💄 `:lipstick:` - UI/스타일 파일 추가/수정
- ♻️ `:recycle:` - 코드 리팩토링
- ✅ `:white_check_mark:` - 테스트 추가/수정
- 🔧 `:wrench:` - 설정 파일 추가/수정
- 🌐 `:globe_with_meridians:` - 국제화/지역화
- 💚 `:green_heart:` - CI 빌드 수정
- 🔒 `:lock:` - 보안 이슈 수정

### Branch Naming

```
feature/{issue-number}-{feature-name}    # New features
bugfix/{issue-number}-{bug-name}         # Bug fixes
hotfix/{issue-number}-{critical-fix}     # Production hotfixes
```
