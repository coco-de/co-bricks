# Architecture and Structure of co-bricks

## Core Workflow Pattern

The CLI follows a three-phase workflow:

1. **Configuration Discovery**: Automatically searches up the directory tree for `.envrc` files
2. **Template Synchronization**: Copies template files to brick directories
3. **Variable Conversion**: Transforms hardcoded values into Mason template syntax

## Directory Structure

```
lib/
  co_bricks.dart                    # Main library export
  src/
    command_runner.dart             # CLI entry point with command registration
    version.dart                    # Auto-generated version (build_runner)
    commands/
      commands.dart                 # Command exports
      sync_command.dart             # Main sync command (--type app|monorepo)
      create_command.dart           # Project creation from bricks
      sample_command.dart           # Sample/example command
      update_command.dart           # CLI update checker
    services/
      services.dart                 # Service exports
      envrc_service.dart            # .envrc file parsing
      sync_app_service.dart         # App template synchronization
      sync_monorepo_service.dart    # Monorepo template synchronization
      create_monorepo_service.dart  # Monorepo project generation
    utils/
      file_utils.dart               # File system operations with logging
      template_converter.dart       # Pattern-based replacement engine
bin/
  co_bricks.dart                    # Executable entry point
test/
  ensure_build_test.dart            # Build verification
  src/                              # Tests mirror lib/src structure
```

## Key Components

### Commands Layer
- **CoBricksCommandRunner**: Main command runner extending `CompletionCommandRunner`
  - Registers all sub-commands
  - Handles version flag and update checking
  - Provides verbose logging option

- **SyncCommand**: Template synchronization
  - Options: `--type` (app|monorepo), `--project-dir`
  - Delegates to appropriate service based on type

- **CreateCommand**: Project generation
  - Options: `--type`, `--name`, `--organization`, `--backend`, `--tld`
  - Supports interactive and non-interactive modes

### Services Layer
- **EnvrcService**: Configuration management
  - Parses `.envrc` files using regex patterns
  - Provides `ProjectConfig` with extracted variables
  - Searches upward through directory tree

- **SyncAppService**: App synchronization
  - Detects app structure (main app, console, widgetbook)
  - Syncs to `bricks/{app,console,widgetbook}/__brick__/`
  - Applies template conversions

- **SyncMonorepoService**: Monorepo synchronization
  - Syncs entire project to `bricks/monorepo/__brick__/{{project_name}}/`
  - Handles nested directory structures
  - Preserves conditional directories

- **CreateMonorepoService**: Project generation
  - Uses Mason generator to create projects
  - Collects variables interactively or from flags
  - Supports multiple backend types (serverpod, firebase, supabase, etc.)

### Utilities Layer
- **TemplateConverter**: Pattern replacement engine
  - Builds ordered regex patterns from ProjectConfig
  - Critical pattern ordering: GitHub URLs → Organizations → Project names
  - Handles multiple case transformations (snake_case, PascalCase, kebab-case, camelCase)

- **FileUtils**: File operations
  - Logging wrappers for file operations
  - Directory creation, file copying with progress

## Template Variable Transformation

Pattern application order (from `TemplateConverter.buildPatterns()`):

1. GitHub URL patterns (highest priority - prevents project name conflicts)
2. GitHub organization patterns
3. Apple Developer ID patterns
4. Firebase and domain-specific patterns
5. Project name patterns (various case formats)
6. Organization patterns

**Critical**: More specific patterns must execute before general ones to prevent incorrect replacements.

## Directory Discovery Logic

All services traverse upward from current/specified directory to find:
- `.envrc` files (configuration source)
- `template/{project_name}/` directories (source templates)
- `bricks/` directory (target brick location)

This enables CLI execution from any subdirectory within a project.

## Repository Context

The CLI is designed for a monorepo structure:
```
bricks/                           # Mason brick definitions
  app/, console/, monorepo/, widgetbook/, ...
template/
  co-bricks/                      # This CLI tool
  {project_name}/                 # Template projects
    app/
      {project_name}/             # Main app
      {project_name}_console/     # Console app
      {project_name}_widgetbook/  # Widgetbook
    .envrc                        # Project configuration
```

## Mason Template Conventions

Generated bricks use Mason's template variable syntax:
- `{{project_name.snakeCase()}}` - Snake case transformation
- `{{project_name.pascalCase()}}` - Pascal case transformation
- `{{org_name}}` - Organization name
- `{{org_tld}}` - Top-level domain
- Conditional directories: `{{#has_serverpod}}backend/{{/has_serverpod}}`
