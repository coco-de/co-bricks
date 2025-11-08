# co-bricks Project Overview

## Purpose
Mason bricks synchronization CLI tool that automates the conversion of template projects into reusable Mason bricks with dynamic template variables.

## Key Functionality
- Scans `.envrc` files for project configuration
- Intelligently transforms hardcoded values into Mason template syntax
- Supports both app and monorepo synchronization
- Creates new projects from Mason bricks with interactive prompts

## Tech Stack
- **Language**: Dart 3.9.0+
- **Build Tool**: dart pub, build_runner
- **CLI Framework**: args, cli_completion, mason_logger
- **Template Engine**: Mason (^0.1.0-dev.58)
- **Testing**: test, mocktail
- **Linting**: very_good_analysis

## Dependencies
- mason ^0.1.0-dev.58 - Brick generation engine
- mason_logger ^0.3.3 - Colorful CLI logging
- args ^2.7.0 - Command-line argument parsing
- yaml ^3.1.2 - YAML parsing
- path ^1.9.0 - Cross-platform path operations
- pub_updater ^0.5.0 - Version checking

## Development Dependencies
- mocktail ^1.0.4 - Testing with mocks
- very_good_analysis ^10.0.0 - Strict linting
- build_runner ^2.8.0 - Code generation
- build_version ^2.1.3 - Version management
