import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// 품질 점수
class QualityScore {
  QualityScore({
    required this.score,
    required this.details,
  });

  /// 점수 (0-100)
  final int score;

  /// 상세 정보
  final String details;

  @override
  String toString() => 'Score: $score/100 - $details';
}

/// 품질 비교 결과
class QualityComparison {
  QualityComparison({
    required this.fileAPath,
    required this.fileBPath,
    required this.errorHandling,
    required this.caching,
    required this.logging,
    required this.complexity,
    required this.recommendation,
  });

  /// File A 경로
  final String fileAPath;

  /// File B 경로
  final String fileBPath;

  /// 에러 처리 품질
  final QualityScore errorHandling;

  /// 캐싱 전략 품질
  final QualityScore caching;

  /// 로깅 품질
  final QualityScore logging;

  /// 코드 복잡도
  final QualityScore complexity;

  /// 권장사항 (A 또는 B 또는 tie)
  final String recommendation;

  /// 총점
  int get totalScore =>
      errorHandling.score +
      caching.score +
      logging.score +
      complexity.score;

  @override
  String toString() {
    return '''
Quality Comparison:
  File A: $fileAPath
  File B: $fileBPath

  Error Handling: ${errorHandling.score}
    ${errorHandling.details}

  Caching: ${caching.score}
    ${caching.details}

  Logging: ${logging.score}
    ${logging.details}

  Complexity: ${complexity.score}
    ${complexity.details}

  Total Score A vs B: ${recommendation == 'A' ? '🏆' : ''} vs ${recommendation == 'B' ? '🏆' : ''}
  Recommendation: $recommendation
''';
  }
}

/// 품질 분석기
class QualityAnalyzer {
  /// 두 mixin 파일의 구현 품질 비교
  Future<QualityComparison> compareQuality({
    required File mixinA,
    required File mixinB,
  }) async {
    final metricsA = await _analyzeFile(mixinA);
    final metricsB = await _analyzeFile(mixinB);

    // 에러 처리 비교
    final errorHandling = _compareErrorHandling(metricsA, metricsB);

    // 캐싱 비교
    final caching = _compareCaching(metricsA, metricsB);

    // 로깅 비교
    final logging = _compareLogging(metricsA, metricsB);

    // 복잡도 비교
    final complexity = _compareComplexity(metricsA, metricsB);

    // 종합 권장사항
    final totalA = errorHandling.score +
        caching.score +
        logging.score +
        complexity.score;
    final totalB = metricsB.errorHandlingScore +
        metricsB.cachingScore +
        metricsB.loggingScore +
        metricsB.complexityScore;

    final recommendation = totalA > totalB
        ? 'A'
        : totalB > totalA
            ? 'B'
            : 'tie';

    return QualityComparison(
      fileAPath: mixinA.path,
      fileBPath: mixinB.path,
      errorHandling: errorHandling,
      caching: caching,
      logging: logging,
      complexity: complexity,
      recommendation: recommendation,
    );
  }

  /// 파일 분석
  Future<_CodeMetrics> _analyzeFile(File file) async {
    if (!file.existsSync()) {
      return _CodeMetrics.empty();
    }

    // Analysis Context 생성
    final collection = AnalysisContextCollection(
      includedPaths: [file.parent.path],
    );

    final context = collection.contextFor(file.path);
    final session = context.currentSession;

    // 파일 분석
    final result = await session.getResolvedUnit(file.path);

    if (result is! ResolvedUnitResult) {
      return _CodeMetrics.empty();
    }

    // AST 방문하여 메트릭 수집
    final visitor = _MetricsCollectorVisitor();
    result.unit.accept(visitor);

    return visitor.finalMetrics;
  }

  /// 에러 처리 비교
  QualityScore _compareErrorHandling(
    _CodeMetrics metricsA,
    _CodeMetrics metricsB,
  ) {
    final score = metricsA.errorHandlingScore;
    final details = metricsA.hasSpecificExceptions
        ? 'Specific exception types (${metricsA.tryCatchCount} catch blocks)'
        : 'Generic exception handling (${metricsA.tryCatchCount} catch blocks)';

    return QualityScore(score: score, details: details);
  }

  /// 캐싱 비교
  QualityScore _compareCaching(_CodeMetrics metricsA, _CodeMetrics metricsB) {
    final score = metricsA.cachingScore;
    final details = metricsA.hasCaching
        ? 'Caching implemented (${metricsA.cacheRelatedCalls} calls)'
        : 'No caching detected';

    return QualityScore(score: score, details: details);
  }

  /// 로깅 비교
  QualityScore _compareLogging(_CodeMetrics metricsA, _CodeMetrics metricsB) {
    final score = metricsA.loggingScore;
    final details = metricsA.loggingStatements > 0
        ? '${metricsA.loggingStatements} logging statements'
        : 'No logging';

    return QualityScore(score: score, details: details);
  }

  /// 복잡도 비교
  QualityScore _compareComplexity(
    _CodeMetrics metricsA,
    _CodeMetrics metricsB,
  ) {
    final score = metricsA.complexityScore;
    final details =
        '${metricsA.methodCount} methods, ${metricsA.lineCount} lines';

    return QualityScore(score: score, details: details);
  }
}

/// 코드 메트릭
class _CodeMetrics {
  _CodeMetrics({
    required this.tryCatchCount,
    required this.hasSpecificExceptions,
    required this.loggingStatements,
    required this.cacheRelatedCalls,
    required this.methodCount,
    required this.lineCount,
  });

  factory _CodeMetrics.empty() {
    return _CodeMetrics(
      tryCatchCount: 0,
      hasSpecificExceptions: false,
      loggingStatements: 0,
      cacheRelatedCalls: 0,
      methodCount: 0,
      lineCount: 0,
    );
  }

  final int tryCatchCount;
  final bool hasSpecificExceptions;
  final int loggingStatements;
  final int cacheRelatedCalls;
  final int methodCount;
  final int lineCount;

  /// 에러 처리 점수
  int get errorHandlingScore {
    var score = tryCatchCount * 10; // 10점 per catch block
    if (hasSpecificExceptions) score += 20; // Bonus for specific exceptions
    return score.clamp(0, 100);
  }

  /// 캐싱 점수
  int get cachingScore {
    if (cacheRelatedCalls == 0) return 0;
    return (cacheRelatedCalls * 15).clamp(0, 100);
  }

  /// 로깅 점수
  int get loggingScore {
    if (loggingStatements == 0) return 0;
    return (loggingStatements * 10).clamp(0, 100);
  }

  /// 복잡도 점수 (낮을수록 좋음, 역산)
  int get complexityScore {
    // 메서드당 평균 라인 수
    final avgLinesPerMethod =
        methodCount > 0 ? lineCount / methodCount : lineCount.toDouble();

    // 20 lines per method = 100점
    // 40 lines per method = 50점
    // 80+ lines per method = 0점
    final score = 100 - ((avgLinesPerMethod - 20) * 2.5).clamp(0, 100);
    return score.toInt();
  }

  bool get hasCaching => cacheRelatedCalls > 0;
}

/// AST 방문자: 메트릭 수집
class _MetricsCollectorVisitor extends RecursiveAstVisitor<void> {
  int _tryCatchCount = 0;
  bool _hasSpecificExceptions = false;
  int _loggingStatements = 0;
  int _cacheRelatedCalls = 0;
  int _methodCount = 0;
  int _lineCount = 0;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    _lineCount = node.lineInfo.lineCount;
    super.visitCompilationUnit(node);

    // 메트릭 업데이트 (final 필드이므로 새 인스턴스 생성 필요)
    // 하지만 visitor 패턴에서는 mutable 필드로 처리하고
    // 최종적으로 getter에서 새 인스턴스 반환
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _methodCount++;
    super.visitMethodDeclaration(node);
  }

  @override
  void visitTryStatement(TryStatement node) {
    _tryCatchCount++;

    // Specific exception type 체크
    for (final catchClause in node.catchClauses) {
      if (catchClause.exceptionType != null) {
        final typeName = catchClause.exceptionType!.toSource();
        // Exception이 아닌 구체적 타입 사용 여부
        if (!typeName.contains('Exception') ||
            typeName.contains('ServerpodClientException') ||
            typeName.contains('NetworkException') ||
            typeName.contains('ValidationException')) {
          _hasSpecificExceptions = true;
        }
      }
    }

    super.visitTryStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    // 로깅 감지
    if (_isLoggingMethod(methodName)) {
      _loggingStatements++;
    }

    // 캐싱 관련 호출 감지
    if (_isCacheMethod(methodName)) {
      _cacheRelatedCalls++;
    }

    super.visitMethodInvocation(node);
  }

  bool _isLoggingMethod(String methodName) {
    return methodName.startsWith('log') ||
        methodName == 'debug' ||
        methodName == 'info' ||
        methodName == 'warn' ||
        methodName == 'error';
  }

  bool _isCacheMethod(String methodName) {
    return methodName.contains('cache') ||
        methodName.contains('Cache') ||
        methodName == 'getCache' ||
        methodName == 'setCache' ||
        methodName == 'clearCache';
  }

  // metrics getter - 최종 수집된 값으로 새 인스턴스 반환
  _CodeMetrics get finalMetrics => _CodeMetrics(
        tryCatchCount: _tryCatchCount,
        hasSpecificExceptions: _hasSpecificExceptions,
        loggingStatements: _loggingStatements,
        cacheRelatedCalls: _cacheRelatedCalls,
        methodCount: _methodCount,
        lineCount: _lineCount,
      );
}
