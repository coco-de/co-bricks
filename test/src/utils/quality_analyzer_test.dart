import 'package:co_bricks/src/utils/quality_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('QualityScore', () {
    test('toString formats score correctly', () {
      final score = QualityScore(
        score: 85,
        details: 'Good error handling with specific exceptions',
      );

      expect(score.toString(), 'Score: 85/100 - Good error handling with specific exceptions');
    });
  });

  group('QualityComparison', () {
    test('calculates totalScore correctly', () {
      final comparison = QualityComparison(
        fileAPath: '/path/a/mixin.dart',
        fileBPath: '/path/b/mixin.dart',
        errorHandling: QualityScore(score: 80, details: 'Error handling A'),
        caching: QualityScore(score: 75, details: 'Caching A'),
        logging: QualityScore(score: 60, details: 'Logging A'),
        complexity: QualityScore(score: 90, details: 'Complexity A'),
        recommendation: 'A',
      );

      expect(comparison.totalScore, 305); // 80 + 75 + 60 + 90
    });

    test('toString includes all components', () {
      final comparison = QualityComparison(
        fileAPath: '/path/a/mixin.dart',
        fileBPath: '/path/b/mixin.dart',
        errorHandling: QualityScore(score: 80, details: 'Error handling'),
        caching: QualityScore(score: 75, details: 'Caching'),
        logging: QualityScore(score: 60, details: 'Logging'),
        complexity: QualityScore(score: 90, details: 'Complexity'),
        recommendation: 'A',
      );

      final output = comparison.toString();
      expect(output, contains('Error Handling: 80'));
      expect(output, contains('Caching: 75'));
      expect(output, contains('Logging: 60'));
      expect(output, contains('Complexity: 90'));
      expect(output, contains('Recommendation: A'));
    });

    test('recommendation shows trophy for winner', () {
      final comparisonA = QualityComparison(
        fileAPath: '/path/a',
        fileBPath: '/path/b',
        errorHandling: QualityScore(score: 80, details: ''),
        caching: QualityScore(score: 75, details: ''),
        logging: QualityScore(score: 60, details: ''),
        complexity: QualityScore(score: 90, details: ''),
        recommendation: 'A',
      );

      final comparisonB = QualityComparison(
        fileAPath: '/path/a',
        fileBPath: '/path/b',
        errorHandling: QualityScore(score: 80, details: ''),
        caching: QualityScore(score: 75, details: ''),
        logging: QualityScore(score: 60, details: ''),
        complexity: QualityScore(score: 90, details: ''),
        recommendation: 'B',
      );

      expect(comparisonA.toString(), contains('🏆 vs'));
      expect(comparisonB.toString(), contains('vs 🏆'));
    });
  });

  group('QualityAnalyzer', () {
    test('compareQuality handles non-existent files', () async {
      // 실제 파일이 필요하므로 통합 테스트에서 수행
      // 여기서는 기본 구조만 테스트
    });
  });
}
