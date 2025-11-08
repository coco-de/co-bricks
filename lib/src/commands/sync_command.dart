import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'package:co_bricks/src/services/envrc_service.dart';
import 'package:co_bricks/src/services/sync_app_service.dart';
import 'package:co_bricks/src/services/sync_monorepo_service.dart';

/// {@template sync_command}
///
/// `co_bricks sync`
/// A [Command] to synchronize template projects to bricks
/// {@endtemplate}
class SyncCommand extends Command<int> {
  /// {@macro sync_command}
  SyncCommand({required Logger logger})
      : _logger = logger,
        _syncAppService = SyncAppService(logger),
        _syncMonorepoService = SyncMonorepoService(logger) {
    argParser
      ..addOption(
        'type',
        abbr: 't',
        allowed: ['app', 'monorepo'],
        help: 'Synchronization type (app or monorepo)',
        mandatory: true,
      )
      ..addOption(
        'project-dir',
        abbr: 'd',
        help: 'Project directory (defaults to current directory)',
      );
  }

  @override
  String get description =>
      'Synchronize template projects to bricks based on .envrc configuration';

  @override
  String get name => 'sync';

  final Logger _logger;
  final SyncAppService _syncAppService;
  final SyncMonorepoService _syncMonorepoService;

  @override
  Future<int> run() async {
    try {
      final type = argResults?['type'] as String?;
      final projectDirPath = argResults?['project-dir'] as String?;

      if (type == null) {
        _logger.err('Type is required. Use --type app or --type monorepo');
        return ExitCode.usage.code;
      }

      // 프로젝트 디렉토리 결정
      final projectDir = projectDirPath != null
          ? Directory(projectDirPath)
          : Directory.current;

      if (!projectDir.existsSync()) {
        _logger.err('Project directory does not exist: ${projectDir.path}');
        return ExitCode.noInput.code;
      }

      // .envrc 파일에서 프로젝트 설정 로드
      _logger.info('🔍 Loading project configuration from .envrc...');
      final config = EnvrcService.loadFromProjectDir(projectDir.path);

      _logger.info('   Project: ${config.projectName}');
      _logger.info('   Organization: ${config.orgName}');
      _logger.info('   TLD: ${config.orgTld}');
      _logger.info('   GitHub Org: ${config.githubOrg}');
      _logger.info('   GitHub Repo: ${config.githubRepo}');
      _logger.info('');

      // 타입에 따라 동기화 실행
      switch (type) {
        case 'app':
          await _syncAppService.sync(config, projectDir);
          break;
        case 'monorepo':
          await _syncMonorepoService.sync(config, projectDir);
          break;
        default:
          _logger.err('Invalid type: $type. Use "app" or "monorepo"');
          return ExitCode.usage.code;
      }

      return ExitCode.success.code;
    } on FileSystemException catch (e) {
      _logger.err('File system error: ${e.message}');
      if (e.path != null) {
        _logger.err('Path: ${e.path}');
      }
      return ExitCode.ioError.code;
    } on FormatException catch (e) {
      _logger.err('Configuration error: ${e.message}');
      if (e.source != null) {
        _logger.err('Source: ${e.source}');
      }
      return ExitCode.ioError.code;
    } catch (e, stackTrace) {
      _logger
        ..err('Unexpected error: $e')
        ..err('$stackTrace');
      return ExitCode.software.code;
    }
  }
}

