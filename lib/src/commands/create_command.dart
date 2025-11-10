import 'dart:io';
import 'dart:math';

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
  }) : _logger = logger,
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
        'project-shortcut',
        help: 'Project shortcut (2-3 characters)',
      )
      ..addOption(
        'description',
        abbr: 'd',
        help: 'Project description',
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
        'github-repo',
        help: 'GitHub repository name',
      )
      ..addOption(
        'github-visibility',
        help: 'GitHub repository visibility (private or public)',
        allowed: ['private', 'public'],
        defaultsTo: 'private',
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
        defaultsTo: 'im',
      )
      ..addOption(
        'org-tld',
        help: 'Organization top-level domain',
        defaultsTo: 'com',
      )
      ..addOption(
        'admin-email',
        help: 'Administrator email address',
      )
      ..addOption(
        'apple-developer-id',
        help: 'Apple Developer ID (email)',
      )
      ..addOption(
        'itc-team-id',
        help: 'App Store Connect Team ID',
      )
      ..addOption(
        'team-id',
        help: 'Developer Portal Team ID',
      )
      ..addOption(
        'cert-cn',
        help: 'Certificate Common Name',
      )
      ..addOption(
        'cert-ou',
        help: 'Certificate Organizational Unit',
      )
      ..addOption(
        'cert-o',
        help: 'Certificate Organization',
      )
      ..addOption(
        'cert-l',
        help: 'Certificate Locality/City',
      )
      ..addOption(
        'cert-st',
        help: 'Certificate State/Province',
      )
      ..addOption(
        'cert-c',
        help: 'Certificate Country (2-letter code)',
      )
      ..addOption(
        'enable-admin',
        help: 'Enable admin functionality (true/false)',
        defaultsTo: 'true',
        allowed: ['true', 'false'],
      )
      ..addFlag(
        'interactive',
        abbr: 'i',
        help: 'Run in interactive mode (prompts for all values)',
        defaultsTo: true,
        negatable: true,
      )
      ..addFlag(
        'auto-start',
        help: 'Automatically run "make start" after project creation',
        defaultsTo: false,
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
      final projectName = vars['project_name'] as String;

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

      // Ask about auto-start in interactive mode
      var autoStart = argResults!['auto-start'] as bool;
      if (interactive && !autoStart) {
        autoStart = _logger.confirm(
          'Run "make start" to initialize the project now?',
          defaultValue: true,
        );
      }
      if (autoStart) {
        final projectPath = Directory('$outputDir/$projectName').absolute.path;
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
        throw ArgumentError(
          'Project name is required. Use --name flag or run in interactive mode.',
        );
      }
    }
    vars['project_name'] = projectName;

    // Project shortcut
    final defaultShortcut = projectName.substring(0, 2).toLowerCase();
    var projectShortcut = argResults!['project-shortcut'] as String?;
    if (interactive && (projectShortcut == null || projectShortcut.isEmpty)) {
      projectShortcut = _logger.prompt(
        'Project shortcut (2-3 characters):',
        defaultValue: defaultShortcut,
      );
    }
    vars['project_shortcut'] = projectShortcut ?? defaultShortcut;

    // Description
    String? description = argResults!['description'] as String?;
    if (interactive && (description == null || description.isEmpty)) {
      description = _logger.prompt(
        'Project description:',
        defaultValue: 'A new monorepo project',
      );
    }
    vars['description'] = description ?? 'A new monorepo project';

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

    // Org TLD
    String orgTld = argResults!['org-tld'] as String;
    if (interactive) {
      orgTld = _logger.prompt('Organization TLD:', defaultValue: orgTld);
    }
    vars['org_tld'] = orgTld;

    // GitHub organization
    String? githubOrg = argResults!['github-org'] as String?;
    if (interactive && (githubOrg == null || githubOrg.isEmpty)) {
      githubOrg = _logger.prompt(
        'GitHub organization:',
        defaultValue: projectName.toLowerCase().replaceAll('_', '-'),
      );
    }
    vars['github_org'] =
        githubOrg ?? projectName.toLowerCase().replaceAll('_', '-');

    // GitHub repository
    String? githubRepo = argResults!['github-repo'] as String?;
    if (interactive && (githubRepo == null || githubRepo.isEmpty)) {
      githubRepo = _logger.prompt(
        'GitHub repository:',
        defaultValue: projectName.toLowerCase().replaceAll('_', '-'),
      );
    }
    vars['github_repo'] =
        githubRepo ?? projectName.toLowerCase().replaceAll('_', '-');

    // GitHub visibility
    String githubVisibility = argResults!['github-visibility'] as String;
    if (interactive) {
      githubVisibility = _logger.chooseOne(
        'GitHub repository visibility:',
        choices: ['private', 'public'],
        defaultValue: githubVisibility,
      );
    }
    vars['github_visibility'] = githubVisibility;

    // Random project ID (auto-generated)
    vars['randomprojectid'] = _generateRandomId();

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

    // Admin email
    String? adminEmail = argResults!['admin-email'] as String?;
    if (interactive && (adminEmail == null || adminEmail.isEmpty)) {
      adminEmail = _logger.prompt(
        'Administrator email:',
        defaultValue: 'dev@${projectName.toLowerCase()}.$tld',
      );
    }
    vars['admin_email'] = adminEmail ?? 'dev@${projectName.toLowerCase()}.$tld';

    // Enable admin
    var enableAdminStr = argResults!['enable-admin'] as String;
    var enableAdmin = enableAdminStr.toLowerCase() == 'true';
    if (interactive) {
      enableAdmin = _logger.confirm(
        'Enable admin functionality?',
        defaultValue: enableAdmin,
      );
    }
    vars['enable_admin'] = enableAdmin;

    // Apple Developer ID
    String? appleDeveloperId = argResults!['apple-developer-id'] as String?;
    if (interactive && (appleDeveloperId == null || appleDeveloperId.isEmpty)) {
      appleDeveloperId = _logger.prompt(
        'Apple Developer ID (email):',
        defaultValue: '',
      );
    }
    vars['apple_developer_id'] = appleDeveloperId ?? '';

    // ITC Team ID
    String? itcTeamId = argResults!['itc-team-id'] as String?;
    if (interactive && (itcTeamId == null || itcTeamId.isEmpty)) {
      itcTeamId = _logger.prompt(
        'App Store Connect Team ID:',
        defaultValue: '',
      );
    }
    vars['itc_team_id'] = itcTeamId ?? '';

    // Team ID
    String? teamId = argResults!['team-id'] as String?;
    if (interactive && (teamId == null || teamId.isEmpty)) {
      teamId = _logger.prompt(
        'Developer Portal Team ID:',
        defaultValue: '',
      );
    }
    vars['team_id'] = teamId ?? '';

    // Certificate variables
    String? certCn = argResults!['cert-cn'] as String?;
    if (interactive && (certCn == null || certCn.isEmpty)) {
      certCn = _logger.prompt(
        'Certificate Common Name:',
        defaultValue: organization ?? _toTitleCase(projectName),
      );
    }
    vars['cert_cn'] = certCn ?? (organization ?? _toTitleCase(projectName));

    String? certOu = argResults!['cert-ou'] as String?;
    if (interactive && (certOu == null || certOu.isEmpty)) {
      certOu = _logger.prompt(
        'Certificate Organizational Unit:',
        defaultValue: 'Production',
      );
    }
    vars['cert_ou'] = certOu ?? 'Production';

    String? certO = argResults!['cert-o'] as String?;
    if (interactive && (certO == null || certO.isEmpty)) {
      certO = _logger.prompt(
        'Certificate Organization:',
        defaultValue: organization ?? _toTitleCase(projectName),
      );
    }
    vars['cert_o'] = certO ?? (organization ?? _toTitleCase(projectName));

    String? certL = argResults!['cert-l'] as String?;
    if (interactive && (certL == null || certL.isEmpty)) {
      certL = _logger.prompt(
        'Certificate Locality/City:',
        defaultValue: 'Seoul',
      );
    }
    vars['cert_l'] = certL ?? 'Seoul';

    String? certSt = argResults!['cert-st'] as String?;
    if (interactive && (certSt == null || certSt.isEmpty)) {
      certSt = _logger.prompt(
        'Certificate State/Province:',
        defaultValue: 'Seoul',
      );
    }
    vars['cert_st'] = certSt ?? 'Seoul';

    String? certC = argResults!['cert-c'] as String?;
    if (interactive && (certC == null || certC.isEmpty)) {
      certC = _logger.prompt(
        'Certificate Country Code (2 letters):',
        defaultValue: 'KR',
      );
    }
    vars['cert_c'] = certC ?? 'KR';

    return vars;
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

  String _toTitleCase(String text) {
    return text
        .split('_')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }
}
