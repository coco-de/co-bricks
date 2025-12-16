---
name: sync
description: "Synchronize template projects to Mason bricks with intelligent template conversion"
category: utility
complexity: enhanced
mcp-servers: [serena]
personas: [devops-engineer]
---

# /bricks:sync - Template Synchronization

## Triggers
- Template project changes need to be synced to bricks
- Mason brick updates required after template modifications
- Pattern conversion validation needed

## Usage
```
/bricks:sync [--type monorepo|app] [--project PROJECT_NAME] [--dry-run] [--verbose]
```

## Parameters
- `--type`: Brick type to sync (monorepo, app)
- `--project`: Project directory name (e.g., good_teacher, petmedi)
- `--dry-run`: Preview changes without writing
- `--verbose`: Show detailed conversion logs

## Behavioral Flow
1. **Discover**: Locate `.envrc` and extract project configuration
2. **Validate**: Check source template and target brick directories
3. **Backup**: Preserve conditional structures and optional features
4. **Sync**: Copy template files to brick `__brick__` directory
5. **Convert**: Transform hardcoded values to Mason template variables
6. **Restore**: Restore conditional structures and merge configurations

Key behaviors:
- Pattern-based template variable conversion (project names, org, domains)
- Conditional directory preservation (`{{#enable_admin}}`, `{{#has_serverpod}}`)
- Git submodule exclusion (coui, etc.)
- Parallel file processing for performance

## Tool Coordination
- **Bash**: Execute `dart run bin/co_bricks.dart sync`
- **Read**: Configuration and template file analysis
- **Serena**: Project memory and symbol operations

## Key Patterns
- **Monorepo Sync**: `make sync-monorepo PROJECT=xxx`
- **App Sync**: `make sync-app PROJECT=xxx`
- **Full Sync**: Sync all brick types for a project

## Examples

### Sync Monorepo Brick
```
/bricks:sync --type monorepo --project good_teacher
# Syncs template/good_teacher to bricks/monorepo/__brick__
```

### Sync App Brick
```
/bricks:sync --type app --project petmedi
# Syncs app templates to bricks/app/__brick__, bricks/console/__brick__, etc.
```

### Dry Run Preview
```
/bricks:sync --type monorepo --dry-run
# Shows what would be synced without making changes
```

## Boundaries

**Will:**
- Sync template files to brick directories
- Convert hardcoded values to template variables
- Preserve conditional structures and optional features
- Exclude git submodules and generated files

**Will Not:**
- Create new brick definitions
- Modify brick.yaml configurations
- Run mason make commands
