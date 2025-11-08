import 'dart:io';

import 'package:path/path.dart' as path;

/// 파일 시스템 유틸리티
class FileUtils {
  /// 제외할 디렉토리 목록
  static const excludedDirs = [
    '.dart_tool',
    'build',
    '.idea',
    'node_modules',
    'Pods',
    '.vscode',
    '.git',
  ];

  /// 제외할 파일 패턴
  static bool shouldExcludeFile(String fileName) {
    // .iml 파일 제외 (프로젝트 설정)
    if (fileName.startsWith('melos_') && fileName.endsWith('.iml')) {
      return true;
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
        // 제외할 디렉토리면 스킵
        if (excludedDirs.contains(entity.path.split(path.separator).last)) {
          continue;
        }
        await copyDirectory(
          entity,
          Directory(targetPath),
          overwrite: overwrite,
        );
      } else if (entity is File) {
        // 제외할 파일이면 스킵
        if (shouldExcludeFile(path.basename(entity.path))) {
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
    List<String> projectNames,
  ) {
    var newName = fileName;
    final fileNameLower = fileName.toLowerCase();

    for (final projectName in projectNames) {
      final patterns = [
        projectName,
        projectName.replaceAll('_', ''),
        projectName.replaceAll('_', '-'),
      ];

      for (final pattern in patterns) {
        if (fileNameLower.contains(pattern.toLowerCase())) {
          newName = newName.replaceAll(
            RegExp(pattern, caseSensitive: false),
            '{{project_name.snakeCase()}}',
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
    List<String> projectNames,
  ) {
    return convertFileName(dirName, projectNames);
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
    'CMakeLists.txt',
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

