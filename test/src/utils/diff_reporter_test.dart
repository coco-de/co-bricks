import 'dart:io';

import 'package:co_bricks/src/utils/diff_reporter.dart';
import 'package:co_bricks/src/utils/feature_differ.dart';
import 'package:co_bricks/src/utils/interface_analyzer.dart';
import 'package:co_bricks/src/utils/quality_analyzer.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('DiffReporter', () {
    late DiffReporter reporter;
    late Directory tempDir;

    setUp(() {
      reporter = DiffReporter();
      tempDir = Directory.systemTemp.createTempSync('diff_reporter_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('generateReport creates valid markdown file', () async {
      final outputPath = path.join(tempDir.path, 'report.md');

      final structuralDiff = StructuralDiff(
        commonFiles: {'lib/common.dart', 'lib/model.dart'},
        onlyInProjectA: {'lib/a_only.dart'},
        onlyInProjectB: {'lib/b_only.dart'},
        projectAPath: '/path/a',
        projectBPath: '/path/b',
      );

      final interfaceDiff = InterfaceDiff(
        commonMethods: [
          MethodSignature(
            name: 'getUser',
            returnType: 'Future<User>',
            parameters: ['String id'],
            isAsync: true,
          ),
        ],
        onlyInProjectA: [
          MethodSignature(
            name: 'deleteUser',
            returnType: 'Future<void>',
            parameters: ['String id'],
            isAsync: true,
          ),
        ],
        onlyInProjectB: [
          MethodSignature(
            name: 'updateUser',
            returnType: 'Future<void>',
            parameters: ['User user'],
            isAsync: true,
          ),
        ],
        conflicts: [],
      );

      final qualityComparison = QualityComparison(
        fileAPath: '/path/a/mixin.dart',
        fileBPath: '/path/b/mixin.dart',
        errorHandling: QualityScore(score: 80, details: 'Good error handling'),
        caching: QualityScore(score: 75, details: 'Caching implemented'),
        logging: QualityScore(score: 60, details: 'Some logging'),
        complexity: QualityScore(score: 90, details: 'Low complexity'),
        recommendation: 'A',
      );

      await reporter.generateReport(
        featureName: 'auth',
        structuralDiff: structuralDiff,
        interfaceDiff: interfaceDiff,
        qualityComparison: qualityComparison,
        outputPath: outputPath,
      );

      expect(File(outputPath).existsSync(), isTrue);

      final content = await File(outputPath).readAsString();
      expect(content, contains('# Feature Diff Report: auth'));
      expect(content, contains('## 📊 Executive Summary'));
      expect(content, contains('## 📁 File Structure Analysis'));
      expect(content, contains('## 🔌 Interface Comparison'));
      expect(content, contains('## ⭐ Implementation Quality'));
      expect(content, contains('## 💡 Recommendations'));
    });

    test('generateReport includes all structural diff data', () async {
      final outputPath = path.join(tempDir.path, 'structural.md');

      final structuralDiff = StructuralDiff(
        commonFiles: {'lib/common.dart'},
        onlyInProjectA: {'lib/a_feature.dart'},
        onlyInProjectB: {'lib/b_feature.dart'},
        projectAPath: '/project/a',
        projectBPath: '/project/b',
      );

      final interfaceDiff = InterfaceDiff(
        commonMethods: [],
        onlyInProjectA: [],
        onlyInProjectB: [],
        conflicts: [],
      );

      final qualityComparison = QualityComparison(
        fileAPath: '/path/a',
        fileBPath: '/path/b',
        errorHandling: QualityScore(score: 50, details: 'Basic'),
        caching: QualityScore(score: 50, details: 'Basic'),
        logging: QualityScore(score: 50, details: 'Basic'),
        complexity: QualityScore(score: 50, details: 'Basic'),
        recommendation: 'tie',
      );

      await reporter.generateReport(
        featureName: 'test',
        structuralDiff: structuralDiff,
        interfaceDiff: interfaceDiff,
        qualityComparison: qualityComparison,
        outputPath: outputPath,
      );

      final content = await File(outputPath).readAsString();
      expect(content, contains('Common Files (1)'));
      expect(content, contains('Project A Only (1)'));
      expect(content, contains('Project B Only (1)'));
      expect(content, contains('lib/common.dart'));
      expect(content, contains('lib/a_feature.dart'));
      expect(content, contains('lib/b_feature.dart'));
    });

    test('generateReport shows interface conflicts', () async {
      final outputPath = path.join(tempDir.path, 'conflicts.md');

      final structuralDiff = StructuralDiff(
        commonFiles: {},
        onlyInProjectA: {},
        onlyInProjectB: {},
        projectAPath: '/path/a',
        projectBPath: '/path/b',
      );

      final interfaceDiff = InterfaceDiff(
        commonMethods: [],
        onlyInProjectA: [],
        onlyInProjectB: [],
        conflicts: [
          SignatureConflict(
            methodName: 'login',
            signatureA: MethodSignature(
              name: 'login',
              returnType: 'Future<String>',
              parameters: ['String email', 'String password'],
              isAsync: true,
            ),
            signatureB: MethodSignature(
              name: 'login',
              returnType: 'Future<bool>',
              parameters: ['String email', 'String password'],
              isAsync: true,
            ),
          ),
        ],
      );

      final qualityComparison = QualityComparison(
        fileAPath: '/path/a',
        fileBPath: '/path/b',
        errorHandling: QualityScore(score: 50, details: 'Basic'),
        caching: QualityScore(score: 50, details: 'Basic'),
        logging: QualityScore(score: 50, details: 'Basic'),
        complexity: QualityScore(score: 50, details: 'Basic'),
        recommendation: 'tie',
      );

      await reporter.generateReport(
        featureName: 'test',
        structuralDiff: structuralDiff,
        interfaceDiff: interfaceDiff,
        qualityComparison: qualityComparison,
        outputPath: outputPath,
      );

      final content = await File(outputPath).readAsString();
      expect(content, contains('⚠️ Signature Conflicts (1)'));
      expect(content, contains('#### login'));
      expect(content, contains('Future<String>'));
      expect(content, contains('Future<bool>'));
      expect(content, contains('**Resolve conflicts**: 1 method signature mismatches'));
    });

    test('generateSummaryReport creates multi-feature summary', () async {
      final outputPath = path.join(tempDir.path, 'summary.md');

      final diffs = {
        'auth': StructuralDiff(
          commonFiles: {'lib/auth.dart'},
          onlyInProjectA: {'lib/a.dart'},
          onlyInProjectB: {'lib/b.dart'},
          projectAPath: '/a',
          projectBPath: '/b',
        ),
        'home': StructuralDiff(
          commonFiles: {'lib/home.dart', 'lib/home_view.dart'},
          onlyInProjectA: {},
          onlyInProjectB: {'lib/home_extra.dart'},
          projectAPath: '/a',
          projectBPath: '/b',
        ),
      };

      await reporter.generateSummaryReport(
        structuralDiffs: diffs,
        outputPath: outputPath,
      );

      expect(File(outputPath).existsSync(), isTrue);

      final content = await File(outputPath).readAsString();
      expect(content, contains('# Multi-Feature Diff Summary'));
      expect(content, contains('Total features analyzed: 2'));
      expect(content, contains('### auth'));
      expect(content, contains('### home'));
      expect(content, contains('## Statistics'));
      expect(content, contains('| Total Files | 6 |'));
      expect(content, contains('| Common Files | 3 |'));
      expect(content, contains('| Project A Only | 1 |'));
      expect(content, contains('| Project B Only | 2 |'));
    });
  });
}
