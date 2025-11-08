# Code Style and Conventions for co-bricks

## Linting Configuration
- **Linter**: very_good_analysis (package:very_good_analysis/analysis_options.yaml)
- **Exception**: `public_member_api_docs: false` (documentation not required for all public APIs)

## Naming Conventions

### Files and Directories
- **Files**: snake_case (e.g., `sync_app_service.dart`, `template_converter.dart`)
- **Directories**: snake_case (e.g., `lib/src/commands/`, `lib/src/services/`)

### Code Elements
- **Classes**: PascalCase (e.g., `SyncCommand`, `EnvrcService`, `ProjectConfig`)
- **Functions/Methods**: camelCase (e.g., `findEnvrcFile()`, `buildPatterns()`)
- **Variables**: camelCase (e.g., `projectName`, `orgTld`)
- **Constants**: camelCase (e.g., `executableName`, `packageName`)
- **Private members**: prefix with underscore (e.g., `_logger`, `_syncAppService`)

## Documentation Style

### Class Documentation
Use dartdoc template style:
```dart
/// {@template class_name}
/// Description of the class.
/// {@endtemplate}
class ClassName { ... }
```

### Constructor Documentation
Reference the template:
```dart
/// {@macro class_name}
ClassName({ ... }) { ... }
```

### Method Documentation
Simple single-line comments for clarity:
```dart
/// Finds and returns the .envrc file starting from the given directory
static File? findEnvrcFile([String? startDir]) { ... }
```

## Code Organization Patterns

### Command Structure
- Extend `Command<int>` from `package:args/command_runner.dart`
- Implement `name`, `description`, and `run()` methods
- Use `argParser` in constructor for CLI argument configuration
- Return `ExitCode` constants for consistency

### Service Structure
- Constructor takes `Logger` as dependency
- Methods are instance methods (not static) when they need logger
- Static methods for utility functions that don't need state
- Use `Future<void>` for async operations

### Error Handling
- Use typed exceptions: `FileSystemException`, `FormatException`, `ArgumentError`
- Provide detailed error messages with context (file paths, expected values)
- Log errors with `_logger.err()` before returning exit codes
- Use try-catch blocks with specific exception types

## Dependency Injection
- Pass dependencies through constructors
- Use optional parameters with null-safety for testability
- Example: `Logger? logger` with `_logger = logger ?? Logger()`

## Testing Conventions
- Test files mirror source structure: `test/src/commands/sync_command_test.dart`
- Use mocktail for mocking dependencies
- Ensure build verification with `build_verify` package

## File Header Pattern
Simple imports organized by:
1. Dart SDK imports
2. External package imports  
3. Internal package imports (using relative paths from lib/)

Example:
```dart
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'package:co_bricks/src/services/envrc_service.dart';
```
