import 'dart:io';

import 'package:co_bricks/src/services/envrc_service.dart';
import 'package:co_bricks/src/utils/file_utils.dart';
import 'package:co_bricks/src/utils/template_converter.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// Monorepo 동기화 서비스
class SyncMonorepoService {
  SyncMonorepoService(this.logger);

  final Logger logger;

  /// Monorepo 동기화 실행
  Future<void> sync(ProjectConfig config, Directory? projectDir) async {
    final rootDir = projectDir ?? Directory.current;

    // --project-dir이 지정된 경우 해당 경로 직접 사용
    Directory? templateDir;
    if (projectDir != null && projectDir.existsSync()) {
      templateDir = projectDir;
    } else {
      // 지정되지 않았으면 template 디렉토리 찾기 (상위로 올라가면서)
      var currentDir = rootDir;

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
    }

    if (templateDir == null) {
      final searchPath = projectDir != null
          ? projectDir.path
          : 'template/${config.projectName}';
      throw FileSystemException(
        'Template directory not found: $searchPath',
        rootDir.path,
      );
    }

    // bricks 디렉토리 찾기 (상위로 올라가면서)
    var currentDir = rootDir;
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
        '{{project_name.paramCase()}}',
      ),
    );

    final projectDirName = projectDir != null
        ? path.basename(projectDir.path)
        : config.projectName;

    logger.info('🚀 Template Monorepo Synchronization');
    logger.info('📄 Project: $projectDirName');
    logger.info('📂 Source: ${path.relative(templateDir.path)}');
    logger.info(
      '🎯 Target: bricks/monorepo/__brick__/{{project_name.paramCase()}}/',
    );
    logger.info('');

    // 동기화할 디렉토리들 (backend는 serverpod_backend brick으로 별도 관리)
    final directories = [
      'feature',
      'package',
      'shared',
      'scripts',
      '.github',
      '.githooks',
      '.cursor',
      '.vscode',
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

    // backend 디렉토리 제거 (serverpod_backend brick으로 별도 관리)
    final backendDir = Directory(path.join(targetBase.path, 'backend'));
    if (backendDir.existsSync()) {
      logger.info(
        '\n🗑️  Removing backend from monorepo (managed as serverpod_backend brick)...',
      );
      await backendDir.delete(recursive: true);
    }

    // 개별 파일 동기화
    final files = [
      'analysis_options.yaml',
      'dcm_global.yaml',
      'devtools_options.yaml',
      'Makefile',
      'CONTRIBUTING.md',
      'README.md',
      '.cursorrules',
      '.envrc',
      '.fvmrc',
      '.gitignore',
      '.hintrc',
      'CLAUDE.md',
      'melos.yaml',
      'pubspec.yaml',
    ];

    for (final fileName in files) {
      final sourceFile = File(path.join(templateDir.path, fileName));
      final targetFile = File(path.join(targetBase.path, fileName));

      if (sourceFile.existsSync()) {
        await syncFile(sourceFile, targetFile, fileName, config);
      }
    }

    // 네트워크별 브릭 동기화 (openapi, graphql, serverpod)
    await _syncNetworkBricks(templateDir, bricksDir, config);

    // serverpod_backend 브릭 동기화
    await _syncServerpodBackend(templateDir, bricksDir, config);

    logger.info('\n${'=' * 60}');
    logger.info('🎉 Monorepo brick synced successfully!');
    logger.info('${'=' * 60}');
  }

  /// serverpod_backend 브릭 동기화
  Future<void> _syncServerpodBackend(
    Directory templateDir,
    Directory bricksDir,
    ProjectConfig config,
  ) async {
    final sourceBackendDir = Directory(path.join(templateDir.path, 'backend'));

    // backend 디렉토리가 없으면 건너뛰기
    if (!sourceBackendDir.existsSync()) {
      logger.warn(
        '\n⚠️  backend directory not found in template, skipping serverpod_backend sync',
      );
      return;
    }

    final targetBrickDir = Directory(
      path.join(bricksDir.path, 'serverpod_backend'),
    );

    if (!targetBrickDir.existsSync()) {
      logger.warn('\n⚠️  serverpod_backend brick not found, creating...');
      targetBrickDir.createSync(recursive: true);
    }

    final targetDir = Directory(path.join(targetBrickDir.path, '__brick__'));

    logger.info('\n📦 Syncing serverpod_backend brick...');

    // 타겟 디렉토리 생성
    targetDir.createSync(recursive: true);

    logger.info('   📋 Updating files from template...');

    // 기존 프로젝트명 디렉토리들 삭제 (깨끗하게 다시 복사하기 위해)
    for (final projectName in config.projectNames) {
      for (final suffix in ['_client', '_server']) {
        final oldDir = Directory(
          path.join(targetDir.path, '$projectName$suffix'),
        );
        if (oldDir.existsSync()) {
          logger.info('   🗑️  Removing old directory: $projectName$suffix');
          await oldDir.delete(recursive: true);
        }
      }
    }

    // backend 하위 디렉토리들을 개별적으로 템플릿 이름으로 복사
    await for (final entity in sourceBackendDir.list(recursive: false)) {
      if (entity is Directory) {
        final dirName = path.basename(entity.path);

        // 프로젝트명으로 끝나는 디렉토리 변환
        var targetDirName = dirName;
        for (final projectName in config.projectNames) {
          if (dirName == '${projectName}_client') {
            targetDirName = '{{project_name.snakeCase()}}_client';
            break;
          } else if (dirName == '${projectName}_server') {
            targetDirName = '{{project_name.snakeCase()}}_server';
            break;
          }
        }

        final targetSubDir = Directory(
          path.join(targetDir.path, targetDirName),
        );
        logger.info('   📁 Copying $dirName → $targetDirName');

        await FileUtils.copyDirectory(entity, targetSubDir, overwrite: true);
      }
    }

    // Android Kotlin 디렉토리 경로 변환
    logger.info('   🔄 Converting Android Kotlin directory paths...');
    await FileUtils.convertAndroidKotlinPaths(targetDir, config.projectNames);

    // 템플릿 변환
    logger.info('   🔄 Converting to template variables...');

    final patterns = TemplateConverter.buildPatterns(config);
    var convertedFiles = 0;

    // 파일 처리 (디렉토리 이름은 이미 변환됨)
    final stats = await _processFiles(targetDir, config, patterns);
    convertedFiles = stats['converted'] as int;

    logger.info('   ✅ serverpod_backend brick synced:');
    logger.info('      • $convertedFiles files converted');
  }

  /// 네트워크/백엔드별 브릭 동기화 (openapi, graphql, serverpod, supabase, firebase)
  Future<void> _syncNetworkBricks(
    Directory templateDir,
    Directory bricksDir,
    ProjectConfig config,
  ) async {
    // 네트워크/백엔드 타입별 브릭 매핑
    final networkBricks = {
      'openapi': ['openapi', 'openapi_service'],
      'graphql': ['graphql', 'graphql_service'],
      'serverpod': ['serverpod', 'serverpod_service'],
      'supabase': ['supabase', 'supabase_service'],
      'firebase': ['firebase', 'firebase_service'],
    };

    for (final entry in networkBricks.entries) {
      final networkType = entry.key;
      final brickNames = entry.value;

      for (final brickName in brickNames) {
        final sourceDir = Directory(
          path.join(templateDir.path, 'package', brickName),
        );

        // 소스가 없으면 건너뛰기
        if (!sourceDir.existsSync()) {
          continue;
        }

        // 타겟 브릭 디렉토리 (bricks/openapi, bricks/graphql 등)
        final targetBrickDir = Directory(path.join(bricksDir.path, brickName));

        if (!targetBrickDir.existsSync()) {
          logger.warn(
            '\n⚠️  Target brick not found: ${targetBrickDir.path}, creating...',
          );
          targetBrickDir.createSync(recursive: true);
        }

        // 브릭 내부 __brick__ 디렉토리
        final targetDir = Directory(
          path.join(targetBrickDir.path, '__brick__', brickName),
        );

        logger.info('\n📦 Syncing $brickName brick ($networkType)...');

        // 타겟 디렉토리 생성
        targetDir.createSync(recursive: true);

        logger.info('   📋 Updating files from template...');

        // 디렉토리 복사
        await FileUtils.copyDirectory(sourceDir, targetDir, overwrite: true);

        // Android Kotlin 디렉토리 경로 변환
        logger.info('   🔄 Converting Android Kotlin directory paths...');
        await FileUtils.convertAndroidKotlinPaths(
          targetDir,
          config.projectNames,
        );

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
  }

  /// 디렉토리 동기화
  Future<void> syncDirectory(
    Directory sourceDir,
    Directory targetDir,
    String dirName,
    ProjectConfig config,
  ) async {
    logger.info('\n📁 Syncing $dirName...');

    // Mason 조건부 파일들 매핑 수집 ({{#condition}}filename{{/condition}} 패턴)
    final conditionalFileMap = <String, String>{};
    if (targetDir.existsSync()) {
      await for (final entity in targetDir.list(recursive: true)) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          // Mason 조건부 파일명 패턴 감지: {{#condition}}actualname{{/condition}}
          final match = RegExp(
            r'\{\{#(\w+)\}\}(.+?)\{\{/\1\}\}',
          ).firstMatch(fileName);

          if (match != null) {
            final condition = match.group(1)!;
            final actualFileName = match.group(2)!;
            final relativePath = path.relative(
              entity.path,
              from: targetDir.path,
            );
            final relativeDir = path.dirname(relativePath);

            // 조건부 파일명 → 실제 파일명 매핑 저장
            final key = path.join(relativeDir, actualFileName);
            conditionalFileMap[key] = fileName;

            logger.info(
              '   🔍 Found conditional file: $actualFileName → {{#$condition}}...',
            );
          }
        }
      }
    }

    // 타겟 디렉토리 생성
    targetDir.createSync(recursive: true);

    logger.info('   📋 Updating files from template...');

    // 디렉토리 복사
    await FileUtils.copyDirectory(sourceDir, targetDir, overwrite: true);

    // Mason 조건부 파일들 처리: 소스에서 복사된 파일을 조건부 이름으로 변경
    for (final entry in conditionalFileMap.entries) {
      final actualPath = entry.key;
      final conditionalFileName = entry.value;

      // 소스에서 복사된 실제 파일
      final copiedFile = File(path.join(targetDir.path, actualPath));

      if (copiedFile.existsSync()) {
        // 조건부 파일명으로 이동
        final conditionalPath = path.join(
          path.dirname(copiedFile.path),
          conditionalFileName,
        );
        final conditionalFile = File(conditionalPath);

        // 기존 조건부 파일 삭제 후 새 내용으로 교체
        if (conditionalFile.existsSync()) {
          await conditionalFile.delete();
        }

        await copiedFile.rename(conditionalPath);
        logger.info('   ♻️  Updated conditional file: $conditionalFileName');
      } else {
        logger.warn(
          '   ⚠️  Source file not found for conditional: $actualPath',
        );
      }
    }

    // package 디렉토리의 경우, 네트워크/백엔드 브릭들은 별도 브릭으로 관리하므로 monorepo에서 제외
    if (dirName == 'package') {
      final networkBricks = [
        'openapi',
        'openapi_service',
        'graphql',
        'graphql_service',
        'serverpod',
        'serverpod_service',
        'supabase',
        'supabase_service',
        'firebase',
        'firebase_service',
      ];

      for (final brickName in networkBricks) {
        final brickDir = Directory(path.join(targetDir.path, brickName));
        if (brickDir.existsSync()) {
          logger.info(
            '   🗑️  Removing $brickName from monorepo (managed as separate brick)...',
          );
          await brickDir.delete(recursive: true);
        }
      }
    }

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

    // feature 디렉토리의 console을 조건부 디렉토리로 변환
    if (dirName == 'feature') {
      await _convertConsoleToConditionalDir(targetDir);
    }

    // 파일 처리 (네트워크별 mixin 파일들을 조건부 디렉토리로 변환)
    final stats = await _processFiles(targetDir, config, patterns);
    convertedFiles = stats['converted'] as int;

    logger.info('   ✅ $dirName synced:');
    logger.info('      • $convertedFiles files converted');
  }

  /// feature 디렉토리의 console을 조건부 디렉토리로 변환
  ///
  /// Mason의 조건부 디렉토리는 파일 시스템에서 다음과 같이 구성됨:
  /// - {{#enable_admin}}console{{/ 디렉토리 (opening tag + content + {{/)
  /// - 그 안에 enable_admin}} 파일 (closing tag)
  /// 이렇게 하면 Mason이 {{#enable_admin}}console{{/enable_admin}} 형태로 인식함
  Future<void> _convertConsoleToConditionalDir(Directory featureDir) async {
    final consoleDir = Directory(path.join(featureDir.path, 'console'));

    if (!consoleDir.existsSync()) {
      return;
    }

    // Mason 조건부 디렉토리 구조
    // 1단계: {{#enable_admin}}console{{/ 디렉토리
    const outerDirName = r'{{#enable_admin}}console{{';
    final outerDir = Directory(path.join(featureDir.path, outerDirName));

    logger.info('   🔄 Converting console to conditional directory...');

    // 기존 조건부 디렉토리가 있으면 삭제
    if (outerDir.existsSync()) {
      await outerDir.delete(recursive: true);
    }

    // 외부 디렉토리 생성
    outerDir.createSync(recursive: true);

    // 2단계: 내부에 enable_admin}} 디렉토리 생성 (슬래시 없이)
    const innerDirName = 'enable_admin}}';
    final innerDir = Directory(path.join(outerDir.path, innerDirName));
    innerDir.createSync(recursive: true);

    // console 디렉토리의 모든 내용을 innerDir로 복사
    await for (final entity in consoleDir.list(recursive: false)) {
      final entityName = path.basename(entity.path);
      final targetPath = path.join(innerDir.path, entityName);

      if (entity is Directory) {
        await FileUtils.copyDirectory(
          entity,
          Directory(targetPath),
          overwrite: true,
        );
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }

    // 원본 console 디렉토리 삭제
    await consoleDir.delete(recursive: true);

    logger.info(
      '   ✅ Converted console → {{#enable_admin}}console{{/enable_admin}}',
    );
  }

  /// 디렉토리 이름 변환
  Future<void> _convertDirectoryNames(
    Directory dir,
    ProjectConfig config,
    int renamedDirs,
  ) async {
    // 먼저 모든 디렉토리를 깊이별로 수집 (깊은 것부터 처리하기 위해)
    final directoriesByDepth = <int, List<Directory>>{};

    await for (final entity in dir.list(recursive: true)) {
      if (entity is Directory) {
        final depth = entity.path.split(path.separator).length;
        directoriesByDepth.putIfAbsent(depth, () => []).add(entity);
      }
    }

    // 깊이가 깊은 순서대로 정렬 (하위 디렉토리부터 처리)
    final sortedDepths = directoriesByDepth.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // 깊은 디렉토리부터 이름 변환
    for (final depth in sortedDepths) {
      for (final directory in directoriesByDepth[depth]!) {
        // 디렉토리가 아직 존재하는지 확인 (상위 디렉토리 변환으로 경로가 바뀔 수 있음)
        if (!directory.existsSync()) {
          continue;
        }

        final dirName = path.basename(directory.path);
        final newDirName = FileUtils.convertDirectoryName(
          dirName,
          config.projectNames,
        );

        if (newDirName != dirName) {
          try {
            final newPath = Directory(
              path.join(path.dirname(directory.path), newDirName),
            );
            await directory.rename(newPath.path);
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

        // 네트워크별 mixin 파일명을 조건부 템플릿으로 변환
        // {{#has_openapi}}community_openapi_mixin.dart{{ 디렉토리를 만들고 그 안에 has_openapi}} 파일 생성
        String? conditionalDir;
        String finalFileName = newFileName;

        if (newFileName.endsWith('_openapi_mixin.dart') &&
            !newFileName.contains('{{#has_openapi}}')) {
          conditionalDir = '{{#has_openapi}}$newFileName{{';
          finalFileName = 'has_openapi}}';
        } else if (newFileName.endsWith('_serverpod_mixin.dart') &&
            !newFileName.contains('{{#has_serverpod}}')) {
          conditionalDir = '{{#has_serverpod}}$newFileName{{';
          finalFileName = 'has_serverpod}}';
        } else if (newFileName.endsWith('_graphql_mixin.dart') &&
            !newFileName.contains('{{#has_graphql}}')) {
          conditionalDir = '{{#has_graphql}}$newFileName{{';
          finalFileName = 'has_graphql}}';
        } else if (newFileName.endsWith('_supabase_mixin.dart') &&
            !newFileName.contains('{{#has_supabase}}')) {
          conditionalDir = '{{#has_supabase}}$newFileName{{';
          finalFileName = 'has_supabase}}';
        } else if (newFileName.endsWith('_firebase_mixin.dart') &&
            !newFileName.contains('{{#has_firebase}}')) {
          conditionalDir = '{{#has_firebase}}$newFileName{{';
          finalFileName = 'has_firebase}}';
        } else if (newFileName == 'console_service_locator.dart' &&
            !newFileName.contains('{{#enable_admin}}')) {
          conditionalDir = '{{#enable_admin}}$newFileName{{';
          finalFileName = 'enable_admin}}';
        }

        // conditionalDir에 실제 파일명이 들어가도록 문자열 보간 적용
        if (conditionalDir != null) {
          conditionalDir = conditionalDir.replaceAll(
            '\$newFileName',
            newFileName,
          );
        }

        // 파일 내용 변환 (파일 이동 전에 수행)
        File? targetFile;
        String? convertedContent;

        if (FileUtils.shouldProcessFile(entity)) {
          if (await FileUtils.isTextFile(entity) &&
              await FileUtils.isFileSizeValid(entity)) {
            try {
              final originalContent = await entity.readAsString();
              var content = originalContent;
              final basename = path.basename(entity.path);

              // mixins.dart 파일의 export 문을 조건부 템플릿으로 변환
              if (basename == 'mixins.dart') {
                content = _convertMixinsExports(content);
              }

              // dependencies.dart 파일의 openapi_service export 문을 조건부 템플릿으로 변환
              if (basename == 'dependencies.dart') {
                content = _convertDependenciesExports(content);
              }

              // pubspec.yaml 파일의 openapi_service 의존성을 조건부 템플릿으로 변환
              if (basename == 'pubspec.yaml') {
                content = _convertPubspecDependencies(content, entity.path);
              }

              // Repository 파일의 mixin/서비스 사용 패턴을 조건부 템플릿으로 변환
              // 생성자 변환을 먼저 실행해야 개별 파라미터 변환과 충돌하지 않음
              if (basename.endsWith('_repository.dart')) {
                content = _convertRepositoryPatterns(content);
              }

              convertedContent = TemplateConverter.convertContent(
                content,
                patterns,
              );
            } catch (e) {
              logger.warn('   ⚠️  Error converting file ${entity.path}: $e');
            }
          }
        }

        // 파일명이 변경되었거나 조건부 디렉토리가 필요한 경우
        if (conditionalDir != null || newFileName != originalFileName) {
          try {
            final baseDir = path.dirname(entity.path);
            final targetPath = conditionalDir != null
                ? path.join(baseDir, conditionalDir, finalFileName)
                : path.join(baseDir, finalFileName);

            targetFile = File(targetPath);

            // 조건부 템플릿 디렉토리 생성
            if (conditionalDir != null) {
              final conditionalDirPath = Directory(
                path.join(baseDir, conditionalDir),
              );
              if (!conditionalDirPath.existsSync()) {
                await conditionalDirPath.create(recursive: true);
              }
            }

            // 일반 디렉토리도 생성 (필요한 경우)
            final targetDir = Directory(path.dirname(targetPath));
            if (!targetDir.existsSync()) {
              await targetDir.create(recursive: true);
            }

            // 변환된 내용이 있으면 새 파일에 저장, 없으면 원본 파일 복사
            if (convertedContent != null) {
              if (targetFile.existsSync()) {
                await targetFile.delete();
              }
              await targetFile.writeAsString(convertedContent);
              await entity.delete();
              convertedFiles++;
            } else {
              // 파일 복사 후 원본 삭제
              if (targetFile.existsSync()) {
                await targetFile.delete();
              }
              await entity.copy(targetFile.path);
              await entity.delete();
            }
          } catch (e) {
            // 파일명 변경 실패 시 무시
            logger.warn('   ⚠️  Could not rename file $originalFileName: $e');
          }
        } else if (convertedContent != null) {
          // 파일명은 변경되지 않았지만 내용이 변환된 경우
          try {
            final originalContent = await entity.readAsString();
            if (convertedContent != originalContent) {
              await entity.writeAsString(convertedContent);
              convertedFiles++;
            }
          } catch (e) {
            logger.warn(
              '   ⚠️  Error writing converted content to ${entity.path}: $e',
            );
          }
        }
      }
    }

    return {'converted': convertedFiles};
  }

  /// mixins.dart 파일의 export 문을 조건부 템플릿으로 변환
  /// Repository와 동일하게 모든 네트워크/백엔드 타입의 export를 생성
  String _convertMixinsExports(String content) {
    // 이미 조건부 템플릿이 포함되어 있으면 변환하지 않음
    if (content.contains('{{#has_openapi}}') ||
        content.contains('{{#has_serverpod}}') ||
        content.contains('{{#has_graphql}}') ||
        content.contains('{{#has_supabase}}') ||
        content.contains('{{#has_firebase}}')) {
      return content;
    }

    // export 문에서 feature/module 이름 추출
    // 예: export 'community_openapi_mixin.dart'; -> community
    final exportPattern = RegExp(
      r'''export\s+['"](\w+)_(openapi|serverpod|graphql|supabase|firebase)_mixin\.dart['"];?''',
      multiLine: true,
    );
    final match = exportPattern.firstMatch(content);

    if (match == null) {
      // export가 없으면 원본 반환
      return content;
    }

    final prefix = match.group(1) ?? '';

    // 모든 네트워크/백엔드 타입의 export를 생성
    final buffer = StringBuffer();

    buffer.writeln('{{#has_openapi}}');
    buffer.writeln("export '${prefix}_openapi_mixin.dart';");
    buffer.writeln('{{/has_openapi}}');

    buffer.writeln('{{#has_serverpod}}');
    buffer.writeln("export '${prefix}_serverpod_mixin.dart';");
    buffer.writeln('{{/has_serverpod}}');

    buffer.writeln('{{#has_graphql}}');
    buffer.writeln("export '${prefix}_graphql_mixin.dart';");
    buffer.writeln('{{/has_graphql}}');

    buffer.writeln('{{#has_supabase}}');
    buffer.writeln("export '${prefix}_supabase_mixin.dart';");
    buffer.writeln('{{/has_supabase}}');

    buffer.writeln('{{#has_firebase}}');
    buffer.writeln("export '${prefix}_firebase_mixin.dart';");
    buffer.write('{{/has_firebase}}');

    return buffer.toString();
  }

  /// dependencies.dart 파일의 네트워크/백엔드 서비스 export 문을 조건부 템플릿으로 변환
  String _convertDependenciesExports(String content) {
    // 이미 조건부 템플릿이 포함되어 있으면 변환하지 않음
    if (content.contains('{{#has_openapi}}') ||
        content.contains('{{#has_serverpod}}') ||
        content.contains('{{#has_graphql}}') ||
        content.contains('{{#has_supabase}}') ||
        content.contains('{{#has_firebase}}')) {
      return content;
    }

    var result = content;

    // 각 서비스별 export 문을 조건부로 변환
    final servicePatterns = {
      'openapi_service': 'has_openapi',
      'serverpod_service': 'has_serverpod',
      'graphql_service': 'has_graphql',
      'supabase_service': 'has_supabase',
      'firebase_service': 'has_firebase',
    };

    for (final entry in servicePatterns.entries) {
      final serviceName = entry.key;
      final conditionalFlag = entry.value;

      final pattern = RegExp(
        '''export\\s+['"]package:$serviceName/$serviceName\\.dart['"](?:\\s+hide\\s+\\w+(?:\\s*,\\s*\\w+)*)?;''',
        multiLine: true,
      );

      result = result.replaceAllMapped(pattern, (match) {
        final exportStatement = match.group(0)!;
        return '{{#$conditionalFlag}}$exportStatement{{/$conditionalFlag}}';
      });
    }

    return result;
  }

  /// pubspec.yaml 파일의 네트워크/백엔드 서비스 의존성을 조건부 템플릿으로 변환
  ///
  /// - shared/dependencies/pubspec.yaml: 조건부 템플릿으로 변환
  /// - feature/*/pubspec.yaml: 서비스 의존성 제거 (dependencies 패키지에서 export되므로)
  String _convertPubspecDependencies(String content, String filePath) {
    // 이미 조건부 템플릿이 포함되어 있으면 변환하지 않음
    if (content.contains('{{#has_openapi}}') ||
        content.contains('{{#has_serverpod}}') ||
        content.contains('{{#has_graphql}}') ||
        content.contains('{{#has_supabase}}') ||
        content.contains('{{#has_firebase}}')) {
      return content;
    }

    var result = content;

    // 각 서비스별 의존성
    final servicePatterns = {
      'openapi_service': 'has_openapi',
      'serverpod_service': 'has_serverpod',
      'graphql_service': 'has_graphql',
      'supabase_service': 'has_supabase',
      'firebase_service': 'has_firebase',
    };

    // shared/dependencies/pubspec.yaml인지 확인
    final isDependenciesPubspec =
        filePath.contains('shared/dependencies/pubspec.yaml') ||
        filePath.contains(
          'shared${path.separator}dependencies${path.separator}pubspec.yaml',
        );

    for (final entry in servicePatterns.entries) {
      final serviceName = entry.key;
      final conditionalFlag = entry.value;

      // 패턴: "  service_name: ^0.1.0" (앞에 공백, 줄 끝까지)
      final pattern = RegExp(
        '^(\\s+)$serviceName:\\s*\\^[\\d.]+\\s*\$',
        multiLine: true,
      );

      if (isDependenciesPubspec) {
        // shared/dependencies/pubspec.yaml: 조건부 템플릿으로 변환
        result = result.replaceAllMapped(pattern, (match) {
          final indent = match.group(1)!;
          final dependencyLine = match.group(0)!.trim();
          return '$indent{{#$conditionalFlag}}$dependencyLine{{/$conditionalFlag}}';
        });
      } else {
        // feature/*/pubspec.yaml: 서비스 의존성 라인 완전히 제거
        result = result.replaceAll(pattern, '');
      }
    }

    return result;
  }

  /// Repository 파일의 mixin/서비스 사용 패턴을 조건부 템플릿으로 변환
  String _convertRepositoryPatterns(String content) {
    var result = content;

    // 이미 조건부 템플릿이 포함되어 있으면 변환하지 않음
    if (result.contains('{{#has_openapi}}') ||
        result.contains('{{#has_serverpod}}') ||
        result.contains('{{#has_graphql}}') ||
        result.contains('{{#has_supabase}}') ||
        result.contains('{{#has_firebase}}')) {
      return result;
    }

    // 먼저 전체 Repository 클래스를 재구성 시도
    final convertedClass = _convertRepositoryClass(result);

    // 변환이 성공했으면 (새로운 템플릿 태그가 포함되어 있으면) 반환
    if (convertedClass.contains('{{#has_openapi}}') ||
        convertedClass.contains('{{#has_serverpod}}') ||
        convertedClass.contains('{{#has_graphql}}') ||
        convertedClass.contains('{{#has_supabase}}') ||
        convertedClass.contains('{{#has_firebase}}')) {
      return convertedClass;
    }

    // 실패했으면 기존 패턴별 변환 방식 사용
    result = _convertRepositoryPatternsLegacy(result);

    return result;
  }

  /// Repository 클래스 전체를 조건부 템플릿으로 변환
  String _convertRepositoryClass(String content) {
    // Repository 파일이 아니면 원본 반환
    if (!content.contains('Repository')) {
      return content;
    }

    final lines = content.split('\n');
    final result = <String>[];
    var i = 0;

    // Import 문들 복사
    while (i < lines.length &&
        (lines[i].startsWith('import') || lines[i].trim().isEmpty)) {
      result.add(lines[i]);
      i++;
    }

    // 문서 주석 복사 (/// 로 시작하는 처음 세 줄)
    final docCommentLines = <String>[];
    while (i < lines.length && lines[i].trim().startsWith('///')) {
      docCommentLines.add(lines[i]);
      i++;
    }
    result.addAll(docCommentLines);

    // 빈 줄 건너뛰기
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }

    // 네트워크 주석 건너뛰기 (/// REST API 또는 /// Serverpod 또는 /// GraphQL 등)
    if (i < lines.length && lines[i].trim().startsWith('///')) {
      i++; // 네트워크 주석 건너뛰기
    }

    // 빈 줄들 건너뛰기
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }

    // 클래스 정보 추출
    String? className;
    String? mixinPrefix;
    String? databaseField;
    String? databaseType;
    final daoGetters =
        <
          Map<String, String>
        >[]; // {getterName: 'postDao', daoType: 'PostDao', sourcePath: '_database.postDao'}

    // 나머지 파일을 스캔해서 정보 수집
    for (var j = i; j < lines.length; j++) {
      final line = lines[j];

      // 클래스 이름
      if (line.contains('class') && line.contains('Repository')) {
        final match = RegExp(r'class\s+(\w+Repository)').firstMatch(line);
        className = match?.group(1);
      }

      // Mixin 이름
      if (line.contains('with') && line.contains('Mixin')) {
        final match = RegExp(
          r'with\s+(\w+)(Openapi|Serverpod|Graphql|Supabase|Firebase)Mixin',
        ).firstMatch(line);
        mixinPrefix = match?.group(1);
      }

      // Database 필드 (예: final CommunityDatabase _database;)
      if (line.contains('final') &&
          line.contains('Database') &&
          line.contains('_database')) {
        final match = RegExp(
          r'final\s+(\w+Database)\s+(_database);',
        ).firstMatch(line);
        if (match != null) {
          databaseType = match.group(1);
          databaseField = match.group(2);
        }
      }

      // DAO getter (예: PostDao get postDao => _database.postDao;)
      if (line.contains('get') && line.contains('Dao') && line.contains('=>')) {
        final match = RegExp(
          r'(\w+Dao)\s+get\s+(\w+)\s+=>\s+_database\.(\w+);',
        ).firstMatch(line);
        if (match != null) {
          final daoType = match.group(1)!;
          final getterName = match.group(2)!;
          final sourcePath = match.group(3)!;

          // 중복 체크
          if (!daoGetters.any((dao) => dao['getterName'] == getterName)) {
            daoGetters.add({
              'getterName': getterName,
              'daoType': daoType,
              'sourcePath': sourcePath,
            });
          }
        }
      }
    }

    if (className == null || mixinPrefix == null) {
      // 정보를 추출하지 못하면 원본 반환
      return content;
    }

    // 네트워크/백엔드별 주석 추가
    result.add('');
    result.add(
      '{{#has_serverpod}}/// Serverpod Client를 통해 실제 백엔드 API와 통신{{/has_serverpod}}',
    );
    result.add('{{#has_openapi}}/// REST API를 통해 실제 백엔드와 통신{{/has_openapi}}');
    result.add('{{#has_graphql}}/// GraphQL을 통해 실제 백엔드와 통신{{/has_graphql}}');
    result.add('{{#has_supabase}}/// Supabase를 통해 실제 백엔드와 통신{{/has_supabase}}');
    result.add('{{#has_firebase}}/// Firebase를 통해 실제 백엔드와 통신{{/has_firebase}}');
    result.add(
      '{{^has_serverpod}}{{^has_openapi}}{{^has_graphql}}{{^has_supabase}}{{^has_firebase}}/// 메모리에서 데이터를 생성하고 관리{{/has_firebase}}{{/has_supabase}}{{/has_graphql}}{{/has_openapi}}{{/has_serverpod}}',
    );
    result.add('');

    // 템플릿 생성
    final template = _generateRepositoryTemplate(
      docComment: '', // 이미 추가됨
      className: className,
      mixinPrefix: mixinPrefix,
      databaseField: databaseField,
      databaseType: databaseType,
      daoGetters: daoGetters,
    );

    // @LazySingleton부터의 템플릿 추가
    final templateLines = template.split('\n');
    // docComment와 네트워크 주석을 건너뛰고 @LazySingleton부터 추가
    var skipLines = true;
    for (final line in templateLines) {
      if (line.contains('@LazySingleton')) {
        skipLines = false;
      }
      if (!skipLines) {
        result.add(line);
      }
    }

    return result.join('\n');
  }

  /// Repository 템플릿 생성
  String _generateRepositoryTemplate({
    required String docComment,
    required String className,
    required String mixinPrefix,
    String? databaseField,
    String? databaseType,
    required List<Map<String, String>> daoGetters,
  }) {
    final buffer = StringBuffer();
    final hasDatabase =
        databaseField != null && databaseType != null && daoGetters.isNotEmpty;

    // 문서 주석
    buffer.writeln(docComment.trimRight());

    // 네트워크/백엔드별 주석
    buffer.writeln(
      '{{#has_serverpod}}/// Serverpod Client를 통해 실제 백엔드 API와 통신{{/has_serverpod}}',
    );
    buffer.writeln(
      '{{#has_openapi}}/// REST API를 통해 실제 백엔드와 통신{{/has_openapi}}',
    );
    buffer.writeln(
      '{{#has_graphql}}/// GraphQL을 통해 실제 백엔드와 통신{{/has_graphql}}',
    );
    buffer.writeln(
      '{{#has_supabase}}/// Supabase를 통해 실제 백엔드와 통신{{/has_supabase}}',
    );
    buffer.writeln(
      '{{#has_firebase}}/// Firebase를 통해 실제 백엔드와 통신{{/has_firebase}}',
    );
    buffer.writeln(
      '{{^has_serverpod}}{{^has_openapi}}{{^has_graphql}}{{^has_supabase}}{{^has_firebase}}/// 메모리에서 데이터를 생성하고 관리{{/has_firebase}}{{/has_supabase}}{{/has_graphql}}{{/has_openapi}}{{/has_serverpod}}',
    );
    buffer.writeln();

    final interfaceName = 'I$className';
    buffer.writeln('@LazySingleton(as: $interfaceName)');
    buffer.writeln('class $className ');
    buffer.writeln(
      '    {{#has_serverpod}}with ${mixinPrefix}ServerpodMixin{{/has_serverpod}}',
    );
    buffer.writeln(
      '    {{#has_openapi}}with ${mixinPrefix}OpenapiMixin{{/has_openapi}}',
    );
    buffer.writeln(
      '    {{#has_graphql}}with ${mixinPrefix}GraphqlMixin{{/has_graphql}}',
    );
    buffer.writeln(
      '    {{#has_supabase}}with ${mixinPrefix}SupabaseMixin{{/has_supabase}}',
    );
    buffer.writeln(
      '    {{#has_firebase}}with ${mixinPrefix}FirebaseMixin{{/has_firebase}}',
    );
    buffer.writeln('    implements $interfaceName {');

    // Serverpod 블록
    buffer.writeln('  {{#has_serverpod}}');
    buffer.writeln('  /// ${mixinPrefix} Repository 생성자');
    if (hasDatabase) {
      buffer.writeln('  $className(');
      buffer.writeln('    this._podService,');
      buffer.writeln('    this.$databaseField,');
      buffer.writeln('  );');
      buffer.writeln('  final ServerpodService _podService;');
      buffer.writeln('  final $databaseType $databaseField;');
    } else {
      buffer.writeln('  $className();');
      buffer.writeln('  final ServerpodService _podService;');
    }
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  ServerpodClient get client => _podService.client;');
    buffer.writeln();
    for (final dao in daoGetters) {
      buffer.writeln('  @override');
      buffer.writeln(
        '  ${dao['daoType']} get ${dao['getterName']} => $databaseField.${dao['sourcePath']};',
      );
      buffer.writeln();
    }
    buffer.writeln('  {{/has_serverpod}}');

    // OpenAPI 블록
    buffer.writeln('  {{#has_openapi}}');
    buffer.writeln('  /// ${mixinPrefix} Repository 생성자');
    if (hasDatabase) {
      buffer.writeln('  $className(');
      buffer.writeln('    this._openApiService,');
      buffer.writeln('    this.$databaseField,');
      buffer.writeln('  );');
      buffer.writeln('  final OpenApiService _openApiService;');
      buffer.writeln('  final $databaseType $databaseField;');
    } else {
      buffer.writeln('  $className(');
      buffer.writeln('    this._openApiService,');
      buffer.writeln('  );');
      buffer.writeln('  final OpenApiService _openApiService;');
    }
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  OpenApiService get openApiService => _openApiService;');
    buffer.writeln();
    for (final dao in daoGetters) {
      buffer.writeln('  @override');
      buffer.writeln(
        '  ${dao['daoType']} get ${dao['getterName']} => $databaseField.${dao['sourcePath']};',
      );
      buffer.writeln();
    }
    buffer.writeln('  {{/has_openapi}}');

    // GraphQL 블록
    buffer.writeln('  {{#has_graphql}}');
    buffer.writeln('  /// ${mixinPrefix} Repository 생성자');
    if (hasDatabase) {
      buffer.writeln('  $className(');
      buffer.writeln('    this._graphQLClient,');
      buffer.writeln('    this.$databaseField,');
      buffer.writeln('  );');
      buffer.writeln('  final GraphQLClient _graphQLClient;');
      buffer.writeln('  final $databaseType $databaseField;');
    } else {
      buffer.writeln('  $className(this._graphQLClient);');
      buffer.writeln('  final GraphQLClient _graphQLClient;');
    }
    buffer.writeln('  ');
    buffer.writeln('  @override');
    buffer.writeln('  GraphQLClient get graphQLClient => _graphQLClient;');
    for (final dao in daoGetters) {
      buffer.writeln();
      buffer.writeln('  @override');
      buffer.writeln(
        '  ${dao['daoType']} get ${dao['getterName']} => $databaseField.${dao['sourcePath']};',
      );
    }
    buffer.writeln('  {{/has_graphql}}');

    // Supabase 블록
    buffer.writeln('  {{#has_supabase}}');
    buffer.writeln('  /// ${mixinPrefix} Repository 생성자');
    if (hasDatabase) {
      buffer.writeln('  $className(');
      buffer.writeln('    this._supabaseClient,');
      buffer.writeln('    this.$databaseField,');
      buffer.writeln('  );');
      buffer.writeln('  final SupabaseClient _supabaseClient;');
      buffer.writeln('  final $databaseType $databaseField;');
    } else {
      buffer.writeln('  $className(this._supabaseClient);');
      buffer.writeln('  final SupabaseClient _supabaseClient;');
    }
    buffer.writeln('  ');
    buffer.writeln('  @override');
    buffer.writeln('  SupabaseClient get supabaseClient => _supabaseClient;');
    for (final dao in daoGetters) {
      buffer.writeln();
      buffer.writeln('  @override');
      buffer.writeln(
        '  ${dao['daoType']} get ${dao['getterName']} => $databaseField.${dao['sourcePath']};',
      );
    }
    buffer.writeln('  {{/has_supabase}}');

    // Firebase 블록
    buffer.writeln('  {{#has_firebase}}');
    buffer.writeln('  /// ${mixinPrefix} Repository 생성자');
    if (hasDatabase) {
      buffer.writeln('  $className(');
      buffer.writeln('    this._firebaseService,');
      buffer.writeln('    this.$databaseField,');
      buffer.writeln('  );');
      buffer.writeln('  final FirebaseService _firebaseService;');
      buffer.writeln('  final $databaseType $databaseField;');
    } else {
      buffer.writeln('  $className(this._firebaseService);');
      buffer.writeln('  final FirebaseService _firebaseService;');
    }
    buffer.writeln('  ');
    buffer.writeln('  @override');
    buffer.writeln(
      '  FirebaseService get firebaseService => _firebaseService;',
    );
    for (final dao in daoGetters) {
      buffer.writeln();
      buffer.writeln('  @override');
      buffer.writeln(
        '  ${dao['daoType']} get ${dao['getterName']} => $databaseField.${dao['sourcePath']};',
      );
    }
    buffer.writeln('  {{/has_firebase}}');

    // Fallback (no network) 블록
    buffer.writeln(
      '  {{^has_serverpod}}{{^has_openapi}}{{^has_graphql}}{{^has_supabase}}{{^has_firebase}}',
    );
    buffer.writeln('  /// ${mixinPrefix} Repository 생성자');
    buffer.writeln('  $className();');
    buffer.writeln(
      '  {{/has_firebase}}{{/has_supabase}}{{/has_graphql}}{{/has_openapi}}{{/has_serverpod}}',
    );
    buffer.write('}');

    return buffer.toString();
  }

  /// 기존 패턴별 변환 로직 (fallback)
  String _convertRepositoryPatternsLegacy(String content) {
    var result = content;

    // OpenAPI 패턴 변환
    // with HomeOpenapiMixin
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)with\s+(\w+OpenapiMixin)\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        final mixinName = match.group(2) ?? '';
        return '${indent}{{#has_openapi}}with $mixinName{{/has_openapi}}';
      },
    );

    // final OpenApiService _openApiService;
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)final\s+OpenApiService\s+(\w+);\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        final varName = match.group(2) ?? '';
        return '${indent}{{#has_openapi}}final OpenApiService $varName;{{/has_openapi}}';
      },
    );

    // OpenApiService get openApiService => _openApiService;
    result = result.replaceAllMapped(
      RegExp(
        r'^(\s*)OpenApiService\s+get\s+(\w+)\s*=>\s*(\w+);\s*$',
        multiLine: true,
      ),
      (match) {
        final indent = match.group(1) ?? '';
        final getterName = match.group(2) ?? '';
        final varName = match.group(3) ?? '';
        return '${indent}{{#has_openapi}}OpenApiService get $getterName => $varName;{{/has_openapi}}';
      },
    );

    // Serverpod 패턴 변환
    // with HomeServerpodMixin
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)with\s+(\w+ServerpodMixin)\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        final mixinName = match.group(2) ?? '';
        return '${indent}{{#has_serverpod}}with $mixinName{{/has_serverpod}}';
      },
    );

    // final pod.PodService _podService;
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)final\s+pod\.PodService\s+(\w+);\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        final varName = match.group(2) ?? '';
        return '${indent}{{#has_serverpod}}final pod.PodService $varName;{{/has_serverpod}}';
      },
    );

    // pod.Client get client => _podService.client;
    result = result.replaceAllMapped(
      RegExp(
        r'^(\s*)pod\.Client\s+get\s+(\w+)\s*=>\s*(\w+\.\w+);\s*$',
        multiLine: true,
      ),
      (match) {
        final indent = match.group(1) ?? '';
        final getterName = match.group(2) ?? '';
        final expression = match.group(3) ?? '';
        return '${indent}{{#has_serverpod}}pod.Client get $getterName => $expression;{{/has_serverpod}}';
      },
    );

    // GraphQL 패턴 변환
    // with HomeGraphqlMixin
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)with\s+(\w+GraphqlMixin)\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        final mixinName = match.group(2) ?? '';
        return '${indent}{{#has_graphql}}with $mixinName{{/has_graphql}}';
      },
    );

    // final GraphQLClient _graphQLClient;
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)final\s+GraphQLClient\s+(\w+);\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        final varName = match.group(2) ?? '';
        return '${indent}{{#has_graphql}}final GraphQLClient $varName;{{/has_graphql}}';
      },
    );

    // GraphQLClient get graphQLClient => _graphQLClient;
    result = result.replaceAllMapped(
      RegExp(
        r'^(\s*)GraphQLClient\s+get\s+(\w+)\s*=>\s*(\w+);\s*$',
        multiLine: true,
      ),
      (match) {
        final indent = match.group(1) ?? '';
        final getterName = match.group(2) ?? '';
        final varName = match.group(3) ?? '';
        return '${indent}{{#has_graphql}}GraphQLClient get $getterName => $varName;{{/has_graphql}}';
      },
    );

    // 주석 변환
    // /// REST API를 통해 실제 백엔드와 통신
    result = result.replaceAllMapped(
      RegExp(
        r'^(\s*)///\s*REST\s+API를\s+통해\s+실제\s+백엔드와\s+통신\s*$',
        multiLine: true,
      ),
      (match) {
        final indent = match.group(1) ?? '';
        return '${indent}{{#has_openapi}}/// REST API를 통해 실제 백엔드와 통신{{/has_openapi}}';
      },
    );

    // /// Serverpod Client를 통해 실제 백엔드 API와 통신
    result = result.replaceAllMapped(
      RegExp(
        r'^(\s*)///\s*Serverpod\s+Client를\s+통해\s+실제\s+백엔드\s+API와\s+통신\s*$',
        multiLine: true,
      ),
      (match) {
        final indent = match.group(1) ?? '';
        return '${indent}{{#has_serverpod}}/// Serverpod Client를 통해 실제 백엔드 API와 통신{{/has_serverpod}}';
      },
    );

    // /// GraphQL을 통해 실제 백엔드와 통신
    result = result.replaceAllMapped(
      RegExp(
        r'^(\s*)///\s*GraphQL을\s+통해\s+실제\s+백엔드와\s+통신\s*$',
        multiLine: true,
      ),
      (match) {
        final indent = match.group(1) ?? '';
        return '${indent}{{#has_graphql}}/// GraphQL을 통해 실제 백엔드와 통신{{/has_graphql}}';
      },
    );

    // /// Supabase를 통해 실제 백엔드와 통신
    result = result.replaceAllMapped(
      RegExp(
        r'^(\s*)///\s*Supabase를\s+통해\s+실제\s+백엔드와\s+통신\s*$',
        multiLine: true,
      ),
      (match) {
        final indent = match.group(1) ?? '';
        return '${indent}{{#has_supabase}}/// Supabase를 통해 실제 백엔드와 통신{{/has_supabase}}';
      },
    );

    // /// Firebase를 통해 실제 백엔드와 통신
    result = result.replaceAllMapped(
      RegExp(
        r'^(\s*)///\s*Firebase를\s+통해\s+실제\s+백엔드와\s+통신\s*$',
        multiLine: true,
      ),
      (match) {
        final indent = match.group(1) ?? '';
        return '${indent}{{#has_firebase}}/// Firebase를 통해 실제 백엔드와 통신{{/has_firebase}}';
      },
    );

    // /// 메모리에서 데이터를 생성하고 관리
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)///\s*메모리에서\s+데이터를\s+생성하고\s+관리\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        return '${indent}{{^has_serverpod}}{{^has_openapi}}{{^has_graphql}}{{^has_supabase}}{{^has_firebase}}/// 메모리에서 데이터를 생성하고 관리{{/has_firebase}}{{/has_supabase}}{{/has_graphql}}{{/has_openapi}}{{/has_serverpod}}';
      },
    );

    // 생성자 변환을 먼저 실행 (개별 파라미터 변환과 충돌 방지)
    // 생성자 주석도 함께 변환됨
    result = _convertRepositoryConstructor(result);

    return result;
  }

  /// Repository 생성자를 조건부 템플릿으로 변환
  String _convertRepositoryConstructor(String content) {
    var result = content;

    // 생성자 패턴 찾기 (여러 줄에 걸친 생성자)
    // CommunityRepository(
    //   this._openApiService,
    //   this._postDao,
    //   this._commentDao,
    // );

    // OpenAPI 생성자 패턴 (여러 줄 지원)
    // 생성자 시작부터 끝까지 매칭 (괄호 안의 모든 내용 포함)
    // 생성자 주석 다음에 오는 생성자 블록 전체를 매칭
    final openApiConstructorPattern = RegExp(
      r'(\s*)///\s+\w+\s+Repository\s+생성자\s*\n\s*(\w+Repository)\s*\(\s*this\._openApiService[\s\S]*?\);\s*',
      multiLine: true,
    );

    // Serverpod 생성자 패턴 (여러 줄 지원)
    final serverpodConstructorPattern = RegExp(
      r'(\s*)///\s+\w+\s+Repository\s+생성자\s*\n\s*(\w+Repository)\s*\(\s*this\._podService[\s\S]*?\);\s*',
      multiLine: true,
    );

    // GraphQL 생성자 패턴
    final graphqlConstructorPattern = RegExp(
      r'^(\s*)(\w+Repository)\(this\._graphQLClient\);\s*$',
      multiLine: true,
    );

    // 빈 생성자 패턴
    final emptyConstructorPattern = RegExp(
      r'^(\s*)(\w+Repository)\(\);\s*$',
      multiLine: true,
    );

    // 각 패턴을 조건부 템플릿으로 변환
    // OpenAPI 생성자 변환 (여러 줄 지원)
    result = result.replaceAllMapped(openApiConstructorPattern, (match) {
      final fullMatch = match.group(0) ?? '';
      final indent = match.group(1) ?? '';
      final className = match.group(2) ?? '';

      // 생성자 본문 추출 (괄호 안의 내용)
      final constructorStart = fullMatch.indexOf('(');
      final constructorEnd = fullMatch.lastIndexOf(')');
      if (constructorStart != -1 && constructorEnd != -1) {
        final constructorBody = fullMatch.substring(
          constructorStart + 1,
          constructorEnd,
        );
        // 여러 줄 생성자 처리
        final bodyLines = constructorBody.split('\n');
        final indentedBody = bodyLines
            .map((line) {
              final trimmed = line.trim();
              if (trimmed.isEmpty) return '';
              // 원본 인덴트 유지
              if (line.trim() == trimmed && line != trimmed) {
                return line;
              }
              // 인덴트 추가
              return '$indent  $trimmed';
            })
            .where((line) => line.isNotEmpty)
            .join('\n');

        // 생성자 주석도 포함하여 변환
        return '${indent}{{#has_openapi}}\n$indent/// ${className.replaceAll('Repository', '')} Repository 생성자\n$indent$className(\n$indentedBody\n$indent);\n${indent}{{/has_openapi}}';
      }
      return fullMatch;
    });

    // Serverpod 생성자 변환 (여러 줄 지원)
    result = result.replaceAllMapped(serverpodConstructorPattern, (match) {
      final fullMatch = match.group(0) ?? '';
      final indent = match.group(1) ?? '';
      final className = match.group(2) ?? '';

      // 생성자 본문 추출 (괄호 안의 내용)
      final constructorStart = fullMatch.indexOf('(');
      final constructorEnd = fullMatch.lastIndexOf(')');
      if (constructorStart != -1 && constructorEnd != -1) {
        final constructorBody = fullMatch.substring(
          constructorStart + 1,
          constructorEnd,
        );
        // 여러 줄 생성자 처리
        final bodyLines = constructorBody.split('\n');
        final indentedBody = bodyLines
            .map((line) {
              final trimmed = line.trim();
              if (trimmed.isEmpty) return '';
              // 원본 인덴트 유지
              if (line.trim() == trimmed && line != trimmed) {
                return line;
              }
              // 인덴트 추가
              return '$indent  $trimmed';
            })
            .where((line) => line.isNotEmpty)
            .join('\n');

        // 생성자 주석도 포함하여 변환
        return '${indent}{{#has_serverpod}}\n$indent/// ${className.replaceAll('Repository', '')} Repository 생성자\n$indent$className(\n$indentedBody\n$indent);\n${indent}{{/has_serverpod}}';
      }
      return fullMatch;
    });

    // GraphQL 생성자 변환 (한 줄)
    result = result.replaceAllMapped(graphqlConstructorPattern, (match) {
      final indent = match.group(1) ?? '';
      final className = match.group(2) ?? '';
      return '${indent}{{#has_graphql}}\n$indent$className(this._graphQLClient);\n${indent}{{/has_graphql}}';
    });

    // 빈 생성자 변환
    result = result.replaceAllMapped(emptyConstructorPattern, (match) {
      final indent = match.group(1) ?? '';
      final className = match.group(2) ?? '';
      return '${indent}{{^has_serverpod}}{{^has_openapi}}{{^has_graphql}}\n$indent$className();\n${indent}{{/has_graphql}}{{/has_openapi}}{{/has_serverpod}}';
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
        var content = await targetFile.readAsString();

        // melos.yaml과 pubspec.yaml은 특별 처리
        if (fileName == 'melos.yaml' || fileName == 'pubspec.yaml') {
          content = _convertMelosYaml(content, config);
        } else {
          final patterns = TemplateConverter.buildPatterns(config);
          content = TemplateConverter.convertContent(
            content,
            patterns,
          );
        }

        final originalContent = await sourceFile.readAsString();
        if (content != originalContent) {
          await targetFile.writeAsString(content);
          logger.info('   ✅ $fileName converted');
        } else {
          logger.info('   ✅ $fileName copied');
        }
      } catch (_) {
        logger.info('   ✅ $fileName copied (binary)');
      }
    }
  }

  /// melos.yaml 또는 pubspec.yaml 파일 변환
  String _convertMelosYaml(String content, ProjectConfig config) {
    final lines = content.split('\n');
    final result = <String>[];
    final projectName = config.projectName;
    var inPackagesSection = false;
    var inWorkspaceSection = false;
    var inScriptsSection = false;
    var inEnableAdminBlock = false;
    var inHasServerpodBlock = false;
    var scriptIndent = '';

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      final trimmed = line.trim();

      // packages: 또는 workspace: 섹션 시작 감지
      if (trimmed == 'packages:' || trimmed == 'workspace:') {
        inPackagesSection = trimmed == 'packages:';
        inWorkspaceSection = trimmed == 'workspace:';
        result.add(line);
        continue;
      }

      // scripts: 섹션 시작 감지
      if (trimmed == 'scripts:' || (line.startsWith('  ') && trimmed == 'scripts:')) {
        inScriptsSection = true;
        scriptIndent = line.substring(0, line.indexOf('scripts:'));
        result.add(line);
        continue;
      }

      // 섹션이 끝났는지 확인 (다음 최상위 키 발견)
      if ((inPackagesSection || inWorkspaceSection) &&
          line.isNotEmpty && !line.startsWith(' ')) {
        // has_serverpod 블록이 열려있으면 닫기
        if (inHasServerpodBlock) {
          result.add('{{/has_serverpod}}');
          inHasServerpodBlock = false;
        }
        // enable_admin 블록이 열려있으면 닫기
        if (inEnableAdminBlock) {
          result.add('{{/enable_admin}}');
          inEnableAdminBlock = false;
        }
        inPackagesSection = false;
        inWorkspaceSection = false;
      }

      // scripts 섹션이 끝났는지 확인
      if (inScriptsSection && line.isNotEmpty && !line.startsWith(' ')) {
        if (inEnableAdminBlock) {
          result.add('{{/enable_admin}}');
          inEnableAdminBlock = false;
        }
        inScriptsSection = false;
      }

      // packages/workspace 섹션 내부 처리
      if ((inPackagesSection || inWorkspaceSection) && trimmed.startsWith('- ')) {
        // console app 패키지 처리
        if (line.contains('${projectName}_console') ||
            line.contains('backend/${projectName}_console')) {
          // has_serverpod 블록이 열려있으면 닫기
          if (inHasServerpodBlock) {
            result.add('{{/has_serverpod}}');
            inHasServerpodBlock = false;
          }
          if (!inEnableAdminBlock) {
            result.add('{{#enable_admin}}');
            inEnableAdminBlock = true;
          }
          final patterns = TemplateConverter.buildPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add(line);
          continue;
        }

        // console feature 패키지 처리
        if (line.contains('feature/console/')) {
          // has_serverpod 블록이 열려있으면 닫기
          if (inHasServerpodBlock) {
            result.add('{{/has_serverpod}}');
            inHasServerpodBlock = false;
          }
          if (!inEnableAdminBlock) {
            result.add('{{#enable_admin}}');
            inEnableAdminBlock = true;
          }
          final patterns = TemplateConverter.buildPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add(line);
          continue;
        }

        // backend server/client 패키지 처리 (has_serverpod)
        if (line.contains('backend/${projectName}_server') ||
            line.contains('backend/${projectName}_client')) {
          // enable_admin 블록이 열려있으면 닫기
          if (inEnableAdminBlock) {
            result.add('{{/enable_admin}}');
            inEnableAdminBlock = false;
          }
          if (!inHasServerpodBlock) {
            result.add('{{#has_serverpod}}');
            inHasServerpodBlock = true;
          }
          final patterns = TemplateConverter.buildPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add(line);

          // client가 오면 블록을 닫음
          if (line.contains('_client')) {
            result.add('{{/has_serverpod}}');
            inHasServerpodBlock = false;
          }
          continue;
        }

        // enable_admin/has_serverpod 블록이 열려있고, 해당되지 않는 패키지를 만나면 블록 닫기
        if (inHasServerpodBlock) {
          result.add('{{/has_serverpod}}');
          inHasServerpodBlock = false;
        }
        if (inEnableAdminBlock) {
          result.add('{{/enable_admin}}');
          inEnableAdminBlock = false;
        }

        // widgetbook 패키지 처리
        if (line.contains('${projectName}_widgetbook')) {
          final patterns = TemplateConverter.buildPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add(line);
          continue;
        }

        // resources 패키지 처리 - 다음 라인에 백엔드 서비스 패키지들 추가
        if (line.contains('package/resources')) {
          result.add('  - package/resources{{#has_serverpod}}');
          result.add('  - package/serverpod_service{{/has_serverpod}}{{#has_openapi}}');
          result.add('  - package/openapi_service');
          result.add('  - package/openapi{{/has_openapi}}');
          continue;
        }

        // serverpod_service 패키지 처리 (이미 resources에서 처리됨)
        if (line.contains('serverpod_service')) {
          continue;
        }

        // 일반 패키지 처리
        final patterns = TemplateConverter.buildPatterns(config);
        line = TemplateConverter.convertContent(line, patterns);
        result.add(line);
        continue;
      }

      // scripts 섹션 내부 처리 - console_router 같은 스크립트를 조건부로
      if (inScriptsSection) {
        // console_router 관련 스크립트 블록 시작 감지
        if (trimmed.startsWith('generate:console_router:') ||
            trimmed.startsWith('web:run:fixed-port:console:') ||
            trimmed.startsWith('dependBuild:feature:console:')) {
          if (!inEnableAdminBlock) {
            result.add('{{#enable_admin}}');
            inEnableAdminBlock = true;
          }
        }

        // console 관련 echo 라인 감지 (단일 라인 조건부 처리)
        if (line.contains('echo') &&
            (line.contains('console_router') ||
             (line.contains('Console') && line.contains('dependBuild:feature:console')))) {
          // echo 라인을 조건부로 감싸기
          final patterns = TemplateConverter.buildPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add('{{#enable_admin}}');
          result.add(line);
          result.add('{{/enable_admin}}');
          continue;
        }

        // 스크립트 블록이 끝나는지 확인 (다음 스크립트 시작)
        // 스크립트 이름 레벨 (2 spaces after scriptIndent)에서 새로운 스크립트가 시작되면
        if (inEnableAdminBlock &&
            line.length >= scriptIndent.length + 2 &&
            trimmed.isNotEmpty &&
            trimmed.endsWith(':') &&
            !trimmed.startsWith('run:') &&
            !trimmed.startsWith('description:') &&
            !trimmed.startsWith('packageFilters:') &&
            !trimmed.startsWith('generate:console') &&
            !trimmed.startsWith('web:run:fixed-port:console') &&
            !trimmed.startsWith('dependBuild:feature:console')) {
          result.add('{{/enable_admin}}');
          inEnableAdminBlock = false;
        }
      }

      // 일반 패턴 변환 적용
      final patterns = TemplateConverter.buildPatterns(config);
      line = TemplateConverter.convertContent(line, patterns);
      result.add(line);
    }

    // 파일 끝에서 블록이 열려있으면 닫기
    if (inHasServerpodBlock) {
      result.add('{{/has_serverpod}}');
    }
    if (inEnableAdminBlock) {
      result.add('{{/enable_admin}}');
    }

    // paramCase를 snakeCase로 변환
    var finalResult = result.join('\n');
    finalResult = finalResult.replaceAll(
      '{{project_name.paramCase()}}',
      '{{project_name.snakeCase()}}',
    );

    // build:select: 스크립트의 ignore 목록에 조건부 항목 추가
    finalResult = _addConditionalIgnoreItems(finalResult);

    // dependencies 섹션에 조건부 패키지 태그 추가
    finalResult = _addConditionalDependencyTags(finalResult);

    return finalResult;
  }

  /// build:select: 스크립트의 ignore 목록에 조건부 항목 추가
  String _addConditionalIgnoreItems(String content) {
    // build:select: 스크립트 블록을 찾아서 ignore 목록 마지막에 조건부 항목 추가
    final lines = content.split('\n');
    final result = <String>[];
    var inBuildSelectIgnore = false;
    var ignoreIndent = '';
    var lastIgnoreLineIndex = -1;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // build:select: 스크립트의 ignore: 섹션 감지
      if (line.contains('build:select:')) {
        // build:select: 블록 시작
        result.add(line);
        // 다음 줄들을 처리하면서 ignore: 섹션 찾기
        continue;
      }

      // ignore: 섹션 시작 감지 (build:select 내부)
      if (trimmed == 'ignore:' && i > 0) {
        // 이전에 build:select를 만났는지 확인
        var foundBuildSelect = false;
        for (var j = i - 1; j >= 0 && j > i - 20; j--) {
          if (lines[j].contains('build:select:')) {
            foundBuildSelect = true;
            break;
          }
        }
        if (foundBuildSelect) {
          inBuildSelectIgnore = true;
          ignoreIndent = line.substring(0, line.indexOf('ignore:'));
          result.add(line);
          continue;
        }
      }

      // ignore 목록 항목 추적
      if (inBuildSelectIgnore && trimmed.startsWith('-')) {
        lastIgnoreLineIndex = result.length;
      }

      // ignore 목록이 끝나는 시점 감지 (dependsOn:)
      if (inBuildSelectIgnore && trimmed == 'dependsOn:') {
        // 마지막 ignore 항목에 {{#has_serverpod}} 태그 추가
        if (lastIgnoreLineIndex >= 0) {
          result[lastIgnoreLineIndex] =
              '${result[lastIgnoreLineIndex]}{{#has_serverpod}}';
        }
        // dependsOn: 직전에 조건부 항목 추가
        final itemIndent = '$ignoreIndent      ';
        result
          ..add('$itemIndent- "serverpod_service"{{/has_serverpod}}{{#has_openapi}}')
          ..add('$itemIndent- "openapi_service"')
          ..add('$itemIndent- "openapi"{{/has_openapi}}');
        inBuildSelectIgnore = false;
      }

      result.add(line);
    }

    return result.join('\n');
  }

  /// dependencies 섹션에 조건부 백엔드 패키지 태그 추가 (인라인 형식)
  String _addConditionalDependencyTags(String content) {
    final lines = content.split('\n');
    final result = <String>[];

    // serverpod 관련 패키지들 (첫 번째 그룹과 두 번째 그룹)
    // 첫 번째 그룹: jaspr 관련 (jaspr ~ jaspr_serverpod)
    const firstServerpodGroupEnd = 'jaspr_serverpod:';
    // 두 번째 그룹: serverpod 코어 (serverpod ~ serverpod_serialization)
    const secondServerpodGroupStart = 'serverpod:';
    final lastServerpodPackages = [
      'serverpod_serialization:',
      'serverpod_test:',
    ];

    // dev_dependencies의 serverpod 그룹 종료
    const devServerpodGroupEnd = 'jaspr_web_compilers:';

    // openapi 관련 패키지들 (첫 패키지와 마지막 패키지)
    const firstOpenapiPkg = 'dio:';
    final lastOpenapiPackages = [
      'json_annotation:',
      'retrofit:',
    ];

    // graphql 관련 패키지 (첫 패키지이자 마지막 패키지)
    const graphqlPkg = 'graphql_flutter:';

    // intl 다음에 serverpod 블록이 시작되는 특수 케이스 (dependencies)
    const intlPkg = 'intl:';
    // mcp_toolkit 다음에 serverpod 두 번째 그룹 시작
    const mcpToolkitPkg = 'mcp_toolkit:';
    // injectable_generator 다음에 serverpod 블록이 시작 (dev_dependencies)
    const injectableGeneratorPkg = 'injectable_generator:';
    // pubspec_dependency_sorter 다음에 serverpod 세 번째 그룹 시작
    const pubspecDependencySorterPkg = 'pubspec_dependency_sorter:';

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      final trimmed = line.trim();

      // intl, injectable_generator, pubspec_dependency_sorter 라인에
      // {{#has_serverpod}} 추가
      if (trimmed.startsWith(intlPkg) ||
          trimmed.startsWith(injectableGeneratorPkg) ||
          trimmed.startsWith(pubspecDependencySorterPkg)) {
        line = '$line{{#has_serverpod}}';
        result.add(line);
        continue;
      }

      // jaspr_serverpod (첫 번째 그룹 종료) 뒤에 {{/has_serverpod}} 추가
      if (trimmed.startsWith(firstServerpodGroupEnd)) {
        line = '$line{{/has_serverpod}}';
        result.add(line);
        continue;
      }

      // mcp_toolkit 뒤에 {{#has_serverpod}} 추가 (두 번째 그룹 시작)
      if (trimmed.startsWith(mcpToolkitPkg)) {
        line = '$line{{#has_serverpod}}';
        result.add(line);
        continue;
      }

      // serverpod_serialization/serverpod_test (두 번째 그룹 종료) 뒤에 {{/has_serverpod}}
      var isLastServerpod = false;
      for (final pkg in lastServerpodPackages) {
        if (trimmed.startsWith(pkg)) {
          line = '$line{{/has_serverpod}}';
          isLastServerpod = true;
          break;
        }
      }
      if (isLastServerpod) {
        result.add(line);
        continue;
      }

      // jaspr_web_compilers (dev_dependencies 그룹 종료) 뒤에 {{/has_serverpod}}
      if (trimmed.startsWith(devServerpodGroupEnd)) {
        line = '$line{{/has_serverpod}}';
        result.add(line);
        continue;
      }

      // skeletonizer 다음에 openapi/graphql 블록 준비
      if (trimmed.startsWith('skeletonizer:')) {
        // 다음 줄에 실제 openapi 패키지가 있는지 확인
        final hasOpenapiPkg = i + 1 < lines.length &&
            lines[i + 1].trim().startsWith(firstOpenapiPkg);

        if (hasOpenapiPkg) {
          // openapi 패키지가 있으면 블록 시작만
          line = '$line{{#has_openapi}}';
        } else {
          // openapi 패키지가 없으면 빈 블록 구조 생성
          line = '$line{{#has_openapi}}{{/has_openapi}}{{#has_graphql}}{{/has_graphql}}';
        }
        result.add(line);
        continue;
      }

      // openapi 마지막 패키지에 {{/has_openapi}}{{#has_graphql}} 추가 (인라인)
      var isLastOpenapi = false;
      for (final pkg in lastOpenapiPackages) {
        if (trimmed.startsWith(pkg)) {
          // 다음 줄이 graphql인지 확인
          if (i + 1 < lines.length &&
              lines[i + 1].trim().startsWith(graphqlPkg)) {
            line = '$line{{/has_openapi}}{{#has_graphql}}';
          } else {
            line = '$line{{/has_openapi}}';
          }
          isLastOpenapi = true;
          break;
        }
      }
      if (isLastOpenapi) {
        result.add(line);
        continue;
      }

      // graphql 패키지에 {{/has_graphql}} 추가 (인라인)
      if (trimmed.startsWith(graphqlPkg)) {
        line = '$line{{/has_graphql}}';
        result.add(line);
        continue;
      }

      result.add(line);
    }

    return result.join('\n');
  }
}
