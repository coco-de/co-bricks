import 'dart:io';

import 'package:co_bricks/src/services/envrc_service.dart';
import 'package:co_bricks/src/utils/file_utils.dart';
import 'package:co_bricks/src/utils/template_converter.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// Mason 조건부 파일 구조 표현
/// Git에서 {{#condition}}filename{{/ 디렉토리와 내부 condition}} 파일로 저장됨
class ConditionalFileStructure {
  ConditionalFileStructure({
    required this.conditionalDirPath,
    required this.conditionalDirName,
    required this.innerFilePath,
    required this.actualFileName,
    required this.condition,
    required this.relativeDir,
  });

  /// 조건부 디렉토리 전체 경로 (예: .../{{#has_graphql}}...{{/)
  final String conditionalDirPath;

  /// 조건부 디렉토리 이름 (예: {{#has_graphql}}sign_in_with_email_graphql_mixin.dart{{)
  final String conditionalDirName;

  /// 내부 파일 전체 경로 (예: .../{{#has_graphql}}...{{/has_graphql}})
  final String innerFilePath;

  /// 실제 파일명 (예: sign_in_with_email_graphql_mixin.dart)
  final String actualFileName;

  /// 조건 (예: has_graphql)
  final String condition;

  /// 상대 디렉토리 경로
  final String relativeDir;
}

/// Monorepo 동기화 서비스
class SyncMonorepoService {
  SyncMonorepoService(this.logger);

  final Logger logger;

  /// 패턴 캐시 (성능 최적화)
  List<ReplacementPattern>? _patternCache;
  ProjectConfig? _lastConfig;

  /// 패턴 가져오기 (캐시 사용)
  List<ReplacementPattern> _getPatterns(ProjectConfig config) {
    // 설정이 동일하면 캐시된 패턴 반환
    if (_lastConfig == config && _patternCache != null) {
      return _patternCache!;
    }

    // 새 패턴 생성 및 캐시
    logger.detail('Building template patterns...');
    _lastConfig = config;
    _patternCache = TemplateConverter.buildPatterns(config);
    logger.detail('Cached ${_patternCache!.length} patterns');

    return _patternCache!;
  }

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

    // 선택적 기능 검증
    await _validateOptionalFeatures(templateDir, config);

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
    logger.info('=' * 60);
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

    // passwords.yaml 파일 백업
    final passwordsBackup = <String, List<int>>{};
    final serverDirPattern = RegExp(
      r'^{{project_name\.snakeCase\(\)}}_server$',
    );
    for (final entity in targetDir.listSync()) {
      if (entity is Directory) {
        final dirName = path.basename(entity.path);
        if (serverDirPattern.hasMatch(dirName)) {
          final passwordsPath = path.join(
            entity.path,
            'config',
            'passwords.yaml',
          );
          final passwordsFile = File(passwordsPath);
          if (passwordsFile.existsSync()) {
            passwordsBackup[passwordsPath] = await passwordsFile.readAsBytes();
          }
        }
      }
    }

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
    await for (final entity in sourceBackendDir.list()) {
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

    final patterns = _getPatterns(config);
    var convertedFiles = 0;

    // 파일 처리 (디렉토리 이름은 이미 변환됨)
    final stats = await _processFiles(targetDir, config, patterns);
    convertedFiles = stats['converted']!;

    // passwords.yaml 파일 복원
    for (final entry in passwordsBackup.entries) {
      final passwordsPath = entry.key;
      final passwordsContent = entry.value;
      final passwordsFile = File(passwordsPath);
      await passwordsFile.writeAsBytes(passwordsContent);
    }

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

        final patterns = _getPatterns(config);
        var convertedFiles = 0;

        // 디렉토리 이름 변환
        await _convertDirectoryNames(targetDir, config, 0);

        // 파일 처리
        final stats = await _processFiles(targetDir, config, patterns);
        convertedFiles = stats['converted']!;

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

    // shared 디렉토리의 경우, dependencies/pubspec.yaml 조건부 라인 백업
    List<String>? pubspecConditionalLines;
    if (dirName == 'shared') {
      pubspecConditionalLines = await _backupPubspecConditionalLines(targetDir);
    }

    // Mason 조건부 파일 구조 스캔 및 백업
    // Git에서는 {{#condition}}filename{{/ 디렉토리와 내부 condition}} 파일로 저장
    final conditionalStructures = <ConditionalFileStructure>[];
    final conditionalBackups = <String, List<int>>{}; // 내용 백업

    logger.detail(
      '   🔍 Scanning conditional file structures: ${targetDir.path}',
    );

    if (targetDir.existsSync()) {
      await for (final entity in targetDir.list(recursive: true)) {
        if (entity is! Directory) continue;

        final dirName = path.basename(entity.path);

        // 조건부 디렉토리 패턴: {{#condition}}filename{{
        final dirMatch = RegExp(
          r'^\{\{#(\w+)\}\}(.+)\{\{$',
        ).firstMatch(dirName);

        if (dirMatch != null) {
          final condition = dirMatch.group(1)!;
          final actualFileName = dirMatch.group(2)!;

          // 디렉토리 내부의 condition}} 파일 찾기
          final innerFileName = '$condition}}';
          final innerFilePath = path.join(entity.path, innerFileName);
          final innerFile = File(innerFilePath);

          if (innerFile.existsSync()) {
            final relativePath = path.relative(
              entity.path,
              from: targetDir.path,
            );

            final structure = ConditionalFileStructure(
              conditionalDirPath: entity.path,
              conditionalDirName: dirName,
              innerFilePath: innerFilePath,
              actualFileName: actualFileName,
              condition: condition,
              relativeDir: path.dirname(relativePath),
            );

            // 내용 백업 (copyDirectory가 삭제하기 전에)
            final content = await innerFile.readAsBytes();
            conditionalBackups[innerFilePath] = content;

            conditionalStructures.add(structure);

            logger.info(
              '   🔍 Found conditional: $actualFileName ($condition) '
              '[${content.length} bytes backed up]',
            );
          }
        }
      }
    }

    logger.detail(
      '   📊 Found ${conditionalStructures.length} conditional structures',
    );

    // 타겟 디렉토리 생성
    targetDir.createSync(recursive: true);

    // 선택적 feature 보존 로직
    Map<String, Directory>? preservedOptionalFeatures;
    if (dirName == 'feature') {
      preservedOptionalFeatures = await _preserveOptionalFeatures(
        sourceDir,
        targetDir,
        config,
      );
    }

    logger.info('   📋 Updating files from template...');

    // 디렉토리 복사
    await FileUtils.copyDirectory(sourceDir, targetDir, overwrite: true);

    // 보존된 선택적 feature 복원
    if (preservedOptionalFeatures != null &&
        preservedOptionalFeatures.isNotEmpty) {
      await _restoreOptionalFeatures(preservedOptionalFeatures, targetDir);
    }

    // Mason 조건부 파일 구조 복원
    for (final structure in conditionalStructures) {
      // Blueprint에서 복사된 파일 경로
      final copiedFilePath = path.join(
        targetDir.path,
        structure.relativeDir,
        structure.actualFileName,
      );
      final copiedFile = File(copiedFilePath);

      // 조건부 디렉토리 재생성 (copyDirectory가 삭제했음)
      final conditionalDir = Directory(structure.conditionalDirPath);
      if (!conditionalDir.existsSync()) {
        await conditionalDir.create(recursive: true);
      }

      final innerFile = File(structure.innerFilePath);

      // Blueprint에 해당 파일이 있으면 새 내용으로 업데이트
      if (copiedFile.existsSync()) {
        // Blueprint 파일 내용을 조건부 구조 내부 파일로 복사
        final content = await copiedFile.readAsBytes();
        await innerFile.writeAsBytes(content);

        // Blueprint 파일 삭제 (조건부 구조로 대체)
        await copiedFile.delete();

        logger.info(
          '   ♻️  Updated conditional: ${structure.actualFileName} '
          '(${structure.condition})',
        );
      } else {
        // Blueprint에 파일이 없으면 백업에서 복원
        final backupContent = conditionalBackups[structure.innerFilePath];
        if (backupContent != null) {
          await innerFile.writeAsBytes(backupContent);

          logger.info(
            '   ✓ Preserved conditional: ${structure.actualFileName} '
            '(${structure.condition}) [${backupContent.length} bytes restored]',
          );
        } else {
          logger.warn(
            '   ⚠️  No backup for: ${structure.actualFileName} '
            '(path: ${structure.innerFilePath})',
          );
        }
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

    final patterns = _getPatterns(config);
    var convertedFiles = 0;
    const renamedDirs = 0;

    // 디렉토리 이름 변환 (하위에서 상위로)
    await _convertDirectoryNames(targetDir, config, renamedDirs);

    // feature 디렉토리의 console을 조건부 디렉토리로 변환
    if (dirName == 'feature') {
      await _convertConsoleToConditionalDir(targetDir);
    }

    // shared 디렉토리의 dependencies/pubspec.yaml 조건부 라인 복원
    if (dirName == 'shared' && pubspecConditionalLines != null) {
      await _restorePubspecConditionalLines(
        targetDir,
        sourceDir,
        pubspecConditionalLines,
      );
    }

    // 파일 처리 (네트워크별 mixin 파일들을 조건부 디렉토리로 변환)
    final stats = await _processFiles(targetDir, config, patterns);
    convertedFiles = stats['converted']!;

    logger.info('   ✅ $dirName synced:');
    logger.info('      • $convertedFiles files converted');
  }

  /// shared/dependencies/pubspec.yaml의 조건부 라인 백업
  Future<List<String>> _backupPubspecConditionalLines(
    Directory targetDir,
  ) async {
    final targetPubspec = File(
      path.join(targetDir.path, 'dependencies', 'pubspec.yaml'),
    );

    if (!targetPubspec.existsSync()) {
      return [];
    }

    final targetContent = await targetPubspec.readAsString();
    final existingConditionalLines = <String>[];
    final conditionalPattern = RegExp(
      r'\{\{#has_\w+\}\}\w+_service:.+?\{\{/has_\w+\}\}',
    );

    for (final line in targetContent.split('\n')) {
      if (conditionalPattern.hasMatch(line)) {
        existingConditionalLines.add(line.trim());
        logger.detail('   📋 Backed up conditional: ${line.trim()}');
      }
    }

    if (existingConditionalLines.isNotEmpty) {
      logger.info(
        '   📋 Backed up ${existingConditionalLines.length} conditional '
        'dependencies from pubspec.yaml',
      );
    }

    return existingConditionalLines;
  }

  /// shared/dependencies/pubspec.yaml의 조건부 dependency 라인들을 보존
  ///
  /// 1. Blueprint에서 service dependencies를 조건부로 변환
  /// 2. 백업된 조건부 라인 중 누락된 것들을 추가
  /// 3. 항상 모든 서비스(openapi, graphql, serverpod)를 조건부로 유지
  Future<void> _restorePubspecConditionalLines(
    Directory targetDir,
    Directory sourceDir,
    List<String> existingConditionalLines,
  ) async {
    final targetPubspec = File(
      path.join(targetDir.path, 'dependencies', 'pubspec.yaml'),
    );
    final sourcePubspec = File(
      path.join(sourceDir.path, 'dependencies', 'pubspec.yaml'),
    );

    if (!targetPubspec.existsSync() || !sourcePubspec.existsSync()) {
      return;
    }

    logger.info('   🔄 Preserving conditional dependencies in pubspec.yaml...');

    // Blueprint 내용 읽기
    final sourceContent = await sourcePubspec.readAsString();
    final sourceLines = sourceContent.split('\n');
    final result = <String>[];
    var inDependenciesSection = false;
    final addedServices = <String>{};

    // 네트워크/백엔드 서비스 패턴 (Brick이 항상 가져야 하는 것들)
    final servicePatterns = {
      'openapi_service': 'has_openapi',
      'graphql_service': 'has_graphql',
      'serverpod_service': 'has_serverpod',
    };

    var foundResourcesLine = false;

    for (final line in sourceLines) {
      final trimmed = line.trim();

      // dependencies: 섹션 시작
      if (trimmed == 'dependencies:') {
        inDependenciesSection = true;
        result.add(line);
        continue;
      }

      // dev_dependencies: 섹션 시작
      if (trimmed == 'dev_dependencies:') {
        inDependenciesSection = false;
        result.add(line);
        continue;
      }

      // dependencies 섹션 내부의 서비스 의존성들을 조건부로 변환
      if (inDependenciesSection) {
        var wasConverted = false;

        // resources: 라인 감지 (서비스들은 이 직후에 추가됨)
        if (trimmed.startsWith('resources:')) {
          foundResourcesLine = true;
          result.add(line);
          continue;
        }

        for (final entry in servicePatterns.entries) {
          final serviceName = entry.key;

          // 정확한 패키지 이름 매칭 (예: "serverpod_service:")
          if (trimmed.startsWith('$serviceName:')) {
            // 이미 이 서비스를 추가했으면 스킵 (중복 방지)
            if (addedServices.contains(serviceName)) {
              wasConverted = true; // 이 라인은 건너뛰기
              logger.detail(
                '   ⏭️  Skipped duplicate: $serviceName',
              );
              break;
            }

            // 이미 조건부인지 확인
            if (!line.contains('{{#')) {
              // 들여쓰기 유지
              final indent = line.substring(0, line.indexOf(serviceName));

              // 첫 번째 서비스를 만났을 때만 모든 서비스를 추가
              if (addedServices.isEmpty) {
                logger.detail(
                  '   🎯 First service found, adding all services in order...',
                );

                // 모든 서비스를 정해진 순서로 추가
                for (final svcEntry in servicePatterns.entries) {
                  final svcName = svcEntry.key;
                  final svcFlag = svcEntry.value;

                  // 백업된 조건부 라인에서 찾기
                  String? existingLine;
                  for (final backupLine in existingConditionalLines) {
                    if (backupLine.contains(svcName)) {
                      existingLine = backupLine;
                      break;
                    }
                  }

                  if (existingLine != null) {
                    // 백업된 라인 사용
                    result.add('$indent$existingLine');
                    logger.detail(
                      '   ✅ Restored from backup: $svcName',
                    );
                  } else {
                    // 새로 생성 (기본 버전 0.1.0)
                    final conditionalLine =
                        '{{#$svcFlag}}$svcName: ^0.1.0{{/$svcFlag}}';
                    result.add('$indent$conditionalLine');
                    logger.detail(
                      '   ✨ Added service: $svcName',
                    );
                  }

                  addedServices.add(svcName);
                }
              }

              wasConverted = true;
              break;
            }
          }
        }

        // 변환되지 않았으면 원본 라인 유지
        if (!wasConverted) {
          result.add(line);
        }
      } else {
        // dependencies 섹션 외부는 그대로 유지
        result.add(line);
      }
    }

    // 만약 어떤 서비스도 변환되지 않았다면 (Blueprint에 서비스가 없는 경우)
    // resources 라인 바로 뒤에 모든 서비스를 추가
    if (addedServices.isEmpty && foundResourcesLine) {
      final insertIndex = result.indexWhere(
        (line) => line.trim().startsWith('resources:'),
      );
      if (insertIndex != -1) {
        final resourcesLine = result[insertIndex];
        final indent = resourcesLine.substring(
          0,
          resourcesLine.indexOf('resources:'),
        );

        // resources 라인 다음 위치에 모든 서비스 삽입
        var insertPos = insertIndex + 1;
        for (final entry in servicePatterns.entries) {
          final serviceName = entry.key;
          final conditionalFlag = entry.value;

          // 백업된 조건부 라인에서 찾기
          String? existingLine;
          for (final line in existingConditionalLines) {
            if (line.contains(serviceName)) {
              existingLine = line;
              break;
            }
          }

          if (existingLine != null) {
            result.insert(insertPos++, '$indent$existingLine');
            logger.detail('   ✅ Restored from backup: $existingLine');
          } else {
            final conditionalLine =
                '{{#$conditionalFlag}}$serviceName: ^0.1.0{{/$conditionalFlag}}';
            result.insert(insertPos++, '$indent$conditionalLine');
            logger.detail('   ✨ Added missing service: $conditionalLine');
          }
        }
      }
    }

    // 변환된 내용 저장
    await targetPubspec.writeAsString(result.join('\n'));

    logger.info(
      '   ✅ Preserved conditional dependencies in pubspec.yaml',
    );
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
      logger.detail(
        '   ⏭️  Console directory not found (skipping conditional conversion)',
      );
      return;
    }

    // Mason 조건부 디렉토리 구조
    // 1단계: {{#enable_admin}}console{{/ 디렉토리
    const outerDirName = '{{#enable_admin}}console{{';
    final outerDir = Directory(path.join(featureDir.path, outerDirName));

    logger.info('   🔄 Converting console to conditional directory...');

    // 기존 조건부 디렉토리가 있으면 삭제하지 않고 병합
    // (조건부 파일들이 이미 복원되어 있을 수 있음)
    if (!outerDir.existsSync()) {
      outerDir.createSync(recursive: true);
    }

    // 2단계: 내부에 enable_admin}} 디렉토리 생성
    const innerDirName = 'enable_admin}}';
    final innerDir = Directory(path.join(outerDir.path, innerDirName));
    if (!innerDir.existsSync()) {
      innerDir.createSync(recursive: true);
    }

    // console 디렉토리의 내용을 innerDir로 복사 (조건부 파일 구조는 건너뜀)
    await for (final entity in consoleDir.list()) {
      final entityName = path.basename(entity.path);
      final targetPath = path.join(innerDir.path, entityName);

      // 이미 존재하는 항목은 건너뜀 (조건부 파일 복원에서 온 것)
      if (await FileSystemEntity.type(targetPath) !=
          FileSystemEntityType.notFound) {
        logger.detail('   ⏭️  Skipping existing: $entityName');
        continue;
      }

      if (entity is Directory) {
        await FileUtils.copyDirectory(
          entity,
          Directory(targetPath),
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

  /// 파일 처리 (병렬 처리 최적화)
  Future<Map<String, int>> _processFiles(
    Directory dir,
    ProjectConfig config,
    List<ReplacementPattern> patterns,
  ) async {
    var convertedFiles = 0;

    // 모든 파일 수집
    final files = <File>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity);
      }
    }

    // 배치로 병렬 처리 (batch size: 50)
    const batchSize = 50;
    for (var i = 0; i < files.length; i += batchSize) {
      final end = (i + batchSize < files.length) ? i + batchSize : files.length;
      final batch = files.sublist(i, end);

      // 배치 내 파일들을 병렬로 처리
      final results = await Future.wait(
        batch.map(
          (entity) => _processSingleFile(entity, config, patterns),
        ),
      );

      // 변환된 파일 수 집계
      convertedFiles += results.where((r) => r).length;
    }

    return {'converted': convertedFiles};
  }

  /// 단일 파일 처리 (병렬 처리용)
  Future<bool> _processSingleFile(
    File entity,
    ProjectConfig config,
    List<ReplacementPattern> patterns,
  ) async {
    try {
      final originalFileName = path.basename(entity.path);

      // Flutter LLDB 관련 파일 제외 (widgetbook의 ephemeral 디렉토리)
      if (entity.path.contains('ios/Flutter/ephemeral') &&
          (originalFileName == 'flutter_lldb_helper.py' ||
              originalFileName == 'flutter_lldbinit')) {
        return false;
      }

      // 이미 조건부 템플릿이 포함된 파일명인지 확인
      final hasConditionalTemplate =
          originalFileName.contains('{{#') && originalFileName.contains('{{/');

      // 조건부 템플릿이 포함된 파일명에서 실제 파일명 추출
      var actualFileName = originalFileName;
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
      final newFileName = FileUtils.convertFileName(
        actualFileName,
        config.projectNames,
      );

      // 네트워크별 mixin 파일명을 조건부 템플릿으로 변환
      // {{#has_openapi}}community_openapi_mixin.dart{{ 디렉토리를 만들고 그 안에 has_openapi}} 파일 생성
      String? conditionalDir;
      var finalFileName = newFileName;

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
          r'$newFileName',
          newFileName,
        );
      }

      // 파일 내용 변환 (파일 이동 전에 수행)
      File? targetFile;
      String? convertedContent;

      if (FileUtils.shouldProcessFile(entity)) {
        if (await FileUtils.isTextFile(entity) &&
            FileUtils.isFileSizeValid(entity)) {
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

            // GitHub Actions 파일의 ${{ }}를 이스케이프 처리
            // Mason 템플릿 변수와 충돌을 피하기 위해 ${{ -> ${ {, }} -> } }로 변환
            if (entity.path.contains('.github') &&
                (basename.endsWith('.yml') || basename.endsWith('.yaml'))) {
              content = content
                  .replaceAll(r'${{', r'${ { ')
                  .replaceAll('}}', ' } }');
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
            return true;
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
            return true;
          }
        } catch (e) {
          logger.warn(
            '   ⚠️  Error writing converted content to ${entity.path}: $e',
          );
        }
      }

      return false; // 파일이 변환되지 않음
    } catch (e) {
      logger.warn('   ⚠️  Error processing file ${entity.path}: $e');
      return false;
    }
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
    var result = content;

    // 이미 조건부 템플릿이 포함되어 있으면 변환하지 않지만, 공백은 정규화
    final hasConditionals =
        content.contains('{{#has_openapi}}') ||
        content.contains('{{#has_serverpod}}') ||
        content.contains('{{#has_graphql}}') ||
        content.contains('{{#has_supabase}}') ||
        content.contains('{{#has_firebase}}') ||
        content.contains('{{#enable_admin}}');

    if (hasConditionals) {
      // 조건부 템플릿이 있는 경우: 공백만 정규화하고 반환
      logger.detail(
        'Normalizing whitespace in existing conditional templates...',
      );

      // dependencies: 섹션 내의 과도한 공백 제거
      final pattern1 = RegExp(
        r'(resources:\s*\^[0-9.]+)\s*\n\s*\n\s*\n(\s+\{\{#has_)',
      );
      if (pattern1.hasMatch(result)) {
        result = result.replaceAllMapped(
          pattern1,
          (match) => '${match.group(1)}\n${match.group(2)}',
        );
      }

      // 조건부 템플릿 직전의 공백 라인 완전히 제거
      final pattern3 = RegExp(r'\n\s*\n(\s+\{\{#has_)');
      if (pattern3.hasMatch(result)) {
        result = result.replaceAllMapped(
          pattern3,
          (match) => '\n${match.group(1)}',
        );
      }

      return result;
    }

    // 여러 줄 공백을 2줄로 정규화 (조건부 템플릿 추가 전)
    result = result.replaceAll(RegExp(r'\n\n\n+'), '\n\n');

    // 각 서비스별 의존성
    final servicePatterns = {
      'openapi_service': 'has_openapi',
      'serverpod_service': 'has_serverpod',
      'graphql_service': 'has_graphql',
      'supabase_service': 'has_supabase',
      'firebase_service': 'has_firebase',
    };

    // console 관련 패키지 (enable_admin 조건)
    final consolePatterns = {
      'console_banner_list': 'enable_admin',
      'console_router': 'enable_admin',
    };

    // shared/dependencies/pubspec.yaml인지 확인
    final isDependenciesPubspec =
        filePath.contains('shared/dependencies/pubspec.yaml') ||
        filePath.contains(
          'shared${path.separator}dependencies${path.separator}pubspec.yaml',
        );

    // package/core/pubspec.yaml인지 확인
    final isCorePubspec =
        filePath.contains('package/core/pubspec.yaml') ||
        filePath.contains(
          'package${path.separator}core${path.separator}pubspec.yaml',
        );

    // 서비스 패턴 처리
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

    // console 패턴 처리 (package/core/pubspec.yaml에서만)
    if (isCorePubspec) {
      for (final entry in consolePatterns.entries) {
        final packageName = entry.key;
        final conditionalFlag = entry.value;

        // 패턴: "  package_name: ^0.1.0" (앞에 공백, 줄 끝까지)
        final pattern = RegExp(
          '^(\\s+)$packageName:\\s*\\^[\\d.]+\\s*\$',
          multiLine: true,
        );

        // 조건부 템플릿으로 변환
        result = result.replaceAllMapped(pattern, (match) {
          final indent = match.group(1)!;
          final dependencyLine = match.group(0)!.trim();
          return '$indent{{#$conditionalFlag}}$dependencyLine{{/$conditionalFlag}}';
        });
      }
    }

    // 조건부 템플릿 추가 후 공백 정규화
    logger.detail('Normalizing whitespace in pubspec dependencies...');

    // 1. dependencies: 섹션 내의 과도한 공백 제거
    // "resources: ^0.1.0\n\n\n  {{#has_openapi}}" -> "resources: ^0.1.0\n  {{#has_openapi}}"
    final pattern1 = RegExp(
      r'(resources:\s*\^[0-9.]+)\s*\n\s*\n\s*\n(\s+\{\{#has_)',
    );
    if (pattern1.hasMatch(result)) {
      logger.detail('Found resources pattern with excessive whitespace');
      result = result.replaceAllMapped(
        pattern1,
        (match) => '${match.group(1)}\n${match.group(2)}',
      );
      logger.detail('Removed excessive whitespace after resources');
    }

    // 2. 3줄 이상 연속 공백을 2줄로 정규화
    result = result.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');

    // 3. 조건부 템플릿 직전의 공백 라인 완전히 제거 (dependencies 섹션)
    final pattern3 = RegExp(r'\n\s*\n(\s+\{\{#has_)');
    if (pattern3.hasMatch(result)) {
      logger.detail('Found whitespace before conditional templates');
      result = result.replaceAllMapped(
        pattern3,
        (match) => '\n${match.group(1)}',
      );
      logger.detail('Removed whitespace before conditional templates');
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
    required List<Map<String, String>> daoGetters,
    String? databaseField,
    String? databaseType,
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
    buffer.writeln('  /// $mixinPrefix Repository 생성자');
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
    buffer.writeln('  /// $mixinPrefix Repository 생성자');
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
    buffer.writeln('  /// $mixinPrefix Repository 생성자');
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
    buffer.writeln('  /// $mixinPrefix Repository 생성자');
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
    buffer.writeln('  /// $mixinPrefix Repository 생성자');
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
    buffer.writeln('  /// $mixinPrefix Repository 생성자');
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
        return '$indent{{#has_openapi}}with $mixinName{{/has_openapi}}';
      },
    );

    // final OpenApiService _openApiService;
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)final\s+OpenApiService\s+(\w+);\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        final varName = match.group(2) ?? '';
        return '$indent{{#has_openapi}}final OpenApiService $varName;{{/has_openapi}}';
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
        return '$indent{{#has_openapi}}OpenApiService get $getterName => $varName;{{/has_openapi}}';
      },
    );

    // Serverpod 패턴 변환
    // with HomeServerpodMixin
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)with\s+(\w+ServerpodMixin)\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        final mixinName = match.group(2) ?? '';
        return '$indent{{#has_serverpod}}with $mixinName{{/has_serverpod}}';
      },
    );

    // final pod.PodService _podService;
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)final\s+pod\.PodService\s+(\w+);\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        final varName = match.group(2) ?? '';
        return '$indent{{#has_serverpod}}final pod.PodService $varName;{{/has_serverpod}}';
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
        return '$indent{{#has_serverpod}}pod.Client get $getterName => $expression;{{/has_serverpod}}';
      },
    );

    // GraphQL 패턴 변환
    // with HomeGraphqlMixin
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)with\s+(\w+GraphqlMixin)\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        final mixinName = match.group(2) ?? '';
        return '$indent{{#has_graphql}}with $mixinName{{/has_graphql}}';
      },
    );

    // final GraphQLClient _graphQLClient;
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)final\s+GraphQLClient\s+(\w+);\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        final varName = match.group(2) ?? '';
        return '$indent{{#has_graphql}}final GraphQLClient $varName;{{/has_graphql}}';
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
        return '$indent{{#has_graphql}}GraphQLClient get $getterName => $varName;{{/has_graphql}}';
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
        return '$indent{{#has_openapi}}/// REST API를 통해 실제 백엔드와 통신{{/has_openapi}}';
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
        return '$indent{{#has_serverpod}}/// Serverpod Client를 통해 실제 백엔드 API와 통신{{/has_serverpod}}';
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
        return '$indent{{#has_graphql}}/// GraphQL을 통해 실제 백엔드와 통신{{/has_graphql}}';
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
        return '$indent{{#has_supabase}}/// Supabase를 통해 실제 백엔드와 통신{{/has_supabase}}';
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
        return '$indent{{#has_firebase}}/// Firebase를 통해 실제 백엔드와 통신{{/has_firebase}}';
      },
    );

    // /// 메모리에서 데이터를 생성하고 관리
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)///\s*메모리에서\s+데이터를\s+생성하고\s+관리\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        return '$indent{{^has_serverpod}}{{^has_openapi}}{{^has_graphql}}{{^has_supabase}}{{^has_firebase}}/// 메모리에서 데이터를 생성하고 관리{{/has_firebase}}{{/has_supabase}}{{/has_graphql}}{{/has_openapi}}{{/has_serverpod}}';
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
        return '$indent{{#has_openapi}}\n$indent/// ${className.replaceAll('Repository', '')} Repository 생성자\n$indent$className(\n$indentedBody\n$indent);\n$indent{{/has_openapi}}';
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
        return '$indent{{#has_serverpod}}\n$indent/// ${className.replaceAll('Repository', '')} Repository 생성자\n$indent$className(\n$indentedBody\n$indent);\n$indent{{/has_serverpod}}';
      }
      return fullMatch;
    });

    // GraphQL 생성자 변환 (한 줄)
    result = result.replaceAllMapped(graphqlConstructorPattern, (match) {
      final indent = match.group(1) ?? '';
      final className = match.group(2) ?? '';
      return '$indent{{#has_graphql}}\n$indent$className(this._graphQLClient);\n$indent{{/has_graphql}}';
    });

    // 빈 생성자 변환
    result = result.replaceAllMapped(emptyConstructorPattern, (match) {
      final indent = match.group(1) ?? '';
      final className = match.group(2) ?? '';
      return '$indent{{^has_serverpod}}{{^has_openapi}}{{^has_graphql}}\n$indent$className();\n$indent{{/has_graphql}}{{/has_openapi}}{{/has_serverpod}}';
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
          // 기존 brick의 melos.yaml에서 조건부 블록 추출 (보존용)
          String? existingConditionalBlocks;
          if (targetFile.existsSync()) {
            final existingContent = await targetFile.readAsString();
            existingConditionalBlocks =
                _extractConditionalBlocks(existingContent);
          }

          content = _convertMelosYaml(content, config);

          // 기존 조건부 블록을 병합
          if (existingConditionalBlocks != null &&
              existingConditionalBlocks.isNotEmpty) {
            content = _mergeConditionalBlocks(content, existingConditionalBlocks);
          }
        } else {
          final patterns = _getPatterns(config);
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
    var inConsoleBuildBlock = false;
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
      if (trimmed == 'scripts:' ||
          (line.startsWith('  ') && trimmed == 'scripts:')) {
        inScriptsSection = true;
        scriptIndent = line.substring(0, line.indexOf('scripts:'));
        result.add(line);
        continue;
      }

      // 섹션이 끝났는지 확인 (다음 최상위 키 발견)
      if ((inPackagesSection || inWorkspaceSection) &&
          line.isNotEmpty &&
          !line.startsWith(' ')) {
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
      if ((inPackagesSection || inWorkspaceSection) &&
          trimmed.startsWith('- ')) {
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
          final patterns = _getPatterns(config);
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
          final patterns = _getPatterns(config);
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
          final patterns = _getPatterns(config);
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
          final patterns = _getPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add(line);
          continue;
        }

        // resources 패키지 처리 - 다음 라인에 백엔드 서비스 패키지들 추가
        if (line.contains('package/resources')) {
          result.add('  - package/resources');
          result.add(
            '  {{#has_serverpod}}- package/serverpod_service{{/has_serverpod}}',
          );
          result.add(
            '  {{#has_openapi}}- package/openapi_service{{/has_openapi}}',
          );
          result.add('  {{#has_openapi}}- package/openapi{{/has_openapi}}');
          continue;
        }

        // serverpod_service 패키지 처리 (이미 resources에서 처리됨)
        if (line.contains('serverpod_service')) {
          continue;
        }

        // 일반 패키지 처리
        final patterns = _getPatterns(config);
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

        // Console 빌드 블록 시작 감지 (# ⚡ 3.5단계: Console 패키지들 빌드)
        if (!inConsoleBuildBlock &&
            line.contains('Console 패키지들 빌드') &&
            line.contains('3.5단계')) {
          inConsoleBuildBlock = true;
          // 먼저 {{#enable_admin}} 태그 추가
          result.add('{{#enable_admin}}');
          // 그 다음 현재 라인(주석 라인) 처리
          final patterns = _getPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add(line);
          continue;
        }

        // Console 빌드 블록 종료 감지 (✅ Console 패키지들 빌드 완료)
        if (inConsoleBuildBlock &&
            line.contains('Console 패키지들 빌드 완료')) {
          final patterns = _getPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add(line);
          result.add('{{/enable_admin}}');
          inConsoleBuildBlock = false;
          continue;
        }

        // Console 빌드 블록 내부 라인 처리
        if (inConsoleBuildBlock) {
          final patterns = _getPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add(line);
          continue;
        }

        // console_router 관련 echo 라인 감지 (단일 라인 조건부 처리)
        if (!inConsoleBuildBlock &&
            line.contains('echo') &&
            line.contains('console_router')) {
          // echo 라인을 조건부로 감싸기
          final patterns = _getPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add('{{#enable_admin}}');
          result.add(line);
          result.add('{{/enable_admin}}');
          continue;
        }

        // Shared 빌드 라인 감지 (블록 전체를 조건부로 감싸기)
        if (!inConsoleBuildBlock &&
            line.contains('echo') &&
            line.contains('Shared') &&
            line.contains('dependBuild:shared')) {
          // Shared 빌드 라인 전체를 조건부 태그로 감싸기
          final patterns = _getPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add('{{#has_serverpod}}$line{{/has_serverpod}}');
          continue;
        }

        // Backend 빌드 라인 감지 (블록 전체를 조건부로 감싸기)
        if (!inConsoleBuildBlock &&
            line.contains('echo') &&
            line.contains('Backend') &&
            line.contains('dependBuild:backend')) {
          // Backend 빌드 라인 전체를 조건부 태그로 감싸기
          final patterns = _getPatterns(config);
          line = TemplateConverter.convertContent(line, patterns);
          result.add('{{#has_serverpod}}$line{{/has_serverpod}}');
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
      final patterns = _getPatterns(config);
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

    // TemplateConverter가 컨텍스트에 맞게 case 변환을 처리하므로
    // 여기서 blanket replacement는 하지 않음
    var finalResult = result.join('\n');

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

      // ignore 목록 항목 추적 및 정적 backend 서비스 항목 필터링
      if (inBuildSelectIgnore && trimmed.startsWith('-')) {
        // 정적 backend 서비스 항목 제거 (조건부로 추가될 것이므로)
        if (trimmed.contains('"serverpod_service"') ||
            trimmed.contains('"openapi_service"') ||
            trimmed.contains('"openapi"') ||
            trimmed.contains('"graphql_service"') ||
            trimmed.contains('"supabase_service"') ||
            trimmed.contains('"firebase_service"')) {
          continue; // 정적 항목은 건너뛰고 조건부로만 추가
        }
      }

      // ignore 목록이 끝나는 시점 감지 (dependsOn:)
      if (inBuildSelectIgnore && trimmed == 'dependsOn:') {
        // dependsOn: 직전에 조건부 항목 추가 (각 조건부 태그를 별도 줄로)
        // ignoreIndent는 "ignore:" 앞의 공백이므로, 리스트 항목을 위해 2칸 더 들여씀
        final itemIndent = '$ignoreIndent  ';
        result
          ..add('$itemIndent{{#has_serverpod}}')
          ..add('$itemIndent- "serverpod_service"')
          ..add('$itemIndent{{/has_serverpod}}')
          ..add('$itemIndent{{#has_openapi}}')
          ..add('$itemIndent- "openapi_service"')
          ..add('$itemIndent- "openapi"')
          ..add('$itemIndent{{/has_openapi}}');
        inBuildSelectIgnore = false;
      }

      result.add(line);
    }

    var finalResult = result.join('\n');

    // 조건부 템플릿 앞의 과도한 공백 제거
    // "  \n  \n  \n  {{#has_serverpod}}" -> "  \n  {{#has_serverpod}}"
    finalResult = finalResult.replaceAllMapped(
      RegExp(r'\n\s*\n\s*\n+(\s+\{\{#)'),
      (match) => '\n${match.group(1)}',
    );

    // 조건부 템플릿 직전의 공백 라인 제거 (2줄 이상의 공백을 1줄로)
    finalResult = finalResult.replaceAllMapped(
      RegExp(r'\n\s*\n(\s+\{\{#)'),
      (match) => '\n${match.group(1)}',
    );

    // workspace 항목 다음의 공백 라인 제거 (조건부 태그 전)
    // "  - item\n  \n{{#" -> "  - item\n{{#"
    finalResult = finalResult.replaceAllMapped(
      RegExp(r'(\n\s+-.+)\n\s*\n(\{\{#)'),
      (match) => '${match.group(1)}\n${match.group(2)}',
    );

    // workspace 항목 다음의 공백 라인 제거 (조건부 종료 태그 전)
    // "  - item\n  \n{{/" -> "  - item\n{{/"
    finalResult = finalResult.replaceAllMapped(
      RegExp(r'(\n\s+-.+)\n\s*\n(\{\{/)'),
      (match) => '${match.group(1)}\n${match.group(2)}',
    );

    // 조건부 템플릿 종료 태그 다음의 공백 라인 제거 (workspace 항목 전)
    // "{{/enable_admin}}\n  \n  -" -> "{{/enable_admin}}\n  -"
    finalResult = finalResult.replaceAllMapped(
      RegExp(r'(\{\{/[^}]+\}\})\n\s*\n(\s+-)'),
      (match) => '${match.group(1)}\n${match.group(2)}',
    );

    // 조건부 템플릿 종료 태그 다음의 공백 라인 제거 (다음 조건부 태그 전)
    // "{{/has_serverpod}}\n  \n  -" -> "{{/has_serverpod}}\n  -"
    finalResult = finalResult.replaceAllMapped(
      RegExp(r'(\{\{/[^}]+\}\})\n\s*\n(\s*)'),
      (match) => '${match.group(1)}\n${match.group(2)}',
    );

    return finalResult;
  }

  /// dependencies 섹션에 조건부 백엔드 패키지 태그 추가 (인라인 형식)
  String _addConditionalDependencyTags(String content) {
    final lines = content.split('\n');
    final result = <String>[];

    // serverpod 관련 패키지들 (첫 번째 그룹과 두 번째 그룹)
    // 첫 번째 그룹: jaspr 관련 (jaspr ~ jaspr_serverpod)
    const firstServerpodGroupEnd = 'jaspr_serverpod:';
    // 두 번째 그룹: serverpod 코어 (serverpod ~ serverpod_serialization)
    // 주의: serverpod_test는 dev_dependencies에서 처리되므로 여기서 제외
    final lastServerpodPackages = [
      'serverpod_serialization:',
    ];

    // dev_dependencies의 jaspr 관련 패키지들 (블록으로 감쌀 패키지들)
    const firstJasprPkg = 'jaspr_builder:';
    const lastJasprPkg = 'jaspr_web_compilers:';

    // dev_dependencies의 serverpod_test (단일 라인 블록)
    const serverpodTestPkg = 'serverpod_test:';

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

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      final trimmed = line.trim();

      // intl 라인에 {{#has_serverpod}} 추가
      if (trimmed.startsWith(intlPkg)) {
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

      // serverpod_serialization (dependencies 두 번째 그룹 종료) 뒤에 {{/has_serverpod}}
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

      // dev_dependencies의 jaspr_builder 시작: 이전 라인에 {{#has_serverpod}} 추가
      if (trimmed.startsWith(firstJasprPkg)) {
        result.add('{{#has_serverpod}}$line');
        continue;
      }

      // dev_dependencies의 jaspr_web_compilers 종료: 라인 끝에 {{/has_serverpod}} 추가
      if (trimmed.startsWith(lastJasprPkg)) {
        line = '$line{{/has_serverpod}}';
        result.add(line);
        continue;
      }

      // dev_dependencies의 serverpod_test: 단일 라인 블록
      if (trimmed.startsWith(serverpodTestPkg)) {
        result.add('{{#has_serverpod}}$line{{/has_serverpod}}');
        continue;
      }

      // skeletonizer 다음에 openapi/graphql 블록 준비
      if (trimmed.startsWith('skeletonizer:')) {
        // 다음 줄에 실제 openapi 패키지가 있는지 확인
        final hasOpenapiPkg =
            i + 1 < lines.length &&
            lines[i + 1].trim().startsWith(firstOpenapiPkg);

        if (hasOpenapiPkg) {
          // openapi 패키지가 있으면 블록 시작만
          line = '$line{{#has_openapi}}';
        }
        // openapi 패키지가 없으면 아무 태그도 추가하지 않음 (빈 조건부 블록 제거)
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

  /// 선택적 feature 보존 (템플릿에 없는 경우)
  ///
  /// 선택적 feature (console 등)가 템플릿에 없으면 brick의 기존 구조를 보존
  Future<Map<String, Directory>> _preserveOptionalFeatures(
    Directory sourceDir,
    Directory targetDir,
    ProjectConfig config,
  ) async {
    final preserved = <String, Directory>{};

    // 선택적 feature 목록 (조건부로 포함되는 feature들)
    final optionalFeatures = <String, String>{
      'console': 'enable_admin', // feature name: condition variable
    };

    for (final entry in optionalFeatures.entries) {
      final featureName = entry.key;
      final condition = entry.value;

      // 소스에 해당 feature가 있는지 확인
      final sourceFeatureDir = Directory(
        path.join(sourceDir.path, featureName),
      );

      // 타겟에 조건부 디렉토리가 있는지 확인
      final conditionalDirName = '{{#$condition}}$featureName{{';
      final targetConditionalDir = Directory(
        path.join(targetDir.path, conditionalDirName),
      );

      // 소스에는 없지만 타겟(brick)에는 있는 경우 → 보존해야 함
      if (!sourceFeatureDir.existsSync() && targetConditionalDir.existsSync()) {
        logger.info(
          '   ⏭️  Preserving optional feature: $featureName (not in template)',
        );

        // 임시 디렉토리에 백업
        final tempDir = Directory.systemTemp.createTempSync('optional_feature_');
        await FileUtils.copyDirectory(
          targetConditionalDir,
          tempDir,
          overwrite: true,
        );
        preserved[featureName] = tempDir;

        logger.detail('   💾 Backed up to: ${tempDir.path}');
      }
    }

    return preserved;
  }

  /// 보존된 선택적 feature 복원
  Future<void> _restoreOptionalFeatures(
    Map<String, Directory> preserved,
    Directory targetDir,
  ) async {
    for (final entry in preserved.entries) {
      final featureName = entry.key;
      final backupDir = entry.value;

      // 조건부 디렉토리 이름 복원 (console → {{#enable_admin}}console{{)
      final conditionalDirName = '{{#${_getConditionForFeature(featureName)}}}'
          '$featureName{{';
      final targetConditionalDir = Directory(
        path.join(targetDir.path, conditionalDirName),
      );

      // 기존 디렉토리가 있으면 삭제 (동기화 과정에서 생성되었을 수 있음)
      if (targetConditionalDir.existsSync()) {
        await targetConditionalDir.delete(recursive: true);
      }

      // 백업에서 복원
      await FileUtils.copyDirectory(backupDir, targetConditionalDir);

      logger.info('   ✅ Restored optional feature: $featureName');

      // 임시 백업 디렉토리 삭제
      await backupDir.delete(recursive: true);
    }
  }

  /// Feature에 해당하는 조건 변수 반환
  String _getConditionForFeature(String featureName) {
    switch (featureName) {
      case 'console':
        return 'enable_admin';
      default:
        return 'unknown';
    }
  }

  /// 선택적 기능 검증
  ///
  /// ENABLE_ADMIN=true인데 console이 없으면 경고
  Future<void> _validateOptionalFeatures(
    Directory templateDir,
    ProjectConfig config,
  ) async {
    // .envrc에서 ENABLE_ADMIN 값 읽기
    final envrcFile = File(path.join(templateDir.path, '.envrc'));
    var enableAdmin = false;

    if (envrcFile.existsSync()) {
      final content = await envrcFile.readAsString();
      final match = RegExp(
        r'export\s+ENABLE_ADMIN="(true|false)"',
      ).firstMatch(content);

      if (match != null) {
        final value = match.group(1);
        enableAdmin = value == 'true';
      }
    }

    // Console feature 검증
    final consoleAppDir = Directory(
      path.join(templateDir.path, 'app', '${config.projectName}_console'),
    );
    final consoleFeatureDir = Directory(
      path.join(templateDir.path, 'feature', 'console'),
    );

    if (enableAdmin) {
      if (!consoleAppDir.existsSync() || !consoleFeatureDir.existsSync()) {
        logger.warn(
          '⚠️  Warning: ENABLE_ADMIN=true but console app/feature not found',
        );
        logger.warn('   Expected locations:');
        if (!consoleAppDir.existsSync()) {
          logger.warn('   - app/${config.projectName}_console (missing)');
        }
        if (!consoleFeatureDir.existsSync()) {
          logger.warn('   - feature/console (missing)');
        }
        logger.warn(
          '   → Existing console templates in brick will be preserved',
        );
        logger.info('');
      }
    } else {
      // ENABLE_ADMIN=false인 경우 정보성 메시지
      if (!consoleAppDir.existsSync() && !consoleFeatureDir.existsSync()) {
        logger.detail('ℹ️  Console feature not present (ENABLE_ADMIN=false)');
        logger.detail(
          '   → Existing console templates in brick will be preserved',
        );
      }
    }
  }

  /// 기존 melos.yaml에서 조건부 블록 추출 (console 관련)
  ///
  /// {{#enable_admin}}로 감싸진 패키지들을 추출하여 보존
  String? _extractConditionalBlocks(String content) {
    final lines = content.split('\n');
    final conditionalLines = <String>[];
    var inEnableAdminBlock = false;

    for (var line in lines) {
      final trimmed = line.trim();

      // enable_admin 블록 시작
      if (trimmed == '{{#enable_admin}}') {
        inEnableAdminBlock = true;
        continue;
      }

      // enable_admin 블록 끝
      if (trimmed == '{{/enable_admin}}') {
        inEnableAdminBlock = false;
        continue;
      }

      // 블록 내부의 패키지 라인 저장
      if (inEnableAdminBlock && trimmed.startsWith('- ')) {
        conditionalLines.add(line);
      }
    }

    return conditionalLines.isNotEmpty ? conditionalLines.join('\n') : null;
  }

  /// 조건부 블록을 병합
  ///
  /// 새로 생성된 melos.yaml에 기존의 console 관련 조건부 블록을 추가
  String _mergeConditionalBlocks(String content, String conditionalBlocks) {
    final lines = content.split('\n');
    final result = <String>[];
    var packagesFound = false;
    var widgetbookFound = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      result.add(line);

      // packages: 섹션 진입 확인
      if (trimmed == 'packages:') {
        packagesFound = true;
        continue;
      }

      // widgetbook 패키지 다음에 console 조건부 블록 삽입
      if (packagesFound &&
          !widgetbookFound &&
          line.contains('_widgetbook') &&
          !conditionalBlocks.isEmpty) {
        // 다음 라인이 조건부 블록이 아니면 삽입
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (!nextLine.startsWith('{{#enable_admin}}')) {
            result.add('{{#enable_admin}}');
            result.add(conditionalBlocks);
            result.add('{{/enable_admin}}');
            widgetbookFound = true;
            logger.detail('   💾 Preserved console packages from existing brick');
          }
        }
      }
    }

    return result.join('\n');
  }
}
