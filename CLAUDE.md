# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**co-bricks** is a Mason bricks synchronization CLI tool that automates the process of converting template projects into reusable Mason bricks with dynamic template variables. It scans `.envrc` files for project configuration and intelligently transforms hardcoded values into Mason template syntax.

## Development Commands

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

## Important Implementation Notes

- **Pattern Order Matters**: In `TemplateConverter`, GitHub URL patterns MUST be applied before project name patterns to prevent incorrect replacements
- **Directory Traversal**: All services traverse upward to find required directories, enabling execution from any subdirectory
- **Template Variable Escaping**: File paths and directory names containing template variables use `{{#conditionalDir}}` syntax for Mason compatibility
- **Error Handling**: Uses typed exceptions (`FileSystemException`, `FormatException`) with detailed error messages for debugging
