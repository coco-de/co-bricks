# Task Completion Checklist for co-bricks

When completing a task in this project, follow this checklist:

## 1. Code Quality Checks

### Format Code
```bash
dart format .
```

### Run Static Analysis
```bash
dart analyze
```
- Must pass with zero issues
- Follows very_good_analysis standards

## 2. Testing

### Run All Tests
```bash
dart test
```
- All tests must pass
- No skipped or failing tests

### Check Coverage (if applicable)
```bash
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
```
- Maintain or improve coverage
- New features should include tests

## 3. Build Verification

### Ensure Build Integrity
```bash
dart test test/ensure_build_test.dart
```
- Verifies build_runner generated files are up to date

## 4. Integration Testing (if applicable)

### Test CLI Commands Manually
```bash
# Test sync command
make sync-app PROJECT=good_teacher

# Test create command
co-bricks create --help
```

## 5. Version Updates (for releases)

### Update Version
- Increment version in `pubspec.yaml`
- Run build_runner to update `version.dart`:
```bash
dart run build_runner build
```

## 6. Documentation

### Update CLAUDE.md
- If architecture changes significantly
- If new commands are added
- If workflow patterns change

### Update README.md
- If user-facing features change
- If installation process changes

## 7. Git Workflow

### Before Committing
```bash
# Verify git status
git status

# Check diff
git diff

# Stage changes
git add .

# Commit with descriptive message
git commit -m "feat: descriptive message"
```

### Commit Message Convention
Follow conventional commits:
- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `test:` - Test additions/changes
- `chore:` - Build/tooling changes

## 8. Pre-Push Checklist
- [ ] All tests passing
- [ ] Code formatted
- [ ] Analysis clean
- [ ] Build verified
- [ ] Documentation updated
- [ ] Commit messages clear

## Common Gotchas

1. **Pattern Order**: When modifying `TemplateConverter`, ensure GitHub URL patterns come before project name patterns
2. **Directory Traversal**: Services must find both `template/` and `bricks/` directories by traversing upward
3. **Template Variables**: Use correct Mason syntax for conditional directories
4. **Error Messages**: Provide detailed error messages with file paths and context
5. **Global Activation**: After code changes, must deactivate and reactivate for changes to take effect
