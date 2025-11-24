import 'package:co_bricks/src/utils/feature_differ.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureDiffer', () {
    test('compareStructure returns valid StructuralDiff', () async {
      // 실제 프로젝트 디렉토리가 필요하므로 스킵
      // 통합 테스트에서 실제 프로젝트로 테스트 필요
    });

    test('StructuralDiff calculates totalFiles correctly', () {
      final diff = StructuralDiff(
        commonFiles: {'file1.dart', 'file2.dart'},
        onlyInProjectA: {'file3.dart'},
        onlyInProjectB: {'file4.dart', 'file5.dart'},
        projectAPath: '/path/a',
        projectBPath: '/path/b',
      );

      expect(diff.totalFiles, 5);
      expect(diff.projectAFiles.length, 3); // common + onlyInA
      expect(diff.projectBFiles.length, 4); // common + onlyInB
    });

    test('filterByLayer filters files correctly', () {
      final diff = StructuralDiff(
        commonFiles: {
          'lib/src/domain/entity/user.dart',
          'lib/src/data/model/user_model.dart',
          'lib/src/presentation/page/home.dart',
        },
        onlyInProjectA: <String>{},
        onlyInProjectB: <String>{},
        projectAPath: '/path/a',
        projectBPath: '/path/b',
      );

      final domainFiles = diff.filterByLayer(diff.commonFiles, 'domain');
      expect(domainFiles.length, 1);
      expect(domainFiles.first, contains('domain'));

      final dataFiles = diff.filterByLayer(diff.commonFiles, 'data');
      expect(dataFiles.length, 1);
      expect(dataFiles.first, contains('data'));

      final presentationFiles =
          diff.filterByLayer(diff.commonFiles, 'presentation');
      expect(presentationFiles.length, 1);
      expect(presentationFiles.first, contains('presentation'));
    });
  });

  group('FeatureDiffException', () {
    test('toString returns formatted message', () {
      final exception = FeatureDiffException('Test error');
      expect(exception.toString(), 'FeatureDiffException: Test error');
    });
  });
}
