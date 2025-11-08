import 'dart:io';

import 'package:mason/mason.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// {@template create_monorepo_service}
/// Service for creating new monorepo projects using Mason bricks.
/// {@endtemplate}
class CreateMonorepoService {
  /// {@macro create_monorepo_service}
  CreateMonorepoService({
    required Logger logger,
    MasonGenerator? generator,
  }) : _logger = logger,
       _generator = generator;

  final Logger _logger;
  final MasonGenerator? _generator;

  /// Creates a new monorepo project with the given variables.
  Future<void> create({
    required Map<String, dynamic> variables,
    required Directory outputDirectory,
  }) async {
    final projectName = variables['project_name'] as String;
    final progress = _logger.progress(
      'Creating monorepo project: $projectName',
    );

    try {
      // Get brick path
      final brickPath = await _getBrickPath();
      _logger.detail('Using brick at: $brickPath');

      // Load brick
      final brick = Brick.path(brickPath);
      _logger.detail('Brick loaded: ${brick.name}');

      // Generate using mason
      final generator = _generator ?? await MasonGenerator.fromBrick(brick);

      final target = DirectoryGeneratorTarget(outputDirectory);

      final generatedFiles = await generator.generate(
        target,
        vars: variables,
        logger: _logger,
      );

      progress.complete('Generated ${generatedFiles.length} files');

      // Create .envrc file for future sync operations
      await _createEnvrcFile(
        projectName: projectName,
        variables: variables,
        outputDirectory: outputDirectory,
      );

      // Display success message
      _displaySuccessMessage(
        projectName: projectName,
        outputPath: outputDirectory.path,
      );
    } catch (e, stackTrace) {
      progress.fail('Failed to create project');
      _logger.err('Error: $e');
      _logger.detail('$stackTrace');
      rethrow;
    }
  }

  /// Gets the path to the monorepo brick.
  Future<String> _getBrickPath() async {
    // Try to find brick in the standard location
    final currentDir = Directory.current.path;

    // Check if we're in the bricks repo
    final brickPath = path.join(currentDir, 'bricks', 'monorepo');
    if (Directory(brickPath).existsSync()) {
      return brickPath;
    }

    // Check if brick exists in parent directory
    final parentBrickPath = path.join(currentDir, '..', 'bricks', 'monorepo');
    if (Directory(parentBrickPath).existsSync()) {
      return path.normalize(parentBrickPath);
    }

    // Check if we're inside template/co-bricks
    final templateBrickPath = path.join(
      currentDir,
      '..',
      '..',
      'bricks',
      'monorepo',
    );
    if (Directory(templateBrickPath).existsSync()) {
      return path.normalize(templateBrickPath);
    }

    throw Exception(
      'Could not find monorepo brick. '
      'Please run this command from the bricks repository root or ensure the brick exists at bricks/monorepo/',
    );
  }

  /// Creates an .envrc file in the generated project for future sync operations.
  Future<void> _createEnvrcFile({
    required String projectName,
    required Map<String, dynamic> variables,
    required Directory outputDirectory,
  }) async {
    final projectDir = Directory(path.join(outputDirectory.path, projectName));
    final envrcFile = File(path.join(projectDir.path, '.envrc'));

    // Determine backend type
    String backend = 'openapi';
    if (variables['has_serverpod'] == true) backend = 'serverpod';
    if (variables['has_graphql'] == true) backend = 'graphql';
    if (variables['has_supabase'] == true) backend = 'supabase';
    if (variables['has_firebase'] == true) backend = 'firebase';

    final envrcContent =
        '''
# Project Configuration
export PROJECT_NAME="${variables['project_name']}"
export PROJECT_SHORTCUT="${variables['project_shortcut']}"
export DESCRIPTION="${variables['description']}"

# Organization Configuration
export ORG_NAME="${variables['org_name']}"
export ORG_TLD="${variables['org_tld']}"
export TLD="${variables['tld']}"

# GitHub Configuration
export GITHUB_ORG="${variables['github_org']}"
export GITHUB_REPO="${variables['github_repo']}"
export GITHUB_VISIBILITY="${variables['github_visibility']}"

# Backend Configuration
export BACKEND="$backend"

# Apple Developer Configuration
export APPLE_DEVELOPER_ID="${variables['apple_developer_id']}"
export ITC_TEAM_ID="${variables['itc_team_id']}"
export TEAM_ID="${variables['team_id']}"

# Admin Configuration
export ADMIN_EMAIL="${variables['admin_email']}"
export ENABLE_ADMIN="${variables['enable_admin']}"

# Android Certificate Configuration
export CERT_CN="${variables['cert_cn']}"
export CERT_OU="${variables['cert_ou']}"
export CERT_O="${variables['cert_o']}"
export CERT_L="${variables['cert_l']}"
export CERT_ST="${variables['cert_st']}"
export CERT_C="${variables['cert_c']}"

# Random Project ID
export RANDOM_PROJECT_ID="${variables['random_project_id']}"
''';

    await envrcFile.writeAsString(envrcContent);
    _logger.detail('Created .envrc file');
  }

  /// Displays success message with next steps.
  void _displaySuccessMessage({
    required String projectName,
    required String outputPath,
  }) {
    final projectPath = path.join(outputPath, projectName);

    _logger
      ..info('')
      ..success('🎉 Successfully created monorepo project: $projectName')
      ..info('')
      ..info('📁 Location: $projectPath')
      ..info('')
      ..info('Next steps:')
      ..info('  1. cd $projectName')
      ..info('  2. make start    # Initialize dependencies, git, and GitHub')
      ..info('')
      ..info('The "make start" command will:')
      ..info('  • Install Flutter dependencies')
      ..info('  • Initialize git repository')
      ..info('  • Create GitHub repository')
      ..info('  • Set up initial commit')
      ..info('');
  }
}
