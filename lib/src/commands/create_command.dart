import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason/mason.dart' hide packageVersion;
import 'package:mason_logger/mason_logger.dart';

import '../services/services.dart';

/// {@template create_command}
/// `co_bricks create` command which creates new projects using Mason bricks.
/// {@endtemplate}
class CreateCommand extends Command<int> {
  /// {@macro create_command}
  CreateCommand({
    required Logger logger,
    required MasonGenerator? generator,
  })  : _logger = logger,
        _generator = generator {
    argParser
      ..addOption(
        'type',
        abbr: 't',
        help: 'Type of project to create',
        allowed: ['monorepo', 'app'],
        defaultsTo: 'monorepo',
      )
      ..addOption(
        'name',
        abbr: 'n',
        help: 'Project name (required in non-interactive mode)',
      )
      ..addOption(
        'output-dir',
        abbr: 'o',
        help: 'Output directory for the generated project',
        defaultsTo: '.',
      )
      ..addOption(
        'github-org',
        help: 'GitHub organization name',
      )
      ..addOption(
        'backend',
        help: 'Backend type to use',
        allowed: ['openapi', 'serverpod', 'graphql', 'supabase', 'firebase'],
        defaultsTo: 'serverpod',
      )
      ..addOption(
        'organization',
        help: 'Organization/company name',
      )
      ..addOption(
        'tld',
        help: 'Top-level domain (e.g., com, io, im)',
        defaultsTo: 'com',
      )
      ..addFlag(
        'interactive',
        abbr: 'i',
        help: 'Run in interactive mode (prompts for all values)',
        defaultsTo: true,
        negatable: true,
      );
  }

  @override
  String get description =>
      'Create new projects or features using Mason bricks.';

  @override
  String get name => 'create';

  final Logger _logger;
  final MasonGenerator? _generator;

  @override
  Future<int> run() async {
    final type = argResults!['type'] as String;
    final interactive = argResults!['interactive'] as bool;

    if (type == 'monorepo') {
      return _createMonorepo(interactive: interactive);
    } else if (type == 'app') {
      _logger.err('App creation is not yet implemented.');
      return ExitCode.unavailable.code;
    }

    return ExitCode.success.code;
  }

  Future<int> _createMonorepo({required bool interactive}) async {
    try {
      // Collect variables
      final vars = await _collectVariables(interactive: interactive);

      // Create service and generate project
      final service = CreateMonorepoService(
        logger: _logger,
        generator: _generator,
      );

      final outputDir = argResults!['output-dir'] as String;
      await service.create(
        variables: vars,
        outputDirectory: Directory(outputDir),
      );

      return ExitCode.success.code;
    } catch (e) {
      _logger.err('Failed to create monorepo project: $e');
      return ExitCode.software.code;
    }
  }

  Future<Map<String, dynamic>> _collectVariables({
    required bool interactive,
  }) async {
    final vars = <String, dynamic>{};

    // Project name (required)
    String? projectName = argResults!['name'] as String?;
    if (projectName == null || projectName.isEmpty) {
      if (interactive) {
        projectName = _logger.prompt('Project name:');
      } else {
        throw ArgumentError('Project name is required. Use --name flag or run in interactive mode.');
      }
    }
    vars['project_name'] = projectName;

    // GitHub organization
    String? githubOrg = argResults!['github-org'] as String?;
    if (interactive && (githubOrg == null || githubOrg.isEmpty)) {
      githubOrg = _logger.prompt(
        'GitHub organization:',
        defaultValue: projectName.toLowerCase().replaceAll('_', '-'),
      );
    }
    vars['github_org'] = githubOrg ?? projectName.toLowerCase().replaceAll('_', '-');
    vars['github_repo'] = projectName.toLowerCase().replaceAll('_', '-');

    // Organization/Company name
    String? organization = argResults!['organization'] as String?;
    if (interactive && (organization == null || organization.isEmpty)) {
      organization = _logger.prompt(
        'Organization/Company name:',
        defaultValue: _toTitleCase(projectName),
      );
    }
    vars['org_name'] = organization ?? _toTitleCase(projectName);

    // TLD
    String tld = argResults!['tld'] as String;
    if (interactive) {
      tld = _logger.prompt('Top-level domain:', defaultValue: tld);
    }
    vars['tld'] = tld;
    vars['org_tld'] = 'com';

    // Backend selection
    String backend = argResults!['backend'] as String;
    if (interactive) {
      backend = _logger.chooseOne(
        'Select backend type:',
        choices: ['openapi', 'serverpod', 'graphql', 'supabase', 'firebase'],
        defaultValue: backend,
      );
    }

    // Set backend flags
    vars['has_openapi'] = backend == 'openapi';
    vars['has_serverpod'] = backend == 'serverpod';
    vars['has_graphql'] = backend == 'graphql';
    vars['has_supabase'] = backend == 'supabase';
    vars['has_firebase'] = backend == 'firebase';

    // Default values for other required variables
    vars['description'] = 'A new monorepo project';
    vars['project_shortcut'] = projectName.substring(0, 2).toLowerCase();
    vars['admin_email'] = 'dev@${projectName.toLowerCase()}.$tld';
    vars['enable_admin'] = true;

    // Certificate variables (optional)
    vars['cert_cn'] = organization ?? _toTitleCase(projectName);
    vars['cert_ou'] = 'Development';
    vars['cert_o'] = organization ?? _toTitleCase(projectName);
    vars['cert_l'] = 'Seoul';
    vars['cert_st'] = 'Seoul';
    vars['cert_c'] = 'KR';

    // Apple/iOS variables (can be filled later)
    vars['apple_developer_id'] = '';
    vars['itc_team_id'] = '';
    vars['team_id'] = '';

    return vars;
  }

  String _toTitleCase(String text) {
    return text
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
