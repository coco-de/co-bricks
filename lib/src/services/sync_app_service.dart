import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:co_bricks/src/services/envrc_service.dart';
import 'package:co_bricks/src/utils/file_utils.dart';
import 'package:co_bricks/src/utils/gitignore_merger.dart';
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
  static Directory? findTemplateProject(
    Directory projectDir,
    String projectName,
  ) {
    // 현재 디렉토리에서 상위로 올라가면서 template/ 디렉토리 찾기
    var currentDir = projectDir;

    while (true) {
      final templateDir = Directory(path.join(currentDir.path, 'template'));
      if (templateDir.existsSync()) {
        // 특정 프로젝트의 app 디렉토리 찾기
        final appDir = Directory(
          path.join(templateDir.path, projectName, 'app'),
        );
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
    ProjectConfig config, {
    bool syncIcons = false,
  }) async {
    logger.info('\n📦 Syncing $brickName brick...');

    final targetBrickDir = Directory(
      path.join(targetBrickPath.path, '__brick__'),
    );

    // syncIcons가 false일 때만 아이콘 백업
    Directory? iconBackupDir;
    if (!syncIcons) {
      iconBackupDir = await _backupAppIconDirectories(targetBrickDir);
    }

    // 기존 __brick__ 내용 삭제
    if (targetBrickDir.existsSync()) {
      logger.info('   🗑️  Removing old content from ${targetBrickDir.path}');
      await FileUtils.deleteDirectory(targetBrickDir);
    }

    // 새 내용 복사
    targetBrickDir.createSync(recursive: true);

    logger.info('   📋 Copying from ${path.basename(sourcePath.path)}...');
    await FileUtils.copyDirectory(
      sourcePath,
      targetBrickDir,
      overwrite: true,
      syncIcons: syncIcons,
    );

    // .envrc 파일 템플릿 변수로 변환
    final sourceEnvrc = File(path.join(sourcePath.path, '.envrc'));
    final targetEnvrc = File(path.join(targetBrickDir.path, '.envrc'));
    if (sourceEnvrc.existsSync()) {
      await _convertEnvrcToTemplate(sourceEnvrc, targetEnvrc);
    }

    // .gitignore 파일들 스마트 병합
    await _mergeGitignoreFiles(sourcePath, targetBrickDir);

    // syncIcons가 false일 때만 백업한 앱 아이콘 복원
    if (!syncIcons && iconBackupDir != null) {
      await _restoreAppIconDirectories(iconBackupDir, targetBrickDir);
    }

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
    convertedFiles = stats['converted']!;
    renamedFiles = stats['renamed']!;

    logger.info('   ✅ Conversion completed:');
    logger.info('      - $convertedFiles files converted');
    logger.info('      - $renamedFiles files renamed');
  }

  /// 파일 처리 (병렬 배치 처리 최적화)
  Future<Map<String, int>> _processFiles(
    Directory dir,
    ProjectConfig config,
    List<ReplacementPattern> patterns,
  ) async {
    var convertedFiles = 0;
    var renamedFiles = 0;

    // 1. 모든 파일/디렉토리 수집 (recursive)
    final files = <File>[];
    final directories = <Directory>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity);
      } else if (entity is Directory) {
        directories.add(entity);
      }
    }

    // 2. 디렉토리명 변환 (깊은 경로부터 처리해야 안전함)
    directories.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final directory in directories) {
      if (FileUtils.excludedDirs.contains(path.basename(directory.path))) {
        continue;
      }
      final originalDirName = path.basename(directory.path);
      final newDirName = FileUtils.convertDirectoryName(
        originalDirName,
        config.projectNames,
      );
      if (newDirName != originalDirName) {
        final newPath = Directory(
          path.join(path.dirname(directory.path), newDirName),
        );
        try {
          await directory.rename(newPath.path);
          renamedFiles++;
        } catch (_) {
          // 디렉토리가 이미 처리됨 (상위 디렉토리 리네임으로 인해)
        }
      }
    }

    // 3. 파일 배치 병렬 처리 + 진행률 출력
    final totalFiles = files.length;
    var processedFiles = 0;
    var lastLoggedProgress = -1;

    const batchSize = 50;
    for (var i = 0; i < files.length; i += batchSize) {
      final end = (i + batchSize < files.length) ? i + batchSize : files.length;
      final batch = files.sublist(i, end);

      final results = await Future.wait(
        batch.map((file) => _processSingleFile(file, config, patterns)),
        eagerError: false,
      );

      convertedFiles += results.where((r) => r['converted'] ?? false).length;
      renamedFiles += results.where((r) => r['renamed'] ?? false).length;
      processedFiles += batch.length;

      // 10% 단위 진행률 출력
      final progress = (processedFiles / totalFiles * 100).toInt();
      final progressTen = (progress ~/ 10) * 10;
      if (progressTen > lastLoggedProgress && progressTen > 0) {
        logger.info(
          '   📊 Progress: $processedFiles/$totalFiles ($progress%)',
        );
        lastLoggedProgress = progressTen;
      }
    }

    return {'converted': convertedFiles, 'renamed': renamedFiles};
  }

  /// 단일 파일 처리 (병렬 처리용)
  Future<Map<String, bool>> _processSingleFile(
    File entity,
    ProjectConfig config,
    List<ReplacementPattern> patterns,
  ) async {
    var converted = false;
    var renamed = false;

    try {
      final originalFileName = path.basename(entity.path);

      // Flutter LLDB 관련 파일 및 ephemeral 파일 제외
      if ((entity.path.contains('ios/Flutter/ephemeral') ||
              entity.path.contains('macos/Flutter/ephemeral')) &&
          (originalFileName == 'flutter_lldb_helper.py' ||
              originalFileName == 'flutter_lldbinit' ||
              originalFileName.endsWith('.xcfilelist'))) {
        return {'converted': false, 'renamed': false};
      }

      // 파일명 변환
      final newFileName = FileUtils.convertFileName(
        originalFileName,
        config.projectNames,
      );

      File fileToProcess = entity;

      if (newFileName != originalFileName) {
        final newPath = File(
          path.join(path.dirname(entity.path), newFileName),
        );
        try {
          await entity.rename(newPath.path);
          renamed = true;
          fileToProcess = newPath;
        } catch (_) {
          // 파일이 이미 처리됨 (디렉토리 리네임으로 인해)
          // 새 경로에서 파일을 찾아봄
          if (newPath.existsSync()) {
            fileToProcess = newPath;
          }
        }
      }

      // 파일 내용 변환
      if (FileUtils.shouldProcessFile(fileToProcess)) {
        if (!await FileUtils.isTextFile(fileToProcess) ||
            !FileUtils.isFileSizeValid(fileToProcess)) {
          return {'converted': converted, 'renamed': renamed};
        }

        final content = await fileToProcess.readAsString();
        final convertedContent = TemplateConverter.convertContent(
          content,
          patterns,
        );

        if (convertedContent != content) {
          await fileToProcess.writeAsString(convertedContent);
          converted = true;
        }
      }
    } catch (_) {
      // 에러 무시 (병렬 처리 안정성 - 디렉토리 리네임으로 인한 경로 변경 등)
    }

    return {'converted': converted, 'renamed': renamed};
  }

  /// App 동기화 실행
  Future<void> sync(
    ProjectConfig config,
    Directory? projectDir, {
    bool syncIcons = false,
  }) async {
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
        syncIcons: syncIcons,
      );
      syncedCount++;
    }

    logger.info('\n${'=' * 60}');
    logger.info('🎉 $syncedCount app brick(s) synced successfully!');
    logger.info('=' * 60);

    logger.info('\n📝 Synced Bricks:');
    for (final syncConfig in syncConfigs) {
      final appTypeLabel =
          {
            'main': 'User app',
            'console': 'Admin console',
            'widgetbook': 'UI showcase',
          }[syncConfig.appType] ??
          syncConfig.appType;
      logger.info('  ✓ bricks/${syncConfig.name}/__brick__/ ($appTypeLabel)');
    }
  }

  /// 앱 아이콘 디렉토리 백업
  Future<Directory?> _backupAppIconDirectories(Directory brickDir) async {
    if (!brickDir.existsSync()) {
      return null;
    }

    // 백업할 아이콘 디렉토리 경로들
    final iconPaths = <String>[];

    // assets/icons 디렉토리
    final assetsIconPath = path.join(brickDir.path, 'assets/icons');
    if (Directory(assetsIconPath).existsSync()) {
      iconPaths.add(assetsIconPath);
    }

    // iOS Assets.xcassets
    final iosIconPath = path.join(brickDir.path, 'ios/Runner/Assets.xcassets');
    if (Directory(iosIconPath).existsSync()) {
      iconPaths.add(iosIconPath);
    }

    // macOS Assets.xcassets
    final macosIconPath = path.join(
      brickDir.path,
      'macos/Runner/Assets.xcassets',
    );
    if (Directory(macosIconPath).existsSync()) {
      iconPaths.add(macosIconPath);
    }

    // Android res 디렉토리와 playstore 아이콘 (main, development, staging flavors)
    final flavors = ['main', 'development', 'staging'];

    for (final flavor in flavors) {
      // res 디렉토리 전체 백업
      final androidResPath = path.join(
        brickDir.path,
        'android/app/src/$flavor/res',
      );
      if (Directory(androidResPath).existsSync()) {
        iconPaths.add(androidResPath);
      }

      // ic_launcher-playstore.png 파일
      final playstoreIconPath = path.join(
        brickDir.path,
        'android/app/src/$flavor/ic_launcher-playstore.png',
      );
      if (File(playstoreIconPath).existsSync()) {
        iconPaths.add(playstoreIconPath);
      }
    }

    // Web 아이콘 파일들
    final webIconFiles = [
      'web/favicon.png',
      'web/icons/Icon-192.png',
      'web/icons/Icon-512.png',
      'web/icons/Icon-maskable-192.png',
      'web/icons/Icon-maskable-512.png',
    ];
    for (final iconFile in webIconFiles) {
      final iconPath = path.join(brickDir.path, iconFile);
      if (File(iconPath).existsSync()) {
        iconPaths.add(iconPath);
      }
    }

    // Web splash 이미지 디렉토리
    final webSplashPath = path.join(brickDir.path, 'web/splash/img');
    if (Directory(webSplashPath).existsSync()) {
      iconPaths.add(webSplashPath);
    }

    // Snap GUI 아이콘
    final snapIconPath = path.join(brickDir.path, 'snap/gui/app_icon.png');
    if (File(snapIconPath).existsSync()) {
      iconPaths.add(snapIconPath);
    }

    // Windows 아이콘
    final windowsIconPath = path.join(
      brickDir.path,
      'windows/runner/resources/app_icon.ico',
    );
    if (File(windowsIconPath).existsSync()) {
      iconPaths.add(windowsIconPath);
    }

    // Firebase 설정 파일들 (flavor별)
    for (final flavor in ['main', 'development', 'staging', 'production']) {
      // Android google-services.json
      final androidFirebasePath = path.join(
        brickDir.path,
        'android/app/src/$flavor/google-services.json',
      );
      if (File(androidFirebasePath).existsSync()) {
        iconPaths.add(androidFirebasePath);
      }

      // iOS GoogleService-Info.plist
      final iosFirebasePath = path.join(
        brickDir.path,
        'ios/Runner/$flavor/GoogleService-Info.plist',
      );
      if (File(iosFirebasePath).existsSync()) {
        iconPaths.add(iosFirebasePath);
      }
    }

    // macOS GoogleService-Info.plist
    final macosFirebasePath = path.join(
      brickDir.path,
      'macos/Runner/GoogleService-Info.plist',
    );
    if (File(macosFirebasePath).existsSync()) {
      iconPaths.add(macosFirebasePath);
    }

    // Firebase 설정 파일들 (루트 레벨 - flavor 없음)
    final rootFirebaseFiles = [
      'android/app/google-services.json',
      'ios/Runner/GoogleService-Info.plist',
    ];
    for (final firebaseFile in rootFirebaseFiles) {
      final firebasePath = path.join(brickDir.path, firebaseFile);
      if (File(firebasePath).existsSync()) {
        iconPaths.add(firebasePath);
      }
    }

    if (iconPaths.isEmpty) {
      return null;
    }

    // 임시 백업 디렉토리 생성
    final tempDir = Directory.systemTemp.createTempSync('icon_backup_');
    logger.info('   📦 Backing up ${iconPaths.length} icon path(s)...');

    // 아이콘 디렉토리/파일들 백업
    for (final iconPath in iconPaths) {
      final relativePath = path.relative(iconPath, from: brickDir.path);
      final backupPath = path.join(tempDir.path, relativePath);

      // 디렉토리인 경우
      if (FileSystemEntity.isDirectorySync(iconPath)) {
        final iconDir = Directory(iconPath);
        final backupDir = Directory(backupPath);
        backupDir.createSync(recursive: true);
        await _copyDirectoryContents(iconDir, backupDir);
      }
      // 파일인 경우
      else if (FileSystemEntity.isFileSync(iconPath)) {
        final iconFile = File(iconPath);
        final backupFile = File(backupPath);
        backupFile.parent.createSync(recursive: true);
        await iconFile.copy(backupFile.path);
      }
    }

    return tempDir;
  }

  /// 앱 아이콘 디렉토리 복원
  Future<void> _restoreAppIconDirectories(
    Directory backupDir,
    Directory brickDir,
  ) async {
    if (!backupDir.existsSync()) {
      return;
    }

    logger.info('   📦 Restoring icon directories...');

    // 백업된 내용을 brick 디렉토리로 복원
    await _copyDirectoryContents(backupDir, brickDir);

    // 백업 디렉토리 삭제
    await backupDir.delete(recursive: true);
  }

  /// 디렉토리 내용 복사 (디렉토리 자체가 아닌 내용만)
  Future<void> _copyDirectoryContents(
    Directory source,
    Directory target,
  ) async {
    await for (final entity in source.list()) {
      if (entity is File) {
        final targetFile = File(
          path.join(target.path, path.basename(entity.path)),
        );
        await entity.copy(targetFile.path);
      } else if (entity is Directory) {
        final targetSubDir = Directory(
          path.join(target.path, path.basename(entity.path)),
        );
        targetSubDir.createSync(recursive: true);
        await _copyDirectoryContents(entity, targetSubDir);
      }
    }
  }

  /// .gitignore 파일들 스마트 병합
  /// - 루트, android, ios 디렉토리의 .gitignore 처리
  /// - Hook 관리 패턴 제거
  /// - 브릭 개선사항 보존
  Future<void> _mergeGitignoreFiles(
    Directory sourceDir,
    Directory targetDir,
  ) async {
    logger.info('   📝 Merging .gitignore files...');

    final merger = GitignoreMerger(logger);
    final gitignoreLocations = [
      '', // 루트
      'android',
      'ios',
    ];

    for (final location in gitignoreLocations) {
      final sourceGitignore = File(
        path.join(sourceDir.path, location, '.gitignore'),
      );
      final targetGitignore = File(
        path.join(targetDir.path, location, '.gitignore'),
      );

      // 두 파일 모두 존재하는 경우만 병합
      if (sourceGitignore.existsSync() && targetGitignore.existsSync()) {
        await merger.merge(
          brickGitignore: targetGitignore,
          templateGitignore: sourceGitignore,
          hookManagedPatterns: HookManagedPatterns.allAppPatterns,
        );
      }
    }
  }

  /// .envrc 파일을 템플릿 변수로 변환
  /// - 키는 유지하고 값만 템플릿 변수로 변환
  /// - 프로젝트별 고유 값들을 Mason 변수로 치환
  Future<void> _convertEnvrcToTemplate(
    File sourceEnvrc,
    File targetEnvrc,
  ) async {
    logger.info('   🔄 Converting .envrc to template...');

    final content = await sourceEnvrc.readAsString();
    final lines = content.split('\n');
    final convertedLines = <String>[];

    for (final line in lines) {
      // 빈 줄이나 주석은 그대로 유지
      if (line.trim().isEmpty || line.trim().startsWith('#')) {
        convertedLines.add(line);
        continue;
      }

      // export 문 파싱
      if (line.startsWith('export ')) {
        final match = RegExp(r"export\s+(\w+)='([^']*)'").firstMatch(line);
        if (match != null) {
          final key = match.group(1)!;
          final value = match.group(2)!;

          // 값을 템플릿 변수로 변환
          final templateValue = _convertValueToTemplate(key, value);
          convertedLines.add("export $key='$templateValue'");
        } else {
          // 파싱 실패 시 원본 유지
          convertedLines.add(line);
        }
      } else {
        convertedLines.add(line);
      }
    }

    await targetEnvrc.writeAsString('${convertedLines.join('\n')}\n');
    logger.info('   ✅ .envrc converted to template');
  }

  /// 환경 변수 값을 템플릿 변수로 변환
  String _convertValueToTemplate(String key, String value) {
    // 프로젝트별로 다른 값들을 템플릿 변수로 치환
    switch (key) {
      case 'GITHUB_ORG':
        return '{{github_org}}';
      case 'GITHUB_REPO':
        return '{{github_repo}}';
      case 'GITHUB_VISIBILITY':
        return '{{github_visibility}}';
      case 'RELEASE_STORE_PASSWORD':
      case 'MATCH_PASSWORD':
      case 'MATCH_KEYCHAIN_PASSWORD':
        // 비밀번호는 플레이스홀더로
        return '{{org_name.paramCase()}}1477!';
      case 'MATCH_KEYCHAIN_NAME':
        return '{{org_name.paramCase()}}';
      case 'APPSTORE_CONNECT_API_KEY_BASE64':
      case 'MATCH_GIT_BASIC_AUTHORIZATION_BASE64':
      case 'FASTLANE_ANDROID_BASE64':
      case 'FASTLANE_IOS_BASE64':
      case 'FIREBASE_DEV_APP_DISTRIBUTION_CREDENTIALS_BASE64':
      case 'FIREBASE_STG_APP_DISTRIBUTION_CREDENTIALS_BASE64':
      case 'FIREBASE_PROD_APP_DISTRIBUTION_CREDENTIALS_BASE64':
      case 'ANDROID_KEY_PROPERTIES_BASE64':
      case 'ANDROID_RELEASE_KEY_BASE64':
      case 'AWS_DEPLOY_SCRIPTS_BASE64':
        // Base64 인코딩된 값들은 플레이스홀더로
        return 'CHANGE_ME_BASE64_ENCODED_VALUE';
      case 'SERVERPOD_PASSWORDS':
        // Serverpod 비밀번호는 플레이스홀더로
        return 'CHANGE_ME_SERVERPOD_PASSWORDS';
      case 'AWS_ACCESS_KEY_ID':
        return '{{aws_access_key_id}}';
      case 'AWS_SECRET_ACCESS_KEY':
        return '{{aws_secret_access_key}}';
      default:
        // Firebase App ID 등 프로젝트별 고유 값들
        if (key.startsWith('FIREBASE_') && key.endsWith('_ID')) {
          return 'CHANGE_ME_FIREBASE_APP_ID';
        }
        // 기타 값은 원본 유지 (주석이나 기본값)
        return value;
    }
  }
}
