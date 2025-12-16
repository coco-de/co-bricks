---
name: diff
description: "Compare features across projects or between template and bricks"
category: analysis
complexity: enhanced
mcp-servers: [serena, sequential-thinking]
personas: [analyzer]
---

# /bricks:diff - Feature Comparison Analysis

## Triggers
- Pre-sync validation between template and bricks
- Cross-project feature comparison
- Migration planning and drift detection
- Best practice identification across implementations

## Usage
```
/bricks:diff [--project-a PATH] [--project-b PATH] [--feature FEATURE] [--all-features] [--full-analysis]
```

## Parameters
- `--project-a`: First project path (required)
- `--project-b`: Second project path (optional, compares with bricks if omitted)
- `--feature`: Specific feature to compare (e.g., auth, home)
- `--all-features`: Compare all detected features
- `--full-analysis`: Include quality metrics analysis
- `--output`: Output directory for reports (default: claudedocs/)

## Behavioral Flow
1. **Scan**: Identify features in both projects/sources
2. **Structure**: Compare file structures and organization
3. **Interface**: Analyze Repository interface compatibility (AST-based)
4. **Quality**: Assess implementation quality metrics (optional)
5. **Report**: Generate comprehensive Markdown reports

Key behaviors:
- Single project mode: Compare template vs existing bricks
- Comparison mode: Compare two different project implementations
- AST-based interface analysis for precise method signature comparison
- Quality metrics: error handling, caching, logging, complexity

## Analysis Components

### Structural Diff (FeatureDiffer)
- File structure comparison across feature directories
- Common, unique, and missing file identification
- Layer filtering (domain, data, presentation)

### Interface Analysis (InterfaceAnalyzer)
- Repository method signature comparison using AST
- Signature conflict detection
- Missing method identification

### Quality Analysis (QualityAnalyzer) - with `--full-analysis`
- Error handling patterns (try-catch, exception types)
- Caching strategy implementation
- Logging coverage
- Code complexity metrics

## Tool Coordination
- **Bash**: Execute `dart run bin/co_bricks.dart diff`
- **Serena**: Symbol analysis and project memory
- **Sequential**: Complex analysis reasoning

## Examples

### Single Project Analysis (Template vs Bricks)
```
/bricks:diff --project-a template/good_teacher --feature auth
# Compares auth feature between template and existing bricks
```

### Cross-Project Comparison
```
/bricks:diff --project-a template/good_teacher --project-b template/blueprint --feature auth
# Compares auth implementations between two projects
```

### Full Feature Analysis
```
/bricks:diff --project-a template/petmedi --all-features --full-analysis
# Comprehensive analysis of all features with quality metrics
```

## Report Output
- Individual feature reports: `claudedocs/{feature}-diff-report.md`
- Summary report: `claudedocs/features-summary.md`

## Use Cases
- **Pre-sync validation**: Check template changes before syncing
- **New feature detection**: Identify features not yet in bricks
- **Drift detection**: Find differences over time
- **Cross-project learning**: Compare different backend implementations
- **Migration planning**: Identify features to port between projects

## Boundaries

**Will:**
- Compare file structures and interfaces
- Generate detailed analysis reports
- Identify implementation differences and quality metrics

**Will Not:**
- Automatically merge or sync differences
- Modify source code based on comparison
- Make architectural decisions
