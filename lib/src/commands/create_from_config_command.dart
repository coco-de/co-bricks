import 'dart:io';
import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:co_bricks/src/models/project_config.dart' as model;
import 'package:co_bricks/src/services/project_config_service.dart';
import 'package:co_bricks/src/services/services.dart';
import 'package:mason/mason.dart' hide packageVersion;

/// {@template create_from_config_command}
/// `co_bricks create-from-config` command which creates projects from saved JSON configs.
/// {@endtemplate}
class CreateFromConfigCommand extends Command<int> {
  /// {@macro create_from_config_command}
  CreateFromConfigCommand({
    required Logger logger,
    required MasonGenerator? generator,
  }) : _logger = logger,
       _generator = generator {
    argParser
      ..addOption(
        'config',
        abbr: 'c',
        help: 'Name of the saved project configuration to use',
      )
      ..addOption(
        'output-dir',
        abbr: 'o',
        help:
            'Output directory for the generated project (overrides saved value)',
      )
      ..addFlag(
        'list',
        abbr: 'l',
        help: 'List all available saved configurations',
      )
      ..addFlag(
        'auto-start',
        help: 'Override auto-start setting from saved configuration',
      );
  }

  @override
  String get description => 'Create projects from saved JSON configurations.';

  @override
  String get name => 'create-from-config';

  final Logger _logger;
  final MasonGenerator? _generator;

  @override
  Future<int> run() async {
    final configService = ProjectConfigService(logger: _logger);
    final listConfigs = argResults!['list'] as bool;

    // List all configurations if requested
    if (listConfigs) {
      return _listConfigurations(configService);
    }

    // Get config name
    final configName = argResults!['config'] as String?;
    if (configName == null || configName.isEmpty) {
      _logger.err('Please specify a configuration name with --config');
      _logger.info('Use --list to see available configurations');
      return ExitCode.usage.code;
    }

    try {
      // Load configuration
      final config = await configService.loadConfig(configName);
      _logger
        ..info('📋 Loaded configuration for: ${config.name}')
        ..info('   Type: ${config.type}')
        ..info('   Description: ${config.description}');

      // Convert config to variables map
      final backend = config.backend ?? 'serverpod';
      final vars = <String, dynamic>{
        'project_name': config.name,
        'description': config.description,
        'org_name': config.organization,
        'tld': config.tld,
        'subdomain': config.subdomain,
        'org_tld': config.orgTld,
        'github_org': config.githubOrg,
        'github_repo': config.githubRepo,
        'github_visibility': config.githubVisibility,
        'backend': backend,
        // Set backend flags
        'has_openapi': backend == 'openapi',
        'has_serverpod': backend == 'serverpod',
        'has_graphql': backend == 'graphql',
        'has_supabase': backend == 'supabase',
        'has_firebase': backend == 'firebase',
        'enable_admin': config.enableAdmin,
        'admin_email': config.adminEmail ?? 'dev@example.com',
        'apple_developer_id': config.appleDeveloperId ?? 'dev@example.com',
        'itc_team_id': config.itcTeamId ?? '000000000',
        'team_id': config.teamId ?? 'XXXXXXXXXX',
        'cert_cn': config.certCn ?? config.organization,
        'cert_ou': config.certOu ?? 'Production',
        'cert_o': config.certO ?? config.organization,
        'cert_l': config.certL ?? 'Seoul',
        'cert_st': config.certSt ?? 'Seoul',
        'cert_c': config.certC ?? 'KR',
        'randomprojectid': config.randomProjectId ?? _generateRandomId(),
        'randomawsid': config.randomAwsId ?? _generateRandomAwsId(),
        'aws_access_key_id': config.awsAccessKeyId ?? '',
        'aws_secret_access_key': config.awsSecretAccessKey ?? '',
      };

      // Create project based on type
      if (config.type == 'monorepo') {
        return _createMonorepo(
          config: config,
          variables: vars,
        );
      } else {
        _logger.err('Unsupported project type: ${config.type}');
        return ExitCode.unavailable.code;
      }
    } on FileSystemException catch (e) {
      _logger.err('Configuration not found: $e');
      _logger.info('Use --list to see available configurations');
      return ExitCode.usage.code;
    } on Exception catch (e) {
      _logger.err('Failed to create project from configuration: $e');
      return ExitCode.software.code;
    }
  }

  Future<int> _listConfigurations(ProjectConfigService service) async {
    try {
      final configs = await service.listConfigs();

      if (configs.isEmpty) {
        _logger.info('No saved configurations found.');
        _logger.info(
          'Create a configuration with: co-bricks create --save-config',
        );
        return ExitCode.success.code;
      }

      _logger.info('📋 Available project configurations:');
      for (final config in configs) {
        _logger.info('   • $config');
      }
      _logger
        ..info('')
        ..info('Use: co-bricks create-from-config --config <name>');

      return ExitCode.success.code;
    } on Exception catch (e) {
      _logger.err('Failed to list configurations: $e');
      return ExitCode.software.code;
    }
  }

  Future<int> _createMonorepo({
    required model.SavedProjectConfig config,
    required Map<String, dynamic> variables,
  }) async {
    try {
      final service = CreateMonorepoService(
        logger: _logger,
        generator: _generator,
      );

      // Use output-dir from args if provided, otherwise use config value
      final outputDir =
          argResults!['output-dir'] as String? ?? config.outputDir ?? '.';

      _logger.info('🎨 Creating project: ${config.name}...');

      await service.create(
        variables: variables,
        outputDirectory: Directory(outputDir),
      );

      // Handle auto-start
      final autoStart = argResults!.wasParsed('auto-start')
          ? argResults!['auto-start'] as bool
          : config.autoStart;

      if (autoStart) {
        final projectPath = Directory(
          '$outputDir/${config.name}',
        ).absolute.path;
        _logger
          ..info('')
          ..info('🚀 Running "make start" in $projectPath...');

        final result = await Process.run(
          'make',
          ['start'],
          workingDirectory: projectPath,
          runInShell: true,
        );

        if (result.exitCode == 0) {
          _logger.success('✅ Project bootstrapped successfully!');
          if (result.stdout.toString().isNotEmpty) {
            _logger.info(result.stdout.toString());
          }
        } else {
          _logger
            ..warn(
              '⚠️  make start failed with exit code ${result.exitCode}',
            )
            ..info(
              'You can manually run: cd $projectPath && make start',
            );
          if (result.stderr.toString().isNotEmpty) {
            _logger.err(result.stderr.toString());
          }
        }
      }

      return ExitCode.success.code;
    } on Exception catch (e) {
      _logger.err('Failed to create monorepo project: $e');
      return ExitCode.software.code;
    }
  }

  /// Generates a random 4-character ID using lowercase letters and numbers
  String _generateRandomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        4,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// Generates a random 7-digit AWS ID for unique resource naming
  String _generateRandomAwsId() {
    final random = Random();
    return random.nextInt(10000000).toString();
  }
}
