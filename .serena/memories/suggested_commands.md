# Suggested Commands for co-bricks

## Development Commands (Recommended)

### Running CLI During Development
```bash
# From template/co-bricks directory
make sync-monorepo PROJECT=good_teacher
make sync-app PROJECT=good_teacher

# Alternative: Direct dart run
dart run bin/co_bricks.dart sync --type monorepo --project-dir template/good_teacher
dart run bin/co_bricks.dart sync --type app --project-dir template/good_teacher
```

## Testing Commands

### Run All Tests
```bash
dart test
```

### Run Specific Test
```bash
dart test test/src/commands/sync_command_test.dart
```

### Run with Coverage
```bash
dart pub global activate coverage 1.15.0
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
```

### View Coverage Report
```bash
genhtml coverage/lcov.info -o coverage/
open coverage/index.html
```

## Code Quality Commands

### Analyze Code
```bash
dart analyze
```

### Format Code
```bash
dart format .
```

### Check Formatting
```bash
dart format --set-exit-if-changed .
```

## Installation Commands

### Global Activation (Development)
```bash
dart pub global activate --source path .
```

### Deactivate and Reactivate (After Code Changes)
```bash
dart pub global deactivate co_bricks
dart pub global activate --source path .
```

### Check Installation
```bash
dart pub global list | grep co-bricks
co-bricks --version
```

## CLI Usage Commands

### Sync Commands
```bash
# App brick synchronization
co-bricks sync --type app --project-dir /path/to/project

# Monorepo brick synchronization
co-bricks sync --type monorepo --project-dir /path/to/project
```

### Create Commands
```bash
# Create new monorepo (interactive)
co-bricks create --type monorepo

# Create with specific options
co-bricks create --type monorepo --name my_project --organization MyOrg --tld io
```

### Help Commands
```bash
co-bricks --help
co-bricks sync --help
co-bricks create --help
```

## macOS-Specific Notes
- System: Darwin
- Use `open` instead of `xdg-open` for viewing HTML reports
- PATH may need pub cache: `export PATH="$PATH:$HOME/.pub-cache/bin"`
