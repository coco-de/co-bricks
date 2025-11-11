import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:co_bricks/src/services/envrc_service.dart';
import 'package:co_bricks/src/utils/file_utils.dart';
import 'package:co_bricks/src/utils/template_converter.dart';

/// 앱 구조 설정
class AppConfig {
  AppConfig({
    required this.source,
    required this.name,
    required this.appType,
  });

  final Directory source;
  final String name;
  final String appType;
}

/// App 동기화 서비스
class SyncAppService {
  SyncAppService(this.logger);

  final Logger logger;

  /// template 디렉토리에서 사용 가능한 프로젝트 찾기
  static Directory? findTemplateProject(Directory projectDir, String projectName) {
    // 현재 디렉토리에서 상위로 올라가면서 template/ 디렉토리 찾기
    var currentDir = projectDir;
    
    while (true) {
      final templateDir = Directory(path.join(currentDir.path, 'template'));
      if (templateDir.existsSync()) {
        // 특정 프로젝트의 app 디렉토리 찾기
        final appDir = Directory(path.join(templateDir.path, projectName, 'app'));
        if (appDir.existsSync()) {
          return appDir;
        }
      }
      
      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        // 루트 디렉토리에 도달
        break;
      }
      currentDir = parent;
    }

    return null;
  }

  /// 앱 구조 자동 탐색하여 동기화 설정 생성
  static List<AppConfig> detectAppStructure(
    Directory appBase,
    String projectName,
  ) {
    final configs = <AppConfig>[];

    // 메인 앱 (필수)
    final mainApp = Directory(path.join(appBase.path, projectName));
    if (mainApp.existsSync()) {
      configs.add(
        AppConfig(
          source: mainApp,
          name: 'app',
          appType: 'main',
        ),
      );
    }

    // 콘솔 앱 (선택적)
    final consoleApp = Directory(
      path.join(appBase.path, '${projectName}_console'),
    );
    if (consoleApp.existsSync()) {
      configs.add(
        AppConfig(
          source: consoleApp,
          name: 'console',
          appType: 'console',
        ),
      );
    }

    // Widgetbook 앱 (선택적)
    final widgetbookApp = Directory(
      path.join(appBase.path, '${projectName}_widgetbook'),
    );
    if (widgetbookApp.existsSync()) {
      configs.add(
        AppConfig(
          source: widgetbookApp,
          name: 'widgetbook',
          appType: 'widgetbook',
        ),
      );
    }

    return configs;
  }

  /// 단일 brick 동기화
  Future<void> syncBrick(
    Directory sourcePath,
    Directory targetBrickPath,
    String brickName,
    ProjectConfig config,
  ) async {
    logger.info('\n📦 Syncing $brickName brick...');

    final targetBrickDir = Directory(
      path.join(targetBrickPath.path, '__brick__'),
    );

    // 기존 __brick__ 내용 삭제
    if (targetBrickDir.existsSync()) {
      logger.info('   🗑️  Removing old content from ${targetBrickDir.path}');
      await FileUtils.deleteDirectory(targetBrickDir);
    }

    // 새 내용 복사
    targetBrickDir.createSync(recursive: true);

    logger.info('   📋 Copying from ${path.basename(sourcePath.path)}...');
    await FileUtils.copyDirectory(sourcePath, targetBrickDir, overwrite: true);

    // Android Kotlin 디렉토리 경로 변환
    logger.info('   🔄 Converting Android Kotlin directory paths...');
    await FileUtils.convertAndroidKotlinPaths(
      targetBrickDir,
      config.projectNames,
    );

    logger.info(
      '   ✅ Copied to ${path.relative(targetBrickDir.path, from: path.dirname(path.dirname(targetBrickPath.path)))}',
    );

    // 템플릿 변환
    logger.info('   🔄 Converting to template variables...');

    final patterns = TemplateConverter.buildPatterns(config);
    var convertedFiles = 0;
    var renamedFiles = 0;

    // 파일 처리
    final stats = await _processFiles(targetBrickDir, config, patterns);
    convertedFiles = stats['converted'] as int;
    renamedFiles = stats['renamed'] as int;

    logger.info('   ✅ Conversion completed:');
    logger.info('      - $convertedFiles files converted');
    logger.info('      - $renamedFiles files renamed');
  }

  /// 파일 처리 (재귀적으로 디렉토리 순회)
  Future<Map<String, int>> _processFiles(
    Directory dir,
    ProjectConfig config,
    List<ReplacementPattern> patterns,
  ) async {
    var convertedFiles = 0;
    var renamedFiles = 0;
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        // 제외할 디렉토리면 스킵
        if (FileUtils.excludedDirs.contains(
          path.basename(entity.path),
        )) {
          continue;
        }

        // 디렉토리명 변환
        final originalDirName = path.basename(entity.path);
        final newDirName = FileUtils.convertDirectoryName(
          originalDirName,
          config.projectNames,
        );

        if (newDirName != originalDirName) {
          final newPath = Directory(path.join(
            path.dirname(entity.path),
            newDirName,
          ));
          await entity.rename(newPath.path);
          renamedFiles++;
          final subStats = await _processFiles(newPath, config, patterns);
          convertedFiles += subStats['converted'] as int;
          renamedFiles += subStats['renamed'] as int;
        } else {
          final subStats = await _processFiles(entity, config, patterns);
          convertedFiles += subStats['converted'] as int;
          renamedFiles += subStats['renamed'] as int;
        }
      } else if (entity is File) {
        // 파일명 변환
        final originalFileName = path.basename(entity.path);
        final newFileName = FileUtils.convertFileName(
          originalFileName,
          config.projectNames,
        );

        if (newFileName != originalFileName) {
          final newPath = File(path.join(
            path.dirname(entity.path),
            newFileName,
          ));
          await entity.rename(newPath.path);
          renamedFiles++;
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

    return {'converted': convertedFiles, 'renamed': renamedFiles};
  }

  /// App 동기화 실행
  Future<void> sync(ProjectConfig config, Directory? projectDir) async {
    final rootDir = projectDir ?? Directory.current;

    // --project-dir이 지정된 경우 해당 경로의 app 디렉토리 직접 확인
    Directory? appBase;
    if (projectDir != null) {
      final directAppDir = Directory(path.join(projectDir.path, 'app'));
      if (directAppDir.existsSync()) {
        appBase = directAppDir;
      }
    }

    // 지정되지 않았거나 app 디렉토리가 없으면 자동 탐색
    appBase ??= findTemplateProject(rootDir, config.projectName);

    if (appBase == null) {
      final searchPath = projectDir != null
        ? '${projectDir.path}/app/'
        : 'template/${config.projectName}/app/';
      throw FileSystemException(
        'Template project not found. Please ensure $searchPath exists.',
        rootDir.path,
      );
    }

    final projectDirName = projectDir != null
      ? path.basename(projectDir.path)
      : config.projectName;

    logger.info('📄 Project: $projectDirName');
    logger.info('📂 Source: ${path.relative(appBase.path)}');
    logger.info('🎯 Target: bricks/{app,console,widgetbook}/__brick__/');
    logger.info('');

    // 앱 구조 자동 탐색
    logger.info('🔍 Detecting app structure...');
    final syncConfigs = detectAppStructure(appBase, config.projectName);

    if (syncConfigs.isEmpty) {
      throw FileSystemException(
        'No apps found in ${appBase.path}',
        appBase.path,
      );
    }

    logger.info('   Found ${syncConfigs.length} app(s):');
    for (final syncConfig in syncConfigs) {
      logger.info('      • ${syncConfig.name} (${syncConfig.appType})');
    }
    logger.info('');

    // 각 brick 동기화
    // bricks 디렉토리 찾기 (상위로 올라가면서)
    var currentDir = rootDir;
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
    
    var syncedCount = 0;

    for (final syncConfig in syncConfigs) {
      final targetBrick = Directory(path.join(bricksDir.path, syncConfig.name));

      if (!targetBrick.existsSync()) {
        logger.warn(
          '\n⚠️  Target brick not found: ${targetBrick.path}, skipping...',
        );
        continue;
      }

      await syncBrick(
        syncConfig.source,
        targetBrick,
        syncConfig.name,
        config,
      );
      syncedCount++;
    }

    logger.info('\n${'=' * 60}');
    logger.info('🎉 $syncedCount app brick(s) synced successfully!');
    logger.info('${'=' * 60}');

    logger.info('\n📝 Synced Bricks:');
    for (final syncConfig in syncConfigs) {
      final appTypeLabel = {
        'main': 'User app',
        'console': 'Admin console',
        'widgetbook': 'UI showcase',
      }[syncConfig.appType] ?? syncConfig.appType;
      logger.info('  ✓ bricks/${syncConfig.name}/__brick__/ ($appTypeLabel)');
    }
  }
}

