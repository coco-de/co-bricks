import 'dart:io';

import 'package:co_bricks/src/utils/feature_differ.dart';
import 'package:co_bricks/src/utils/interface_analyzer.dart';
import 'package:co_bricks/src/utils/quality_analyzer.dart';

/// Feature 비교 리포트 생성기
class DiffReporter {
  /// 종합 리포트 생성
  ///
  /// [featureName] - 비교할 feature 이름
  /// [structuralDiff] - 파일 구조 비교 결과
  /// [interfaceDiff] - 인터페이스 비교 결과
  /// [qualityComparison] - 품질 비교 결과
  /// [outputPath] - 출력 파일 경로
  Future<void> generateReport({
    required String featureName,
    required StructuralDiff structuralDiff,
    required InterfaceDiff interfaceDiff,
    required QualityComparison qualityComparison,
    required String outputPath,
  }) async {
    final buffer = StringBuffer();

    // 헤더
    buffer
      ..writeln('# Feature Diff Report: $featureName')
      ..writeln()
      ..writeln('Generated: ${DateTime.now()}')
      ..writeln()
      ..writeln('---')
      ..writeln();

    // 1. Executive Summary
    _writeExecutiveSummary(
      buffer,
      structuralDiff,
      interfaceDiff,
      qualityComparison,
    );

    // 2. File Structure Analysis
    _writeStructuralAnalysis(buffer, structuralDiff);

    // 3. Interface Comparison
    _writeInterfaceAnalysis(buffer, interfaceDiff);

    // 4. Implementation Quality
    _writeQualityAnalysis(buffer, qualityComparison);

    // 5. Recommendations
    _writeRecommendations(
      buffer,
      structuralDiff,
      interfaceDiff,
      qualityComparison,
    );

    // 파일 쓰기
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(buffer.toString());
  }

  /// 요약 섹션
  void _writeExecutiveSummary(
    StringBuffer buffer,
    StructuralDiff structuralDiff,
    InterfaceDiff interfaceDiff,
    QualityComparison qualityComparison,
  ) {
    buffer
      ..writeln('## 📊 Executive Summary')
      ..writeln()
      ..writeln('### File Structure')
      ..writeln('- **Total Files**: ${structuralDiff.totalFiles}')
      ..writeln(
        '- **Common Files**: ${structuralDiff.commonFiles.length}',
      )
      ..writeln(
        '- **Project A Only**: ${structuralDiff.onlyInProjectA.length}',
      )
      ..writeln(
        '- **Project B Only**: ${structuralDiff.onlyInProjectB.length}',
      )
      ..writeln()
      ..writeln('### Interface Compatibility')
      ..writeln(
        '- **Common Methods**: ${interfaceDiff.commonMethods.length}',
      )
      ..writeln('- **Method Conflicts**: ${interfaceDiff.conflicts.length}')
      ..writeln(
        '- **Project A Methods**: ${interfaceDiff.projectAMethodCount}',
      )
      ..writeln(
        '- **Project B Methods**: ${interfaceDiff.projectBMethodCount}',
      )
      ..writeln()
      ..writeln('### Implementation Quality')
      ..writeln('- **Winner**: ${qualityComparison.recommendation}')
      ..writeln(
        '- **Error Handling**: ${qualityComparison.errorHandling.score}/100',
      )
      ..writeln('- **Caching**: ${qualityComparison.caching.score}/100')
      ..writeln('- **Logging**: ${qualityComparison.logging.score}/100')
      ..writeln(
        '- **Complexity**: ${qualityComparison.complexity.score}/100',
      )
      ..writeln()
      ..writeln('---')
      ..writeln();
  }

  /// 파일 구조 분석 섹션
  void _writeStructuralAnalysis(
    StringBuffer buffer,
    StructuralDiff structuralDiff,
  ) {
    buffer
      ..writeln('## 📁 File Structure Analysis')
      ..writeln()
      ..writeln('### Common Files (${structuralDiff.commonFiles.length})')
      ..writeln();

    if (structuralDiff.commonFiles.isEmpty) {
      buffer.writeln('*No common files found*');
    } else {
      for (final file in structuralDiff.commonFiles) {
        buffer.writeln('- `$file`');
      }
    }
    buffer.writeln();

    // Project A only
    buffer
      ..writeln('### Project A Only (${structuralDiff.onlyInProjectA.length})')
      ..writeln()
      ..writeln('Path: `${structuralDiff.projectAPath}`')
      ..writeln();

    if (structuralDiff.onlyInProjectA.isEmpty) {
      buffer.writeln('*All files are common or in Project B*');
    } else {
      for (final file in structuralDiff.onlyInProjectA) {
        buffer.writeln('- `$file`');
      }
    }
    buffer.writeln();

    // Project B only
    buffer
      ..writeln('### Project B Only (${structuralDiff.onlyInProjectB.length})')
      ..writeln()
      ..writeln('Path: `${structuralDiff.projectBPath}`')
      ..writeln();

    if (structuralDiff.onlyInProjectB.isEmpty) {
      buffer.writeln('*All files are common or in Project A*');
    } else {
      for (final file in structuralDiff.onlyInProjectB) {
        buffer.writeln('- `$file`');
      }
    }
    buffer
      ..writeln()
      ..writeln('---')
      ..writeln();
  }

  /// 인터페이스 분석 섹션
  void _writeInterfaceAnalysis(
    StringBuffer buffer,
    InterfaceDiff interfaceDiff,
  ) {
    buffer
      ..writeln('## 🔌 Interface Comparison')
      ..writeln()
      ..writeln('### Common Methods (${interfaceDiff.commonMethods.length})')
      ..writeln();

    if (interfaceDiff.commonMethods.isEmpty) {
      buffer.writeln('*No common methods found*');
    } else {
      for (final method in interfaceDiff.commonMethods) {
        buffer.writeln('- `${method.signature}`');
      }
    }
    buffer.writeln();

    // Conflicts
    if (interfaceDiff.conflicts.isNotEmpty) {
      buffer
        ..writeln(
          '### ⚠️ Signature Conflicts (${interfaceDiff.conflicts.length})',
        )
        ..writeln();

      for (final conflict in interfaceDiff.conflicts) {
        buffer
          ..writeln('#### ${conflict.methodName}')
          ..writeln()
          ..writeln('**Project A:**')
          ..writeln('```dart')
          ..writeln(conflict.signatureA.signature)
          ..writeln('```')
          ..writeln()
          ..writeln('**Project B:**')
          ..writeln('```dart')
          ..writeln(conflict.signatureB.signature)
          ..writeln('```')
          ..writeln();
      }
    }

    // Project A only methods
    buffer
      ..writeln(
        '### Project A Only Methods (${interfaceDiff.onlyInProjectA.length})',
      )
      ..writeln();

    if (interfaceDiff.onlyInProjectA.isEmpty) {
      buffer.writeln('*All methods are common or in Project B*');
    } else {
      for (final method in interfaceDiff.onlyInProjectA) {
        buffer.writeln('- `${method.signature}`');
      }
    }
    buffer.writeln();

    // Project B only methods
    buffer
      ..writeln(
        '### Project B Only Methods (${interfaceDiff.onlyInProjectB.length})',
      )
      ..writeln();

    if (interfaceDiff.onlyInProjectB.isEmpty) {
      buffer.writeln('*All methods are common or in Project A*');
    } else {
      for (final method in interfaceDiff.onlyInProjectB) {
        buffer.writeln('- `${method.signature}`');
      }
    }
    buffer
      ..writeln()
      ..writeln('---')
      ..writeln();
  }

  /// 품질 분석 섹션
  void _writeQualityAnalysis(
    StringBuffer buffer,
    QualityComparison qualityComparison,
  ) {
    buffer
      ..writeln('## ⭐ Implementation Quality')
      ..writeln()
      ..writeln('### Recommendation: ${qualityComparison.recommendation}')
      ..writeln()
      ..writeln('### Detailed Scores')
      ..writeln()
      ..writeln('| Metric | Project A | Details |')
      ..writeln('|--------|-----------|---------|')
      ..writeln(
        '| Error Handling | ${qualityComparison.errorHandling.score}/100 | ${qualityComparison.errorHandling.details} |',
      )
      ..writeln(
        '| Caching | ${qualityComparison.caching.score}/100 | ${qualityComparison.caching.details} |',
      )
      ..writeln(
        '| Logging | ${qualityComparison.logging.score}/100 | ${qualityComparison.logging.details} |',
      )
      ..writeln(
        '| Complexity | ${qualityComparison.complexity.score}/100 | ${qualityComparison.complexity.details} |',
      )
      ..writeln('| **Total** | **${qualityComparison.totalScore}/400** | |')
      ..writeln()
      ..writeln('### Analysis')
      ..writeln();

    // Error Handling
    buffer
      ..writeln(
        '**Error Handling (${qualityComparison.errorHandling.score}/100)**',
      )
      ..writeln()
      ..writeln(qualityComparison.errorHandling.details)
      ..writeln();

    // Caching
    buffer
      ..writeln('**Caching (${qualityComparison.caching.score}/100)**')
      ..writeln()
      ..writeln(qualityComparison.caching.details)
      ..writeln();

    // Logging
    buffer
      ..writeln('**Logging (${qualityComparison.logging.score}/100)**')
      ..writeln()
      ..writeln(qualityComparison.logging.details)
      ..writeln();

    // Complexity
    buffer
      ..writeln('**Complexity (${qualityComparison.complexity.score}/100)**')
      ..writeln()
      ..writeln(qualityComparison.complexity.details)
      ..writeln()
      ..writeln('---')
      ..writeln();
  }

  /// 권장사항 섹션
  void _writeRecommendations(
    StringBuffer buffer,
    StructuralDiff structuralDiff,
    InterfaceDiff interfaceDiff,
    QualityComparison qualityComparison,
  ) {
    buffer
      ..writeln('## 💡 Recommendations')
      ..writeln();

    // 1. Missing files
    if (structuralDiff.onlyInProjectA.isNotEmpty ||
        structuralDiff.onlyInProjectB.isNotEmpty) {
      buffer
        ..writeln('### File Structure')
        ..writeln();

      if (structuralDiff.onlyInProjectA.isNotEmpty) {
        buffer
          ..writeln(
            '- **Add to Project B**: ${structuralDiff.onlyInProjectA.length} files missing',
          )
          ..writeln(
            '  - Consider: ${structuralDiff.onlyInProjectA.take(3).join(', ')}${structuralDiff.onlyInProjectA.length > 3 ? '...' : ''}',
          )
          ..writeln();
      }

      if (structuralDiff.onlyInProjectB.isNotEmpty) {
        buffer
          ..writeln(
            '- **Add to Project A**: ${structuralDiff.onlyInProjectB.length} files missing',
          )
          ..writeln(
            '  - Consider: ${structuralDiff.onlyInProjectB.take(3).join(', ')}${structuralDiff.onlyInProjectB.length > 3 ? '...' : ''}',
          )
          ..writeln();
      }
    }

    // 2. Interface conflicts
    if (interfaceDiff.conflicts.isNotEmpty) {
      buffer
        ..writeln('### Interface Compatibility')
        ..writeln()
        ..writeln(
          '- **Resolve conflicts**: ${interfaceDiff.conflicts.length} method signature mismatches',
        )
        ..writeln(
          '  - ${interfaceDiff.conflicts.map((c) => c.methodName).join(', ')}',
        )
        ..writeln();
    }

    // 3. Quality improvements
    buffer
      ..writeln('### Quality Improvements')
      ..writeln();

    final scores = [
      ('Error Handling', qualityComparison.errorHandling.score),
      ('Caching', qualityComparison.caching.score),
      ('Logging', qualityComparison.logging.score),
      ('Complexity', qualityComparison.complexity.score),
    ];

    final lowScores = scores.where((s) => s.$2 < 50).toList();
    if (lowScores.isNotEmpty) {
      buffer.writeln('**Low scores needing attention:**');
      for (final score in lowScores) {
        buffer.writeln('- ${score.$1}: ${score.$2}/100');
      }
      buffer.writeln();
    }

    final mediumScores = scores.where((s) => s.$2 >= 50 && s.$2 < 80).toList();
    if (mediumScores.isNotEmpty) {
      buffer.writeln('**Areas for improvement:**');
      for (final score in mediumScores) {
        buffer.writeln('- ${score.$1}: ${score.$2}/100');
      }
      buffer.writeln();
    }

    // 4. Winner recommendation
    if (qualityComparison.recommendation != 'tie') {
      buffer
        ..writeln('### Overall Recommendation')
        ..writeln()
        ..writeln(
          'Project ${qualityComparison.recommendation} has better implementation quality.',
        )
        ..writeln(
          'Consider adopting patterns from Project ${qualityComparison.recommendation}.',
        )
        ..writeln();
    }

    buffer
      ..writeln('---')
      ..writeln()
      ..writeln('*Report generated by co-bricks diff detection engine*');
  }

  /// 여러 feature의 리포트를 통합
  Future<void> generateSummaryReport({
    required Map<String, StructuralDiff> structuralDiffs,
    required String outputPath,
  }) async {
    final buffer = StringBuffer();

    buffer
      ..writeln('# Multi-Feature Diff Summary')
      ..writeln()
      ..writeln('Generated: ${DateTime.now()}')
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln('## Overview')
      ..writeln()
      ..writeln('Total features analyzed: ${structuralDiffs.length}')
      ..writeln();

    // Feature-by-feature summary
    for (final entry in structuralDiffs.entries) {
      final featureName = entry.key;
      final diff = entry.value;

      buffer
        ..writeln('### $featureName')
        ..writeln()
        ..writeln('- Total Files: ${diff.totalFiles}')
        ..writeln('- Common: ${diff.commonFiles.length}')
        ..writeln('- Project A Only: ${diff.onlyInProjectA.length}')
        ..writeln('- Project B Only: ${diff.onlyInProjectB.length}')
        ..writeln();
    }

    // Statistics
    final totalFiles = structuralDiffs.values
        .map((d) => d.totalFiles)
        .reduce((a, b) => a + b);
    final totalCommon = structuralDiffs.values
        .map((d) => d.commonFiles.length)
        .reduce((a, b) => a + b);
    final totalAOnly = structuralDiffs.values
        .map((d) => d.onlyInProjectA.length)
        .reduce((a, b) => a + b);
    final totalBOnly = structuralDiffs.values
        .map((d) => d.onlyInProjectB.length)
        .reduce((a, b) => a + b);

    buffer
      ..writeln('---')
      ..writeln()
      ..writeln('## Statistics')
      ..writeln()
      ..writeln('| Metric | Count |')
      ..writeln('|--------|-------|')
      ..writeln('| Total Files | $totalFiles |')
      ..writeln('| Common Files | $totalCommon |')
      ..writeln('| Project A Only | $totalAOnly |')
      ..writeln('| Project B Only | $totalBOnly |')
      ..writeln();

    // 파일 쓰기
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(buffer.toString());
  }
}
