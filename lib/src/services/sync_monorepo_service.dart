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

    // 네트워크별 브릭 동기화 (openapi, graphql, serverpod)
    await _syncNetworkBricks(templateDir, bricksDir, config);

    logger.info('\n${'=' * 60}');
    logger.info('🎉 Monorepo brick synced successfully!');
    logger.info('${'=' * 60}');
  }

  /// 네트워크별 브릭 동기화 (openapi, graphql, serverpod)
  Future<void> _syncNetworkBricks(
    Directory templateDir,
    Directory bricksDir,
    ProjectConfig config,
  ) async {
    // 네트워크 타입별 브릭 매핑
    final networkBricks = {
      'openapi': ['openapi', 'openapi_service'],
      'graphql': ['graphql', 'graphql_service'],
      'serverpod': ['serverpod', 'serverpod_service'],
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

    // 타겟 디렉토리 생성
    targetDir.createSync(recursive: true);

    logger.info('   📋 Updating files from template...');

    // 디렉토리 복사
    await FileUtils.copyDirectory(sourceDir, targetDir, overwrite: true);

    // package 디렉토리의 경우, 네트워크 브릭들은 별도 브릭으로 관리하므로 monorepo에서 제외
    if (dirName == 'package') {
      final networkBricks = [
        'openapi',
        'openapi_service',
        'graphql',
        'graphql_service',
        'serverpod',
        'serverpod_service',
      ];

      for (final brickName in networkBricks) {
        final brickDir = Directory(path.join(targetDir.path, brickName));
        if (brickDir.existsSync()) {
          logger.info('   🗑️  Removing $brickName from monorepo (managed as separate brick)...');
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
  /// Repository와 동일하게 모든 네트워크 타입의 export를 생성
  String _convertMixinsExports(String content) {
    // 이미 조건부 템플릿이 포함되어 있으면 변환하지 않음
    if (content.contains('{{#has_openapi}}') ||
        content.contains('{{#has_serverpod}}') ||
        content.contains('{{#has_graphql}}')) {
      return content;
    }

    // export 문에서 feature/module 이름 추출
    // 예: export 'community_openapi_mixin.dart'; -> community
    final exportPattern = RegExp(
      r'''export\s+['"](\w+)_(openapi|serverpod|graphql)_mixin\.dart['"];?''',
      multiLine: true,
    );
    final match = exportPattern.firstMatch(content);

    if (match == null) {
      // export가 없으면 원본 반환
      return content;
    }

    final prefix = match.group(1) ?? '';

    // 모든 네트워크 타입의 export를 생성
    final buffer = StringBuffer();

    buffer.writeln('{{#has_openapi}}');
    buffer.writeln("export '${prefix}_openapi_mixin.dart';");
    buffer.writeln('{{/has_openapi}}');

    buffer.writeln('{{#has_serverpod}}');
    buffer.writeln("export '${prefix}_serverpod_mixin.dart';");
    buffer.writeln('{{/has_serverpod}}');

    buffer.writeln('{{#has_graphql}}');
    buffer.writeln("export '${prefix}_graphql_mixin.dart';");
    buffer.write('{{/has_graphql}}');

    return buffer.toString();
  }

  /// Repository 파일의 mixin/서비스 사용 패턴을 조건부 템플릿으로 변환
  String _convertRepositoryPatterns(String content) {
    var result = content;

    // 이미 조건부 템플릿이 포함되어 있으면 변환하지 않음
    if (result.contains('{{#has_openapi}}') ||
        result.contains('{{#has_serverpod}}') ||
        result.contains('{{#has_graphql}}')) {
      return result;
    }

    // 먼저 전체 Repository 클래스를 재구성 시도
    final convertedClass = _convertRepositoryClass(result);

    // 변환이 성공했으면 (새로운 템플릿 태그가 포함되어 있으면) 반환
    if (convertedClass.contains('{{#has_openapi}}') ||
        convertedClass.contains('{{#has_serverpod}}') ||
        convertedClass.contains('{{#has_graphql}}')) {
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
    while (i < lines.length && (lines[i].startsWith('import') || lines[i].trim().isEmpty)) {
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
    final daoFields = <String>[];

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
        final match = RegExp(r'with\s+(\w+)(Openapi|Serverpod|Graphql)Mixin').firstMatch(line);
        mixinPrefix = match?.group(1);
      }

      // DAO 필드
      if (line.contains('final') && line.contains('Dao')) {
        final match = RegExp(r'final\s+\w+\s+(_\w+Dao);').firstMatch(line);
        final dao = match?.group(1);
        if (dao != null && !daoFields.contains(dao)) {
          daoFields.add(dao);
        }
      }
    }

    if (className == null || mixinPrefix == null) {
      // 정보를 추출하지 못하면 원본 반환
      return content;
    }

    // 네트워크별 주석 추가
    result.add('');
    result.add('{{#has_serverpod}}/// Serverpod Client를 통해 실제 백엔드 API와 통신{{/has_serverpod}}');
    result.add('{{#has_openapi}}/// REST API를 통해 실제 백엔드와 통신{{/has_openapi}}');
    result.add('{{#has_graphql}}/// GraphQL을 통해 실제 백엔드와 통신{{/has_graphql}}');
    result.add('{{^has_serverpod}}{{^has_openapi}}{{^has_graphql}}/// 메모리에서 데이터를 생성하고 관리{{/has_graphql}}{{/has_openapi}}{{/has_serverpod}}');
    result.add('');

    // 템플릿 생성
    final template = _generateRepositoryTemplate(
      docComment: '',  // 이미 추가됨
      className: className,
      mixinPrefix: mixinPrefix,
      daoFields: daoFields,
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
    required List<String> daoFields,
  }) {
    final buffer = StringBuffer();

    // 문서 주석
    buffer.writeln(docComment.trimRight());

    // 네트워크별 주석
    buffer.writeln('{{#has_serverpod}}/// Serverpod Client를 통해 실제 백엔드 API와 통신{{/has_serverpod}}');
    buffer.writeln('{{#has_openapi}}/// REST API를 통해 실제 백엔드와 통신{{/has_openapi}}');
    buffer.writeln('{{#has_graphql}}/// GraphQL을 통해 실제 백엔드와 통신{{/has_graphql}}');
    buffer.writeln('{{^has_serverpod}}{{^has_openapi}}{{^has_graphql}}/// 메모리에서 데이터를 생성하고 관리{{/has_graphql}}{{/has_openapi}}{{/has_serverpod}}');
    buffer.writeln();

    final interfaceName = 'I$className';
    buffer.writeln('@LazySingleton(as: $interfaceName)');
    buffer.writeln('class $className ');
    buffer.writeln('    {{#has_serverpod}}with ${mixinPrefix}ServerpodMixin{{/has_serverpod}}');
    buffer.writeln('    {{#has_openapi}}with ${mixinPrefix}OpenapiMixin{{/has_openapi}}');
    buffer.writeln('    {{#has_graphql}}with ${mixinPrefix}GraphqlMixin{{/has_graphql}}');
    buffer.writeln('    implements $interfaceName {');

    // Serverpod 블록
    buffer.writeln('  {{#has_serverpod}}');
    buffer.writeln('  /// ${mixinPrefix} Repository 생성자');
    buffer.write('  $className(');
    if (daoFields.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('    this._podService,');
      for (final dao in daoFields) {
        buffer.writeln('    this.$dao,');
      }
      buffer.write('  ');
    }
    buffer.writeln(');');
    buffer.writeln('  final pod.PodService _podService;');
    for (final dao in daoFields) {
      final daoType = dao.substring(1, 2).toUpperCase() + dao.substring(2);
      buffer.writeln('  final $daoType $dao;');
    }
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  pod.Client get client => _podService.client;');
    buffer.writeln();
    for (final dao in daoFields) {
      final daoType = dao.substring(1, 2).toUpperCase() + dao.substring(2);
      final getterName = dao.substring(1);
      buffer.writeln('  @override');
      buffer.writeln('  $daoType get $getterName => $dao;');
      buffer.writeln();
    }
    buffer.writeln('  {{/has_serverpod}}');

    // OpenAPI 블록
    buffer.writeln('  {{#has_openapi}}');
    buffer.writeln('  /// ${mixinPrefix} Repository 생성자');
    buffer.write('  $className(');
    if (daoFields.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('    this._openApiService,');
      for (final dao in daoFields) {
        buffer.writeln('    this.$dao,');
      }
      buffer.write('  ');
    }
    buffer.writeln(');');
    buffer.writeln('  final OpenApiService _openApiService;');
    for (final dao in daoFields) {
      final daoType = dao.substring(1, 2).toUpperCase() + dao.substring(2);
      buffer.writeln('  final $daoType $dao;');
    }
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  OpenApiService get openApiService => _openApiService;');
    buffer.writeln();
    for (final dao in daoFields) {
      final daoType = dao.substring(1, 2).toUpperCase() + dao.substring(2);
      final getterName = dao.substring(1);
      buffer.writeln('  @override');
      buffer.writeln('  $daoType get $getterName => $dao;');
      buffer.writeln();
    }
    buffer.writeln('  {{/has_openapi}}');

    // GraphQL 블록
    buffer.writeln('  {{#has_graphql}}');
    buffer.writeln('  /// ${mixinPrefix} Repository 생성자');
    buffer.writeln('  $className(this._graphQLClient);');
    buffer.writeln('  final GraphQLClient _graphQLClient;');
    buffer.writeln('  ');
    buffer.writeln('  @override');
    buffer.writeln('  GraphQLClient get graphQLClient => _graphQLClient;');
    buffer.writeln('  {{/has_graphql}}');

    // Fallback (no network) 블록
    buffer.writeln('  {{^has_serverpod}}{{^has_openapi}}{{^has_graphql}}');
    buffer.writeln('  /// ${mixinPrefix} Repository 생성자');
    buffer.writeln('  $className();');
    buffer.writeln('  {{/has_graphql}}{{/has_openapi}}{{/has_serverpod}}');
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

    // /// 메모리에서 데이터를 생성하고 관리
    result = result.replaceAllMapped(
      RegExp(r'^(\s*)///\s*메모리에서\s+데이터를\s+생성하고\s+관리\s*$', multiLine: true),
      (match) {
        final indent = match.group(1) ?? '';
        return '${indent}{{^has_serverpod}}{{^has_openapi}}{{^has_graphql}}/// 메모리에서 데이터를 생성하고 관리{{/has_graphql}}{{/has_openapi}}{{/has_serverpod}}';
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
