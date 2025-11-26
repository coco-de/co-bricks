import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// Hook에서 관리하는 .gitignore 패턴들
/// 이 패턴들은 브릭 템플릿에서 제거되고 post_gen.dart에서 동적으로 추가됨
class HookManagedPatterns {
  /// 환경 변수 관련 패턴 (모든 브릭)
  static const environmentPatterns = [
    '**/.envrc',
    '.envrc',
    '.env',
    '.env.*',
  ];

  /// scloud 배포 관련 패턴 (monorepo 브릭)
  static const scloudPatterns = [
    '**/.scloud/',
    '.scloud/',
  ];

  /// Widgetbook 관련 패턴 (monorepo 브릭)
  static const widgetbookPatterns = [
    'app/{{project_name.snakeCase()}}_widgetbook/.idea/',
    'app/{{project_name.snakeCase()}}_widgetbook/.metadata',
  ];

  /// Fastlane 관련 패턴 (app, console 브릭)
  static const fastlanePatterns = [
    'fastlane',
    'ios/fastlane/README.md',
    'ios/fastlane/report.xml',
    'ios/Runner.app.dSYM.zip',
    'ios/Runner.ipa',
    'android/fastlane/README.md',
    'android/fastlane/report.xml',
    '# Note: Commented out to allow fastlane template files in brick',
    '# ios/fastlane',
    '# android/fastlane',
  ];

  /// Makefile 관련 패턴 (모든 브릭)
  static const makefilePatterns = [
    'Makefile',
    '# Makefile',
  ];

  /// 모든 Hook 관리 패턴 (monorepo용)
  static Set<String> get allMonorepoPatterns => {
        ...environmentPatterns,
        ...scloudPatterns,
        ...widgetbookPatterns,
      };

  /// 모든 Hook 관리 패턴 (app/console용)
  static Set<String> get allAppPatterns => {
        ...environmentPatterns,
        ...fastlanePatterns,
        ...makefilePatterns,
      };

  /// 패턴이 Hook 관리 패턴인지 확인
  static bool isHookManaged(String line, Set<String> hookPatterns) {
    final trimmed = line.trim();

    // 빈 줄은 무시
    if (trimmed.isEmpty) return false;

    // Hook 관리 패턴과 정확히 일치하는지 확인
    return hookPatterns.any((pattern) => trimmed == pattern);
  }

  /// 주석이 Hook 관리 패턴 관련인지 확인
  static bool isHookManagedComment(String line, Set<String> hookPatterns) {
    final trimmed = line.trim();

    // Hook 관리 패턴 관련 주석 식별
    for (final pattern in hookPatterns) {
      final isComment = trimmed.startsWith('#');
      final commentContent = isComment ? trimmed.substring(1).trim() : '';
      if (trimmed.contains(pattern) ||
          (isComment && hookPatterns.contains(commentContent))) {
        return true;
      }
    }

    return false;
  }
}

/// .gitignore 파일 스마트 병합 유틸리티
class GitignoreMerger {
  GitignoreMerger(this.logger);

  final Logger logger;

  /// .gitignore 파일 스마트 병합
  ///
  /// 로직:
  /// 1. 브릭의 기존 내용을 읽음 (수동 개선사항 포함)
  /// 2. 템플릿의 신규 내용을 읽음
  /// 3. Hook 관리 패턴을 제거
  /// 4. 브릭 개선사항 유지 + 템플릿 신규 패턴 병합
  Future<void> merge({
    required File brickGitignore,
    required File templateGitignore,
    required Set<String> hookManagedPatterns,
  }) async {
    logger.detail('   🔄 Merging .gitignore: ${brickGitignore.path}');

    // 1. 브릭의 기존 패턴 읽기
    final brickLines = brickGitignore.existsSync()
        ? await brickGitignore.readAsLines()
        : <String>[];

    // 2. 템플릿의 패턴 읽기
    final templateLines = templateGitignore.existsSync()
        ? await templateGitignore.readAsLines()
        : <String>[];

    // 3. 템플릿에서 Hook 관리 패턴 제거
    final cleanedTemplateLines = _removeHookManagedPatterns(
      templateLines,
      hookManagedPatterns,
    );

    // 4. 브릭의 수동 개선사항 추출 (템플릿에 없는 것)
    final brickImprovements = _extractBrickImprovements(
      brickLines,
      cleanedTemplateLines,
      hookManagedPatterns,
    );

    // 5. 최종 병합: 템플릿 + 브릭 개선사항
    final mergedLines = _mergeLinesWithImprovements(
      cleanedTemplateLines,
      brickImprovements,
    );

    // 6. 파일 저장
    if (mergedLines.isNotEmpty) {
      final content = '${mergedLines.join('\n')}\n';
      await brickGitignore.writeAsString(content);

      if (brickImprovements.isNotEmpty) {
        logger.info(
          '   ✅ Merged with ${brickImprovements.length} brick improvements',
        );
      } else {
        logger.info('   ✅ Merged (no brick improvements)');
      }
    }
  }

  /// Hook 관리 패턴 제거
  List<String> _removeHookManagedPatterns(
    List<String> lines,
    Set<String> hookPatterns,
  ) {
    final result = <String>[];
    var skipNextEmptyLine = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Hook 관리 패턴이면 스킵
      if (HookManagedPatterns.isHookManaged(line, hookPatterns)) {
        skipNextEmptyLine = true;
        continue;
      }

      // Hook 관리 패턴 관련 주석이면 스킵
      if (HookManagedPatterns.isHookManagedComment(line, hookPatterns)) {
        skipNextEmptyLine = true;
        continue;
      }

      // 이전에 Hook 패턴을 제거했고 현재 줄이 빈 줄이면 스킵 (중복 빈 줄 방지)
      if (skipNextEmptyLine && trimmed.isEmpty) {
        skipNextEmptyLine = false;
        continue;
      }

      skipNextEmptyLine = false;
      result.add(line);
    }

    return result;
  }

  /// 브릭의 수동 개선사항 추출
  List<String> _extractBrickImprovements(
    List<String> brickLines,
    List<String> templateLines,
    Set<String> hookPatterns,
  ) {
    final improvements = <String>[];
    final templateSet = templateLines.map((l) => l.trim()).toSet();
    final seenPatterns = <String>{};
    var inBrickImprovements = false;

    for (final line in brickLines) {
      final trimmed = line.trim();

      // 빈 줄은 무시
      if (trimmed.isEmpty) continue;

      // "# Brick-specific improvements" 섹션 시작 감지
      if (trimmed == '# Brick-specific improvements') {
        inBrickImprovements = true;
        continue;
      }

      // Hook 관리 패턴은 무시
      if (HookManagedPatterns.isHookManaged(line, hookPatterns)) continue;
      if (HookManagedPatterns.isHookManagedComment(line, hookPatterns)) {
        continue;
      }

      // 템플릿에 없는 브릭만의 패턴 (개선사항)
      if (!templateSet.contains(trimmed)) {
        // 이미 본 패턴은 중복 추가하지 않음
        if (seenPatterns.contains(trimmed)) continue;
        seenPatterns.add(trimmed);

        // Brick-specific improvements 섹션 내부의 패턴만 추출
        // (이전 동기화에서 추가된 개선사항 재사용 방지)
        if (!inBrickImprovements) {
          improvements.add(line);
        }
      }
    }

    return improvements;
  }

  /// 템플릿과 브릭 개선사항 병합
  List<String> _mergeLinesWithImprovements(
    List<String> templateLines,
    List<String> improvements,
  ) {
    final result = <String>[...templateLines];

    // 브릭 개선사항이 있으면 파일 끝에 추가
    if (improvements.isNotEmpty) {
      // 마지막 빈 줄 확인
      if (result.isNotEmpty && result.last.trim().isNotEmpty) {
        result.add('');
      }

      result
        ..add('# Brick-specific improvements')
        ..addAll(improvements);
    }

    return result;
  }
}
