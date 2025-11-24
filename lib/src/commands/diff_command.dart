import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:co_bricks/src/utils/diff_reporter.dart';
import 'package:co_bricks/src/utils/feature_differ.dart';
import 'package:co_bricks/src/utils/interface_analyzer.dart';
import 'package:co_bricks/src/utils/quality_analyzer.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// {@template diff_command}
///
/// `co_bricks diff`
/// A [Command] to detect differences between project features
/// {@endtemplate}
class DiffCommand extends Command<int> {
  /// {@macro diff_command}
  DiffCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'project-a',
        abbr: 'a',
        help:
            'Path to Project A root directory (or single project for analysis)',
        mandatory: true,
      )
      ..addOption(
        'project-b',
        abbr: 'b',
        help:
            'Path to Project B root directory (optional - for comparison mode)',
      )
      ..addOption(
        'feature',
        abbr: 'f',
        help: 'Feature name to compare (e.g., auth, home)',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output directory for reports (defaults to claudedocs/)',
        defaultsTo: 'claudedocs',
      )
      ..addFlag(
        'all-features',
        help: 'Compare all features in both projects',
        negatable: false,
      )
      ..addFlag(
        'full-analysis',
        help: 'Include quality analysis (requires mixin files)',
        negatable: false,
      );
  }

  @override
  String get description => 'Detect differences between project features';

  @override
  String get name => 'diff';

  final Logger _logger;

  @override
  Future<int> run() async {
    try {
      final projectAPath = argResults?['project-a'] as String;
      final projectBPath = argResults?['project-b'] as String?;
      final featureName = argResults?['feature'] as String?;
      final outputDir = argResults?['output'] as String;
      final allFeatures = argResults?['all-features'] as bool;
      final fullAnalysis = argResults?['full-analysis'] as bool;

      if (!allFeatures && featureName == null) {
        _logger.err(
          'Either --feature or --all-features must be specified',
        );
        return ExitCode.usage.code;
      }

      // Validate project A
      final projectA = Directory(projectAPath);
      if (!projectA.existsSync()) {
        _logger.err('Project A directory does not exist: $projectAPath');
        return ExitCode.noInput.code;
      }

      // Check if comparison mode or single project analysis
      final isComparisonMode = projectBPath != null;
      Directory? projectB;

      if (isComparisonMode) {
        projectB = Directory(projectBPath);
        if (!projectB.existsSync()) {
          _logger.err('Project B directory does not exist: $projectBPath');
          return ExitCode.noInput.code;
        }
      }

      // Display mode info
      if (isComparisonMode) {
        _logger
          ..info('🔍 Starting diff detection (comparison mode)...')
          ..info('   Project A: $projectAPath')
          ..info('   Project B: $projectBPath')
          ..info('   Output: $outputDir/');
      } else {
        _logger
          ..info('🔍 Starting project analysis (single project mode)...')
          ..info('   Project: $projectAPath')
          ..info('   Output: $outputDir/');
      }

      final reporter = DiffReporter();
      final differ = FeatureDiffer();

      if (allFeatures) {
        if (isComparisonMode) {
          await _compareAllFeatures(
            differ,
            reporter,
            projectA,
            projectB!,
            outputDir,
            fullAnalysis,
          );
        } else {
          await _analyzeAllFeatures(
            differ,
            reporter,
            projectA,
            outputDir,
            fullAnalysis,
          );
        }
      } else {
        if (isComparisonMode) {
          await _compareSingleFeature(
            differ,
            reporter,
            projectA,
            projectB!,
            featureName!,
            outputDir,
            fullAnalysis,
          );
        } else {
          await _analyzeSingleFeature(
            differ,
            reporter,
            projectA,
            featureName!,
            outputDir,
            fullAnalysis,
          );
        }
      }

      _logger
        ..success('\n✅ Diff detection complete!')
        ..info('📄 Reports saved to: $outputDir/');

      return ExitCode.success.code;
    } on Exception catch (e, stackTrace) {
      _logger
        ..err('❌ Diff detection failed: $e')
        ..detail('$stackTrace');
      return ExitCode.software.code;
    }
  }

  /// Compare a single feature
  Future<void> _compareSingleFeature(
    FeatureDiffer differ,
    DiffReporter reporter,
    Directory projectA,
    Directory projectB,
    String featureName,
    String outputDir,
    bool fullAnalysis,
  ) async {
    _logger.info('\n📊 Comparing feature: $featureName');

    // 1. Structural diff
    final progress = _logger.progress('Analyzing file structure');
    final structuralDiff = await differ.compareStructure(
      projectADir: projectA,
      projectBDir: projectB,
      featureName: featureName,
    );
    progress.complete('File structure analyzed');

    _logger
      ..info('   Total files: ${structuralDiff.totalFiles}')
      ..info('   Common: ${structuralDiff.commonFiles.length}')
      ..info('   Project A only: ${structuralDiff.onlyInProjectA.length}')
      ..info('   Project B only: ${structuralDiff.onlyInProjectB.length}');

    // 2. Interface diff
    final interfaceProgress = _logger.progress('Analyzing interfaces');
    final interfaceDiff = await _analyzeInterfaces(
      structuralDiff,
      featureName,
    );
    interfaceProgress.complete('Interfaces analyzed');

    if (interfaceDiff != null) {
      _logger
        ..info('   Common methods: ${interfaceDiff.commonMethods.length}')
        ..info('   Conflicts: ${interfaceDiff.conflicts.length}');
    } else {
      _logger.info('   No repository interfaces found');
    }

    // 3. Quality analysis (optional)
    QualityComparison? qualityComparison;
    if (fullAnalysis) {
      final qualityProgress = _logger.progress('Analyzing code quality');
      qualityComparison = await _analyzeQuality(
        structuralDiff,
        featureName,
      );
      qualityProgress.complete('Quality analyzed');

      if (qualityComparison != null) {
        _logger.info(
          '   Recommendation: ${qualityComparison.recommendation}',
        );
      } else {
        _logger.info('   No mixin files found for quality analysis');
      }
    }

    // Generate report
    final reportProgress = _logger.progress('Generating report');
    final outputPath = path.join(
      outputDir,
      '$featureName-diff-report.md',
    );

    await reporter.generateReport(
      featureName: featureName,
      structuralDiff: structuralDiff,
      interfaceDiff: interfaceDiff ?? _emptyInterfaceDiff(),
      qualityComparison: qualityComparison ?? _emptyQualityComparison(),
      outputPath: outputPath,
    );
    reportProgress.complete('Report generated');
  }

  /// Compare all features
  Future<void> _compareAllFeatures(
    FeatureDiffer differ,
    DiffReporter reporter,
    Directory projectA,
    Directory projectB,
    String outputDir,
    bool fullAnalysis,
  ) async {
    _logger.info('\n📊 Comparing all features...');

    final progress = _logger.progress('Scanning features');
    final allDiffs = await differ.compareAllFeatures(
      projectADir: projectA,
      projectBDir: projectB,
    );
    progress.complete('Features scanned');

    _logger.info('   Found ${allDiffs.length} features');

    // Generate summary report
    final summaryProgress = _logger.progress('Generating summary report');
    final summaryPath = path.join(outputDir, 'features-summary.md');
    await reporter.generateSummaryReport(
      structuralDiffs: allDiffs,
      outputPath: summaryPath,
    );
    summaryProgress.complete('Summary report generated');

    // Generate individual reports for each feature
    for (final entry in allDiffs.entries) {
      final featureName = entry.key;
      final structuralDiff = entry.value;

      _logger.info('\n   Processing: $featureName');

      final interfaceDiff = await _analyzeInterfaces(
        structuralDiff,
        featureName,
      );

      QualityComparison? qualityComparison;
      if (fullAnalysis) {
        qualityComparison = await _analyzeQuality(
          structuralDiff,
          featureName,
        );
      }

      final outputPath = path.join(
        outputDir,
        '$featureName-diff-report.md',
      );

      await reporter.generateReport(
        featureName: featureName,
        structuralDiff: structuralDiff,
        interfaceDiff: interfaceDiff ?? _emptyInterfaceDiff(),
        qualityComparison: qualityComparison ?? _emptyQualityComparison(),
        outputPath: outputPath,
      );
    }
  }

  /// Analyze repository interfaces
  Future<InterfaceDiff?> _analyzeInterfaces(
    StructuralDiff structuralDiff,
    String featureName,
  ) async {
    try {
      // Find repository interface files
      final repositoryFiles = structuralDiff.commonFiles
          .where(
            (f) =>
                f.contains('data/repository') &&
                f.endsWith('_repository.dart') &&
                !f.contains('_impl'),
          )
          .toList();

      if (repositoryFiles.isEmpty) {
        return null;
      }

      // Use the first repository file found
      final repoFile = repositoryFiles.first;
      final repoA = File(path.join(structuralDiff.projectAPath, repoFile));
      final repoB = File(path.join(structuralDiff.projectBPath, repoFile));

      if (!repoA.existsSync() || !repoB.existsSync()) {
        return null;
      }

      final analyzer = InterfaceAnalyzer();
      return await analyzer.compareInterfaces(
        repositoryA: repoA,
        repositoryB: repoB,
      );
    } on Exception catch (e) {
      _logger.warn('Interface analysis failed: $e');
      return null;
    }
  }

  /// Analyze implementation quality
  Future<QualityComparison?> _analyzeQuality(
    StructuralDiff structuralDiff,
    String featureName,
  ) async {
    try {
      // Find mixin files
      final mixinFiles = structuralDiff.commonFiles
          .where(
            (f) =>
                f.contains('data/repository') &&
                f.contains('_mixin.dart'),
          )
          .toList();

      if (mixinFiles.isEmpty) {
        return null;
      }

      // Use the first mixin file found
      final mixinFile = mixinFiles.first;
      final mixinA = File(path.join(structuralDiff.projectAPath, mixinFile));
      final mixinB = File(path.join(structuralDiff.projectBPath, mixinFile));

      if (!mixinA.existsSync() || !mixinB.existsSync()) {
        return null;
      }

      final analyzer = QualityAnalyzer();
      return await analyzer.compareQuality(
        mixinA: mixinA,
        mixinB: mixinB,
      );
    } on Exception catch (e) {
      _logger.warn('Quality analysis failed: $e');
      return null;
    }
  }

  /// Empty interface diff for fallback
  InterfaceDiff _emptyInterfaceDiff() {
    return InterfaceDiff(
      commonMethods: [],
      onlyInProjectA: [],
      onlyInProjectB: [],
      conflicts: [],
    );
  }

  /// Empty quality comparison for fallback
  QualityComparison _emptyQualityComparison() {
    return QualityComparison(
      fileAPath: 'N/A',
      fileBPath: 'N/A',
      errorHandling: QualityScore(score: 0, details: 'Not analyzed'),
      caching: QualityScore(score: 0, details: 'Not analyzed'),
      logging: QualityScore(score: 0, details: 'Not analyzed'),
      complexity: QualityScore(score: 0, details: 'Not analyzed'),
      recommendation: 'N/A',
    );
  }

  /// Analyze single feature against bricks
  Future<void> _analyzeSingleFeature(
    FeatureDiffer differ,
    DiffReporter reporter,
    Directory templateProject,
    String featureName,
    String outputDir,
    bool fullAnalysis,
  ) async {
    // Find bricks directory
    final bricksDir = _findBricksDirectory(templateProject);
    if (bricksDir == null) {
      _logger.err('Could not find bricks directory');
      return;
    }

    // Construct brick path based on feature
    final brickFeatureDir = Directory(
      path.join(bricksDir.path, 'app', '__brick__', 'feature', featureName),
    );

    if (!brickFeatureDir.existsSync()) {
      _logger.warn(
        'Feature "$featureName" not found in bricks, creating baseline report',
      );
      // Just analyze the template project
      await _createBaselineReport(
        templateProject,
        featureName,
        outputDir,
      );
      return;
    }

    _logger
      ..info('\n📊 Comparing feature: $featureName')
      ..info('   Template: ${templateProject.path}')
      ..info('   Brick: ${brickFeatureDir.path}');

    // Use existing comparison logic
    await _compareSingleFeature(
      differ,
      reporter,
      templateProject,
      brickFeatureDir,
      featureName,
      outputDir,
      fullAnalysis,
    );
  }

  /// Analyze all features against bricks
  Future<void> _analyzeAllFeatures(
    FeatureDiffer differ,
    DiffReporter reporter,
    Directory templateProject,
    String outputDir,
    bool fullAnalysis,
  ) async {
    // Find bricks directory
    final bricksDir = _findBricksDirectory(templateProject);
    if (bricksDir == null) {
      _logger.err('Could not find bricks directory');
      return;
    }

    final brickAppDir = Directory(
      path.join(bricksDir.path, 'app', '__brick__'),
    );

    if (!brickAppDir.existsSync()) {
      _logger.err('Brick app directory not found: ${brickAppDir.path}');
      return;
    }

    _logger
      ..info('\n📊 Comparing all features...')
      ..info('   Template: ${templateProject.path}')
      ..info('   Bricks: ${brickAppDir.path}');

    // Use existing comparison logic
    await _compareAllFeatures(
      differ,
      reporter,
      templateProject,
      brickAppDir,
      outputDir,
      fullAnalysis,
    );
  }

  /// Find bricks directory by traversing up from template project
  Directory? _findBricksDirectory(Directory templateProject) {
    var current = templateProject;

    // Traverse up to find bricks directory
    for (var i = 0; i < 5; i++) {
      final bricksDir = Directory(path.join(current.path, 'bricks'));
      if (bricksDir.existsSync()) {
        return bricksDir;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        break; // Reached root
      }
      current = parent;
    }

    // Also try ../bricks and ../../bricks directly
    final relativeBricks1 = Directory(
      path.join(templateProject.path, '..', 'bricks'),
    );
    if (relativeBricks1.existsSync()) {
      return relativeBricks1;
    }

    final relativeBricks2 = Directory(
      path.join(templateProject.path, '..', '..', 'bricks'),
    );
    if (relativeBricks2.existsSync()) {
      return relativeBricks2;
    }

    return null;
  }

  /// Create baseline report for new feature
  Future<void> _createBaselineReport(
    Directory templateProject,
    String featureName,
    String outputDir,
  ) async {
    _logger.info(
      '\n📋 Creating baseline report for new feature: $featureName',
    );

    // Scan feature files in template
    final featurePath = path.join(
      templateProject.path,
      'feature',
      'common',
      featureName,
    );
    final featureDir = Directory(featurePath);

    if (!featureDir.existsSync()) {
      _logger.err('Feature directory not found: $featurePath');
      return;
    }

    // Count files
    var fileCount = 0;
    await for (final entity in featureDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        fileCount++;
      }
    }

    // Create simple baseline report
    final reportPath = path.join(
      outputDir,
      '$featureName-baseline-report.md',
    );
    final report = '''
# Feature Baseline Report: $featureName

Generated: ${DateTime.now()}

---

## 📊 Overview

This is a new feature not yet synced to bricks.

### Template Project
- **Location**: ${templateProject.path}
- **Feature Path**: feature/common/$featureName
- **Dart Files**: $fileCount

### Status
- ✨ New feature ready for sync
- ⚠️ Not yet in bricks - run sync command to add

### Recommendation
Run the sync command to add this feature to bricks:
```bash
dart run bin/co_bricks.dart sync --type app --project-dir ${templateProject.path}
```

---

*Report generated by co-bricks diff detection engine*
''';

    await File(reportPath).writeAsString(report);
    _logger.success('Baseline report created: $reportPath');
  }
}
