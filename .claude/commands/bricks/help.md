---
name: help
description: "Display co-bricks CLI help and available commands"
category: utility
complexity: basic
---

# /bricks:help - Co-Bricks CLI Help

## Overview
Co-bricks is a Mason bricks synchronization CLI tool that automates template-to-brick conversion.

## Available Commands

### /bricks:sync
Synchronize template projects to Mason bricks.
```
/bricks:sync --type monorepo --project good_teacher
/bricks:sync --type app --project petmedi
```

### /bricks:create
Create new projects from Mason bricks.
```
/bricks:create --type monorepo --interactive
/bricks:create --config blueprint
```

### /bricks:diff
Compare features across projects or templates.
```
/bricks:diff --project-a template/good_teacher --feature auth
/bricks:diff --project-a template/good_teacher --project-b template/blueprint --all-features
```

## Quick Reference

### Makefile Commands
```bash
make sync-monorepo PROJECT=good_teacher
make sync-app PROJECT=good_teacher
```

### Direct CLI Commands
```bash
dart run bin/co_bricks.dart sync --type monorepo --project-dir template/good_teacher
dart run bin/co_bricks.dart create --type monorepo --interactive
dart run bin/co_bricks.dart diff --project-a template/good_teacher --feature auth
```

### Project Configuration
Configurations are stored in `projects/` as JSON files.
```bash
dart run bin/co_bricks.dart create-from-config --list
dart run bin/co_bricks.dart create-from-config --config blueprint
```

## Key Concepts

### Template Variables
- `{{project_name.snakeCase()}}` - my_project
- `{{project_name.pascalCase()}}` - MyProject
- `{{org_name}}` - Organization name
- `{{#has_serverpod}}...{{/has_serverpod}}` - Conditional blocks

### Excluded Directories
- `.dart_tool`, `build`, `node_modules`, `Pods`, `.git`
- `coui` (git submodule)
- `migrations` (backend server migrations)

### Excluded Files
- `pubspec.lock`, `pubspec_overrides.yaml`
- Generated files: `.g.dart`, `.freezed.dart`, `.config.dart`

## Documentation
- Full documentation: See `CLAUDE.md`
- Brick development: See `bricks/CLAUDE.md`
