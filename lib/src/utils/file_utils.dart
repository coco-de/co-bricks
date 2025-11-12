import 'dart:io';

import 'package:path/path.dart' as path;

/// 파일 시스템 유틸리티
class FileUtils {
  /// 제외할 디렉토리 목록 (정확한 이름 매칭)
  static const excludedDirs = [
    '.dart_tool',
    'build',
    'node_modules',
    'Pods',
    '.git', // .github, .githooks는 포함해야 하므로 정확히 .git만
  ];

  /// 제외할 파일 패턴 (파일명 기반)
  static bool shouldExcludeFile(String fileName, [String? filePath]) {
    // melos .iml 파일 제외
    if (fileName.startsWith('melos_') && fileName.endsWith('.iml')) {
      return true;
    }

    // pubspec.lock, pubspec_overrides.yaml, .flutter-plugins-dependencies 제외
    if (fileName == 'pubspec.lock' ||
        fileName == 'pubspec_overrides.yaml' ||
        fileName == '.flutter-plugins-dependencies') {
      return true;
    }

    // 코드 생성 파일들 제외 (전역)
    final generatedPatterns = [
      '.g.dart', // build_runner 생성 파일
      '.freezed.dart', // freezed 생성 파일
      '.config.dart', // envied 등 설정 생성 파일
      '.gr.dart', // auto_route 생성 파일
      '.gen.dart', // flutter_gen 등 생성 파일
      '.module.dart', // injectable 모듈 생성 파일
    ];

    for (final pattern in generatedPatterns) {
      if (fileName.endsWith(pattern)) {
        return true;
      }
    }

    // 경로 기반 제외 (filePath가 제공된 경우)
    if (filePath != null) {
      // 정규화된 경로 사용 (윈도우 호환)
      final normalizedPath = filePath.replaceAll('\\', '/');

      // 테스트 Mock 파일 제외: **/test/**/*.mocks.dart
      if (normalizedPath.contains('/test/') &&
          fileName.endsWith('.mocks.dart')) {
        return true;
      }

      // Serverpod 생성 파일 제외
      // backend/*_client/lib/src/protocol/**/*.dart
      if (normalizedPath.contains('/backend/') &&
          normalizedPath.contains('_client/lib/src/protocol/') &&
          fileName.endsWith('.dart')) {
        return true;
      }

      // backend/*_server/lib/src/generated/**/*.dart
      if (normalizedPath.contains('/backend/') &&
          normalizedPath.contains('_server/lib/src/generated/') &&
          fileName.endsWith('.dart')) {
        return true;
      }

      // backend/*_server/test/integration/test_tools/serverpod_test_tools.dart
      if (normalizedPath.contains('/backend/') &&
          normalizedPath.contains('_server/test/integration/test_tools/') &&
          fileName == 'serverpod_test_tools.dart') {
        return true;
      }

      // backend/*_server/migrations/**/* (마이그레이션 파일 제외)
      if (normalizedPath.contains('/backend/') &&
          normalizedPath.contains('_server/migrations/')) {
        return true;
      }
    }

    return false;
  }

  /// 디렉토리 복사 (제외 패턴 지원)
  static Future<void> copyDirectory(
    Directory source,
    Directory target, {
    bool overwrite = false,
  }) async {
    if (!source.existsSync()) {
      throw FileSystemException(
        'Source directory does not exist',
        source.path,
      );
    }

    // 타겟 디렉토리 생성
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    } else if (!overwrite) {
      throw FileSystemException(
        'Target directory already exists',
        target.path,
      );
    }

    await for (final entity in source.list(recursive: false)) {
      final targetPath = path.join(target.path, path.basename(entity.path));

      if (entity is Directory) {
        final dirName = entity.path.split(path.separator).last;

        // 제외할 디렉토리면 스킵
        if (excludedDirs.contains(dirName)) {
          continue;
        }

        // migrations 디렉토리 제외 (backend/*_server/migrations)
        final normalizedPath = entity.path.replaceAll(r'\', '/');
        if (dirName == 'migrations' &&
            normalizedPath.contains('/backend/') &&
            normalizedPath.contains('_server/')) {
          continue;
        }

        await copyDirectory(
          entity,
          Directory(targetPath),
          overwrite: overwrite,
        );
      } else if (entity is File) {
        // 제외할 파일이면 스킵
        if (shouldExcludeFile(path.basename(entity.path), entity.path)) {
          continue;
        }
        await entity.copy(targetPath);
      }
    }
  }

  /// 디렉토리 삭제 (재귀적)
  static Future<void> deleteDirectory(Directory dir) async {
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// 파일명 변환 (프로젝트명을 템플릿 변수로 변환)
  static String convertFileName(
    String fileName,
    List<String> projectNames, {
    bool isRootDirectory = false,
  }) {
    var newName = fileName;
    final fileNameLower = fileName.toLowerCase();

    for (final projectName in projectNames) {
      // Longer suffixes first to avoid partial matches
      final suffixes = [
        '_server',
        '_client',
        '_widgetbook',
        '_console',
        '_service',
        '_module',
      ];

      // Try matching with suffixes first (more specific)
      var matched = false;
      for (final suffix in suffixes) {
        final patternWithSuffix = '$projectName$suffix';
        if (fileNameLower.contains(patternWithSuffix.toLowerCase())) {
          newName = newName.replaceAll(
            RegExp(patternWithSuffix, caseSensitive: false),
            '{{project_name.snakeCase()}}$suffix',
          );
          matched = true;
          break;
        }
      }

      if (matched) continue;

      // Try basic patterns (snake_case, no separator, param-case)
      final patterns = [
        projectName,
        projectName.replaceAll('_', ''),
        projectName.replaceAll('_', '-'),
      ];

      for (final pattern in patterns) {
        if (fileNameLower.contains(pattern.toLowerCase())) {
          // 루트 디렉토리는 paramCase, 나머지는 snakeCase 사용
          final templateVar = isRootDirectory
              ? '{{project_name.paramCase()}}'
              : '{{project_name.snakeCase()}}';
          newName = newName.replaceAll(
            RegExp(pattern, caseSensitive: false),
            templateVar,
          );
          break;
        }
      }
    }

    return newName;
  }

  /// 디렉토리명 변환
  static String convertDirectoryName(
    String dirName,
    List<String> projectNames, {
    bool isRootDirectory = false,
  }) {
    return convertFileName(
      dirName,
      projectNames,
      isRootDirectory: isRootDirectory,
    );
  }

  /// Android Kotlin 디렉토리 경로 변환
  static Future<void> convertAndroidKotlinPaths(
    Directory targetDir,
    List<String> projectNames,
  ) async {
    final kotlinBasePath = Directory(
      path.join(
        targetDir.path,
        'android',
        'app',
        'src',
        'main',
        'kotlin',
      ),
    );

    if (!kotlinBasePath.existsSync()) {
      return;
    }

    // 여러 조직 TLD 지원 (im, com 등)
    for (final orgTld in ['im', 'com']) {
      final orgTldPath = Directory(path.join(kotlinBasePath.path, orgTld));
      if (!orgTldPath.existsSync()) {
        continue;
      }

      // 여러 조직명 지원
      for (final orgName in ['cocode', 'laputa', 'gonft']) {
        final orgPath = Directory(path.join(orgTldPath.path, orgName));
        if (!orgPath.existsSync()) {
          continue;
        }

        // 여러 프로젝트명 지원
        for (final projectName in projectNames) {
          var projectPath = Directory(
            path.join(orgPath.path, projectName.replaceAll('_', '')),
          );

          if (!projectPath.existsSync()) {
            // 하이픈 형식도 시도
            projectPath = Directory(
              path.join(orgPath.path, projectName.replaceAll('_', '-')),
            );
          }

          if (projectPath.existsSync()) {
            // 새 패키지 구조 생성
            final newPackagePath = Directory(
              path.join(
                kotlinBasePath.path,
                '{{org_tld}}',
                '{{org_name.lowerCase()}}',
                '{{project_name.paramCase()}}',
              ),
            );
            newPackagePath.createSync(recursive: true);

            // 파일들 이동
            await for (final entity in projectPath.list()) {
              if (entity is File) {
                final targetFile = File(
                  path.join(newPackagePath.path, path.basename(entity.path)),
                );
                await entity.copy(targetFile.path);
                await entity.delete();
              }
            }

            // 빈 디렉토리들 제거 (하위부터)
            try {
              await projectPath.delete(recursive: true);
              await orgPath.delete(recursive: true);
              await orgTldPath.delete(recursive: true);
            } catch (_) {
              // 디렉토리가 비어있지 않으면 무시
            }

            return; // 첫 번째 매치만 처리
          }
        }
      }
    }
  }

  /// 파일이 텍스트 파일인지 확인
  static Future<bool> isTextFile(File file) async {
    try {
      final bytes = await file.openRead(0, 1024).first;
      // NULL 바이트가 있으면 바이너리
      return !bytes.contains(0);
    } catch (_) {
      return false;
    }
  }

  /// 파일 크기 확인 (5MB 이상이면 false)
  static bool isFileSizeValid(File file) {
    try {
      final size = file.lengthSync();
      return size < 5 * 1024 * 1024; // 5MB
    } catch (_) {
      return false;
    }
  }

  /// 처리할 파일 확장자 목록
  static const _processableExtensions = [
    '.dart',
    '.yaml',
    '.yml',
    '.json',
    '.md',
    '.sh',
    '.gradle',
    '.kts',
    '.kt',
    '.xml',
    '.plist',
    '.pbxproj',
    '.html',
    '.envrc',
    '.env',
    '.properties',
    '.firebaserc',
    '.cpp',
    '.cc',
    '.c',
    '.h',
    '.hpp',
    '.rc',
    '.txt',
    '.xcconfig',
    '.xcscheme',
  ];

  /// 특수 파일명 목록
  static const _specialFiles = [
    'Makefile',
    'Podfile',
    'Appfile',
    'Matchfile',
    'Fastfile',
    '.envrc',
    '.firebaserc',
    '.cursorrules',
    '.fvmrc',
    '.gitignore',
    '.hintrc',
    'CLAUDE.md',
    'melos.yaml',
    'pubspec.yaml',
    'CMakeLists.txt',
    'apple-app-site-association',
  ];

  /// 파일을 처리해야 하는지 확인
  static bool shouldProcessFile(File file) {
    final fileName = path.basename(file.path);
    final extension = path.extension(fileName);

    // 특수 파일명 체크
    if (_specialFiles.contains(fileName)) {
      return true;
    }

    // 확장자 체크 (이중 확장자도 처리: .html.original 등)
    final allExtensions = fileName.split('.');
    if (allExtensions.length > 1) {
      for (var i = 1; i < allExtensions.length; i++) {
        final ext = '.${allExtensions[i]}';
        if (_processableExtensions.contains(ext)) {
          return true;
        }
      }
    }

    return _processableExtensions.contains(extension);
  }
}
