import 'dart:io';

import 'package:path/path.dart' as path;

/// 두 프로젝트의 feature 구조를 비교하는 결과
class StructuralDiff {
  StructuralDiff({
    required this.commonFiles,
    required this.onlyInProjectA,
    required this.onlyInProjectB,
    required this.projectAPath,
    required this.projectBPath,
  });

  /// 두 프로젝트 모두에 있는 파일들
  final Set<String> commonFiles;

  /// Project A에만 있는 파일들
  final Set<String> onlyInProjectA;

  /// Project B에만 있는 파일들
  final Set<String> onlyInProjectB;

  /// Project A의 루트 경로
  final String projectAPath;

  /// Project B의 루트 경로
  final String projectBPath;

  /// 전체 파일 수
  int get totalFiles =>
      commonFiles.length + onlyInProjectA.length + onlyInProjectB.length;

  /// 도메인 레이어 파일 필터링
  Set<String> filterByLayer(Set<String> files, String layer) {
    return files.where((file) => file.contains('/src/$layer/')).toSet();
  }

  /// Project A 전체 파일
  Set<String> get projectAFiles => {...commonFiles, ...onlyInProjectA};

  /// Project B 전체 파일
  Set<String> get projectBFiles => {...commonFiles, ...onlyInProjectB};
}

/// Feature 구조를 비교하는 유틸리티
class FeatureDiffer {
  /// 두 프로젝트의 feature 디렉토리를 비교
  ///
  /// [projectADir] - Project A의 feature 루트 디렉토리
  /// [projectBDir] - Project B의 feature 루트 디렉토리
  /// [featureName] - 비교할 feature 이름 (예: 'auth', 'home')
  Future<StructuralDiff> compareStructure({
    required Directory projectADir,
    required Directory projectBDir,
    required String featureName,
  }) async {
    // Feature 디렉토리 찾기
    final featureADir = await _findFeatureDirectory(projectADir, featureName);
    final featureBDir = await _findFeatureDirectory(projectBDir, featureName);

    if (featureADir == null && featureBDir == null) {
      throw FeatureDiffException(
        'Feature "$featureName" not found in either project',
      );
    }

    // Dart 파일 스캔
    final filesA = featureADir != null
        ? await _scanDartFiles(featureADir)
        : <String>{};
    final filesB = featureBDir != null
        ? await _scanDartFiles(featureBDir)
        : <String>{};

    // 상대 경로로 변환
    final relativeFilesA = featureADir != null
        ? _toRelativePaths(filesA, featureADir.path)
        : <String>{};
    final relativeFilesB = featureBDir != null
        ? _toRelativePaths(filesB, featureBDir.path)
        : <String>{};

    // 차이 계산
    final common = relativeFilesA.intersection(relativeFilesB);
    final onlyInA = relativeFilesA.difference(relativeFilesB);
    final onlyInB = relativeFilesB.difference(relativeFilesA);

    return StructuralDiff(
      commonFiles: common,
      onlyInProjectA: onlyInA,
      onlyInProjectB: onlyInB,
      projectAPath: featureADir?.path ?? '',
      projectBPath: featureBDir?.path ?? '',
    );
  }

  /// Feature 디렉토리 찾기
  ///
  /// feature/common/{featureName} 또는 feature/{featureName} 패턴 검색
  Future<Directory?> _findFeatureDirectory(
    Directory projectDir,
    String featureName,
  ) async {
    // 가능한 경로 패턴
    final patterns = [
      'feature/common/$featureName',
      'feature/$featureName',
      'features/common/$featureName',
      'features/$featureName',
    ];

    for (final pattern in patterns) {
      final dir = Directory(path.join(projectDir.path, pattern));
      if (dir.existsSync()) {
        return dir;
      }
    }

    return null;
  }

  /// 디렉토리 내 모든 Dart 파일 스캔 (재귀적)
  Future<Set<String>> _scanDartFiles(Directory dir) async {
    final files = <String>{};

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity.path);
      }
    }

    return files;
  }

  /// 절대 경로를 상대 경로로 변환
  Set<String> _toRelativePaths(Set<String> absolutePaths, String basePath) {
    return absolutePaths
        .map((filePath) => path.relative(filePath, from: basePath))
        .toSet();
  }

  /// 모든 feature를 비교
  ///
  /// [projectADir] - Project A의 루트 디렉토리
  /// [projectBDir] - Project B의 루트 디렉토리
  Future<Map<String, StructuralDiff>> compareAllFeatures({
    required Directory projectADir,
    required Directory projectBDir,
  }) async {
    // 두 프로젝트에서 feature 이름 추출
    final featuresA = await _listFeatureNames(projectADir);
    final featuresB = await _listFeatureNames(projectBDir);

    // 모든 feature 목록 (union)
    final allFeatures = {...featuresA, ...featuresB};

    final results = <String, StructuralDiff>{};

    for (final featureName in allFeatures) {
      try {
        final diff = await compareStructure(
          projectADir: projectADir,
          projectBDir: projectBDir,
          featureName: featureName,
        );
        results[featureName] = diff;
      } on FeatureDiffException {
        // Feature가 한쪽에만 있는 경우 무시
        continue;
      }
    }

    return results;
  }

  /// 프로젝트의 모든 feature 이름 목록
  Future<Set<String>> _listFeatureNames(Directory projectDir) async {
    final features = <String>{};

    // feature/common/ 디렉토리 스캔
    final patterns = ['feature/common', 'feature', 'features/common', 'features'];

    for (final pattern in patterns) {
      final dir = Directory(path.join(projectDir.path, pattern));
      if (dir.existsSync()) {
        await for (final entity in dir.list()) {
          if (entity is Directory) {
            features.add(path.basename(entity.path));
          }
        }
      }
    }

    return features;
  }
}

/// Feature diff 관련 예외
class FeatureDiffException implements Exception {
  FeatureDiffException(this.message);

  final String message;

  @override
  String toString() => 'FeatureDiffException: $message';
}
