---
name: create
description: "Create new projects from Mason bricks with interactive or config-based generation"
category: utility
complexity: enhanced
mcp-servers: [serena]
personas: [architect]
---

# /bricks:create - Project Creation

## Triggers
- New project generation from bricks
- Project scaffolding with specific configurations
- Batch project creation from saved configs

## Usage
```
/bricks:create [--type monorepo|app] [--config CONFIG_NAME] [--interactive] [--save-config]
```

## Parameters
- `--type`: Project type to create (monorepo, app)
- `--config`: Use saved configuration file
- `--interactive`: Run in interactive mode (default)
- `--save-config`: Save configuration for reuse
- `--name`: Project name
- `--organization`: Organization name
- `--backend`: Backend type (serverpod, openapi, graphql, supabase, firebase)

## Behavioral Flow
1. **Configure**: Gather project settings (interactive or from config)
2. **Validate**: Check configuration completeness and consistency
3. **Generate**: Run Mason brick generation with variables
4. **Initialize**: Set up project dependencies and configurations
5. **Report**: Show generation summary and next steps

Key behaviors:
- Interactive mode with sensible defaults
- Configuration file support for reproducible generation
- Backend-specific template selection
- Post-generation initialization options

## Tool Coordination
- **Bash**: Execute `dart run bin/co_bricks.dart create`
- **Read**: Configuration file parsing
- **Write**: Save configuration files

## Key Patterns
- **Interactive Creation**: Guided project setup with prompts
- **Config-Based**: `create-from-config --config blueprint`
- **Save for Reuse**: `--save-config` stores settings in `projects/`

## Examples

### Interactive Monorepo Creation
```
/bricks:create --type monorepo --interactive
# Guided creation with prompts for all options
```

### Create from Saved Config
```
/bricks:create --config blueprint
# Uses projects/blueprint.json configuration
```

### Non-Interactive with Options
```
/bricks:create --type monorepo --name my_app --organization MyOrg --backend serverpod
# Creates project with specified options
```

### Save Configuration
```
/bricks:create --type monorepo --name template_app --save-config
# Creates project and saves config to projects/template_app.json
```

## Configuration File Format
```json
{
  "type": "monorepo",
  "name": "blueprint",
  "description": "Blueprint project",
  "organization": "Cocode",
  "tld": "im",
  "backend": "serverpod",
  "enable_admin": true
}
```

## Boundaries

**Will:**
- Generate projects from Mason bricks
- Save and load project configurations
- Initialize generated project structure

**Will Not:**
- Modify existing projects
- Run post-generation build commands automatically
- Push to remote repositories
