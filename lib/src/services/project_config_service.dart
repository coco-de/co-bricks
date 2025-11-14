import 'dart:io';

import 'package:co_bricks/src/models/project_config.dart' as model;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// Service for saving and loading project configurations
class ProjectConfigService {
  /// Creates a new [ProjectConfigService]
  ProjectConfigService({
    required Logger logger,
    String? projectsDir,
  })  : _logger = logger,
        _projectsDir = projectsDir ?? 'projects';

  final Logger _logger;
  final String _projectsDir;

  /// Ensures the projects directory exists
  Future<void> ensureProjectsDirectory() async {
    final dir = Directory(_projectsDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      _logger.info('Created projects directory: $_projectsDir');
    }
  }

  /// Gets the file path for a project config
  String getConfigPath(String projectName) {
    return path.join(_projectsDir, '$projectName.json');
  }

  /// Saves a project configuration to a JSON file
  Future<void> saveConfig(model.SavedProjectConfig config) async {
    await ensureProjectsDirectory();

    final configPath = getConfigPath(config.name);
    final file = File(configPath);

    try {
      await file.writeAsString(config.toJsonString());
      _logger.success('Project configuration saved to: $configPath');
    } catch (e) {
      _logger.err('Failed to save project configuration: $e');
      rethrow;
    }
  }

  /// Loads a project configuration from a JSON file
  Future<model.SavedProjectConfig> loadConfig(String projectName) async {
    final configPath = getConfigPath(projectName);
    final file = File(configPath);

    if (!await file.exists()) {
      throw FileSystemException(
        'Project configuration not found: $configPath',
        configPath,
      );
    }

    try {
      final jsonString = await file.readAsString();
      final config = model.SavedProjectConfig.fromJsonString(jsonString);
      _logger.info('Loaded project configuration from: $configPath');
      return config;
    } catch (e) {
      _logger.err('Failed to load project configuration: $e');
      rethrow;
    }
  }

  /// Lists all available project configurations
  Future<List<String>> listConfigs() async {
    final dir = Directory(_projectsDir);
    if (!await dir.exists()) {
      return [];
    }

    try {
      final configs = <String>[];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          final name = path.basenameWithoutExtension(entity.path);
          configs.add(name);
        }
      }
      return configs..sort();
    } catch (e) {
      _logger.err('Failed to list project configurations: $e');
      rethrow;
    }
  }

  /// Deletes a project configuration
  Future<void> deleteConfig(String projectName) async {
    final configPath = getConfigPath(projectName);
    final file = File(configPath);

    if (!await file.exists()) {
      _logger.warn('Project configuration not found: $configPath');
      return;
    }

    try {
      await file.delete();
      _logger.success('Deleted project configuration: $configPath');
    } catch (e) {
      _logger.err('Failed to delete project configuration: $e');
      rethrow;
    }
  }

  /// Checks if a project configuration exists
  Future<bool> configExists(String projectName) async {
    final configPath = getConfigPath(projectName);
    return File(configPath).exists();
  }
}
