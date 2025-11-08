import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:co_bricks/src/services/envrc_service.dart';
import 'package:co_bricks/src/utils/file_utils.dart';
import 'package:co_bricks/src/utils/template_converter.dart';

/// Monorepo 동기화 서비스
class SyncMonorepoService {
  SyncMonorepoService(this.logger);

  final Logger logger;

  /// Monorepo 동기화 실행
  Future<void> sync(ProjectConfig config, Directory? projectDir) async {
    final rootDir = projectDir ?? Directory.current;

    // template 디렉토리 찾기 (상위로 올라가면서)
    var currentDir = rootDir;
    Directory? templateDir;

    while (true) {
      final candidateTemplateDir = Directory(
        path.join(currentDir.path, 'template', config.projectName),
      );
      if (candidateTemplateDir.existsSync()) {
        templateDir = candidateTemplateDir;
        break;
      }

      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        break;
      }
      currentDir = parent;
    }

    if (templateDir == null) {
      throw FileSystemException(
        'Template directory not found: template/${config.projectName}',
        rootDir.path,
      );
    }

    // bricks 디렉토리 찾기 (상위로 올라가면서)
    currentDir = rootDir;
    Directory? bricksDir;

    while (true) {
      final candidateBricksDir = Directory(
        path.join(currentDir.path, 'bricks'),
      );
      if (candidateBricksDir.existsSync()) {
        bricksDir = candidateBricksDir;
        break;
      }

      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        break;
      }
      currentDir = parent;
    }

    if (bricksDir == null) {
      throw FileSystemException(
        'Bricks directory not found. Please ensure bricks/ directory exists.',
        rootDir.path,
      );
    }

    final targetBase = Directory(
      path.join(
        bricksDir.path,
        'monorepo',
        '__brick__',
        '{{project_name.snakeCase()}}',
      ),
    );

    logger.info('🚀 Template Monorepo Synchronization');
    logger.info('📍 Root: $rootDir');
    logger.info('📄 Source: template/${config.projectName}/');
    logger.info(
      '🎯 Target: bricks/monorepo/__brick__/{{project_name.snakeCase()}}/',
    );
    logger.info('');

    // 동기화할 디렉토리들
    final directories = [
      'backend',
      'feature',
      'package',
      'shared',
      'scripts',
      '.github',
    ];

    for (final dirName in directories) {
      final sourceDir = Directory(path.join(templateDir.path, dirName));
      final targetDir = Directory(path.join(targetBase.path, dirName));

      if (sourceDir.existsSync()) {
        await syncDirectory(sourceDir, targetDir, dirName, config);
      } else {
        logger.warn('\n⚠️  $dirName not found in source');
      }
    }

    // 개별 파일 동기화
    final files = [
      'analysis_options.yaml',
      'dcm_global.yaml',
      'devtools_options.yaml',
      'Makefile',
      'CONTRIBUTING.md',
      'README.md',
    ];

    for (final fileName in files) {
      final sourceFile = File(path.join(templateDir.path, fileName));
      final targetFile = File(path.join(targetBase.path, fileName));

      if (sourceFile.existsSync()) {
        await syncFile(sourceFile, targetFile, fileName, config);
      }
    }

    // openapi와 openapi_service 브릭 동기화
    await _syncOpenApiBricks(templateDir, bricksDir, config);

    logger.info('\n${'=' * 60}');
    logger.info('🎉 Monorepo brick synced successfully!');
    logger.info('${'=' * 60}');
  }

  /// openapi와 openapi_service 브릭 동기화
  Future<void> _syncOpenApiBricks(
    Directory templateDir,
    Directory bricksDir,
    ProjectConfig config,
  ) async {
    final openApiBricks = ['openapi', 'openapi_service'];

    for (final brickName in openApiBricks) {
      final sourceDir = Directory(path.join(templateDir.path, 'package', brickName));
      final targetBrickDir = Directory(path.join(bricksDir.path, brickName));

      if (!sourceDir.existsSync()) {
        continue;
      }

      if (!targetBrickDir.existsSync()) {
        logger.warn('\n⚠️  Target brick not found: ${targetBrickDir.path}, skipping...');
        continue;
      }

      final targetDir = Directory(path.join(targetBrickDir.path, '__brick__', brickName));

      logger.info('\n📦 Syncing $brickName brick...');

      // 타겟 디렉토리 생성
      targetDir.createSync(recursive: true);

      logger.info('   📋 Updating files from template...');

      // 디렉토리 복사
      await FileUtils.copyDirectory(sourceDir, targetDir, overwrite: true);

      // Android Kotlin 디렉토리 경로 변환
      logger.info('   🔄 Converting Android Kotlin directory paths...');
      await FileUtils.convertAndroidKotlinPaths(targetDir, config.projectNames);

      // 템플릿 변환
      logger.info('   🔄 Converting to template variables...');

      final patterns = TemplateConverter.buildPatterns(config);
      var convertedFiles = 0;

      // 디렉토리 이름 변환
      await _convertDirectoryNames(targetDir, config, 0);

      // 파일 처리
      final stats = await _processFiles(targetDir, config, patterns);
      convertedFiles = stats['converted'] as int;

      logger.info('   ✅ $brickName brick synced:');
      logger.info('      • $convertedFiles files converted');
    }
  }

  /// 디렉토리 동기화
  Future<void> syncDirectory(
    Directory sourceDir,
    Directory targetDir,
    String dirName,
    ProjectConfig config,
  ) async {
    logger.info('\n📁 Syncing $dirName...');

    // package/openapi와 package/openapi_service는 monorepo 브릭에도 포함
    // 별도 브릭으로도 관리되지만, monorepo 브릭에도 동기화 필요

    // 타겟 디렉토리 생성
    targetDir.createSync(recursive: true);

    logger.info('   📋 Updating files from template...');

    // 디렉토리 복사
    await FileUtils.copyDirectory(sourceDir, targetDir, overwrite: true);

    // Android Kotlin 디렉토리 경로 변환
    logger.info('   🔄 Converting Android Kotlin directory paths...');
    await FileUtils.convertAndroidKotlinPaths(targetDir, config.projectNames);

    // 템플릿 변환
    logger.info('   🔄 Converting to template variables...');

    final patterns = TemplateConverter.buildPatterns(config);
    var convertedFiles = 0;
    var renamedDirs = 0;

    // 디렉토리 이름 변환 (하위에서 상위로)
    await _convertDirectoryNames(targetDir, config, renamedDirs);

    // 파일 처리
    final stats = await _processFiles(targetDir, config, patterns);
    convertedFiles = stats['converted'] as int;

    logger.info('   ✅ $dirName synced:');
    logger.info('      • $convertedFiles files converted');
  }

  /// 디렉토리 이름 변환
  Future<void> _convertDirectoryNames(
    Directory dir,
    ProjectConfig config,
    int renamedDirs,
  ) async {
    // 하위 디렉토리부터 처리
    await for (final entity in dir.list(recursive: true)) {
      if (entity is Directory) {
        final dirName = path.basename(entity.path);
        final newDirName = FileUtils.convertDirectoryName(
          dirName,
          config.projectNames,
        );

        if (newDirName != dirName) {
          try {
            final newPath = Directory(
              path.join(path.dirname(entity.path), newDirName),
            );
            await entity.rename(newPath.path);
            renamedDirs++;
          } catch (e) {
            logger.warn('   ⚠️  Could not rename directory $dirName: $e');
          }
        }
      }
    }
  }

  /// 파일 처리
  Future<Map<String, int>> _processFiles(
    Directory dir,
    ProjectConfig config,
    List<ReplacementPattern> patterns,
  ) async {
    var convertedFiles = 0;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final originalFileName = path.basename(entity.path);

        // 이미 조건부 템플릿이 포함된 파일명인지 확인
        final hasConditionalTemplate =
            originalFileName.contains('{{#') &&
            originalFileName.contains('{{/');

        // 조건부 템플릿이 포함된 파일명에서 실제 파일명 추출
        String actualFileName = originalFileName;
        if (hasConditionalTemplate) {
          // {{#has_openapi}}...{{/has_openapi}} 패턴에서 실제 파일명 추출
          final match = RegExp(
            r'\{\{#\w+\}\}(.+?)\{\{/\w+\}\}',
          ).firstMatch(originalFileName);
          if (match != null) {
            actualFileName = match.group(1)!;
          }
        }

        // 파일명 변환
        var newFileName = FileUtils.convertFileName(
          actualFileName,
          config.projectNames,
        );

        // 조건부 템플릿이 필요한 파일명 패턴 처리
        // _openapi_mixin.dart -> {{#has_openapi}}..._openapi_mixin.dart{{/has_openapi}}
        if (newFileName.contains('_openapi_mixin.dart') &&
            !newFileName.contains('{{#has_openapi}}')) {
          newFileName = '{{#has_openapi}}$newFileName{{/has_openapi}}';
        }

        // 파일명이 변경되었거나 조건부 템플릿이 추가된 경우
        if (newFileName != originalFileName) {
          try {
            final newPath = File(
              path.join(path.dirname(entity.path), newFileName),
            );

            // 새 파일명이 이미 존재하면 삭제 (중복 방지)
            if (newPath.existsSync()) {
              await newPath.delete();
            }

            await entity.rename(newPath.path);
          } catch (e) {
            // 파일명 변경 실패 시 무시
            logger.warn('   ⚠️  Could not rename file $originalFileName: $e');
          }
        }

        // 파일 내용 변환
        if (FileUtils.shouldProcessFile(entity)) {
          if (!await FileUtils.isTextFile(entity) ||
              !FileUtils.isFileSizeValid(entity)) {
            continue;
          }

          try {
            var content = await entity.readAsString();

            // mixins.dart 파일의 export 문을 조건부 템플릿으로 변환
            if (path.basename(entity.path) == 'mixins.dart') {
              content = _convertMixinsExports(content);
            }

            final convertedContent = TemplateConverter.convertContent(
              content,
              patterns,
            );

            if (convertedContent != content) {
              await entity.writeAsString(convertedContent);
              convertedFiles++;
            }
          } catch (e) {
            logger.warn('   ⚠️  Error processing ${entity.path}: $e');
          }
        }
      }
    }

    return {'converted': convertedFiles};
  }

  /// mixins.dart 파일의 export 문을 조건부 템플릿으로 변환
  String _convertMixinsExports(String content) {
    var result = content;

    // 이미 조건부 템플릿이 포함되어 있으면 변환하지 않음
    if (result.contains('{{#has_openapi}}') ||
        result.contains('{{#has_serverpod}}') ||
        result.contains('{{#has_graphql}}')) {
      return result;
    }

    // _openapi_mixin.dart export 문을 조건부 템플릿으로 감싸기
    // 작은따옴표와 큰따옴표 모두 지원
    final openapiPatternSingle = RegExp(
      r"^(\s*)export\s+'(.+?_openapi_mixin\.dart)';?\s*$",
      multiLine: true,
    );
    final openapiPatternDouble = RegExp(
      r'^(\s*)export\s+"(.+?_openapi_mixin\.dart)";?\s*$',
      multiLine: true,
    );
    result = result.replaceAllMapped(openapiPatternSingle, (match) {
      final indent = match.group(1) ?? '';
      final filePath = match.group(2) ?? '';
      return '${indent}{{#has_openapi}}\n${indent}export \'$filePath\';\n${indent}{{/has_openapi}}';
    });
    result = result.replaceAllMapped(openapiPatternDouble, (match) {
      final indent = match.group(1) ?? '';
      final filePath = match.group(2) ?? '';
      return '${indent}{{#has_openapi}}\n${indent}export "$filePath";\n${indent}{{/has_openapi}}';
    });

    // _serverpod_mixin.dart export 문을 조건부 템플릿으로 감싸기
    final serverpodPatternSingle = RegExp(
      r"^(\s*)export\s+'(.+?_serverpod_mixin\.dart)';?\s*$",
      multiLine: true,
    );
    final serverpodPatternDouble = RegExp(
      r'^(\s*)export\s+"(.+?_serverpod_mixin\.dart)";?\s*$',
      multiLine: true,
    );
    result = result.replaceAllMapped(serverpodPatternSingle, (match) {
      final indent = match.group(1) ?? '';
      final filePath = match.group(2) ?? '';
      return '${indent}{{#has_serverpod}}\n${indent}export \'$filePath\';\n${indent}{{/has_serverpod}}';
    });
    result = result.replaceAllMapped(serverpodPatternDouble, (match) {
      final indent = match.group(1) ?? '';
      final filePath = match.group(2) ?? '';
      return '${indent}{{#has_serverpod}}\n${indent}export "$filePath";\n${indent}{{/has_serverpod}}';
    });

    // _graphql_mixin.dart export 문을 조건부 템플릿으로 감싸기
    final graphqlPatternSingle = RegExp(
      r"^(\s*)export\s+'(.+?_graphql_mixin\.dart)';?\s*$",
      multiLine: true,
    );
    final graphqlPatternDouble = RegExp(
      r'^(\s*)export\s+"(.+?_graphql_mixin\.dart)";?\s*$',
      multiLine: true,
    );
    result = result.replaceAllMapped(graphqlPatternSingle, (match) {
      final indent = match.group(1) ?? '';
      final filePath = match.group(2) ?? '';
      return '${indent}{{#has_graphql}}\n${indent}export \'$filePath\';\n${indent}{{/has_graphql}}';
    });
    result = result.replaceAllMapped(graphqlPatternDouble, (match) {
      final indent = match.group(1) ?? '';
      final filePath = match.group(2) ?? '';
      return '${indent}{{#has_graphql}}\n${indent}export "$filePath";\n${indent}{{/has_graphql}}';
    });

    return result;
  }

  /// 단일 파일 동기화
  Future<void> syncFile(
    File sourceFile,
    File targetFile,
    String fileName,
    ProjectConfig config,
  ) async {
    logger.info('\n📄 Syncing $fileName...');

    // 파일 복사
    await sourceFile.copy(targetFile.path);

    // 텍스트 파일이면 내용 변환
    if (FileUtils.shouldProcessFile(targetFile)) {
      try {
        final content = await targetFile.readAsString();
        final patterns = TemplateConverter.buildPatterns(config);
        final convertedContent = TemplateConverter.convertContent(
          content,
          patterns,
        );

        if (convertedContent != content) {
          await targetFile.writeAsString(convertedContent);
          logger.info('   ✅ $fileName converted');
        } else {
          logger.info('   ✅ $fileName copied');
        }
      } catch (_) {
        logger.info('   ✅ $fileName copied (binary)');
      }
    }
  }
}
