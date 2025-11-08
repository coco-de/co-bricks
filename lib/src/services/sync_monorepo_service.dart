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
      final candidateBricksDir = Directory(path.join(currentDir.path, 'bricks'));
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
    logger.info('🎯 Target: bricks/monorepo/__brick__/{{project_name.snakeCase()}}/');
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

    logger.info('\n${'=' * 60}');
    logger.info('🎉 Monorepo brick synced successfully!');
    logger.info('${'=' * 60}');
  }

  /// 디렉토리 동기화
  Future<void> syncDirectory(
    Directory sourceDir,
    Directory targetDir,
    String dirName,
    ProjectConfig config,
  ) async {
    logger.info('\n📁 Syncing $dirName...');

    // package/openapi와 package/openapi_service는 별도 브릭으로 관리되므로 제외
    if (sourceDir.path.contains('package/openapi') ||
        sourceDir.path.contains('package/openapi_service')) {
      logger.info('   ⏭️  Skipping $dirName (managed by separate bricks)');
      return;
    }

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
            final newPath = Directory(path.join(
              path.dirname(entity.path),
              newDirName,
            ));
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
        // 파일명 변환
        final originalFileName = path.basename(entity.path);
        final newFileName = FileUtils.convertFileName(
          originalFileName,
          config.projectNames,
        );

        if (newFileName != originalFileName) {
          try {
            final newPath = File(path.join(
              path.dirname(entity.path),
              newFileName,
            ));
            await entity.rename(newPath.path);
          } catch (_) {
            // 파일명 변경 실패 시 무시
          }
        }

        // 파일 내용 변환
        if (FileUtils.shouldProcessFile(entity)) {
          if (!await FileUtils.isTextFile(entity) ||
              !FileUtils.isFileSizeValid(entity)) {
            continue;
          }

          try {
            final content = await entity.readAsString();
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

